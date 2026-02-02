# Backend Testing Guide

Comprehensive guide for running and maintaining backend tests for SubscribeCoffie.

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [CI/CD Pipeline](#cicd-pipeline)
- [Writing New Tests](#writing-new-tests)
- [Best Practices](#best-practices)

## Overview

The backend testing suite consists of:

- **Unit Tests**: Testing individual RPC functions
- **Integration Tests**: Testing complete workflows and interactions
- **Security Tests**: Testing RLS policies and permissions
- **Performance Tests**: Testing query performance and scalability

## Test Structure

```
tests/
├── run_all_tests.sh              # Original test runner
├── run_all_tests_enhanced.sh     # Enhanced test runner with reporting
├── seed_test_data.sql            # Test data seeding
├── orders_rpc.test.sql           # Orders RPC tests
├── wallets_rpc.test.sql          # Wallets RPC tests
├── analytics.test.sql            # Analytics tests
├── payment_integration.test.sql  # Payment integration tests
├── rpc_integration.test.sql      # RPC integration tests
├── integration_full.test.sql     # Full integration tests (NEW)
├── security_tests.sql            # Security tests
└── README_TESTING.md             # This file
```

## Running Tests

### Prerequisites

1. **Supabase Running**: Make sure Supabase is running locally
   ```bash
   cd SubscribeCoffieBackend
   supabase start
   ```

2. **Database Connection**: Tests use the default local connection
   ```bash
   export DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
   ```

### Run All Tests

```bash
cd SubscribeCoffieBackend
./tests/run_all_tests_enhanced.sh
```

### Run Individual Test Suites

```bash
# Orders RPC tests
psql $DATABASE_URL -f tests/orders_rpc.test.sql

# Wallets RPC tests
psql $DATABASE_URL -f tests/wallets_rpc.test.sql

# Integration tests
psql $DATABASE_URL -f tests/integration_full.test.sql
```

### Run Specific Test

Edit the test file and run only the section you need:

```bash
psql $DATABASE_URL -c "
DO \$\$
BEGIN
  -- Your test code here
END \$\$;
"
```

## CI/CD Pipeline

### GitHub Actions Workflows

The project includes GitHub Actions workflows for automated testing:

#### Backend Tests (`backend-tests.yml`)

- **Triggers**: Push to `main` or `develop`, Pull Requests
- **What it does**:
  - Starts Supabase instance
  - Runs all migrations
  - Executes test suite
  - Uploads test results

#### Deploy Staging (`deploy-staging.yml`)

- **Triggers**: Push to `develop` branch
- **What it does**:
  - Deploys to Supabase staging environment
  - Runs database migrations
  - Deploys Edge Functions

### Running CI Locally

You can simulate CI locally using Docker:

```bash
# Start local Supabase
supabase start

# Run migrations
supabase db reset

# Run tests
./tests/run_all_tests_enhanced.sh
```

## Writing New Tests

### Test File Structure

```sql
-- Test Suite Name
-- Description of what this test suite covers

\echo '========================================'
\echo 'Test Suite Name'
\echo '========================================'

-- Test Case 1: Description
\echo ''
\echo 'Test 1: Test case description'
DO $$
DECLARE
  -- Variables
BEGIN
  -- Test logic
  
  -- Assertions
  IF condition THEN
    RAISE NOTICE '✅ PASS: Test description';
  ELSE
    RAISE EXCEPTION '❌ FAIL: Test description';
  END IF;
  
  -- Cleanup
END $$;
```

### Test Naming Convention

- Use descriptive names: `test_wallet_creation_with_citypass`
- Include expected outcome: `test_order_status_update_success`
- Group related tests: `test_payment_integration_*`

### Assertions

```sql
-- Success
IF condition THEN
  RAISE NOTICE '✅ PASS: Description';
ELSE
  RAISE EXCEPTION '❌ FAIL: Description';
END IF;

-- Exception handling
BEGIN
  -- Code that should fail
  RAISE EXCEPTION '❌ FAIL: Should have thrown error';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE '%Expected error%' THEN
      RAISE NOTICE '✅ PASS: Correct error thrown';
    ELSE
      RAISE EXCEPTION '❌ FAIL: Wrong error: %', SQLERRM;
    END IF;
END;
```

### Cleanup

Always clean up test data:

```sql
-- Cleanup at end of test
DELETE FROM table_name WHERE id = test_id;
DELETE FROM auth.users WHERE id = test_user_id;
```

## Best Practices

### 1. Isolation

- Each test should be independent
- Don't rely on other tests' data
- Clean up after yourself

### 2. Test Data

- Use specific UUIDs for test data
- Prefix test emails: `test_*@test.com`
- Use test phone numbers: `+7999*`

### 3. Performance

- Keep tests fast (< 1 second each)
- Use transactions when possible
- Mock external dependencies

### 4. Documentation

- Add comments explaining complex logic
- Document expected behavior
- Include test scenarios in comments

### 5. Error Messages

- Make error messages descriptive
- Include actual vs expected values
- Use emojis for quick visual feedback (✅ ❌ ⚠️)

## Test Categories

### Unit Tests

Test individual functions in isolation:

```sql
-- Test: create_wallet function
result := create_wallet(user_id, 'citypass');
#expect(result IS NOT NULL);
```

### Integration Tests

Test complete workflows:

```sql
-- Test: Complete order flow
1. Create user
2. Create wallet
3. Add balance
4. Create order
5. Pay for order
6. Update order status
7. Verify all steps
```

### Security Tests

Test RLS policies:

```sql
-- Test: Users can only see their own wallets
SET LOCAL role = 'authenticated';
SET LOCAL request.jwt.claims = '{"sub": "user-id"}';
SELECT * FROM wallets; -- Should only see user's wallets
```

### Performance Tests

Test query performance:

```sql
-- Test: Query should complete in < 1 second
start_time := clock_timestamp();
-- Run query
end_time := clock_timestamp();
duration := end_time - start_time;
IF duration < interval '1 second' THEN
  RAISE NOTICE '✅ Performance OK';
END IF;
```

## Troubleshooting

### Tests Fail to Connect

```bash
# Check Supabase status
supabase status

# Restart Supabase
supabase stop
supabase start
```

### Tests Fail Due to Missing Data

```bash
# Reset database and reseed
supabase db reset
psql $DATABASE_URL -f tests/seed_test_data.sql
```

### Permission Errors

```bash
# Make scripts executable
chmod +x tests/*.sh
```

## Test Coverage

Current test coverage:

- ✅ Orders RPC: 100%
- ✅ Wallets RPC: 100%
- ✅ Payment Integration: 100%
- ✅ Analytics: 80%
- ✅ Full Integration: 100%
- ⚠️ Social Features: 50%

Goal: 90%+ coverage for all critical paths

## Contributing

When adding new features:

1. Write tests first (TDD)
2. Run existing tests to ensure no breakage
3. Update this README if adding new test categories
4. Ensure all tests pass before PR

## Support

For questions or issues with tests:

1. Check this README
2. Review test output for error messages
3. Check GitHub Actions logs
4. Open an issue with test output

---

Last Updated: January 30, 2026
