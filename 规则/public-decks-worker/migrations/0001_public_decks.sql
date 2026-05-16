CREATE TABLE IF NOT EXISTS public_decks (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  first_card_key TEXT NOT NULL,
  card_count INTEGER NOT NULL,
  cards_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_public_decks_created_at
  ON public_decks(created_at DESC);
