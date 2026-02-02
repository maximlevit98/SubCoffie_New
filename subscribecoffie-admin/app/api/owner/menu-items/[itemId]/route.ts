import { NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/server';
import { getUserRole } from '@/lib/supabase/roles';

type RouteContext = {
  params: Promise<{ itemId: string }>;
};

// Update menu item (full update)
export async function PUT(request: Request, context: RouteContext) {
  try {
    const { role, userId } = await getUserRole();

    if (role !== 'owner' || !userId) {
      return NextResponse.json(
        { error: 'Only owners can update menu items' },
        { status: 403 }
      );
    }

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

    const supabase = await createServerClient();

    // Get menu item and verify ownership
    const { data: menuItem } = await supabase
      .from('menu_items')
      .select('cafe_id, cafes(account_id)')
      .eq('id', itemId)
      .single();

    if (!menuItem) {
      return NextResponse.json(
        { error: 'Menu item not found' },
        { status: 404 }
      );
    }

    const { data: account } = await supabase
      .from('accounts')
      .select('id')
      .eq('id', (menuItem.cafes as any).account_id)
      .eq('owner_user_id', userId)
      .single();

    if (!account) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
    }

    // Update menu item
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
      console.error('Menu item update error:', updateError);
      return NextResponse.json(
        { error: 'Failed to update menu item', details: updateError.message },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      menuItem: updated,
      message: 'Menu item updated successfully',
    });
  } catch (error) {
    console.error('Menu item update API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

// Partial update (e.g., toggle availability)
export async function PATCH(request: Request, context: RouteContext) {
  try {
    const { role, userId } = await getUserRole();

    if (role !== 'owner' || !userId) {
      return NextResponse.json(
        { error: 'Only owners can update menu items' },
        { status: 403 }
      );
    }

    const { itemId } = await context.params;
    const body = await request.json();

    const supabase = await createServerClient();

    // Get menu item and verify ownership
    const { data: menuItem } = await supabase
      .from('menu_items')
      .select('cafe_id, cafes(account_id)')
      .eq('id', itemId)
      .single();

    if (!menuItem) {
      return NextResponse.json(
        { error: 'Menu item not found' },
        { status: 404 }
      );
    }

    const { data: account } = await supabase
      .from('accounts')
      .select('id')
      .eq('id', (menuItem.cafes as any).account_id)
      .eq('owner_user_id', userId)
      .single();

    if (!account) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
    }

    // Update only provided fields
    const { data: updated, error: updateError } = await supabase
      .from('menu_items')
      .update(body)
      .eq('id', itemId)
      .select()
      .single();

    if (updateError) {
      console.error('Menu item patch error:', updateError);
      return NextResponse.json(
        { error: 'Failed to update menu item', details: updateError.message },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      menuItem: updated,
      message: 'Menu item updated successfully',
    });
  } catch (error) {
    console.error('Menu item patch API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

// Delete menu item
export async function DELETE(request: Request, context: RouteContext) {
  try {
    const { role, userId } = await getUserRole();

    if (role !== 'owner' || !userId) {
      return NextResponse.json(
        { error: 'Only owners can delete menu items' },
        { status: 403 }
      );
    }

    const { itemId } = await context.params;
    const supabase = await createServerClient();

    // Get menu item and verify ownership
    const { data: menuItem } = await supabase
      .from('menu_items')
      .select('cafe_id, cafes(account_id)')
      .eq('id', itemId)
      .single();

    if (!menuItem) {
      return NextResponse.json(
        { error: 'Menu item not found' },
        { status: 404 }
      );
    }

    const { data: account } = await supabase
      .from('accounts')
      .select('id')
      .eq('id', (menuItem.cafes as any).account_id)
      .eq('owner_user_id', userId)
      .single();

    if (!account) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 });
    }

    // Delete menu item
    const { error: deleteError } = await supabase
      .from('menu_items')
      .delete()
      .eq('id', itemId);

    if (deleteError) {
      console.error('Menu item delete error:', deleteError);
      return NextResponse.json(
        { error: 'Failed to delete menu item', details: deleteError.message },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      message: 'Menu item deleted successfully',
    });
  } catch (error) {
    console.error('Menu item delete API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
