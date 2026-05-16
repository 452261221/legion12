import { computed, ref, watch } from "vue";

import type { Card, DeckCard, DeckDraft, SavedDeck } from "@/types";
import { buildCardKey, matchCardKey } from "@/utils/cardKey";

export const MAX_DECK_SIZE = 50;
export const MAX_CARD_COPIES = 3;

const DRAFT_STORAGE_KEY = "legion-card-mini-deck-draft";
const DECKS_STORAGE_KEY = "legion-card-mini-created-decks";

function createEmptyDraft(): DeckDraft {
  return {
    editingDeckId: "",
    editingPublicDeckId: "",
    name: "",
    description: "",
    difficulty: 1,
    deckPassword: "",
    isPublic: false,
    coverImage: "",
    manualCardText: "",
    cards: []
  };
}

function cloneCards(cards: DeckCard[]): DeckCard[] {
  return cards.map((item) => ({ ...item }));
}

function normalizeDifficulty(value: unknown): number {
  const difficulty = Number(value);
  if (Number.isInteger(difficulty) && difficulty >= 1 && difficulty <= 3) {
    return difficulty;
  }
  return 1;
}

function normalizeDraft(value: unknown): DeckDraft {
  const rawValue = value && typeof value === "object" ? (value as Partial<DeckDraft>) : {};
  return {
    ...createEmptyDraft(),
    editingDeckId: typeof rawValue.editingDeckId === "string" ? rawValue.editingDeckId : "",
    editingPublicDeckId: typeof rawValue.editingPublicDeckId === "string" ? rawValue.editingPublicDeckId : "",
    name: typeof rawValue.name === "string" ? rawValue.name : "",
    description: typeof rawValue.description === "string" ? rawValue.description : "",
    difficulty: normalizeDifficulty(rawValue.difficulty),
    deckPassword: typeof rawValue.deckPassword === "string" ? rawValue.deckPassword : "",
    isPublic: Boolean(rawValue.isPublic),
    coverImage: typeof rawValue.coverImage === "string" ? rawValue.coverImage : "",
    manualCardText: typeof rawValue.manualCardText === "string" ? rawValue.manualCardText : "",
    cards: Array.isArray(rawValue.cards) ? cloneCards(rawValue.cards as DeckCard[]) : []
  };
}

function normalizeSavedDeck(value: unknown): SavedDeck | null {
  const rawValue = value && typeof value === "object" ? (value as Partial<SavedDeck>) : null;
  if (!rawValue || typeof rawValue.id !== "string" || typeof rawValue.name !== "string") {
    return null;
  }

  return {
    id: rawValue.id,
    name: rawValue.name,
    description: typeof rawValue.description === "string" ? rawValue.description : "",
    difficulty: normalizeDifficulty(rawValue.difficulty),
    coverImage: typeof rawValue.coverImage === "string" ? rawValue.coverImage : "",
    cards: Array.isArray(rawValue.cards) ? cloneCards(rawValue.cards as DeckCard[]) : [],
    createdAt: typeof rawValue.createdAt === "string" ? rawValue.createdAt : new Date().toISOString()
  };
}

function normalizeDeckCardList(deckCards: DeckCard[], libraryCards: Card[]): DeckCard[] {
  const countMap = new Map<string, number>();

  for (const item of deckCards) {
    const matchedCard = libraryCards.find((card) => matchCardKey(card, item.cardKey));
    const normalizedCardKey = matchedCard ? buildCardKey(matchedCard) : item.cardKey;
    countMap.set(normalizedCardKey, (countMap.get(normalizedCardKey) ?? 0) + item.count);
  }

  return Array.from(countMap.entries()).map(([cardKey, count]) => ({ cardKey, count }));
}

function loadFromStorage<T>(storageKey: string, fallback: T): T {
  try {
    const rawValue = uni.getStorageSync(storageKey);
    if (!rawValue) {
      return fallback;
    }

    if (typeof rawValue === "string") {
      return JSON.parse(rawValue) as T;
    }

    return rawValue as T;
  } catch {
    return fallback;
  }
}

function saveToStorage(storageKey: string, value: unknown) {
  uni.setStorageSync(storageKey, JSON.stringify(value));
}

const draft = ref<DeckDraft>(normalizeDraft(loadFromStorage(DRAFT_STORAGE_KEY, createEmptyDraft())));
const decks = ref<SavedDeck[]>(
  loadFromStorage(DECKS_STORAGE_KEY, [])
    .map((item: unknown) => normalizeSavedDeck(item))
    .filter(Boolean) as SavedDeck[]
);

watch(
  draft,
  (value) => {
    saveToStorage(DRAFT_STORAGE_KEY, value);
  },
  { deep: true }
);

watch(
  decks,
  (value) => {
    saveToStorage(DECKS_STORAGE_KEY, value);
  },
  { deep: true }
);

function createDeckId() {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }

  return `deck-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

export function validateDeckCards(cards: DeckCard[]) {
  const totalCount = cards.reduce((sum, item) => sum + item.count, 0);
  if (totalCount > MAX_DECK_SIZE) {
    return `卡组总数不能超过 ${MAX_DECK_SIZE} 张。`;
  }

  for (const item of cards) {
    if (item.count > MAX_CARD_COPIES) {
      return `单张卡牌最多只能选择 ${MAX_CARD_COPIES} 张。`;
    }
  }

  return null;
}

export function useDeck() {
  function reconcileCardKeys(libraryCards: Card[]) {
    if (!libraryCards.length) {
      return;
    }

    const normalizedDraftCards = normalizeDeckCardList(draft.value.cards, libraryCards);
    const draftChanged =
      normalizedDraftCards.length !== draft.value.cards.length ||
      normalizedDraftCards.some((item, index) => {
        const current = draft.value.cards[index];
        return !current || current.cardKey !== item.cardKey || current.count !== item.count;
      });

    if (draftChanged) {
      draft.value = {
        ...draft.value,
        cards: normalizedDraftCards
      };
    }

    const normalizedDecks = decks.value.map((deckItem) => ({
      ...deckItem,
      cards: normalizeDeckCardList(deckItem.cards, libraryCards)
    }));

    const decksChanged = normalizedDecks.some((deckItem, deckIndex) => {
      const currentDeck = decks.value[deckIndex];
      return (
        currentDeck.cards.length !== deckItem.cards.length ||
        deckItem.cards.some((cardItem, cardIndex) => {
          const currentCard = currentDeck.cards[cardIndex];
          return !currentCard || currentCard.cardKey !== cardItem.cardKey || currentCard.count !== cardItem.count;
        })
      );
    });

    if (decksChanged) {
      decks.value = normalizedDecks;
    }
  }

  function addCard(cardKey: string) {
    const currentTotal = draft.value.cards.reduce((sum, item) => sum + item.count, 0);
    const existing = draft.value.cards.find((item) => item.cardKey === cardKey);
    if (existing) {
      if (currentTotal >= MAX_DECK_SIZE) {
        return { ok: false, reason: `卡组总数不能超过 ${MAX_DECK_SIZE} 张。` };
      }
      if (existing.count >= MAX_CARD_COPIES) {
        return { ok: false, reason: `单张卡牌最多只能选择 ${MAX_CARD_COPIES} 张。` };
      }
      existing.count += 1;
      return { ok: true };
    }

    if (currentTotal >= MAX_DECK_SIZE) {
      return { ok: false, reason: `卡组总数不能超过 ${MAX_DECK_SIZE} 张。` };
    }

    draft.value.cards.push({ cardKey, count: 1 });
    return { ok: true };
  }

  function decreaseCard(cardKey: string) {
    const existing = draft.value.cards.find((item) => item.cardKey === cardKey);
    if (!existing) {
      return;
    }
    if (existing.count <= 1) {
      draft.value.cards = draft.value.cards.filter((item) => item.cardKey !== cardKey);
      return;
    }
    existing.count -= 1;
  }

  function removeCard(cardKey: string) {
    draft.value.cards = draft.value.cards.filter((item) => item.cardKey !== cardKey);
  }

  function clearDraftCards() {
    draft.value.cards = [];
  }

  function clearDraft() {
    draft.value = createEmptyDraft();
  }

  function setDraftDetails(payload: Partial<Omit<DeckDraft, "cards">>) {
    draft.value = {
      ...draft.value,
      ...payload
    };
  }

  function loadDeckToDraft(deckId: string) {
    const targetDeck = decks.value.find((item) => item.id === deckId);
    if (!targetDeck) {
      return false;
    }

    draft.value = {
      editingDeckId: targetDeck.id,
      editingPublicDeckId: "",
      name: targetDeck.name,
      description: targetDeck.description,
      difficulty: normalizeDifficulty(targetDeck.difficulty),
      deckPassword: "",
      isPublic: false,
      coverImage: targetDeck.coverImage,
      manualCardText: "",
      cards: cloneCards(targetDeck.cards)
    };

    return true;
  }

  function loadPublicDeckToDraft(payload: {
    id: string;
    name: string;
    description: string;
    difficulty: number;
    cards: DeckCard[];
    password: string;
  }) {
    draft.value = {
      editingDeckId: "",
      editingPublicDeckId: payload.id,
      name: payload.name,
      description: payload.description,
      difficulty: normalizeDifficulty(payload.difficulty),
      deckPassword: payload.password,
      isPublic: true,
      coverImage: "",
      manualCardText: "",
      cards: cloneCards(payload.cards)
    };
  }

  function createDeck(cardsOverride?: DeckCard[]) {
    const name = draft.value.name.trim();
    const sourceCards = cardsOverride?.length ? cardsOverride : draft.value.cards;
    if (!name || !sourceCards.length) {
      return null;
    }

    if (validateDeckCards(sourceCards)) {
      return null;
    }

    const targetDeckId = draft.value.editingDeckId.trim();
    const newDeck: SavedDeck = {
      id: targetDeckId || createDeckId(),
      name,
      description: draft.value.description.trim(),
      difficulty: normalizeDifficulty(draft.value.difficulty),
      coverImage: draft.value.coverImage,
      cards: cloneCards(sourceCards),
      createdAt: targetDeckId
        ? decks.value.find((item) => item.id === targetDeckId)?.createdAt ?? new Date().toISOString()
        : new Date().toISOString()
    };

    if (targetDeckId) {
      decks.value = decks.value.map((item) => (item.id === targetDeckId ? newDeck : item));
    } else {
      decks.value = [newDeck, ...decks.value];
    }

    clearDraft();
    return newDeck;
  }

  function removeCreatedDeck(deckId: string) {
    decks.value = decks.value.filter((item) => item.id !== deckId);
  }

  return {
    draft,
    deck: computed(() => draft.value.cards),
    decks,
    getDeckById: (deckId: string) => decks.value.find((item) => item.id === deckId) ?? null,
    totalCount: computed(() => draft.value.cards.reduce((sum, item) => sum + item.count, 0)),
    selectedCardKeys: computed(() => draft.value.cards.map((item) => item.cardKey)),
    addCard,
    decreaseCard,
    removeCard,
    clearDraftCards,
    clearDraft,
    setDraftDetails,
    reconcileCardKeys,
    loadDeckToDraft,
    loadPublicDeckToDraft,
    createDeck,
    removeCreatedDeck
  };
}
