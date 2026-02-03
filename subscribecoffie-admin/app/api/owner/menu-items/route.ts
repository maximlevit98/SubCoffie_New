import { NextResponse } from 'next/server';
import { 
  requireOwnerOrAdmin, 
  verifyCafeOwnership,
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
        { error: 'Missing required fields: cafe_id, name, description, category' },
        { status: 400 }
      );
    }

    if (!['drinks', 'food', 'syrups', 'merch'].includes(category)) {
      return NextResponse.json(
        { error: 'Invalid category. Must be one of: drinks, food, syrups, merch' },
        { status: 400 }
      );
    }

    // 🔐 SECURITY: Verify cafe ownership (admins bypass)
    const ownershipError = await verifyCafeOwnership(supabase, userId, role, cafe_id);
    if (ownershipError) {
      return ownershipError; // Return 403/404 error
    }

    // Create menu item (RLS will also enforce this on DB level)
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
      // Safe error response (no SQL details leaked)
      return safeErrorResponse(createError, 'Failed to create menu item');
    }

    return NextResponse.json({
      success: true,
      menuItem,
      message: 'Menu item created successfully',
    });
  } catch (error) {
    // Safe error response (no internal details leaked)
    return safeErrorResponse(error, 'Internal server error');
  }
}
