/**
 * Owner Admin Panel - TypeScript Types
 * Generated from Supabase database schema
 * Date: 2026-02-01
 */

// ============================================================================
// Core Tables
// ============================================================================

export interface Account {
  id: string;
  owner_user_id: string;
  company_name: string;
  inn?: string | null;
  bank_details?: Record<string, any> | null;
  legal_address?: string | null;
  contact_phone?: string | null;
  contact_email?: string | null;
  created_at: string;
  updated_at: string;
}

export type CafeMode = 'open' | 'busy' | 'paused' | 'closed';
export type CafeStatus = 'draft' | 'moderation' | 'published' | 'paused' | 'rejected';

export interface Cafe {
  id: string;
  account_id: string | null;
  name: string;
  address: string;
  phone?: string | null;
  email?: string | null;
  description?: string | null;
  mode: CafeMode;
  status: CafeStatus;
  eta_minutes?: number | null;
  active_orders: number;
  max_active_orders?: number | null;
  distance_km?: number | null;
  supports_citypass: boolean;
  brand_id?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  opening_time?: string | null;
  closing_time?: string | null;
  working_hours?: Record<string, any> | null;
  logo_url?: string | null;
  cover_url?: string | null;
  photo_urls?: string[] | null;
  rating?: number | null;
  avg_check_credits?: number | null;
  created_at: string;
  updated_at?: string;
}

export interface MenuCategory {
  id: string;
  cafe_id: string;
  name: string;
  sort_order: number;
  is_visible: boolean;
  created_at: string;
  updated_at: string;
}

export type MenuItemCategory = 'drinks' | 'food' | 'syrups' | 'merch';

export interface MenuItem {
  id: string;
  cafe_id: string;
  category_id?: string | null;
  category: MenuItemCategory;
  name: string;
  description: string;
  price_credits: number;
  sort_order: number;
  is_active: boolean;
  photo_urls?: string[] | null;
  prep_time_sec?: number | null;
  availability_schedule?: {
    days: number[];
    time_from: string;
    time_to: string;
  } | null;
  created_at: string;
  updated_at: string;
}

export interface MenuModifier {
  id: string;
  menu_item_id: string;
  group_name: string;
  modifier_name: string;
  price_change: number;
  is_required: boolean;
  allow_multiple: boolean;
  sort_order: number;
  is_available: boolean;
  created_at: string;
  updated_at: string;
}

export type OrderStatus = 
  | 'Created'
  | 'Accepted'
  | 'Rejected'
  | 'In progress'
  | 'Ready'
  | 'Picked up'
  | 'Canceled'
  | 'Refunded'
  | 'No-show';

export type OrderType = 'now' | 'preorder' | 'subscription';
export type PaymentStatus = 'pending' | 'paid' | 'failed' | 'refunded';

export interface Order {
  id: string;
  user_id?: string | null;
  cafe_id: string;
  status: OrderStatus;
  order_type: OrderType;
  payment_status: PaymentStatus;
  subtotal_credits: number;
  bonus_used: number;
  paid_credits: number;
  wallet_id?: string | null;
  slot_time?: string | null;
  customer_phone: string;
  eta_minutes: number;
  pickup_deadline?: string | null;
  no_show_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface OrderItem {
  id: string;
  order_id: string;
  menu_item_id?: string | null;
  title: string;
  unit_credits: number;
  quantity: number;
  category: MenuItemCategory;
  line_total?: number;
  created_at: string;
}

export interface OrderEvent {
  id: string;
  order_id: string;
  status: string;
  created_at: string;
}

export interface CafePublicationHistory {
  id: string;
  cafe_id: string;
  status: string;
  moderator_comment?: string | null;
  moderator_user_id?: string | null;
  submitted_at?: string | null;
  reviewed_at?: string | null;
  created_at: string;
}

// ============================================================================
// RPC Function Return Types
// ============================================================================

export interface PublicationChecklist {
  basic_info: boolean;
  working_hours: boolean;
  storefront: boolean;
  menu: boolean;
  legal_data: boolean;
  coordinates: boolean;
}

export interface OrderWithDetails extends Order {
  items_count: number;
  customer_name?: string | null;
}

export interface OrderDetails {
  order: Order;
  items: OrderItem[];
  customer: {
    id: string;
    full_name?: string | null;
    phone?: string | null;
  } | null;
  cafe: {
    id: string;
    name: string;
    address: string;
    phone?: string | null;
  };
}

export interface OrdersByStatus {
  Created: Order[];
  Accepted: Order[];
  'In progress': Order[];
  Ready: Order[];
  'Picked up': Order[];
}

export interface CafeDashboardStats {
  total_orders: number;
  total_revenue: number;
  avg_order_value: number;
  active_orders: number;
  date_from: string;
  date_to: string;
}

export interface AccountDashboardStats {
  total_cafes: number;
  published_cafes: number;
  total_orders: number;
  total_revenue: number;
  date_from: string;
  date_to: string;
}

// ============================================================================
// RPC Function Parameters
// ============================================================================

export interface GetOrCreateOwnerAccountParams {
  p_user_id: string;
  p_company_name?: string;
}

export interface GetOwnerCafesParams {
  p_user_id: string;
}

export interface DuplicateCafeParams {
  p_cafe_id: string;
  p_new_name?: string;
}

export interface GetCafePublicationChecklistParams {
  p_cafe_id: string;
}

export interface SubmitCafeForModerationParams {
  p_cafe_id: string;
}

export interface OwnerUpdateOrderStatusParams {
  p_order_id: string;
  p_new_status: OrderStatus;
  p_owner_user_id?: string;
}

export interface OwnerCancelOrderParams {
  p_order_id: string;
  p_reason: string;
  p_owner_user_id?: string;
}

export interface GetCafeOrdersParams {
  p_cafe_id: string;
  p_status_filter?: OrderStatus;
  p_date_from?: string;
  p_date_to?: string;
  p_limit?: number;
  p_offset?: number;
}

export interface GetOrderDetailsParams {
  p_order_id: string;
}

export interface GetCafeDashboardStatsParams {
  p_cafe_id: string;
  p_date_from?: string;
  p_date_to?: string;
}

export interface GetAccountDashboardStatsParams {
  p_user_id: string;
  p_date_from?: string;
  p_date_to?: string;
}

export interface GetCafeOrdersByStatusParams {
  p_cafe_id: string;
}

export interface ToggleMenuItemStopListParams {
  p_item_id: string;
  p_is_available: boolean;
  p_owner_user_id?: string;
}

// ============================================================================
// Form Types (for creating/updating)
// ============================================================================

export interface CreateAccountInput {
  owner_user_id: string;
  company_name: string;
  inn?: string;
  bank_details?: Record<string, any>;
  legal_address?: string;
  contact_phone?: string;
  contact_email?: string;
}

export interface UpdateAccountInput {
  company_name?: string;
  inn?: string;
  bank_details?: Record<string, any>;
  legal_address?: string;
  contact_phone?: string;
  contact_email?: string;
}

export interface CreateCafeInput {
  account_id: string;
  name: string;
  address: string;
  phone?: string;
  email?: string;
  description?: string;
  mode?: CafeMode;
  status?: CafeStatus;
  latitude?: number;
  longitude?: number;
  opening_time?: string;
  closing_time?: string;
  working_hours?: Record<string, any>;
  logo_url?: string;
  cover_url?: string;
  photo_urls?: string[];
}

export interface UpdateCafeInput {
  name?: string;
  address?: string;
  phone?: string;
  email?: string;
  description?: string;
  mode?: CafeMode;
  status?: CafeStatus;
  latitude?: number;
  longitude?: number;
  opening_time?: string;
  closing_time?: string;
  working_hours?: Record<string, any>;
  logo_url?: string;
  cover_url?: string;
  photo_urls?: string[];
  eta_minutes?: number;
  max_active_orders?: number;
}

export interface CreateMenuCategoryInput {
  cafe_id: string;
  name: string;
  sort_order?: number;
  is_visible?: boolean;
}

export interface UpdateMenuCategoryInput {
  name?: string;
  sort_order?: number;
  is_visible?: boolean;
}

export interface CreateMenuItemInput {
  cafe_id: string;
  category_id?: string;
  category: MenuItemCategory;
  name: string;
  description: string;
  price_credits: number;
  sort_order?: number;
  is_active?: boolean;
  photo_urls?: string[];
  prep_time_sec?: number;
  availability_schedule?: {
    days: number[];
    time_from: string;
    time_to: string;
  };
}

export interface UpdateMenuItemInput {
  category_id?: string;
  category?: MenuItemCategory;
  name?: string;
  description?: string;
  price_credits?: number;
  sort_order?: number;
  is_active?: boolean;
  photo_urls?: string[];
  prep_time_sec?: number;
  availability_schedule?: {
    days: number[];
    time_from: string;
    time_to: string;
  };
}

export interface CreateMenuModifierInput {
  menu_item_id: string;
  group_name: string;
  modifier_name: string;
  price_change: number;
  is_required?: boolean;
  allow_multiple?: boolean;
  sort_order?: number;
  is_available?: boolean;
}

export interface UpdateMenuModifierInput {
  group_name?: string;
  modifier_name?: string;
  price_change?: number;
  is_required?: boolean;
  allow_multiple?: boolean;
  sort_order?: number;
  is_available?: boolean;
}

// ============================================================================
// Helper Types
// ============================================================================

export interface WorkingHoursDay {
  open: string;
  close: string;
  closed?: boolean;
}

export interface WorkingHours {
  mon?: WorkingHoursDay;
  tue?: WorkingHoursDay;
  wed?: WorkingHoursDay;
  thu?: WorkingHoursDay;
  fri?: WorkingHoursDay;
  sat?: WorkingHoursDay;
  sun?: WorkingHoursDay;
}

export interface AvailabilitySchedule {
  days: number[]; // 0-6 (Sunday-Saturday)
  time_from: string; // "HH:MM"
  time_to: string; // "HH:MM"
}

export interface ModifierGroup {
  name: string;
  is_required: boolean;
  allow_multiple: boolean;
  modifiers: MenuModifier[];
}

// ============================================================================
// Real-time Subscription Types
// ============================================================================

export interface RealtimeOrderPayload {
  new: Order;
  old?: Order;
  eventType: 'INSERT' | 'UPDATE' | 'DELETE';
}

// ============================================================================
// Enums (for validation)
// ============================================================================

export const CAFE_MODES: CafeMode[] = ['open', 'busy', 'paused', 'closed'];
export const CAFE_STATUSES: CafeStatus[] = ['draft', 'moderation', 'published', 'paused', 'rejected'];
export const ORDER_STATUSES: OrderStatus[] = [
  'Created',
  'Accepted',
  'Rejected',
  'In progress',
  'Ready',
  'Picked up',
  'Canceled',
  'Refunded',
  'No-show'
];
export const ORDER_TYPES: OrderType[] = ['now', 'preorder', 'subscription'];
export const PAYMENT_STATUSES: PaymentStatus[] = ['pending', 'paid', 'failed', 'refunded'];
export const MENU_ITEM_CATEGORIES: MenuItemCategory[] = ['drinks', 'food', 'syrups', 'merch'];

// ============================================================================
// Utility Types
// ============================================================================

export type DatabaseError = {
  message: string;
  details?: string;
  hint?: string;
  code?: string;
};

export type RPCResult<T> = {
  data: T | null;
  error: DatabaseError | null;
};

// ============================================================================
// Status Badge Colors (for UI)
// ============================================================================

export const CAFE_STATUS_COLORS: Record<CafeStatus, { bg: string; text: string }> = {
  draft: { bg: 'bg-blue-100', text: 'text-blue-800' },
  moderation: { bg: 'bg-yellow-100', text: 'text-yellow-800' },
  published: { bg: 'bg-green-100', text: 'text-green-800' },
  paused: { bg: 'bg-gray-100', text: 'text-gray-800' },
  rejected: { bg: 'bg-red-100', text: 'text-red-800' }
};

export const ORDER_STATUS_COLORS: Record<OrderStatus, string> = {
  'Created': 'bg-blue-500',
  'Accepted': 'bg-yellow-500',
  'In progress': 'bg-orange-500',
  'Ready': 'bg-green-500',
  'Picked up': 'bg-green-200',
  'Rejected': 'bg-red-500',
  'Canceled': 'bg-red-500',
  'Refunded': 'bg-purple-500',
  'No-show': 'bg-gray-500'
};

export const PAYMENT_STATUS_COLORS: Record<PaymentStatus, string> = {
  pending: 'bg-yellow-500',
  paid: 'bg-green-500',
  failed: 'bg-red-500',
  refunded: 'bg-blue-500'
};
