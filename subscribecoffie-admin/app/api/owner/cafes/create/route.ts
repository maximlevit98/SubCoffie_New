import { NextResponse } from 'next/server';
import { 
  requireOwnerOrAdmin,
  safeErrorResponse 
} from '@/lib/supabase/roles';

export async function POST(request: Request) {
  try {
    // 🔐 SECURITY: Require owner or admin role
    const authResult = await requireOwnerOrAdmin();
    if (authResult instanceof NextResponse) {
      return authResult; // Return 401/403 error
    }

    const { userId, role, supabase } = authResult;

    const body = await request.json();
    const {
      name,
      address,
      phone,
      email,
      city,
      workingHours,
      preorderInterval,
      slotsPerInterval,
      preorderStartHour,
      description,
      logoUrl,
      coverUrl,
    } = body;

    // Validation
    if (!name || !address || !phone || !email) {
      return NextResponse.json(
        { error: 'Missing required fields: name, address, phone, email' },
        { status: 400 }
      );
    }

    // Get or create owner's account
    let accountId: string;

    if (role === 'admin') {
      // Admins can create cafes for any account
      // For now, admins create unlinked cafes (account_id can be null or we can require it in body)
      // TODO: Add account_id to request body for admin cafe creation
      const { data: account, error: accountError } = await supabase
        .from('accounts')
        .select('id')
        .eq('owner_user_id', userId)
        .maybeSingle();

      if (account) {
        accountId = account.id;
      } else {
        // Create account for admin if not exists (or handle differently)
        return NextResponse.json(
          { error: 'Admin account setup required. Please create an account first.' },
          { status: 400 }
        );
      }
    } else {
      // Owners create cafes linked to their account
      const { data: account, error: accountError } = await supabase
        .from('accounts')
        .select('id')
        .eq('owner_user_id', userId)
        .single();

      if (accountError || !account) {
        return NextResponse.json(
          { error: 'Owner account not found. Please complete your account setup first.' },
          { status: 404 }
        );
      }

      accountId = account.id;
    }

    // Extract simplified opening/closing time from Monday (as default)
    const mondaySchedule = workingHours?.monday;
    const openingTime = mondaySchedule?.isOpen ? mondaySchedule.openTime : '09:00';
    const closingTime = mondaySchedule?.isOpen ? mondaySchedule.closeTime : '18:00';

    // Create cafe (RLS will also enforce this on DB level)
    const { data: cafe, error: cafeError } = await supabase
      .from('cafes')
      .insert({
        account_id: accountId,
        name,
        address,
        phone,
        email,
        description: description || null,
        mode: 'open',
        status: 'draft', // Start as draft
        supports_citypass: true,
        opening_time: openingTime,
        closing_time: closingTime,
        // Note: coordinates (latitude/longitude) can be added later via geocoding or manual input
      })
      .select('id')
      .single();

    if (cafeError) {
      // Safe error response (no SQL details leaked)
      return safeErrorResponse(cafeError, 'Failed to create cafe');
    }

    // TODO: When we add cafe_working_hours and cafe_preorder_settings tables:
    // - Insert detailed working hours for each day
    // - Insert preorder settings (interval, slots, start time)
    // For now, we're storing simplified hours in the cafes table itself

    return NextResponse.json({
      success: true,
      cafeId: cafe.id,
      message: 'Cafe created successfully',
    });
  } catch (error) {
    // Safe error response (no internal details leaked)
    return safeErrorResponse(error, 'Internal server error');
  }
}
