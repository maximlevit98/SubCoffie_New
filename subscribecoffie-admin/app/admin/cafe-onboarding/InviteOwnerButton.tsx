"use client";

import { useState } from "react";

export default function InviteOwnerButton({
  email,
  companyName,
}: {
  email: string;
  companyName: string;
}) {
  const [loading, setLoading] = useState(false);
  const [inviteUrl, setInviteUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const handleCreateInvite = async () => {
    try {
      setLoading(true);
      setError(null);

      const res = await fetch("/api/admin/owner-invites", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email,
          company_name: companyName,
          expires_in_hours: 168, // 7 days
        }),
      });

      const data = await res.json();

      if (!res.ok) {
        throw new Error(data.error || "Failed to create invitation");
      }

      setInviteUrl(data.invite_url);
    } catch (err: any) {
      setError(err.message || "Ошибка создания приглашения");
    } finally {
      setLoading(false);
    }
  };

  const handleCopy = () => {
    if (inviteUrl) {
      navigator.clipboard.writeText(inviteUrl);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  if (inviteUrl) {
    return (
      <div className="space-y-2">
        <div className="rounded border border-green-200 bg-green-50 p-3 text-xs">
          <p className="font-semibold text-green-800 mb-1">✅ Приглашение создано!</p>
          <p className="text-green-700 mb-2 break-all">{inviteUrl}</p>
          <button
            onClick={handleCopy}
            className="rounded bg-green-600 px-3 py-1 text-white text-xs hover:bg-green-700 transition-colors"
          >
            {copied ? "✓ Скопировано!" : "📋 Копировать ссылку"}
          </button>
          <p className="text-green-600 mt-2 text-xs">
            ⚠️ Ссылка показывается только один раз. Отправьте её владельцу.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {error && (
        <p className="rounded border border-red-200 bg-red-50 px-3 py-2 text-xs text-red-700">
          {error}
        </p>
      )}
      <button
        onClick={handleCreateInvite}
        disabled={loading}
        className="rounded bg-blue-600 px-3 py-1.5 text-xs text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        {loading ? "⏳ Создаём..." : "➕ Создать приглашение"}
      </button>
    </div>
  );
}
