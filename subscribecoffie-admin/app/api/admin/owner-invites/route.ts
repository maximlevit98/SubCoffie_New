import { NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/server';
import { requireAdmin } from '@/lib/supabase/roles';

export async function POST(request: Request) {
  try {
    // 🔐 SECURITY: Require admin role
    const { userId } = await requireAdmin();

    const supabase = await createServerClient();
    const body = await request.json();
    
    const {
      email,
      company_name,
      cafe_id,
      expires_in_hours = 168, // 7 days default
    } = body;

    // Validation
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return NextResponse.json(
        { error: 'Valid email is required' },
        { status: 400 }
      );
    }

    if (expires_in_hours < 1 || expires_in_hours > 720) {
      return NextResponse.json(
        { error: 'Expiry must be between 1 and 720 hours' },
        { status: 400 }
      );
    }

    // Call Supabase RPC to create invitation
    const { data, error } = await supabase.rpc('admin_create_owner_invitation', {
      p_email: email,
      p_company_name: company_name || null,
      p_cafe_id: cafe_id || null,
      p_expires_in_hours: expires_in_hours,
    });

    if (error) {
      console.error('Error creating invitation:', error);
      return NextResponse.json(
        { error: error.message || 'Failed to create invitation' },
        { status: 500 }
      );
    }

    // Generate full invite URL
    const baseUrl = process.env.NEXT_PUBLIC_BASE_URL || 'http://localhost:3000';
    const inviteUrl = `${baseUrl}/register/owner?token=${data.token}`;

    return NextResponse.json({
      success: true,
      invitation: {
        id: data.invitation_id,
        email: data.email,
        token: data.token, // ⚠️ CRITICAL: Only shown once!
        invite_url: inviteUrl,
        expires_at: data.expires_at,
      },
      message: 'Invitation created successfully',
    });
  } catch (error) {
    console.error('Create invitation error:', error);
    
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

export async function GET(request: Request) {
  try {
    // 🔐 SECURITY: Require admin role
    await requireAdmin();

    const supabase = await createServerClient();

    // Get all invitations
    const { data: invitations, error } = await supabase
      .from('owner_invitations')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching invitations:', error);
      return NextResponse.json(
        { error: 'Failed to fetch invitations' },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      invitations: invitations || [],
    });
  } catch (error) {
    console.error('Get invitations error:', error);
    
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
