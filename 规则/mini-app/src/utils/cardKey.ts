import type { Card } from "@/types";

export function buildLegacyCardKey(card: Card): string {
  return `${card.series}__${card.cardNo}`;
}

export function buildCardKey(card: Card): string {
  return card.id.trim() || buildLegacyCardKey(card);
}

function isCardNoLike(value: string): boolean {
  return /^(?:S\d{2}-[0-9A-Z]{4,5}|\d{3}|DS\d{2})$/i.test(value.trim());
}

export function getCardKeyVariants(card: Card): string[] {
  const variants = [buildCardKey(card), buildLegacyCardKey(card)];

  for (const alias of card.alias ?? []) {
    const trimmed = alias.trim();
    if (!trimmed) {
      continue;
    }
    if (trimmed.includes("__")) {
      variants.push(trimmed);
      continue;
    }
    if (isCardNoLike(trimmed)) {
      variants.push(`${card.series}__${trimmed}`);
    }
  }

  return [...new Set(variants.filter(Boolean))];
}

export function matchCardKey(card: Card, cardKey: string): boolean {
  return getCardKeyVariants(card).includes(cardKey);
}
