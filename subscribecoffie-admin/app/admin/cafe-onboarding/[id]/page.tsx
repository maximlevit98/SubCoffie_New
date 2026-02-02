import { notFound, redirect } from "next/navigation";
import { getOnboardingRequest, updateOnboardingRequestStatus, approveCafe } from "../../../../lib/supabase/queries/cafe-onboarding";
import { getUserRole } from "../../../../lib/supabase/roles";
import ApprovalForm from "./ApprovalForm";

export const dynamic = "force-dynamic";

export default async function OnboardingRequestDetailPage({ params }: { params: { id: string } }) {
  const { role, userId } = await getUserRole();

  if (!role || !userId) {
    redirect("/login");
  }

  const { data: request, error } = await getOnboardingRequest(params.id);

  if (error || !request) {
    notFound();
  }

  async function handleApprove(formData: FormData) {
    "use server";
    const adminNotes = formData.get("admin_notes") as string;

    try {
      // Call the approve_cafe RPC
      await approveCafe(params.id, userId!);
      
      // Update admin notes if provided
      if (adminNotes) {
        await updateOnboardingRequestStatus(params.id, "approved", adminNotes);
      }
      
      redirect("/admin/cafe-onboarding");
    } catch (error) {
      console.error("Error approving cafe:", error);
      throw error;
    }
  }

  async function handleReject(formData: FormData) {
    "use server";
    const adminNotes = formData.get("admin_notes") as string;

    try {
      await updateOnboardingRequestStatus(params.id, "rejected", adminNotes);
      redirect("/admin/cafe-onboarding");
    } catch (error) {
      console.error("Error rejecting cafe:", error);
      throw error;
    }
  }

  const statusColor =
    request.status === "pending"
      ? "bg-yellow-100 text-yellow-700"
      : request.status === "approved"
      ? "bg-green-100 text-green-700"
      : "bg-red-100 text-red-700";

  return (
    <section className="space-y-6">
      <div className="flex items-center gap-3">
        <a
          href="/admin/cafe-onboarding"
          className="text-sm text-blue-600 hover:text-blue-700 underline"
        >
          ← Назад к списку
        </a>
      </div>

      <div className="rounded border border-zinc-200 bg-white p-6 shadow-sm">
        <div className="flex items-start justify-between">
          <h2 className="text-2xl font-semibold text-zinc-800">{request.cafe_name}</h2>
          <span className={`rounded-full px-3 py-1 text-sm font-medium ${statusColor}`}>
            {request.status === "pending" ? "В ожидании" : request.status === "approved" ? "Одобрено" : "Отклонено"}
          </span>
        </div>

        <div className="mt-6 space-y-4 text-sm">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="font-medium text-zinc-700">Название кафе</p>
              <p className="text-zinc-600">{request.cafe_name}</p>
            </div>
            <div>
              <p className="font-medium text-zinc-700">Адрес</p>
              <p className="text-zinc-600">{request.cafe_address}</p>
            </div>
          </div>

          {request.cafe_description && (
            <div>
              <p className="font-medium text-zinc-700">Описание</p>
              <p className="text-zinc-600">{request.cafe_description}</p>
            </div>
          )}

          <div className="border-t border-zinc-200 pt-4">
            <p className="font-semibold text-zinc-800 mb-2">Контактная информация заявителя</p>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="font-medium text-zinc-700">Имя</p>
                <p className="text-zinc-600">{request.applicant_name}</p>
              </div>
              <div>
                <p className="font-medium text-zinc-700">Email</p>
                <p className="text-zinc-600">{request.applicant_email}</p>
              </div>
            </div>
            {request.applicant_phone && (
              <div className="mt-2">
                <p className="font-medium text-zinc-700">Телефон</p>
                <p className="text-zinc-600">{request.applicant_phone}</p>
              </div>
            )}
          </div>

          <div className="border-t border-zinc-200 pt-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="font-medium text-zinc-700">Дата заявки</p>
                <p className="text-zinc-600">{new Date(request.created_at).toLocaleString()}</p>
              </div>
              <div>
                <p className="font-medium text-zinc-700">Последнее обновление</p>
                <p className="text-zinc-600">{new Date(request.updated_at).toLocaleString()}</p>
              </div>
            </div>
          </div>

          {request.admin_notes && (
            <div className="border-t border-zinc-200 pt-4">
              <p className="font-medium text-zinc-700 mb-2">Заметки администратора</p>
              <p className="rounded bg-zinc-50 p-3 text-zinc-700">{request.admin_notes}</p>
            </div>
          )}
        </div>
      </div>

      {request.status === "pending" && role === "admin" && (
        <div className="rounded border border-zinc-200 bg-white p-6 shadow-sm">
          <h3 className="text-lg font-semibold text-zinc-800 mb-4">Действия</h3>
          <ApprovalForm requestId={params.id} onApprove={handleApprove} onReject={handleReject} />
        </div>
      )}
    </section>
  );
}
