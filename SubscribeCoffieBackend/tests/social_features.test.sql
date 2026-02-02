-- Test Suite for Social Features
-- Run this after applying migration 20260213000000_social_features.sql

BEGIN;

-- Create test users
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'user1@test.com', 'encrypted', now(), now(), now()),
    ('22222222-2222-2222-2222-222222222222', 'user2@test.com', 'encrypted', now(), now(), now()),
    ('33333333-3333-3333-3333-333333333333', 'user3@test.com', 'encrypted', now(), now(), now())
ON CONFLICT (id) DO NOTHING;

-- Create test cafe
INSERT INTO cafes (id, name, address, latitude, longitude, created_at, updated_at)
VALUES 
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Cafe', '123 Test St', 55.7558, 37.6173, now(), now())
ON CONFLICT (id) DO NOTHING;

-- Create test menu item
INSERT INTO menu_items (id, cafe_id, name, description, price_credits, category, is_available, created_at, updated_at)
VALUES 
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 
     'Test Latte', 'Delicious test latte', 350, 'coffee', true, now(), now())
ON CONFLICT (id) DO NOTHING;

-- Create test order
INSERT INTO orders (id, user_id, cafe_id, total_amount_credits, status, created_at, updated_at)
VALUES 
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 500, 'issued', now(), now())
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- TEST 1: Submit Review
-- =====================================================
DO $$
DECLARE
    v_result JSON;
    v_review_id UUID;
BEGIN
    -- Submit a review for cafe
    SELECT submit_review(
        '11111111-1111-1111-1111-111111111111'::UUID,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
        NULL,
        'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID,
        5,
        'Great coffee and atmosphere!',
        ARRAY['photo1.jpg', 'photo2.jpg']
    ) INTO v_result;
    
    -- Check success
    IF (v_result->>'success')::BOOLEAN THEN
        v_review_id := (v_result->>'review_id')::UUID;
        RAISE NOTICE 'TEST 1 PASSED: Review submitted successfully. ID: %', v_review_id;
        
        -- Verify review was created
        IF EXISTS (SELECT 1 FROM user_reviews WHERE id = v_review_id) THEN
            RAISE NOTICE 'TEST 1 PASSED: Review exists in database';
        ELSE
            RAISE EXCEPTION 'TEST 1 FAILED: Review not found in database';
        END IF;
    ELSE
        RAISE EXCEPTION 'TEST 1 FAILED: %', v_result->>'error';
    END IF;
END $$;

-- =====================================================
-- TEST 2: Get Cafe Reviews
-- =====================================================
DO $$
DECLARE
    v_result JSON;
    v_total_reviews INTEGER;
BEGIN
    SELECT get_cafe_reviews('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID, 20, 0) INTO v_result;
    
    v_total_reviews := (v_result->>'total_reviews')::INTEGER;
    
    IF v_total_reviews >= 1 THEN
        RAISE NOTICE 'TEST 2 PASSED: Found % reviews', v_total_reviews;
    ELSE
        RAISE EXCEPTION 'TEST 2 FAILED: Expected at least 1 review, found %', v_total_reviews;
    END IF;
END $$;

-- =====================================================
-- TEST 3: Toggle Favorite (Add)
-- =====================================================
DO $$
DECLARE
    v_result JSON;
    v_is_favorited BOOLEAN;
BEGIN
    -- Add to favorites
    SELECT toggle_favorite(
        '11111111-1111-1111-1111-111111111111'::UUID,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
        NULL
    ) INTO v_result;
    
    v_is_favorited := (v_result->>'is_favorited')::BOOLEAN;
    
    IF v_is_favorited THEN
        RAISE NOTICE 'TEST 3 PASSED: Cafe added to favorites';
    ELSE
        RAISE EXCEPTION 'TEST 3 FAILED: Cafe should be favorited';
    END IF;
END $$;

-- =====================================================
-- TEST 4: Toggle Favorite (Remove)
-- =====================================================
DO $$
DECLARE
    v_result JSON;
    v_is_favorited BOOLEAN;
BEGIN
    -- Remove from favorites
    SELECT toggle_favorite(
        '11111111-1111-1111-1111-111111111111'::UUID,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
        NULL
    ) INTO v_result;
    
    v_is_favorited := (v_result->>'is_favorited')::BOOLEAN;
    
    IF NOT v_is_favorited THEN
        RAISE NOTICE 'TEST 4 PASSED: Cafe removed from favorites';
    ELSE
        RAISE EXCEPTION 'TEST 4 FAILED: Cafe should not be favorited';
    END IF;
END $$;

-- =====================================================
-- TEST 5: Get User Favorites
-- =====================================================
DO $$
DECLARE
    v_result JSON;
BEGIN
    -- Add a favorite first
    PERFORM toggle_favorite(
        '11111111-1111-1111-1111-111111111111'::UUID,
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID,
        NULL
    );
    
    -- Get favorites
    SELECT get_user_favorites('11111111-1111-1111-1111-111111111111'::UUID, 'all') INTO v_result;
    
    IF v_result IS NOT NULL THEN
        RAISE NOTICE 'TEST 5 PASSED: User favorites retrieved';
    ELSE
        RAISE EXCEPTION 'TEST 5 FAILED: Could not retrieve favorites';
    END IF;
END $$;

-- =====================================================
-- TEST 6: Send Friend Request
-- =====================================================
DO $$
DECLARE
    v_result JSON;
    v_request_id UUID;
BEGIN
    SELECT send_friend_request(
        '11111111-1111-1111-1111-111111111111'::UUID,
        '22222222-2222-2222-2222-222222222222'::UUID
    ) INTO v_result;
    
    IF (v_result->>'success')::BOOLEAN THEN
        v_request_id := (v_result->>'request_id')::UUID;
        RAISE NOTICE 'TEST 6 PASSED: Friend request sent. ID: %', v_request_id;
    ELSE
        RAISE EXCEPTION 'TEST 6 FAILED: %', v_result->>'error';
    END IF;
END $$;

-- =====================================================
-- TEST 7: Respond to Friend Request (Accept)
-- =====================================================
DO $$
DECLARE
    v_result JSON;
    v_request_id UUID;
BEGIN
    -- Get the request ID
    SELECT id INTO v_request_id
    FROM user_friends
    WHERE user_id = '11111111-1111-1111-1111-111111111111'
      AND friend_id = '22222222-2222-2222-2222-222222222222'
      AND status = 'pending'
    LIMIT 1;
    
    -- Accept the request
    SELECT respond_to_friend_request(
        v_request_id,
        '22222222-2222-2222-2222-222222222222'::UUID,
        true
    ) INTO v_result;
    
    IF (v_result->>'success')::BOOLEAN AND (v_result->>'status') = 'accepted' THEN
        RAISE NOTICE 'TEST 7 PASSED: Friend request accepted';
    ELSE
        RAISE EXCEPTION 'TEST 7 FAILED: %', v_result->>'error';
    END IF;
END $$;

-- =====================================================
-- TEST 8: Get User Friends
-- =====================================================
DO $$
DECLARE
    v_result JSON;
    v_friends_count INTEGER;
BEGIN
    SELECT get_user_friends('11111111-1111-1111-1111-111111111111'::UUID, 'accepted') INTO v_result;
    
    v_friends_count := json_array_length(v_result);
    
    IF v_friends_count >= 1 THEN
        RAISE NOTICE 'TEST 8 PASSED: Found % friends', v_friends_count;
    ELSE
        RAISE EXCEPTION 'TEST 8 FAILED: Expected at least 1 friend, found %', v_friends_count;
    END IF;
END $$;

-- =====================================================
-- TEST 9: Create Shared Order
-- =====================================================
DO $$
DECLARE
    v_result JSON;
    v_shared_order_id UUID;
    v_participants JSON;
BEGIN
    -- Prepare participants JSON
    v_participants := json_build_array(
        json_build_object('user_id', '22222222-2222-2222-2222-222222222222', 'share_amount_credits', 250),
        json_build_object('user_id', '33333333-3333-3333-3333-333333333333', 'share_amount_credits', 250)
    );
    
    SELECT create_shared_order(
        'cccccccc-cccc-cccc-cccc-cccccccccccc'::UUID,
        '11111111-1111-1111-1111-111111111111'::UUID,
        v_participants
    ) INTO v_result;
    
    IF (v_result->>'success')::BOOLEAN THEN
        v_shared_order_id := (v_result->>'shared_order_id')::UUID;
        RAISE NOTICE 'TEST 9 PASSED: Shared order created. ID: %', v_shared_order_id;
        
        -- Verify participants were created
        IF EXISTS (
            SELECT 1 FROM shared_order_participants 
            WHERE shared_order_id = v_shared_order_id
        ) THEN
            RAISE NOTICE 'TEST 9 PASSED: Participants created';
        ELSE
            RAISE EXCEPTION 'TEST 9 FAILED: No participants found';
        END IF;
    ELSE
        RAISE EXCEPTION 'TEST 9 FAILED: %', v_result->>'error';
    END IF;
END $$;

-- =====================================================
-- TEST 10: Mark Review as Helpful
-- =====================================================
DO $$
DECLARE
    v_result JSON;
    v_review_id UUID;
BEGIN
    -- Get the review ID from TEST 1
    SELECT id INTO v_review_id
    FROM user_reviews
    WHERE user_id = '11111111-1111-1111-1111-111111111111'
      AND cafe_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    LIMIT 1;
    
    -- Mark as helpful by another user
    SELECT mark_review_helpful(
        v_review_id,
        '22222222-2222-2222-2222-222222222222'::UUID,
        true
    ) INTO v_result;
    
    IF (v_result->>'success')::BOOLEAN THEN
        RAISE NOTICE 'TEST 10 PASSED: Review marked as helpful';
        
        -- Verify helpful count increased
        IF EXISTS (
            SELECT 1 FROM user_reviews 
            WHERE id = v_review_id AND helpful_count > 0
        ) THEN
            RAISE NOTICE 'TEST 10 PASSED: Helpful count increased';
        ELSE
            RAISE EXCEPTION 'TEST 10 FAILED: Helpful count not updated';
        END IF;
    ELSE
        RAISE EXCEPTION 'TEST 10 FAILED: %', v_result->>'error';
    END IF;
END $$;

-- =====================================================
-- TEST 11: Check Views
-- =====================================================
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Check cafe_ratings_summary view
    SELECT COUNT(*) INTO v_count FROM cafe_ratings_summary WHERE cafe_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    
    IF v_count >= 1 THEN
        RAISE NOTICE 'TEST 11 PASSED: cafe_ratings_summary view works';
    ELSE
        RAISE EXCEPTION 'TEST 11 FAILED: cafe_ratings_summary view returned no results';
    END IF;
    
    -- Check popular_items_by_favorites view
    SELECT COUNT(*) INTO v_count FROM popular_items_by_favorites;
    
    IF v_count >= 0 THEN
        RAISE NOTICE 'TEST 11 PASSED: popular_items_by_favorites view works';
    ELSE
        RAISE EXCEPTION 'TEST 11 FAILED: popular_items_by_favorites view error';
    END IF;
END $$;

-- =====================================================
-- Cleanup
-- =====================================================
-- Delete test data (in reverse order of dependencies)
DELETE FROM review_helpfulness WHERE review_id IN (SELECT id FROM user_reviews WHERE user_id = '11111111-1111-1111-1111-111111111111');
DELETE FROM shared_order_participants WHERE shared_order_id IN (SELECT id FROM shared_orders WHERE initiator_user_id = '11111111-1111-1111-1111-111111111111');
DELETE FROM shared_orders WHERE initiator_user_id = '11111111-1111-1111-1111-111111111111';
DELETE FROM user_friends WHERE user_id = '11111111-1111-1111-1111-111111111111' OR friend_id = '11111111-1111-1111-1111-111111111111';
DELETE FROM user_favorites WHERE user_id = '11111111-1111-1111-1111-111111111111';
DELETE FROM user_reviews WHERE user_id = '11111111-1111-1111-1111-111111111111';
DELETE FROM orders WHERE id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
DELETE FROM menu_items WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
DELETE FROM cafes WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
DELETE FROM auth.users WHERE id IN ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');

RAISE NOTICE '====================================';
RAISE NOTICE 'ALL TESTS PASSED! 🎉';
RAISE NOTICE '====================================';

ROLLBACK;
-- Note: Use COMMIT instead of ROLLBACK if you want to keep the test data
