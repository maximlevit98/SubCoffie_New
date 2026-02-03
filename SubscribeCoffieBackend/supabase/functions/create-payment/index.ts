// ⚠️ SECURITY NOTICE ⚠️
// This Edge Function handles REAL MONEY transactions
// Only works when real_payment_integration migration is enabled
// See: SubscribeCoffieBackend/PAYMENT_SECURITY.md
//
// Create Payment Edge Function
// Creates payment intent with YooKassa or Stripe

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@13.10.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const YOOKASSA_SHOP_ID = Deno.env.get("YOOKASSA_SHOP_ID") ?? "";
const YOOKASSA_SECRET_KEY = Deno.env.get("YOOKASSA_SECRET_KEY") ?? "";

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

interface CreatePaymentRequest {
  wallet_id: string;
  amount: number; // In credits (1 credit = 1 RUB)
  payment_method_id?: string;
  description?: string;
  return_url?: string; // For redirects after payment
}

serve(async (req) => {
  try {
    // Only allow POST requests
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { status: 405, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // Parse request body
    const requestData: CreatePaymentRequest = await req.json();
    const { wallet_id, amount, payment_method_id, description, return_url } = requestData;

    // Validate request
    if (!wallet_id || !amount || amount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid request: wallet_id and amount are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Create Supabase client with user's auth token
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    // Create payment intent in database
    const { data: paymentIntent, error: intentError } = await supabase.rpc(
      "create_payment_intent",
      {
        p_wallet_id: wallet_id,
        p_amount: amount,
        p_payment_method_id: payment_method_id,
        p_description: description || "Wallet Top-Up",
      }
    );

    if (intentError) {
      console.error("Error creating payment intent:", intentError);
      throw intentError;
    }

    const transactionId = paymentIntent.transaction_id;
    const provider = paymentIntent.provider;

    console.log("Payment intent created:", {
      transactionId,
      amount,
      provider,
    });

    // Create payment with provider
    let providerPaymentIntent;

    if (provider === "stripe") {
      // Create Stripe Payment Intent
      providerPaymentIntent = await stripe.paymentIntents.create({
        amount: amount * 100, // Stripe uses cents
        currency: "rub",
        metadata: {
          transaction_id: transactionId,
          wallet_id: wallet_id,
        },
        description: description || "Wallet Top-Up",
        automatic_payment_methods: {
          enabled: true,
        },
      });

      console.log("Stripe PaymentIntent created:", providerPaymentIntent.id);

      return new Response(
        JSON.stringify({
          success: true,
          transaction_id: transactionId,
          provider: "stripe",
          client_secret: providerPaymentIntent.client_secret,
          payment_intent_id: providerPaymentIntent.id,
          amount: paymentIntent.amount,
          commission: paymentIntent.commission,
          amount_credited: paymentIntent.amount_credited,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );

    } else if (provider === "yookassa") {
      // Create YooKassa Payment
      const idempotenceKey = crypto.randomUUID();
      
      const yookassaPayment = await fetch("https://api.yookassa.ru/v3/payments", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Idempotence-Key": idempotenceKey,
          "Authorization": `Basic ${btoa(`${YOOKASSA_SHOP_ID}:${YOOKASSA_SECRET_KEY}`)}`,
        },
        body: JSON.stringify({
          amount: {
            value: (amount).toFixed(2),
            currency: "RUB",
          },
          confirmation: {
            type: "redirect",
            return_url: return_url || `${SUPABASE_URL}/wallet-topup-success`,
          },
          capture: true, // Auto-capture
          description: description || "Wallet Top-Up",
          metadata: {
            transaction_id: transactionId,
            wallet_id: wallet_id,
          },
        }),
      });

      if (!yookassaPayment.ok) {
        const errorText = await yookassaPayment.text();
        console.error("YooKassa error:", errorText);
        throw new Error(`YooKassa API error: ${errorText}`);
      }

      providerPaymentIntent = await yookassaPayment.json();

      console.log("YooKassa Payment created:", providerPaymentIntent.id);

      return new Response(
        JSON.stringify({
          success: true,
          transaction_id: transactionId,
          provider: "yookassa",
          confirmation_url: providerPaymentIntent.confirmation.confirmation_url,
          payment_id: providerPaymentIntent.id,
          amount: paymentIntent.amount,
          commission: paymentIntent.commission,
          amount_credited: paymentIntent.amount_credited,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );

    } else {
      // Mock provider (fallback)
      return new Response(
        JSON.stringify({
          success: true,
          transaction_id: transactionId,
          provider: "mock",
          mock: true,
          amount: paymentIntent.amount,
          commission: paymentIntent.commission,
          amount_credited: paymentIntent.amount_credited,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

  } catch (error) {
    console.error("Error creating payment:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
