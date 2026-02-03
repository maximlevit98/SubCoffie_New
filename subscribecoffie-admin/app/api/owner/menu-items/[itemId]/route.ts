import { NextResponse } from 'next/server';
import { 
  requireOwnerOrAdmin, 
  verifyMenuItemOwnership,
  safeErrorResponse 
} from '@/lib/supabase/roles';

type RouteContext = {
  params: Promise<{ itemId: string }>;
};

// Update menu item (full update)
export async function PUT(request: Request, context: RouteContext) {
  try {
    // 🔐 SECURITY: Require owner or admin role
    const authResult = await requireOwnerOrAdmin();
    if (authResult instanceof NextResponse) {
      return authResult; // Return 401/403 error
    }

    const { userId, role, supabase } = authResult;
    const { itemId } = await context.params;
    const body = await request.json();

    const {
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

    // 🔐 SECURITY: Verify menu item ownership (admins bypass)
    const ownershipResult = await verifyMenuItemOwnership(supabase, userId, role, itemId);
    if (ownershipResult instanceof NextResponse) {
      return ownershipResult; // Return 403/404 error
    }

    // Update menu item (RLS will also enforce this on DB level)
    const { data: updated, error: updateError } = await supabase
      .from('menu_items')
      .update({
        name,
        title: title || name,
        description,
        category,
        price_credits,
        prep_time_sec,
        is_available,
        sort_order,
        ingredients,
        sizes,
      })
      .eq('id', itemId)
      .select()
      .single();

    if (updateError) {
      // Safe error response (no SQL details leaked)
      return safeErrorResponse(updateError, 'Failed to update menu item');
    }

    return NextResponse.json({
      success: true,
      menuItem: updated,
      message: 'Menu item updated successfully',
    });
  } catch (error) {
    // Safe error response (no internal details leaked)
    return safeErrorResponse(error, 'Internal server error');
  }
}

// Partial update (e.g., toggle availability)
export async function PATCH(request: Request, context: RouteContext) {
  try {
    // 🔐 SECURITY: Require owner or admin role
    const authResult = await requireOwnerOrAdmin();
    if (authResult instanceof NextResponse) {
      return authResult; // Return 401/403 error
    }

    const { userId, role, supabase } = authResult;
    const { itemId } = await context.params;
    const body = await request.json();

    // 🔐 SECURITY: Verify menu item ownership (admins bypass)
    const ownershipResult = await verifyMenuItemOwnership(supabase, userId, role, itemId);
    if (ownershipResult instanceof NextResponse) {
      return ownershipResult; // Return 403/404 error
    }

    // Update only provided fields (RLS will also enforce this on DB level)
    const { data: updated, error: updateError } = await supabase
      .from('menu_items')
      .update(body)
      .eq('id', itemId)
      .select()
      .single();

    if (updateError) {
      // Safe error response (no SQL details leaked)
      return safeErrorResponse(updateError, 'Failed to update menu item');
    }

    return NextResponse.json({
      success: true,
      menuItem: updated,
      message: 'Menu item updated successfully',
    });
  } catch (error) {
    // Safe error response (no internal details leaked)
    return safeErrorResponse(error, 'Internal server error');
  }
}

// Delete menu item
export async function DELETE(request: Request, context: RouteContext) {
  try {
    // 🔐 SECURITY: Require owner or admin role
    const authResult = await requireOwnerOrAdmin();
    if (authResult instanceof NextResponse) {
      return authResult; // Return 401/403 error
    }

    const { userId, role, supabase } = authResult;
    const { itemId } = await context.params;

    // 🔐 SECURITY: Verify menu item ownership (admins bypass)
    const ownershipResult = await verifyMenuItemOwnership(supabase, userId, role, itemId);
    if (ownershipResult instanceof NextResponse) {
      return ownershipResult; // Return 403/404 error
    }

    // Delete menu item (RLS will also enforce this on DB level)
    const { error: deleteError } = await supabase
      .from('menu_items')
      .delete()
      .eq('id', itemId);

    if (deleteError) {
      // Safe error response (no SQL details leaked)
      return safeErrorResponse(deleteError, 'Failed to delete menu item');
    }

    return NextResponse.json({
      success: true,
      message: 'Menu item deleted successfully',
    });
  } catch (error) {
    // Safe error response (no internal details leaked)
    return safeErrorResponse(error, 'Internal server error');
  }
}
