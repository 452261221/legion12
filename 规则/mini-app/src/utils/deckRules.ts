import type { Card, DeckCard } from "@/types";

import { getCardTypeLabel } from "@/utils/cardCategory";
import { buildCardKey, matchCardKey } from "@/utils/cardKey";

interface DeckComposition {
  dominionCards: DeckCard[];
  handCards: DeckCard[];
  dominionCardKey: string;
  handCount: number;
  totalCount: number;
}

function findCard(cards: Card[], cardKey: string): Card | undefined {
  return cards.find((card) => matchCardKey(card, cardKey));
}

function isDominionCard(card: Card): boolean {
  return getCardTypeLabel(card) === "主宰卡";
}

export function getDeckComposition(deckCards: DeckCard[], cards: Card[]): DeckComposition {
  const dominionCards: DeckCard[] = [];
  const handCards: DeckCard[] = [];

  for (const item of deckCards) {
    const card = findCard(cards, item.cardKey);
    if (card && isDominionCard(card)) {
      dominionCards.push(item);
    } else {
      handCards.push(item);
    }
  }

  return {
    dominionCards,
    handCards,
    dominionCardKey: dominionCards[0]?.cardKey ?? "",
    handCount: handCards.reduce((sum, item) => sum + item.count, 0),
    totalCount: deckCards.reduce((sum, item) => sum + item.count, 0)
  };
}

export function validateDeckWithLibrary(deckCards: DeckCard[], cards: Card[]): string | null {
  const composition = getDeckComposition(deckCards, cards);

  if (composition.dominionCards.length !== 1 || composition.dominionCards[0].count !== 1) {
    return "卡组必须且只能包含 1 张主宰卡。";
  }

  if (composition.handCount <= 0) {
    return "请至少选择 1 张手牌。";
  }

  return null;
}

export function sortDeckCardsWithDominionFirst(deckCards: DeckCard[], cards: Card[]): DeckCard[] {
  const dominionCardKey = getDeckComposition(deckCards, cards).dominionCardKey;
  if (!dominionCardKey) {
    return deckCards.map((item) => ({ ...item }));
  }

  return deckCards
    .map((item) => ({ ...item }))
    .sort((left, right) => {
      if (left.cardKey === dominionCardKey && right.cardKey !== dominionCardKey) {
        return -1;
      }
      if (right.cardKey === dominionCardKey && left.cardKey !== dominionCardKey) {
        return 1;
      }
      return 0;
    });
}

export function findCardByDeckText(inputName: string, cards: Card[]): Card | undefined {
  const normalizedName = inputName.trim().toLowerCase();

  return cards.find((card) => {
    if (card.cardNo?.trim().toLowerCase() === normalizedName) {
      return true;
    }

    if (card.name.trim().toLowerCase() === normalizedName) {
      return true;
    }

    return card.alias.some((alias) => alias.trim().toLowerCase() === normalizedName);
  });
}
