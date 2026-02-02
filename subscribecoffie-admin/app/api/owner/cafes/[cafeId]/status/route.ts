import { NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ cafeId: string }> }
) {
  try {
    const { role, userId } = await getUserRole();
    const { cafeId } = await params;

    // Only owners can update cafe status
    if (role !== 'owner' || !userId) {
      return NextResponse.json(
        { error: 'Only owners can update cafe status' },
        { status: 403 }
      );
    }

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

    const supabase = await createServerClient();

    // Verify ownership
    const { data: cafe } = await supabase
      .from('cafes')
      .select('account_id')
      .eq('id', cafeId)
      .single();

    if (!cafe) {
      return NextResponse.json(
        { error: 'Cafe not found' },
        { status: 404 }
      );
    }

    const { data: account } = await supabase
      .from('accounts')
      .select('id')
      .eq('id', cafe.account_id)
      .eq('owner_user_id', userId)
      .single();

    if (!account) {
      return NextResponse.json(
        { error: 'You do not own this cafe' },
        { status: 403 }
      );
    }

    // Update status
    const { error: updateError } = await supabase
      .from('cafes')
      .update({ status })
      .eq('id', cafeId);

    if (updateError) {
      console.error('Status update error:', updateError);
      return NextResponse.json(
        { error: 'Failed to update status', details: updateError.message },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      message: 'Cafe status updated successfully',
    });
  } catch (error) {
    console.error('Cafe status update API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
