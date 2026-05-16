import type { Card, FaqEntry } from "@/types";
import { buildCardKey } from "@/utils/cardKey";

function normalizeText(value: string): string {
  return value
    .toLowerCase()
    .replace(/[\s\"'“”’`~!@#$%^&*()_+\-=[\]{};:\\|,.<>/?，。！？；：、（）【】《》·・]/g, "");
}

function getCardTerms(card: Card): string[] {
  const terms = [card.name, ...card.alias].map((item) => normalizeText(item)).filter((item) => item.length >= 2);
  return [...new Set(terms)];
}

export function faqRelatesToCard(item: FaqEntry, card: Card, cards: Card[]): boolean {
  const text = normalizeText(`${item.question} ${item.answer}`);
  const cardId = buildCardKey(card);

  if (item.relatedCardKeys?.includes(cardId) || item.relatedCardIds.includes(cardId)) {
    return true;
  }

  if (getCardTerms(card).some((term) => text.includes(term))) {
    return true;
  }

  return false;
}
