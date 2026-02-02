import { NextResponse } from 'next/server';
import { createServerClient } from '@/lib/supabase/server';

export async function GET() {
  try {
    const supabase = await createServerClient();
    
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    
    if (userError || !user) {
      return NextResponse.json({ role: null }, { status: 401 });
    }

    const { data: roleData, error: roleError } = await supabase
      .from('user_roles')
      .select('role')
      .eq('user_id', user.id)
      .single();

    if (roleError) {
      console.error('Role fetch error:', roleError);
      return NextResponse.json({ role: null }, { status: 200 });
    }

    return NextResponse.json({ role: roleData?.role || null });
  } catch (error) {
    console.error('Get user role error:', error);
    return NextResponse.json({ role: null }, { status: 500 });
  }
}
