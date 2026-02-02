import { NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';

export async function POST(request: Request) {
  try {
    const { role, userId } = await getUserRole();

    if (role !== 'owner' || !userId) {
      return NextResponse.json(
        { error: 'Only owners can create menu items' },
        { status: 403 }
      );
    }

    const body = await request.json();
    const {
      cafe_id,
      name,
      title,
      description,
      category,
      price_credits,
      prep_time_sec,
      is_available,
      sort_order,
      ingredients,
      sizes,
    } = body;

    // Validation
    if (!cafe_id || !name || !description || !category) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    if (!['drinks', 'food', 'syrups', 'merch'].includes(category)) {
      return NextResponse.json(
        { error: 'Invalid category' },
        { status: 400 }
      );
    }

    const supabase = await createServerClient();

    // Verify cafe ownership
    const { data: cafe } = await supabase
      .from('cafes')
      .select('account_id')
      .eq('id', cafe_id)
      .single();

    if (!cafe) {
      return NextResponse.json({ error: 'Cafe not found' }, { status: 404 });
    }

    const { data: account } = await supabase
      .from('accounts')
      .select('id')
      .eq('id', cafe.account_id)
      .eq('owner_user_id', userId)
      .single();

    if (!account) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
    }

    // Create menu item
    const { data: menuItem, error: createError } = await supabase
      .from('menu_items')
      .insert({
        cafe_id,
        name,
        title: title || name,
        description,
        category,
        price_credits: price_credits || 100,
        prep_time_sec: prep_time_sec || 300,
        is_available: is_available ?? true,
        sort_order: sort_order || 0,
        ingredients: ingredients || null,
        sizes: sizes || [],
      })
      .select()
      .single();

    if (createError) {
      console.error('Menu item creation error:', createError);
      return NextResponse.json(
        { error: 'Failed to create menu item', details: createError.message },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      menuItem,
      message: 'Menu item created successfully',
    });
  } catch (error) {
    console.error('Menu item creation API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
