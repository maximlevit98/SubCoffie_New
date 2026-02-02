import { NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';

export async function POST(request: Request) {
  try {
    const { role, userId } = await getUserRole();

    // Only owners can create cafes
    if (role !== 'owner' || !userId) {
      return NextResponse.json(
        { error: 'Only owners can create cafes' },
        { status: 403 }
      );
    }

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
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    const supabase = await createServerClient();

    // Get owner's account
    const { data: account, error: accountError } = await supabase
      .from('accounts')
      .select('id')
      .eq('owner_user_id', userId)
      .single();

    if (accountError || !account) {
      return NextResponse.json(
        { error: 'Owner account not found' },
        { status: 404 }
      );
    }

    // Extract simplified opening/closing time from Monday (as default)
    const mondaySchedule = workingHours?.monday;
    const openingTime = mondaySchedule?.isOpen ? mondaySchedule.openTime : '09:00';
    const closingTime = mondaySchedule?.isOpen ? mondaySchedule.closeTime : '18:00';

    // Create cafe
    const { data: cafe, error: cafeError } = await supabase
      .from('cafes')
      .insert({
        account_id: account.id,
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
      console.error('Cafe creation error:', cafeError);
      return NextResponse.json(
        { error: 'Failed to create cafe', details: cafeError.message },
        { status: 500 }
      );
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
    console.error('Cafe creation API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
