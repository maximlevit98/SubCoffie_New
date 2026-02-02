-- Add ingredients, sizes and volume pricing to menu_items

-- Add column for ingredients list
ALTER TABLE menu_items 
ADD COLUMN IF NOT EXISTS ingredients TEXT;

-- Add column for sizes/volumes with prices (stored as JSONB)
-- Structure: [{"size": "0.3л", "price_credits": 100}, {"size": "0.5л", "price_credits": 150}]
ALTER TABLE menu_items 
ADD COLUMN IF NOT EXISTS sizes JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN menu_items.ingredients IS 'Comma-separated list of ingredients, e.g., "Эспрессо, молоко, сироп"';
COMMENT ON COLUMN menu_items.sizes IS 'Array of size options with prices, e.g., [{"size": "0.3л", "price_credits": 100}]';

-- Create index for searching by ingredients
CREATE INDEX IF NOT EXISTS menu_items_ingredients_idx ON menu_items USING gin(to_tsvector('russian', ingredients));
