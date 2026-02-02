// Stripe Webhook Handler
// Handles payment notifications from Stripe

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@13.10.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});

serve(async (req) => {
  try {
    // Only allow POST requests
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { status: 405, headers: { "Content-Type": "application/json" } }
      );
    }

    const signature = req.headers.get("stripe-signature");
    if (!signature) {
      return new Response(
        JSON.stringify({ error: "Missing stripe-signature header" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get raw body for signature verification
    const body = await req.text();

    // Verify webhook signature
    let event: Stripe.Event;
    try {
      event = stripe.webhooks.constructEvent(body, signature, STRIPE_WEBHOOK_SECRET);
    } catch (err) {
      console.error("Webhook signature verification failed:", err.message);
      return new Response(
        JSON.stringify({ error: "Invalid signature" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log("Stripe webhook received:", {
      type: event.type,
      id: event.id,
    });

    // Create Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Log webhook event
    await supabase.rpc("process_webhook_event", {
      p_provider: "stripe",
      p_event_type: event.type,
      p_event_id: event.id,
      p_payload: event,
    });

    // Process based on event type
    switch (event.type) {
      case "payment_intent.succeeded": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        const transactionId = paymentIntent.metadata.transaction_id;

        if (!transactionId) {
          console.error("No transaction_id in metadata");
          return new Response(
            JSON.stringify({ error: "Missing transaction_id" }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          );
        }

        console.log(`Payment intent succeeded: ${paymentIntent.id}, transaction: ${transactionId}`);

        const { data, error } = await supabase.rpc("confirm_payment", {
          p_transaction_id: transactionId,
          p_provider_transaction_id: paymentIntent.id,
          p_provider_payment_intent_id: paymentIntent.id,
        });

        if (error) {
          console.error("Error confirming payment:", error);
          throw error;
        }

        console.log("Payment confirmed successfully:", data);
        break;
      }

      case "payment_intent.payment_failed": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        const transactionId = paymentIntent.metadata.transaction_id;

        if (!transactionId) {
          console.error("No transaction_id in metadata");
          return new Response(
            JSON.stringify({ error: "Missing transaction_id" }),
            { status: 400, headers: { "Content-Type": "application/json" } }
          );
        }

        console.log(`Payment intent failed: ${paymentIntent.id}, transaction: ${transactionId}`);

        const errorMessage = paymentIntent.last_payment_error?.message || "Payment failed";
        const errorCode = paymentIntent.last_payment_error?.code || "payment_failed";

        const { data, error } = await supabase.rpc("fail_payment", {
          p_transaction_id: transactionId,
          p_error_code: errorCode,
          p_error_message: errorMessage,
        });

        if (error) {
          console.error("Error failing payment:", error);
          throw error;
        }

        console.log("Payment marked as failed:", data);
        break;
      }

      case "payment_intent.canceled": {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        const transactionId = paymentIntent.metadata.transaction_id;

        if (transactionId) {
          await supabase.rpc("fail_payment", {
            p_transaction_id: transactionId,
            p_error_code: "payment_canceled",
            p_error_message: "Payment canceled by user or system",
          });
        }
        break;
      }

      case "charge.refunded": {
        const charge = event.data.object as Stripe.Charge;
        console.log(`Charge refunded: ${charge.id}`);
        // Implement refund logic if needed
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    // Return success response
    return new Response(
      JSON.stringify({ received: true }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error processing webhook:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
