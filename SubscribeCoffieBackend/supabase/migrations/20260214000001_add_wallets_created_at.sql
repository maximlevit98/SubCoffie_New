-- Migration: Add created_at column to wallets table
-- Date: 2026-02-14
-- Purpose: Fix missing created_at column that get_user_wallets() expects

-- Add created_at column (defaults to updated_at if missing)
ALTER TABLE public.wallets
ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now() NOT NULL;

-- Backfill created_at with updated_at for existing records
UPDATE public.wallets
SET created_at = updated_at
WHERE created_at IS NULL OR created_at = updated_at;

-- Comment
COMMENT ON COLUMN public.wallets.created_at IS 'Timestamp when wallet was created';
