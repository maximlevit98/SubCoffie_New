"use client";

import { useState, useEffect } from "react";
import { createBrowserClient } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";
import Link from "next/link";

type Account = {
  id: string;
  company_name: string;
  owner_user_id: string;
};

type Cafe = {
  id: string;
  name: string;
  account_id: string;
};

export default function OwnerOnboardingPage() {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);
  const [account, setAccount] = useState<Account | null>(null);
  const [cafes, setCafes] = useState<Cafe[]>([]);
  const [error, setError] = useState<string | null>(null);

  const supabase = createBrowserClient();

  useEffect(() => {
    loadOwnerData();
  }, []);

  async function loadOwnerData() {
    try {
      setIsLoading(true);
      setError(null);

      // Get current user
      const { data: { user }, error: userError } = await supabase.auth.getUser();
      
      if (userError || !user) {
        setError("Not authenticated");
        return;
      }

      // Get owner account
      const { data: accountData, error: accountError } = await supabase
        .from("accounts")
        .select("*")
        .eq("owner_user_id", user.id)
        .single();

      if (accountError && accountError.code !== "PGRST116") {
        throw accountError;
      }

      setAccount(accountData);

      // Get cafes if account exists
      if (accountData) {
        const { data: cafesData, error: cafesError } = await supabase
          .from("cafes")
          .select("*")
          .eq("account_id", accountData.id)
          .order("created_at", { ascending: false });

        if (cafesError) throw cafesError;
        setCafes(cafesData || []);
      }
    } catch (err) {
      console.error("Error loading owner data:", err);
      setError(err instanceof Error ? err.message : "Failed to load data");
    } finally {
      setIsLoading(false);
    }
  }

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-50">
        <div className="text-zinc-500">Loading your account...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-50 px-4">
        <div className="w-full max-w-md rounded border border-red-200 bg-red-50 p-6 shadow-sm">
          <h1 className="text-lg font-semibold text-red-900 mb-2">Error</h1>
          <p className="text-sm text-red-700">{error}</p>
        </div>
      </div>
    );
  }

  if (!account) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-50 px-4">
        <div className="w-full max-w-md rounded border border-yellow-200 bg-yellow-50 p-6 shadow-sm">
          <h1 className="text-lg font-semibold text-yellow-900 mb-2">
            Account Setup Required
          </h1>
          <p className="text-sm text-yellow-700 mb-4">
            Your owner account hasn't been created yet. Please contact support.
          </p>
          <Link
            href="/admin/owner/dashboard"
            className="inline-block rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
          >
            Go to Dashboard
          </Link>
        </div>
      </div>
    );
  }

  // If owner has cafes, redirect to dashboard
  if (cafes.length > 0) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-50 px-4">
        <div className="w-full max-w-md space-y-4 rounded border border-zinc-200 bg-white p-6 shadow-sm">
          <div>
            <h1 className="text-2xl font-semibold text-zinc-900">
              Welcome Back!
            </h1>
            <p className="text-sm text-zinc-500 mt-1">
              You already have {cafes.length} cafe{cafes.length > 1 ? "s" : ""} set up.
            </p>
          </div>

          <div className="rounded border border-green-200 bg-green-50 p-4">
            <p className="text-sm font-medium text-green-900">
              ✅ Your account is active
            </p>
            <p className="text-xs text-green-700 mt-1">
              Company: {account.company_name}
            </p>
          </div>

          <div className="space-y-2">
            <Link
              href="/admin/owner/dashboard"
              className="block w-full rounded bg-zinc-900 px-4 py-2 text-center text-sm font-medium text-white hover:bg-zinc-800"
            >
              Go to Dashboard
            </Link>
            <Link
              href="/admin/owner/cafes/new"
              className="block w-full rounded border border-zinc-300 px-4 py-2 text-center text-sm font-medium text-zinc-700 hover:bg-zinc-50"
            >
              Add Another Cafe
            </Link>
          </div>
        </div>
      </div>
    );
  }

  // Onboarding flow for new owners without cafes
  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-50 px-4 py-12">
      <div className="w-full max-w-2xl space-y-6">
        {/* Welcome Header */}
        <div className="text-center space-y-2">
          <h1 className="text-3xl font-semibold text-zinc-900">
            Welcome to the Platform! 🎉
          </h1>
          <p className="text-lg text-zinc-600">
            Let's get your cafe set up in just a few steps.
          </p>
        </div>

        {/* Account Info */}
        <div className="rounded border border-zinc-200 bg-white p-6 shadow-sm">
          <div className="flex items-center gap-3 mb-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-green-100">
              <svg
                className="h-6 w-6 text-green-600"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M5 13l4 4L19 7"
                />
              </svg>
            </div>
            <div>
              <h2 className="text-lg font-semibold text-zinc-900">
                Your Account is Active
              </h2>
              <p className="text-sm text-zinc-500">
                Company: {account.company_name}
              </p>
            </div>
          </div>
        </div>

        {/* Next Steps */}
        <div className="rounded border border-zinc-200 bg-white p-6 shadow-sm space-y-4">
          <h2 className="text-lg font-semibold text-zinc-900">Next Steps</h2>

          <div className="space-y-4">
            {/* Step 1 */}
            <div className="flex gap-4">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-zinc-900 text-sm font-semibold text-white">
                1
              </div>
              <div className="flex-1">
                <h3 className="font-medium text-zinc-900">Create Your First Cafe</h3>
                <p className="text-sm text-zinc-600 mt-1">
                  Add your cafe details, location, and operating hours.
                </p>
                <Link
                  href="/admin/owner/cafes/new"
                  className="mt-3 inline-block rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
                >
                  Create Cafe →
                </Link>
              </div>
            </div>

            {/* Step 2 */}
            <div className="flex gap-4 opacity-60">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-zinc-200 text-sm font-semibold text-zinc-600">
                2
              </div>
              <div className="flex-1">
                <h3 className="font-medium text-zinc-700">Build Your Menu</h3>
                <p className="text-sm text-zinc-500 mt-1">
                  Add menu items, categories, and pricing.
                </p>
                <p className="text-xs text-zinc-400 mt-2">
                  Available after creating your cafe
                </p>
              </div>
            </div>

            {/* Step 3 */}
            <div className="flex gap-4 opacity-60">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-zinc-200 text-sm font-semibold text-zinc-600">
                3
              </div>
              <div className="flex-1">
                <h3 className="font-medium text-zinc-700">Submit for Review</h3>
                <p className="text-sm text-zinc-500 mt-1">
                  Complete the publication checklist and submit your cafe for approval.
                </p>
                <p className="text-xs text-zinc-400 mt-2">
                  Available after setting up your menu
                </p>
              </div>
            </div>

            {/* Step 4 */}
            <div className="flex gap-4 opacity-60">
              <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-zinc-200 text-sm font-semibold text-zinc-600">
                4
              </div>
              <div className="flex-1">
                <h3 className="font-medium text-zinc-700">Go Live!</h3>
                <p className="text-sm text-zinc-500 mt-1">
                  Once approved, your cafe will be visible to customers.
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Help Section */}
        <div className="rounded border border-blue-200 bg-blue-50 p-4">
          <h3 className="text-sm font-medium text-blue-900 mb-2">
            Need Help?
          </h3>
          <p className="text-xs text-blue-700 mb-3">
            Our team is here to help you get started. Contact us if you have any questions.
          </p>
          <div className="flex gap-2">
            <a
              href="mailto:support@example.com"
              className="text-xs text-blue-800 hover:underline font-medium"
            >
              Email Support
            </a>
            <span className="text-xs text-blue-600">•</span>
            <a
              href="/admin/owner/settings"
              className="text-xs text-blue-800 hover:underline font-medium"
            >
              Account Settings
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
