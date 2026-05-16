export interface Card {
  id: string;
  name: string;
  alias: string[];
  series: string;
  cardNo: string;
  image: string;
  type: string;
  subType?: string;
  faction: string;
  rarity: string;
  cost: number | null;
  attack: number | null;
  health: number | null;
  tags: string[];
  effectText: string;
  flavorText?: string;
  faqIds: string[];
  searchText: string;
  verified: boolean;
}

export interface FaqEntry {
  id: string;
  question: string;
  answer: string;
  relatedCardIds: string[];
  relatedCardKeys?: string[];
  keywords: string[];
  source: string;
}

export interface DeckCard {
  cardKey: string;
  count: number;
}

export interface DeckCompatibilityIssue {
  cardKey: string;
  count: number;
  reason: "ambiguous-legacy-id" | "unknown-card-key";
  candidates: string[];
}

export interface DeckDraft {
  editingDeckId: string;
  editingPublicDeckId: string;
  name: string;
  description: string;
  difficulty: number;
  deckPassword: string;
  isPublic: boolean;
  coverImage: string;
  manualCardText: string;
  cards: DeckCard[];
}

export interface SavedDeck {
  id: string;
  name: string;
  description: string;
  difficulty: number;
  coverImage: string;
  cards: DeckCard[];
  createdAt: string;
}

export interface PublicDeck {
  id: string;
  name: string;
  description: string;
  difficulty: number;
  firstCardKey: string;
  cardCount: number;
  cards: DeckCard[];
  createdAt: string;
  updatedAt: string;
  originalCardCount?: number;
  compatibilityStatus?: "full" | "partial" | "none";
  incompatibleCardCount?: number;
  incompatibleCards?: DeckCompatibilityIssue[];
}

export interface CreatePublicDeckPayload {
  name: string;
  description: string;
  difficulty: number;
  deckPassword: string;
  cards: DeckCard[];
}

export interface UpdatePublicDeckPayload extends CreatePublicDeckPayload {
  password: string;
}
