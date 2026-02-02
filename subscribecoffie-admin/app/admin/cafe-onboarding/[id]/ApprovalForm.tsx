"use client";

import { useState, useTransition } from "react";

type ApprovalFormProps = {
  requestId: string;
  onApprove: (formData: FormData) => Promise<void>;
  onReject: (formData: FormData) => Promise<void>;
};

export default function ApprovalForm({ requestId, onApprove, onReject }: ApprovalFormProps) {
  const [isPending, startTransition] = useTransition();
  const [adminNotes, setAdminNotes] = useState("");
  const [error, setError] = useState<string | null>(null);

  const handleApprove = () => {
    startTransition(async () => {
      try {
        setError(null);
        const formData = new FormData();
        formData.set("admin_notes", adminNotes);
        await onApprove(formData);
      } catch (error) {
        setError((error as Error).message);
      }
    });
  };

  const handleReject = () => {
    if (!adminNotes.trim()) {
      setError("Пожалуйста, укажите причину отклонения в заметках администратора.");
      return;
    }

    startTransition(async () => {
      try {
        setError(null);
        const formData = new FormData();
        formData.set("admin_notes", adminNotes);
        await onReject(formData);
      } catch (error) {
        setError((error as Error).message);
      }
    });
  };

  return (
    <div className="space-y-4">
      <div>
        <label htmlFor="admin_notes" className="block text-sm font-medium text-zinc-700 mb-1">
          Заметки администратора
        </label>
        <textarea
          id="admin_notes"
          rows={4}
          value={adminNotes}
          onChange={(e) => setAdminNotes(e.target.value)}
          placeholder="Добавьте заметки (обязательны при отклонении)..."
          className="w-full rounded border border-zinc-300 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
          disabled={isPending}
        />
      </div>

      {error && (
        <p className="rounded border border-red-200 bg-red-50 p-3 text-sm text-red-700">
          {error}
        </p>
      )}

      <div className="flex gap-3">
        <button
          onClick={handleApprove}
          disabled={isPending}
          className="rounded bg-green-600 px-4 py-2 text-white text-sm font-medium hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isPending ? "Обработка..." : "✓ Одобрить"}
        </button>
        <button
          onClick={handleReject}
          disabled={isPending}
          className="rounded bg-red-600 px-4 py-2 text-white text-sm font-medium hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isPending ? "Обработка..." : "✗ Отклонить"}
        </button>
      </div>

      <p className="text-xs text-zinc-500">
        При одобрении заявки автоматически будет создано новое кафе в системе, и заявителю будет назначена роль владельца.
      </p>
    </div>
  );
}
