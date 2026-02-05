// Supabase Edge Function: Create Payment Intent
// Path: supabase/functions/create-payment-intent/index.ts
// Purpose: Create payment intent with Stripe/YooKassa with idempotency

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import Stripe from 'https://esm.sh/stripe@14.0.0';

// Environment variables
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!;
const YOOKASSA_SHOP_ID = Deno.env.get('YOOKASSA_SHOP_ID');
const YOOKASSA_SECRET_KEY = Deno.env.get('YOOKASSA_SECRET_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: '2023-10-16',
});

interface CreatePaymentIntentRequest {
  walletId: string;
  amount: number; // Credits (not cents)
  paymentMethodId?: string;
  idempotencyKey: string; // Required! Format: {userId}_{timestamp}_{uuid}
  provider?: 'stripe' | 'yookassa'; // Optional, will use active provider if not specified
}

interface CreatePaymentIntentResponse {
  success: boolean;
  transactionId: string;
  amount: number;
  commission: number;
  amountCredited: number;
  provider: string;
  clientSecret: string | null; // For client-side confirmation
  providerPaymentIntentId: string;
  status: string;
  message?: string;
}

serve(async (req) => {
  try {
    // ✅ Only accept POST requests
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    // ✅ Get user from Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response('Missing authorization', { status: 401 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: {
        headers: { Authorization: authHeader },
      },
    });

    // Verify user is authenticated
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response('Unauthorized', { status: 401 });
    }

    // Parse request
    const requestData: CreatePaymentIntentRequest = await req.json();

    // ✅ Validate idempotency key
    if (!requestData.idempotencyKey || requestData.idempotencyKey.length < 20) {
      return new Response(
        JSON.stringify({
          error: 'Invalid idempotency_key. Format: {userId}_{timestamp}_{uuid}',
        }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // ✅ Check rate limit
    const { data: rateLimit } = await supabase.rpc('check_payment_rate_limit', {
      p_user_id: user.id,
    });

    if (rateLimit && !rateLimit.is_allowed) {
      return new Response(
        JSON.stringify({
          error: 'Rate limit exceeded. Please try again later.',
          attempts_remaining: 0,
          window_resets_at: rateLimit.window_resets_at,
        }),
        { status: 429, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // ✅ Check if transaction already exists (idempotency)
    const { data: existingTx, error: checkError } = await supabase
      .from('payment_transactions')
      .select('id, status, amount_credits, commission_credits, metadata, provider_payment_intent_id')
      .eq('idempotency_key', requestData.idempotencyKey)
      .maybeSingle();

    if (existingTx) {
      console.log(`Idempotent request: returning existing transaction ${existingTx.id}`);
      
      // Return existing transaction
      return new Response(
        JSON.stringify({
          success: true,
          transactionId: existingTx.id,
          amount: existingTx.amount_credits,
          commission: existingTx.commission_credits,
          amountCredited: existingTx.amount_credits - existingTx.commission_credits,
          provider: existingTx.metadata?.provider || 'mock',
          clientSecret: existingTx.metadata?.client_secret || null,
          providerPaymentIntentId: existingTx.provider_payment_intent_id,
          status: existingTx.status,
          message: 'Idempotent: Transaction already exists',
        } as CreatePaymentIntentResponse),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // ✅ Get active payment provider
    const { data: providerName } = await supabase.rpc('get_active_payment_provider');
    const provider = requestData.provider || providerName || 'mock';

    console.log(`Creating payment intent with provider: ${provider}`);

    // ✅ Create payment based on provider
    let response: CreatePaymentIntentResponse;

    if (provider === 'stripe') {
      response = await createStripePaymentIntent(
        supabase,
        user.id,
        requestData
      );
    } else if (provider === 'yookassa') {
      response = await createYooKassaPayment(
        supabase,
        user.id,
        requestData
      );
    } else {
      // Mock payment (instant success)
      response = await createMockPayment(supabase, requestData);
    }

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Create payment intent error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});

async function createStripePaymentIntent(
  supabase: any,
  userId: string,
  request: CreatePaymentIntentRequest
): Promise<CreatePaymentIntentResponse> {
  // ✅ Get wallet and calculate commission
  const { data: commissionData } = await supabase.rpc('calculate_commission', {
    p_amount: request.amount,
    p_transaction_type: 'topup',
    p_wallet_type: 'citypass', // Will be updated when we get wallet info
  });

  const commission = commissionData || Math.floor(request.amount * 0.07);
  const amountCredited = request.amount - commission;

  // ✅ Create Stripe payment intent
  const paymentIntent = await stripe.paymentIntents.create(
    {
      amount: request.amount * 100, // Convert credits to cents (1 credit = 1 ruble = 100 kopeks)
      currency: 'rub',
      payment_method: request.paymentMethodId,
      confirmation_method: 'manual',
      confirm: false,
      metadata: {
        wallet_id: request.walletId,
        user_id: userId,
        idempotency_key: request.idempotencyKey,
      },
      description: `Wallet Top-Up: ${request.amount} credits`,
    },
    {
      idempotencyKey: request.idempotencyKey, // ✅ Stripe-level idempotency
    }
  );

  // ✅ Create transaction record in database
  const { data: transaction, error: dbError } = await supabase
    .from('payment_transactions')
    .insert({
      user_id: userId,
      wallet_id: request.walletId,
      amount_credits: request.amount,
      commission_credits: commission,
      transaction_type: 'topup',
      payment_method_id: request.paymentMethodId,
      status: 'pending',
      idempotency_key: request.idempotencyKey,
      provider_payment_intent_id: paymentIntent.id,
      metadata: {
        provider: 'stripe',
        client_secret: paymentIntent.client_secret,
      },
    })
    .select()
    .single();

  if (dbError) {
    // Cancel Stripe payment intent if DB insert fails
    await stripe.paymentIntents.cancel(paymentIntent.id);
    throw dbError;
  }

  return {
    success: true,
    transactionId: transaction.id,
    amount: request.amount,
    commission: commission,
    amountCredited: amountCredited,
    provider: 'stripe',
    clientSecret: paymentIntent.client_secret,
    providerPaymentIntentId: paymentIntent.id,
    status: 'pending',
  };
}

async function createYooKassaPayment(
  supabase: any,
  userId: string,
  request: CreatePaymentIntentRequest
): Promise<CreatePaymentIntentResponse> {
  // TODO: Implement YooKassa integration
  // https://yookassa.ru/developers/api#create_payment
  
  throw new Error('YooKassa integration not yet implemented');
  
  /*
  Example YooKassa API call:
  
  const response = await fetch('https://api.yookassa.ru/v3/payments', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Idempotence-Key': request.idempotencyKey,
      'Authorization': 'Basic ' + btoa(`${YOOKASSA_SHOP_ID}:${YOOKASSA_SECRET_KEY}`),
    },
    body: JSON.stringify({
      amount: {
        value: request.amount.toFixed(2),
        currency: 'RUB',
      },
      confirmation: {
        type: 'redirect',
        return_url: 'https://your-app.com/payment-success',
      },
      capture: true,
      description: `Wallet Top-Up: ${request.amount} credits`,
      metadata: {
        wallet_id: request.walletId,
        user_id: userId,
      },
    }),
  });
  
  const payment = await response.json();
  
  // Store in DB similar to Stripe
  // Return confirmation URL for redirect
  */
}

async function createMockPayment(
  supabase: any,
  request: CreatePaymentIntentRequest
): Promise<CreatePaymentIntentResponse> {
  // ✅ Use existing mock_wallet_topup RPC with idempotency
  const { data, error } = await supabase.rpc('mock_wallet_topup', {
    p_wallet_id: request.walletId,
    p_amount: request.amount,
    p_payment_method_id: request.paymentMethodId,
    p_idempotency_key: request.idempotencyKey,
  });

  if (error) {
    throw error;
  }

  return {
    success: true,
    transactionId: data.transaction_id,
    amount: data.amount,
    commission: data.commission,
    amountCredited: data.amount_credited,
    provider: 'mock',
    clientSecret: null,
    providerPaymentIntentId: data.provider_transaction_id,
    status: 'completed', // Mock payments complete instantly
    message: 'Mock payment completed instantly',
  };
}

// ============================================================================
// Testing
// ============================================================================

/*
Test locally:

supabase functions serve create-payment-intent --env-file .env.local

curl -X POST http://localhost:54321/functions/v1/create-payment-intent \
  -H "Authorization: Bearer YOUR_SUPABASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "walletId": "your-wallet-uuid",
    "amount": 1000,
    "idempotencyKey": "user123_1643723456789_x9y8z7w6-v5u4-3210-fedc-ba0987654321"
  }'

Test idempotency (same key should return same transaction):

curl -X POST http://localhost:54321/functions/v1/create-payment-intent \
  -H "Authorization: Bearer YOUR_SUPABASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "walletId": "your-wallet-uuid",
    "amount": 1000,
    "idempotencyKey": "user123_1643723456789_x9y8z7w6-v5u4-3210-fedc-ba0987654321"
  }'

Test rate limiting (run 11 times):

for i in {1..11}; do
  curl -X POST http://localhost:54321/functions/v1/create-payment-intent \
    -H "Authorization: Bearer YOUR_SUPABASE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"walletId\": \"your-wallet-uuid\",
      \"amount\": 100,
      \"idempotencyKey\": \"user123_$(date +%s)_$(uuidgen)\"
    }"
done
# 11th request should fail with 429 Rate Limit Exceeded
*/
