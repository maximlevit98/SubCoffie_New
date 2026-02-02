import { OwnerSidebar } from '@/components/OwnerSidebar';

export default function FinancesPage() {
  return (
    <div className="flex min-h-[calc(100vh-73px)]">
      <OwnerSidebar currentContext="account" />
      <main className="flex-1 px-6 py-6">
        <div className="mx-auto max-w-7xl">
          <h1 className="mb-6 text-2xl font-bold text-zinc-900">
            Финансы аккаунта
          </h1>
          <div className="rounded-lg border border-zinc-200 bg-white p-8 text-center">
            <p className="text-zinc-600">Coming soon...</p>
          </div>
        </div>
      </main>
    </div>
  );
}
