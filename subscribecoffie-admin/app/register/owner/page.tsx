"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useState, useEffect, Suspense } from "react";
import { createBrowserClient } from "@/lib/supabase/client";

function OwnerRegistrationForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const token = searchParams.get("token");

  const [isValidating, setIsValidating] = useState(true);
  const [invitationValid, setInvitationValid] = useState(false);
  const [invitationData, setInvitationData] = useState<{
    email: string;
    company_name: string | null;
    expires_at: string;
  } | null>(null);
  const [validationError, setValidationError] = useState<string | null>(null);

  // Registration form state
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [isRegistering, setIsRegistering] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const supabase = createBrowserClient();

  useEffect(() => {
    if (!token) {
      setValidationError("Missing invitation token");
      setIsValidating(false);
      return;
    }

    validateInvitation();
  }, [token]);

  async function validateInvitation() {
    try {
      setIsValidating(true);
      setValidationError(null);

      const { data, error } = await supabase.rpc("validate_owner_invitation", {
        p_token: token,
      });

      if (error) throw error;

      if (!data.valid) {
        setValidationError(data.error || "Invalid invitation");
        setInvitationValid(false);
      } else {
        setInvitationValid(true);
        setInvitationData({
          email: data.email,
          company_name: data.company_name,
          expires_at: data.expires_at,
        });
        setEmail(data.email); // Pre-fill email
      }
    } catch (err) {
      console.error("Error validating invitation:", err);
      setValidationError(
        err instanceof Error ? err.message : "Failed to validate invitation"
      );
      setInvitationValid(false);
    } finally {
      setIsValidating(false);
    }
  }

  // ✅ ENHANCED VALIDATION
  function validateForm(): string | null {
    // Required fields
    if (!email.trim()) {
      return "Email is required";
    }
    
    if (!fullName.trim()) {
      return "Full name is required";
    }
    
    if (!phone.trim()) {
      return "Phone number is required";
    }
    
    if (!password) {
      return "Password is required";
    }
    
    if (!confirmPassword) {
      return "Please confirm your password";
    }
    
    // Email format validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return "Please enter a valid email address";
    }
    
    // Email must match invitation
    if (invitationData && email.toLowerCase().trim() !== invitationData.email.toLowerCase().trim()) {
      return `Email must match invitation: ${invitationData.email}`;
    }
    
    // Phone format validation (basic)
    const phoneRegex = /^[\d\s\-\+\(\)]{10,}$/;
    if (!phoneRegex.test(phone)) {
      return "Please enter a valid phone number (at least 10 digits)";
    }
    
    // Strong password validation
    if (password.length < 8) {
      return "Password must be at least 8 characters long";
    }
    
    if (!/[A-Z]/.test(password)) {
      return "Password must contain at least one uppercase letter";
    }
    
    if (!/[a-z]/.test(password)) {
      return "Password must contain at least one lowercase letter";
    }
    
    if (!/[0-9]/.test(password)) {
      return "Password must contain at least one number";
    }
    
    // Password confirmation
    if (password !== confirmPassword) {
      return "Passwords do not match";
    }
    
    // Token
    if (!token) {
      return "Missing invitation token";
    }
    
    return null;
  }

  async function handleRegister(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    // ✅ VALIDATION
    const validationError = validateForm();
    if (validationError) {
      setError(validationError);
      return;
    }

    setIsRegistering(true);

    try {
      console.log("🔐 Starting owner registration...");

      // Step 1: Sign up with Supabase Auth
      const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: fullName,
            phone: phone,
          },
        },
      });

      if (signUpError) throw signUpError;

      if (!signUpData.user) {
        throw new Error("Failed to create user account");
      }

      console.log("✅ User created:", signUpData.user.id);

      // Step 2: Redeem invitation (assigns owner role + creates account)
      console.log("🎯 Redeeming invitation...");
      const { data: acceptData, error: acceptError } = await supabase.rpc(
        "redeem_owner_invitation",
        {
          p_token: token,
        }
      );

      if (acceptError) {
        console.error("❌ Accept invitation error:", acceptError);
        
        // ✅ USER-FRIENDLY ERROR MESSAGES
        let friendlyMessage = acceptError.message;
        
        if (acceptError.message.includes("expired")) {
          friendlyMessage = "⏰ This invitation has expired. Please request a new invitation from the administrator.";
        } else if (acceptError.message.includes("already") || acceptError.message.includes("used")) {
          friendlyMessage = "🔒 This invitation has already been used and cannot be redeemed again.";
        } else if (acceptError.message.includes("Email mismatch")) {
          friendlyMessage = `📧 Email mismatch: This invitation was sent to ${invitationData?.email}. Please use the correct email address.`;
        } else if (acceptError.message.includes("Invalid invitation")) {
          friendlyMessage = "❌ Invalid invitation token. Please check your invitation link and try again.";
        } else if (acceptError.message.includes("already has owner role")) {
          friendlyMessage = "✅ You already have an owner account! Please sign in instead.";
        } else if (acceptError.message.includes("Authentication required")) {
          friendlyMessage = "🔐 Authentication failed. Please try again or contact support.";
        }
        
        // ⚠️ SECURITY NOTE: We do NOT delete the user account here.
        // Reason: auth.admin.deleteUser() requires service_role key and should NEVER be called from browser.
        // The user account will remain in auth.users but WITHOUT owner role (safe).
        // Admin can manually cleanup orphaned accounts if needed.
        console.warn("⚠️ User account created but invitation failed. Manual cleanup may be needed for:", signUpData.user.id);
        
        throw new Error(friendlyMessage);
      }

      console.log("✅ Invitation accepted:", acceptData);

      // Step 3: Redirect to appropriate dashboard
      const redirectUrl = acceptData.redirect_url || "/admin/owner/onboarding";
      console.log("🚀 Redirecting to:", redirectUrl);

      // Show success message
      alert(
        "🎉 Registration successful! Welcome to the platform. Redirecting to your dashboard..."
      );

      // Hard redirect to ensure authentication state is refreshed
      window.location.href = redirectUrl;
    } catch (err) {
      console.error("❌ Registration error:", err);
      setError(err instanceof Error ? err.message : "Registration failed");
      setIsRegistering(false);
    }
  }

  if (isValidating) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-50 px-4">
        <div className="w-full max-w-md space-y-6 rounded border border-zinc-200 bg-white p-6 shadow-sm">
          <div className="text-center">
            <div className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-zinc-900 border-r-transparent"></div>
            <p className="mt-4 text-sm text-zinc-500">Validating invitation...</p>
          </div>
        </div>
      </div>
    );
  }

  if (!invitationValid || validationError) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-zinc-50 px-4">
        <div className="w-full max-w-md space-y-6 rounded border border-zinc-200 bg-white p-6 shadow-sm">
          <div className="space-y-1">
            <h1 className="text-2xl font-semibold text-zinc-900">
              Invalid Invitation
            </h1>
            <p className="text-sm text-zinc-500">
              This invitation link is not valid or has expired.
            </p>
          </div>

          <div className="rounded border border-red-200 bg-red-50 p-4">
            <p className="text-sm text-red-700">
              {validationError || "Invalid invitation token"}
            </p>
          </div>

          <div className="text-sm text-zinc-600">
            <p className="mb-2">Possible reasons:</p>
            <ul className="list-disc list-inside space-y-1 text-zinc-500">
              <li>The invitation has already been used</li>
              <li>The invitation has expired</li>
              <li>The invitation was revoked by an administrator</li>
              <li>The link is incorrect or incomplete</li>
            </ul>
          </div>

          <div className="text-sm text-zinc-500">
            Please contact your administrator for a new invitation.
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-50 px-4 py-12">
      <div className="w-full max-w-md space-y-6 rounded border border-zinc-200 bg-white p-6 shadow-sm">
        <div className="space-y-1">
          <h1 className="text-2xl font-semibold text-zinc-900">
            Register as Cafe Owner
          </h1>
          <p className="text-sm text-zinc-500">
            You've been invited to join the platform as a cafe owner.
          </p>
        </div>

        {/* Invitation Info */}
        <div className="rounded border border-blue-200 bg-blue-50 p-4 space-y-1">
          <p className="text-sm font-medium text-blue-900">
            Invitation Details
          </p>
          {invitationData?.company_name && (
            <p className="text-xs text-blue-700">
              Company: {invitationData.company_name}
            </p>
          )}
          <p className="text-xs text-blue-700">
            Email: {invitationData?.email}
          </p>
          <p className="text-xs text-blue-700">
            Expires: {invitationData?.expires_at && new Date(invitationData.expires_at).toLocaleString()}
          </p>
        </div>

        {/* Error Alert */}
        {error && (
          <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            {error}
          </div>
        )}

        {/* Registration Form */}
        <form onSubmit={handleRegister} className="space-y-4">
          <label className="grid gap-1 text-sm text-zinc-700">
            Email
            <input
              type="email"
              value={email}
              readOnly
              className="rounded border border-zinc-300 bg-zinc-100 px-3 py-2 text-sm cursor-not-allowed"
              disabled
            />
            <span className="text-xs text-zinc-500">
              Email is pre-filled from invitation
            </span>
          </label>

          <label className="grid gap-1 text-sm text-zinc-700">
            Full Name <span className="text-red-500">*</span>
            <input
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              required
              placeholder="John Doe"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
              disabled={isRegistering}
            />
          </label>

          <label className="grid gap-1 text-sm text-zinc-700">
            Phone Number
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="+7 (999) 123-45-67"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
              disabled={isRegistering}
            />
          </label>

          <label className="grid gap-1 text-sm text-zinc-700">
            Password <span className="text-red-500">*</span>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={8}
              placeholder="••••••••"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
              disabled={isRegistering}
              autoComplete="new-password"
            />
            <span className="text-xs text-zinc-500">
              Minimum 8 characters
            </span>
          </label>

          <label className="grid gap-1 text-sm text-zinc-700">
            Confirm Password <span className="text-red-500">*</span>
            <input
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              required
              placeholder="••••••••"
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
              disabled={isRegistering}
              autoComplete="new-password"
            />
          </label>

          <div className="rounded border border-zinc-200 bg-zinc-50 p-4">
            <p className="text-xs text-zinc-600">
              By registering, you agree to manage your cafe(s) through this platform
              and comply with our terms of service.
            </p>
          </div>

          <button
            type="submit"
            disabled={isRegistering}
            className="w-full rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isRegistering ? "Registering..." : "Complete Registration"}
          </button>
        </form>

        <div className="text-center text-xs text-zinc-500">
          Already have an account?{" "}
          <a href="/login" className="text-zinc-900 font-medium hover:underline">
            Sign in
          </a>
        </div>
      </div>
    </div>
  );
}

export default function RegisterOwnerPage() {
  return (
    <Suspense fallback={
      <div className="flex min-h-screen items-center justify-center bg-zinc-50">
        <div className="text-zinc-500">Loading...</div>
      </div>
    }>
      <OwnerRegistrationForm />
    </Suspense>
  );
}
