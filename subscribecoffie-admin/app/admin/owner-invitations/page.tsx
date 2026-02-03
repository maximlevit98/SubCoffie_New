"use client";

import { useState, useEffect } from "react";
import { createBrowserClient } from "@/lib/supabase/client";
import Link from "next/link";

type Invitation = {
  id: string;
  email: string;
  company_name: string | null;
  cafe_id: string | null;
  status: string;
  expires_at: string;
  created_at: string;
  accepted_at: string | null;
  accepted_by_user_id: string | null;
};

type Cafe = {
  id: string;
  name: string;
};

export default function OwnerInvitationsPage() {
  const [invitations, setInvitations] = useState<Invitation[]>([]);
  const [cafes, setCafes] = useState<Cafe[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Create invitation form
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [email, setEmail] = useState("");
  const [companyName, setCompanyName] = useState("");
  const [selectedCafeId, setSelectedCafeId] = useState<string>("");
  const [expiresInHours, setExpiresInHours] = useState(168); // 7 days
  const [isCreating, setIsCreating] = useState(false);
  const [createdInvite, setCreatedInvite] = useState<{
    token: string;
    invite_url: string;
    expires_at: string;
  } | null>(null);

  const supabase = createBrowserClient();

  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    try {
      setIsLoading(true);
      setError(null);

      // Load invitations
      const { data: invData, error: invError } = await supabase
        .from("owner_invitations")
        .select("*")
        .order("created_at", { ascending: false });

      if (invError) throw invError;
      setInvitations(invData || []);

      // Load cafes for dropdown
      const { data: cafesData, error: cafesError } = await supabase
        .from("cafes")
        .select("id, name")
        .order("name");

      if (cafesError) throw cafesError;
      setCafes(cafesData || []);
    } catch (err) {
      console.error("Error loading data:", err);
      setError(err instanceof Error ? err.message : "Failed to load data");
    } finally {
      setIsLoading(false);
    }
  }

  async function handleCreateInvitation(e: React.FormEvent) {
    e.preventDefault();
    setIsCreating(true);
    setError(null);
    setCreatedInvite(null);

    try {
      const response = await fetch('/api/admin/owner-invites', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email,
          company_name: companyName || null,
          cafe_id: selectedCafeId || null,
          expires_in_hours: expiresInHours,
        }),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Failed to create invitation');
      }

      // Show created invitation with token
      setCreatedInvite({
        token: result.invitation.token,
        invite_url: result.invitation.invite_url,
        expires_at: result.invitation.expires_at,
      });

      // Reset form
      setEmail("");
      setCompanyName("");
      setSelectedCafeId("");
      setExpiresInHours(168);

      // Reload invitations list
      await loadData();
    } catch (err) {
      console.error("Error creating invitation:", err);
      setError(err instanceof Error ? err.message : "Failed to create invitation");
    } finally {
      setIsCreating(false);
    }
  }

  async function handleRevokeInvitation(invitationId: string) {
    if (!confirm("Are you sure you want to revoke this invitation?")) return;

    try {
      const response = await fetch(`/api/admin/owner-invites/${invitationId}`, {
        method: 'DELETE',
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Failed to revoke invitation');
      }

      alert("Invitation revoked successfully");
      await loadData();
    } catch (err) {
      console.error("Error revoking invitation:", err);
      alert(err instanceof Error ? err.message : "Failed to revoke invitation");
    }
  }

  function getStatusBadge(status: string) {
    const styles = {
      pending: "bg-yellow-100 text-yellow-800 border-yellow-300",
      accepted: "bg-green-100 text-green-800 border-green-300",
      expired: "bg-gray-100 text-gray-600 border-gray-300",
      revoked: "bg-red-100 text-red-800 border-red-300",
    };
    return styles[status as keyof typeof styles] || styles.expired;
  }

  if (isLoading) {
    return (
      <div className="p-6">
        <p className="text-zinc-500">Loading invitations...</p>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-zinc-900">Owner Invitations</h1>
          <p className="text-sm text-zinc-500 mt-1">
            Invite new cafe owners to join the platform
          </p>
        </div>
        <button
          onClick={() => {
            setShowCreateForm(!showCreateForm);
            setCreatedInvite(null);
            setError(null);
          }}
          className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
        >
          {showCreateForm ? "Cancel" : "+ Create Invitation"}
        </button>
      </div>

      {/* Error Alert */}
      {error && (
        <div className="rounded border border-red-200 bg-red-50 p-4">
          <p className="text-sm text-red-700">{error}</p>
        </div>
      )}

      {/* Create Invitation Form */}
      {showCreateForm && (
        <div className="rounded border border-zinc-200 bg-white p-6 shadow-sm">
          <h2 className="text-lg font-semibold text-zinc-900 mb-4">
            Create Owner Invitation
          </h2>

          {createdInvite ? (
            <div className="space-y-4">
              <div className="rounded border border-green-200 bg-green-50 p-4">
                <p className="text-sm font-medium text-green-900 mb-2">
                  ✅ Invitation created successfully!
                </p>
                <p className="text-xs text-green-700">
                  Send this link to the owner. It will expire on{" "}
                  {new Date(createdInvite.expires_at).toLocaleString()}.
                </p>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-zinc-700">
                  Invitation Link (send to owner):
                </label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={`${createdInvite.invite_url}`}
                    readOnly
                    className="flex-1 rounded border border-zinc-300 bg-zinc-50 px-3 py-2 text-sm font-mono"
                  />
                  <button
                    onClick={() => {
                      navigator.clipboard.writeText(createdInvite.invite_url);
                      alert("Copied to clipboard!");
                    }}
                    className="rounded border border-zinc-300 px-4 py-2 text-sm font-medium hover:bg-zinc-50"
                  >
                    Copy
                  </button>
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-zinc-700">
                  Token (for manual sharing):
                </label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={createdInvite.token}
                    readOnly
                    className="flex-1 rounded border border-zinc-300 bg-zinc-50 px-3 py-2 text-sm font-mono"
                  />
                  <button
                    onClick={() => {
                      navigator.clipboard.writeText(createdInvite.token);
                      alert("Token copied!");
                    }}
                    className="rounded border border-zinc-300 px-4 py-2 text-sm font-medium hover:bg-zinc-50"
                  >
                    Copy
                  </button>
                </div>
              </div>

              <button
                onClick={() => {
                  setShowCreateForm(false);
                  setCreatedInvite(null);
                }}
                className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800"
              >
                Done
              </button>
            </div>
          ) : (
            <form onSubmit={handleCreateInvitation} className="space-y-4">
              <div className="grid gap-4 md:grid-cols-2">
                <label className="grid gap-1 text-sm text-zinc-700">
                  Email <span className="text-red-500">*</span>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    placeholder="owner@example.com"
                    className="rounded border border-zinc-300 px-3 py-2 text-sm"
                    disabled={isCreating}
                  />
                </label>

                <label className="grid gap-1 text-sm text-zinc-700">
                  Company Name (optional)
                  <input
                    type="text"
                    value={companyName}
                    onChange={(e) => setCompanyName(e.target.value)}
                    placeholder="Acme Coffee Co."
                    className="rounded border border-zinc-300 px-3 py-2 text-sm"
                    disabled={isCreating}
                  />
                </label>
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <label className="grid gap-1 text-sm text-zinc-700">
                  Link to Cafe (optional)
                  <select
                    value={selectedCafeId}
                    onChange={(e) => setSelectedCafeId(e.target.value)}
                    className="rounded border border-zinc-300 px-3 py-2 text-sm"
                    disabled={isCreating}
                  >
                    <option value="">— Create cafe later —</option>
                    {cafes.map((cafe) => (
                      <option key={cafe.id} value={cafe.id}>
                        {cafe.name}
                      </option>
                    ))}
                  </select>
                  <span className="text-xs text-zinc-500">
                    Pre-link invitation to an existing cafe
                  </span>
                </label>

                <label className="grid gap-1 text-sm text-zinc-700">
                  Expires In (hours)
                  <input
                    type="number"
                    value={expiresInHours}
                    onChange={(e) => setExpiresInHours(parseInt(e.target.value))}
                    min="1"
                    max="720"
                    className="rounded border border-zinc-300 px-3 py-2 text-sm"
                    disabled={isCreating}
                  />
                  <span className="text-xs text-zinc-500">
                    Default: 168 hours (7 days)
                  </span>
                </label>
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  type="submit"
                  disabled={isCreating}
                  className="rounded bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-50"
                >
                  {isCreating ? "Creating..." : "Create Invitation"}
                </button>
                <button
                  type="button"
                  onClick={() => setShowCreateForm(false)}
                  disabled={isCreating}
                  className="rounded border border-zinc-300 px-4 py-2 text-sm font-medium hover:bg-zinc-50 disabled:opacity-50"
                >
                  Cancel
                </button>
              </div>
            </form>
          )}
        </div>
      )}

      {/* Invitations Table */}
      <div className="rounded border border-zinc-200 bg-white shadow-sm overflow-hidden">
        <table className="w-full">
          <thead className="bg-zinc-50 border-b border-zinc-200">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase">
                Email
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase">
                Company
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase">
                Status
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase">
                Created
              </th>
              <th className="px-4 py-3 text-left text-xs font-medium text-zinc-500 uppercase">
                Expires
              </th>
              <th className="px-4 py-3 text-right text-xs font-medium text-zinc-500 uppercase">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-200">
            {invitations.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-sm text-zinc-500">
                  No invitations yet. Create one to invite a cafe owner!
                </td>
              </tr>
            ) : (
              invitations.map((invitation) => (
                <tr key={invitation.id} className="hover:bg-zinc-50">
                  <td className="px-4 py-3 text-sm text-zinc-900">
                    {invitation.email}
                  </td>
                  <td className="px-4 py-3 text-sm text-zinc-600">
                    {invitation.company_name || "—"}
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex items-center rounded-full border px-2 py-1 text-xs font-medium ${getStatusBadge(
                        invitation.status
                      )}`}
                    >
                      {invitation.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-zinc-600">
                    {new Date(invitation.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 text-sm text-zinc-600">
                    {new Date(invitation.expires_at).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 text-right text-sm">
                    {invitation.status === "pending" && (
                      <button
                        onClick={() => handleRevokeInvitation(invitation.id)}
                        className="text-red-600 hover:text-red-800 font-medium"
                      >
                        Revoke
                      </button>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
