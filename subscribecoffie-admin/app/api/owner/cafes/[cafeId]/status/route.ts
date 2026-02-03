import { NextResponse } from 'next/server';
import { 
  requireOwnerOrAdmin, 
  verifyCafeOwnership,
  safeErrorResponse 
} from '@/lib/supabase/roles';

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ cafeId: string }> }
) {
  try {
    // 🔐 SECURITY: Require owner or admin role
    const authResult = await requireOwnerOrAdmin();
    if (authResult instanceof NextResponse) {
      return authResult; // Return 401/403 error
    }

    const { userId, role, supabase } = authResult;
    const { cafeId } = await params;

    const body = await request.json();
    const { status } = body;

    // Validate status
    const validStatuses = ['draft', 'moderation', 'published', 'paused', 'rejected'];
    if (!status || !validStatuses.includes(status)) {
      return NextResponse.json(
        { error: 'Invalid status. Must be one of: draft, moderation, published, paused, rejected' },
        { status: 400 }
      );
    }

    // 🔐 SECURITY: Verify cafe ownership (admins bypass)
    const ownershipError = await verifyCafeOwnership(supabase, userId, role, cafeId);
    if (ownershipError) {
      return ownershipError; // Return 403/404 error
    }

    // Update status (RLS will also enforce this on DB level)
    const { error: updateError } = await supabase
      .from('cafes')
      .update({ status })
      .eq('id', cafeId);

    if (updateError) {
      // Safe error response (no SQL details leaked)
      return safeErrorResponse(updateError, 'Failed to update cafe status');
    }

    return NextResponse.json({
      success: true,
      message: 'Cafe status updated successfully',
    });
  } catch (error) {
    // Safe error response (no internal details leaked)
    return safeErrorResponse(error, 'Internal server error');
  }
}
