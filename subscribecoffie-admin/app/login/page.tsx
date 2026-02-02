"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { createBrowserClient } from "@/lib/supabase/client";

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const validate = () => {
    if (!email.trim() || !emailRegex.test(email.trim())) {
      return "Введите корректный email.";
    }
    if (password.length < 8) {
      return "Пароль должен быть не короче 8 символов.";
    }
    return null;
  };

  const handleSignIn = async () => {
    setError(null);
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }

    setIsLoading(true);
    try {
      console.log('🔐 Starting sign in...');
      const supabase = createBrowserClient();
      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });

      if (signInError) {
        console.error('❌ Sign in error:', signInError);
        setError(signInError.message);
        setIsLoading(false);
        return;
      }

      if (!data?.user) {
        console.error('❌ No user data returned');
        setError("Не удалось получить данные пользователя");
        setIsLoading(false);
        return;
      }

      console.log('✅ User signed in:', data.user.id, data.user.email);

      // Fetch user role directly from database
      console.log('🔍 Fetching user role...');
      const { data: roleData, error: roleError } = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', data.user.id)
        .single();

      if (roleError) {
        console.error('❌ Role fetch error:', roleError);
        console.log('⚠️ Defaulting to admin dashboard');
        // Default to admin dashboard if role not found
        window.location.href = "/admin/dashboard";
        return;
      }

      console.log('✅ Role fetched:', roleData?.role);

      if (roleData?.role === 'owner') {
        console.log('🏢 Redirecting to owner dashboard');
        window.location.href = "/admin/owner/dashboard";
      } else {
        console.log('📊 Redirecting to admin dashboard');
        window.location.href = "/admin/dashboard";
      }
    } catch (err) {
      console.error('❌ Sign in error:', err);
      setError(err instanceof Error ? err.message : "Не удалось выполнить вход.");
      setIsLoading(false);
    }
  };

  const handleSignUp = async () => {
    setError(null);
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }

    setIsLoading(true);
    try {
      const supabase = createBrowserClient();
      const { data, error: signUpError } = await supabase.auth.signUp({
        email: email.trim(),
        password,
      });

      if (signUpError) {
        setError(signUpError.message);
        setIsLoading(false);
        return;
      }

      if (!data?.user) {
        setError("Не удалось создать пользователя");
        setIsLoading(false);
        return;
      }

      // Fetch user role directly from database
      const { data: roleData, error: roleError } = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', data.user.id)
        .single();

      if (roleError) {
        console.error('Role fetch error:', roleError);
        // Default to admin dashboard if role not found
        window.location.href = "/admin/dashboard";
        return;
      }

      if (roleData?.role === 'owner') {
        window.location.href = "/admin/owner/dashboard";
      } else {
        window.location.href = "/admin/dashboard";
      }
    } catch (err) {
      console.error('Sign up error:', err);
      setError(err instanceof Error ? err.message : "Не удалось создать аккаунт.");
      setIsLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-50 px-4">
      <div className="w-full max-w-md space-y-6 rounded border border-zinc-200 bg-white p-6 shadow-sm">
        <div className="space-y-1">
          <h1 className="text-2xl font-semibold text-zinc-900">
            Вход в админку
          </h1>
          <p className="text-sm text-zinc-500">
            Введите email и пароль, чтобы продолжить.
          </p>
        </div>
        {error && (
          <div className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            {error}
          </div>
        )}
        <div className="space-y-4">
          <label className="grid gap-1 text-sm text-zinc-700">
            Email
            <input
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
              placeholder="admin@coffie.local"
              disabled={isLoading}
              autoComplete="email"
            />
          </label>
          <label className="grid gap-1 text-sm text-zinc-700">
            Пароль
            <input
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="rounded border border-zinc-300 px-3 py-2 text-sm"
              placeholder="••••••••"
              disabled={isLoading}
              autoComplete="current-password"
            />
          </label>
          <div className="grid gap-2">
            <button
              type="button"
              onClick={handleSignIn}
              disabled={isLoading}
              className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-60"
            >
              {isLoading ? "Входим..." : "Войти"}
            </button>
            <button
              type="button"
              onClick={handleSignUp}
              disabled={isLoading}
              className="rounded border border-zinc-300 px-4 py-2 text-sm font-medium text-zinc-700 disabled:opacity-60"
            >
              {isLoading ? "Создаём..." : "Создать админ-аккаунт (dev)"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
