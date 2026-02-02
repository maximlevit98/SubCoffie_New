# Marketing Tools Quickstart

## Overview

The marketing tools feature provides a comprehensive system for managing promotional campaigns, promo codes, and push notifications to engage users and drive conversions.

## Features Implemented

### 1. Promo Codes
- Create and manage discount codes
- Support for percentage, fixed amount, and free item discounts
- Usage limits (total and per user)
- Validity periods
- Cafe-specific targeting
- Real-time validation and application

### 2. Campaigns
- Create marketing campaigns linked to promo codes
- Track performance metrics (impressions, clicks, conversions)
- Schedule campaigns with start/end dates
- Multiple campaign types (promo, push, email, banner, loyalty)

### 3. Push Campaigns
- Send targeted push notifications
- User segmentation (all, new, active, dormant, VIP)
- Deep linking to specific actions
- Delivery tracking and analytics

## Database Schema

### Tables Created

1. **promo_codes**: Store promotional discount codes
   - Discount configuration (type, value, caps)
   - Usage limits and restrictions
   - Validity periods
   - Targeting options

2. **promo_usage**: Track promo code usage history
   - User and order associations
   - Discount amounts applied
   - Timestamps

3. **campaigns**: Marketing campaigns
   - Campaign details and status
   - Performance metrics
   - Promo code associations

4. **push_campaigns**: Push notification campaigns
   - Message content and targeting
   - Delivery metrics
   - Deep link configuration

### RPC Functions

- `validate_promo_code(code, user_id, order_amount)`: Validate a promo code
- `apply_promo_code(order_id, promo_id)`: Apply a promo to an order
- `get_eligible_promo_codes(user_id, cafe_id, order_amount)`: Get available promos
- `send_push_campaign(campaign_id, user_segment)`: Send push notifications
- `get_campaign_analytics(campaign_id, start_date, end_date)`: Get campaign stats

### Views

- `active_promo_codes_summary`: Summary of active promo codes with stats
- `campaign_performance`: Campaign performance metrics with CTR and conversion rates

## Admin Panel Usage

### Creating a Promo Code

1. Navigate to `/admin/marketing/promo-codes`
2. Click "Create Promo Code"
3. Fill in the form:
   - **Code**: Uppercase alphanumeric (e.g., SUMMER2026)
   - **Discount Type**: Percentage, Fixed Amount, or Free Item
   - **Discount Value**: Amount or percentage
   - **Restrictions**: Min order amount, max discount cap
   - **Usage Limits**: Total uses and per-user limits
   - **Validity**: Start and end dates
4. Submit to create

### Managing Campaigns

1. Navigate to `/admin/marketing/campaigns`
2. Click "Create Campaign"
3. Configure:
   - **Name & Description**: Campaign details
   - **Type**: Promo, Push, Email, Banner, or Loyalty
   - **Promo Code**: Link to existing promo code (optional)
   - **Schedule**: Start and end dates
4. Track performance on the campaign detail page

### Viewing Analytics

- **Promo Codes Page**: Shows total uses, discount given, and revenue
- **Campaign Performance**: CTR, conversion rate, and ROI metrics
- **Individual Detail Pages**: Deep dive into specific promos or campaigns

## iOS App Integration

### Promo Code Usage Flow

1. User enters checkout
2. Sees promo code input field
3. Enters promo code (e.g., "SUMMER2026")
4. Clicks "Apply"
5. App validates via RPC: `validate_promo_code`
6. If valid:
   - Discount is shown in order summary
   - Final amount is updated
   - Promo code is applied to the order
7. If invalid:
   - Error message is displayed
   - User can try another code

### Implementation Details

The `CheckoutView.swift` includes:
- Promo code input field with validation
- Real-time discount calculation
- Visual feedback for applied codes
- Integration with existing order flow

## API Examples

### Validate Promo Code

```typescript
const response = await supabase.rpc('validate_promo_code', {
  p_code: 'SUMMER2026',
  p_user_id: userId,
  p_order_amount: 500
});

// Response:
{
  valid: true,
  promo_id: 'uuid',
  code: 'SUMMER2026',
  discount_amount: 100,
  final_amount: 400,
  savings: 100
}
```

### Apply Promo Code

```typescript
const result = await supabase.rpc('apply_promo_code', {
  p_order_id: orderId,
  p_promo_id: promoId
});

// Response:
{
  success: true,
  discount_applied: 100,
  final_amount: 400
}
```

### Get Eligible Promo Codes

```typescript
const promoCodes = await supabase.rpc('get_eligible_promo_codes', {
  p_user_id: userId,
  p_cafe_id: cafeId,
  p_order_amount: 500
});

// Returns array of eligible promo codes with estimated discounts
```

## Best Practices

### Creating Effective Promo Codes

1. **Clear Naming**: Use descriptive codes (e.g., WELCOME20, SUMMER50)
2. **Set Caps**: Always cap percentage discounts to prevent abuse
3. **Usage Limits**: Limit per-user usage for one-time offers
4. **Expiry Dates**: Set reasonable validity periods
5. **Min Order**: Require minimum order amounts for profitability

### Campaign Strategy

1. **Track Everything**: Monitor impressions, clicks, conversions
2. **A/B Testing**: Create multiple campaigns to test effectiveness
3. **Segmentation**: Target the right users with relevant offers
4. **Timing**: Schedule campaigns for peak engagement times
5. **Follow-up**: Send reminders before promo expiry

### Security Considerations

1. **Validation**: All promo codes are validated server-side
2. **Usage Tracking**: Every usage is logged and audited
3. **RLS Policies**: Users can only see active, valid codes
4. **Admin Only**: Campaign creation restricted to admins
5. **Audit Logs**: All marketing actions are logged

## Metrics to Monitor

### Key Performance Indicators

1. **Redemption Rate**: % of codes used vs distributed
2. **Average Discount**: Mean discount given per order
3. **ROI**: Revenue generated vs discount given
4. **User Acquisition**: New users from campaigns
5. **Repeat Usage**: Users returning after promo

### Campaign Metrics

1. **CTR (Click-Through Rate)**: Clicks / Impressions
2. **Conversion Rate**: Conversions / Clicks
3. **Total Revenue**: Sum of orders from campaign
4. **Cost per Acquisition**: Campaign cost / New users

## Next Steps

### Planned Enhancements

1. **Push Notifications Integration**: Connect to Firebase/OneSignal
2. **Email Campaigns**: Integration with SendGrid/Mailchimp
3. **Advanced Segmentation**: ML-based user targeting
4. **Automated Campaigns**: Trigger-based campaigns (birthdays, anniversaries)
5. **Referral Codes**: User-specific referral tracking

### Testing Checklist

- [ ] Create promo code in admin panel
- [ ] Apply promo code in iOS app
- [ ] Verify discount calculation
- [ ] Check usage limits
- [ ] Test expiry dates
- [ ] Validate cafe-specific codes
- [ ] Monitor campaign analytics
- [ ] Test push campaign (when integrated)

## Support

For issues or questions:
1. Check migration logs: `supabase/migrations/20260211000000_marketing_tools.sql`
2. Review admin panel implementation: `subscribecoffie-admin/app/admin/marketing/`
3. iOS integration: `SubscribeCoffieClean/Views/CheckoutView.swift`
4. Backend queries: `subscribecoffie-admin/lib/supabase/queries/marketing.ts`

## Related Documentation

- [Payment Integration](./PAYMENT_INTEGRATION.md)
- [Loyalty Program](./LOYALTY_PROGRAM_IMPLEMENTATION.md)
- [Analytics Implementation](./ANALYTICS_IMPLEMENTATION.md)
- [Admin Panel Guide](../subscribecoffie-admin/README.md)
