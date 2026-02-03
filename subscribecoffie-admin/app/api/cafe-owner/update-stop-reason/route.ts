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
    const { item_id, stop_reason } = body;

    if (!item_id) {
      return NextResponse.json(
        { error: "Invalid request parameters: item_id required" },
        { status: 400 }
      );
    }

    // 🔐 SECURITY: Verify menu item ownership (admins bypass)
    const ownershipResult = await verifyMenuItemOwnership(supabase, userId, role, item_id);
    if (ownershipResult instanceof NextResponse) {
      return ownershipResult; // Return 403/404 error
    }

    // Update stop reason via RPC (RLS will also enforce this on DB level)
    const { data, error } = await supabase.rpc("update_menu_item_stop_reason", {
      item_id_param: item_id,
      stop_reason_param: stop_reason || null,
    });

    if (error) {
      // Safe error response (no SQL details leaked)
      return safeErrorResponse(error, "Failed to update menu item stop reason");
    }

    return NextResponse.json({ success: true, data });
  } catch (error: any) {
    // Safe error response (no internal details leaked)
    return safeErrorResponse(error, "Internal server error");
  }
}
