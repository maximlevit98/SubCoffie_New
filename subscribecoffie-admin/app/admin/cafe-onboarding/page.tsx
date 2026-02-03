import Link from "next/link";
import { listOnboardingRequests } from "../../../lib/supabase/queries/cafe-onboarding";
import { createServerClient } from "@/lib/supabase/server";
import InviteOwnerButton from "./InviteOwnerButton";

export const dynamic = "force-dynamic";

export default async function CafeOnboardingPage() {
  const { data: requests, error } = await listOnboardingRequests();

  // Load owner invitations for each request (by matching email)
  const supabase = await createServerClient();
  const { data: allInvites } = await supabase
    .from("owner_invitations")
    .select("id, email, status, expires_at, created_at, accepted_at")
    .order("created_at", { ascending: false });

  // Create a map of email -> latest invite
  const invitesByEmail = new Map();
  if (allInvites) {
    for (const invite of allInvites) {
      const email = invite.email?.toLowerCase();
      if (!email) continue;
      // Keep only the latest invite per email
      if (!invitesByEmail.has(email)) {
        invitesByEmail.set(email, invite);
      }
    }
  }

  if (error) {
    return (
      <section className="space-y-4">
        <h2 className="text-2xl font-semibold">Заявки на подключение кафе</h2>
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          Не удалось загрузить заявки: {error}
        </p>
      </section>
    );
  }

  const pendingRequests = (requests ?? []).filter((r) => r.status === "pending");
  const approvedRequests = (requests ?? []).filter((r) => r.status === "approved");
  const rejectedRequests = (requests ?? []).filter((r) => r.status === "rejected");

  return (
    <section className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-semibold">Заявки на подключение кафе</h2>
        <div className="flex gap-2 text-sm">
          <span className="rounded-full bg-yellow-100 px-3 py-1 font-medium text-yellow-700">
            {pendingRequests.length} В ожидании
          </span>
          <span className="rounded-full bg-green-100 px-3 py-1 font-medium text-green-700">
            {approvedRequests.length} Одобрено
          </span>
          <span className="rounded-full bg-red-100 px-3 py-1 font-medium text-red-700">
            {rejectedRequests.length} Отклонено
          </span>
        </div>
      </div>

      {/* Pending Requests */}
      {pendingRequests.length > 0 && (
        <div className="space-y-4">
          <h3 className="text-lg font-semibold text-yellow-700">В ожидании</h3>
          <div className="grid gap-4">
            {pendingRequests.map((request) => (
              <RequestCard 
                key={request.id} 
                request={request} 
                invitation={invitesByEmail.get(request.applicant_email?.toLowerCase())}
              />
            ))}
          </div>
        </div>
      )}

      {/* Approved Requests */}
      {approvedRequests.length > 0 && (
        <div className="space-y-4">
          <h3 className="text-lg font-semibold text-green-700">Одобрено</h3>
          <div className="grid gap-4">
            {approvedRequests.map((request) => (
              <RequestCard 
                key={request.id} 
                request={request}
                invitation={invitesByEmail.get(request.applicant_email?.toLowerCase())}
              />
            ))}
          </div>
        </div>
      )}

      {/* Rejected Requests */}
      {rejectedRequests.length > 0 && (
        <div className="space-y-4">
          <h3 className="text-lg font-semibold text-red-700">Отклонено</h3>
          <div className="grid gap-4">
            {rejectedRequests.map((request) => (
              <RequestCard 
                key={request.id} 
                request={request}
                invitation={invitesByEmail.get(request.applicant_email?.toLowerCase())}
              />
            ))}
          </div>
        </div>
      )}

      {requests && requests.length === 0 && (
        <div className="rounded border border-zinc-200 bg-zinc-50 p-6 text-center text-zinc-500">
          Нет заявок на подключение кафе.
        </div>
      )}
    </section>
  );
}

function RequestCard({ request, invitation }: { request: any; invitation?: any }) {
  const statusColor =
    request.status === "pending"
      ? "bg-yellow-100 text-yellow-700"
      : request.status === "approved"
      ? "bg-green-100 text-green-700"
      : "bg-red-100 text-red-700";

  // Determine invitation status
  let inviteStatusText = "";
  let inviteStatusColor = "";
  if (invitation) {
    if (invitation.status === "accepted") {
      inviteStatusText = "✅ Принято";
      inviteStatusColor = "bg-green-50 text-green-700 border-green-200";
    } else if (invitation.status === "pending") {
      const isExpired = new Date(invitation.expires_at) < new Date();
      if (isExpired) {
        inviteStatusText = "⏰ Истекло";
        inviteStatusColor = "bg-gray-50 text-gray-600 border-gray-200";
      } else {
        inviteStatusText = `⏳ Ожидает (до ${new Date(invitation.expires_at).toLocaleDateString()})`;
        inviteStatusColor = "bg-blue-50 text-blue-700 border-blue-200";
      }
    } else if (invitation.status === "revoked") {
      inviteStatusText = "🚫 Отозвано";
      inviteStatusColor = "bg-red-50 text-red-600 border-red-200";
    }
  }

  return (
    <div className="rounded border border-zinc-200 bg-white p-4 shadow-sm">
      <div className="flex items-start justify-between">
        <div className="flex-1 space-y-2">
          <div className="flex items-center gap-3">
            <h4 className="text-lg font-semibold text-zinc-800">{request.cafe_name}</h4>
            <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${statusColor}`}>
              {request.status === "pending" ? "В ожидании" : request.status === "approved" ? "Одобрено" : "Отклонено"}
            </span>
          </div>
          <p className="text-sm text-zinc-600">{request.cafe_address}</p>
          {request.cafe_description && (
            <p className="text-sm text-zinc-500">{request.cafe_description}</p>
          )}
          <div className="mt-3 space-y-1 text-xs text-zinc-500">
            <p>
              <strong>Заявитель:</strong> {request.applicant_name} ({request.applicant_email})
            </p>
            {request.applicant_phone && (
              <p>
                <strong>Телефон:</strong> {request.applicant_phone}
              </p>
            )}
            <p>
              <strong>Дата заявки:</strong> {new Date(request.created_at).toLocaleString()}
            </p>
            {request.admin_notes && (
              <p className="mt-2 rounded bg-zinc-50 p-2 text-zinc-700">
                <strong>Заметки администратора:</strong> {request.admin_notes}
              </p>
            )}
          </div>

          {/* Owner Invitation Status */}
          <div className="mt-3 pt-3 border-t border-zinc-200">
            <p className="text-xs font-semibold text-zinc-700 mb-2">📨 Приглашение владельца:</p>
            {invitation ? (
              <div className={`inline-flex items-center gap-2 rounded border px-3 py-1.5 text-xs ${inviteStatusColor}`}>
                {inviteStatusText}
              </div>
            ) : (
              <InviteOwnerButton 
                email={request.applicant_email}
                companyName={request.cafe_name}
              />
            )}
          </div>
        </div>
        <div className="ml-4">
          <Link
            href={`/admin/cafe-onboarding/${request.id}`}
            className="text-sm text-blue-600 hover:text-blue-700 underline"
          >
            Подробнее →
          </Link>
        </div>
      </div>
    </div>
  );
}
