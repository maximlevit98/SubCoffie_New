import Link from 'next/link';
import { redirect } from 'next/navigation';

import { getUserRole } from '@/lib/supabase/roles';

export default async function OwnerLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const { role, userId } = await getUserRole();

  if (!role || !userId) {
    redirect('/login');
  }

  // STRICT: Only owners can access this area
  // Admins must stay in /admin/* (no cross-context switching)
  if (role !== 'owner') {
    redirect('/admin/dashboard');
  }

  return (
    <div className="min-h-screen bg-zinc-50 font-sans text-zinc-900">
      <header className="border-b border-zinc-200 bg-white px-6 py-4">
        <div className="flex items-center justify-between">
          <Link href="/admin/owner/dashboard">
            <h1 className="text-lg font-semibold hover:text-blue-600 transition-colors cursor-pointer">
              ☕ SubscribeCoffie Owner
            </h1>
          </Link>
          <div className="rounded-lg bg-green-100 px-3 py-1 text-sm font-medium text-green-800">
            Владелец
          </div>
        </div>
      </header>
      {children}
    </div>
  );
}
