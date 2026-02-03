import { redirect } from 'next/navigation';
import { getUserRole } from '@/lib/supabase/roles';

export default async function OwnerInvitationsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  // ADMIN-ONLY GUARD for owner-invitations
  const { role, userId } = await getUserRole();
  
  if (!userId) {
    redirect('/login');
  }
  
  // Strict: only admin can manage owner invitations
  if (role !== 'admin') {
    redirect('/admin/owner/dashboard');
  }

  return <>{children}</>;
}
