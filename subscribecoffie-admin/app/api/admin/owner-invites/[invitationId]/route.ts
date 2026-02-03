import { NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/server';
import { requireAdmin } from '@/lib/supabase/roles';

type RouteContext = {
  params: Promise<{ invitationId: string }>;
};

export async function DELETE(request: Request, context: RouteContext) {
  try {
    // 🔐 SECURITY: Require admin role
    await requireAdmin();

    const supabase = await createServerClient();
    const { invitationId } = await context.params;

    // Call Supabase RPC to revoke invitation
    const { data, error } = await supabase.rpc('admin_revoke_owner_invitation', {
      p_invitation_id: invitationId,
    });

    if (error) {
      console.error('Error revoking invitation:', error);
      return NextResponse.json(
        { error: error.message || 'Failed to revoke invitation' },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      message: 'Invitation revoked successfully',
    });
  } catch (error) {
    console.error('Revoke invitation error:', error);
    
    if (error instanceof Error && error.message === 'Admin role required') {
      return NextResponse.json(
        { error: 'Admin role required' },
        { status: 403 }
      );
    }

    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
