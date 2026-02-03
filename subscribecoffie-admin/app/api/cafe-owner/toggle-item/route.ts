import { NextRequest, NextResponse } from "next/server";
import { 
  requireOwnerOrAdmin, 
  verifyMenuItemOwnership,
  safeErrorResponse 
} from "@/lib/supabase/roles";

export async function POST(request: NextRequest) {
  try {
    // 🔐 SECURITY: Require owner or admin role
    const authResult = await requireOwnerOrAdmin();
    if (authResult instanceof NextResponse) {
      return authResult; // Return 401/403 error
    }

    const { userId, role, supabase } = authResult;

    const body = await request.json();
    const { item_id, is_active } = body;

    if (!item_id || typeof is_active !== "boolean") {
      return NextResponse.json(
        { error: "Invalid request parameters: item_id and is_active (boolean) required" },
        { status: 400 }
      );
    }

    // 🔐 SECURITY: Verify menu item ownership (admins bypass)
    const ownershipResult = await verifyMenuItemOwnership(supabase, userId, role, item_id);
    if (ownershipResult instanceof NextResponse) {
      return ownershipResult; // Return 403/404 error
    }

    // Toggle availability via RPC (RLS will also enforce this on DB level)
    const { data, error } = await supabase.rpc(
      "toggle_menu_item_availability",
      {
        item_id_param: item_id,
        is_active_param: is_active,
      }
    );

    if (error) {
      // Safe error response (no SQL details leaked)
      return safeErrorResponse(error, "Failed to toggle menu item availability");
    }

    return NextResponse.json({ success: true, data });
  } catch (error: any) {
    // Safe error response (no internal details leaked)
    return safeErrorResponse(error, "Internal server error");
  }
}
