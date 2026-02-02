// YooKassa Webhook Handler
// Handles payment notifications from YooKassa

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface YooKassaPayment {
  id: string;
  status: "pending" | "waiting_for_capture" | "succeeded" | "canceled";
  amount: {
    value: string;
    currency: string;
  };
  metadata?: {
    transaction_id: string;
    user_id: string;
  };
  payment_method?: {
    type: string;
    id: string;
    saved: boolean;
    card?: {
      first6: string;
      last4: string;
      expiry_month: string;
      expiry_year: string;
      card_type: string;
    };
  };
  created_at: string;
  captured_at?: string;
  cancellation_details?: {
    party: string;
    reason: string;
  };
}

interface YooKassaWebhookEvent {
  type: "notification";
  event: "payment.succeeded" | "payment.waiting_for_capture" | "payment.canceled" | "refund.succeeded";
  object: YooKassaPayment;
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

    // Parse webhook payload
    const webhookEvent: YooKassaWebhookEvent = await req.json();
    
    console.log("YooKassa webhook received:", {
      event: webhookEvent.event,
      paymentId: webhookEvent.object.id,
      status: webhookEvent.object.status,
    });

    // Create Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Log webhook event
    await supabase.rpc("process_webhook_event", {
      p_provider: "yookassa",
      p_event_type: webhookEvent.event,
      p_event_id: webhookEvent.object.id,
      p_payload: webhookEvent,
    });

    // Process based on event type
    const payment = webhookEvent.object;
    const transactionId = payment.metadata?.transaction_id;

    if (!transactionId) {
      console.error("No transaction_id in metadata");
      return new Response(
        JSON.stringify({ error: "Missing transaction_id" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    switch (webhookEvent.event) {
      case "payment.succeeded": {
        // Payment successful - credit wallet
        console.log(`Payment succeeded: ${payment.id}, transaction: ${transactionId}`);
        
        const { data, error } = await supabase.rpc("confirm_payment", {
          p_transaction_id: transactionId,
          p_provider_transaction_id: payment.id,
          p_provider_payment_intent_id: payment.id,
        });

        if (error) {
          console.error("Error confirming payment:", error);
          throw error;
        }

        console.log("Payment confirmed successfully:", data);
        break;
      }

      case "payment.canceled": {
        // Payment canceled - mark as failed
        console.log(`Payment canceled: ${payment.id}, transaction: ${transactionId}`);
        
        const reason = payment.cancellation_details?.reason || "Unknown reason";
        
        const { data, error } = await supabase.rpc("fail_payment", {
          p_transaction_id: transactionId,
          p_error_code: "payment_canceled",
          p_error_message: `Payment canceled: ${reason}`,
        });

        if (error) {
          console.error("Error failing payment:", error);
          throw error;
        }

        console.log("Payment marked as failed:", data);
        break;
      }

      case "payment.waiting_for_capture": {
        // Payment authorized but not captured yet (for two-step payments)
        console.log(`Payment waiting for capture: ${payment.id}`);
        // For wallet top-ups, we typically use one-step payments (auto-capture)
        // If needed, implement capture logic here
        break;
      }

      case "refund.succeeded": {
        // Refund processed successfully
        console.log(`Refund succeeded: ${payment.id}`);
        // Implement refund logic if needed
        break;
      }

      default:
        console.warn(`Unhandled event type: ${webhookEvent.event}`);
    }

    // Return success response
    return new Response(
      JSON.stringify({ success: true }),
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
