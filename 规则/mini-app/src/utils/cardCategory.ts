import type { Card } from "@/types";

export const CARD_TYPE_OPTIONS = [
  "主宰卡",
  "军团卡",
  "战术卡",
  "天灾卡",
  "圣物卡",
  "士气卡",
  "试炼卡",
  "主城卡",
  "衍生卡",
  "其他"
] as const;

export const CARD_FACTION_OPTIONS = ["通用", "天廷", "太阳城", "高天原", "阿斯加德", "奥林匹斯", "彼界"] as const;

function safeText(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

export function getCardTypeLabel(card: Card): string {
  const rawType = safeText(card.type);
  const rawFaction = safeText(card.faction);
  const name = safeText(card.name);

  if (rawFaction === "天灾" || rawType.includes("天灾")) {
    return "天灾卡";
  }

  if (name === "帕尔修斯·晋升" || name === "帕洛特埃") {
    return "军团卡";
  }

  if (name === "野外扎营") {
    return "战术卡";
  }

  if (name === "符文") {
    return "衍生卡";
  }

  if (name === "士气") {
    return "士气卡";
  }

  if (name === "神力") {
    return "其他";
  }

  switch (rawType) {
    case "主宰":
      return "主宰卡";
    case "军团":
      return "军团卡";
    case "战术":
    case "反击战术":
      return "战术卡";
    case "圣物":
      return "圣物卡";
    case "士气卡":
      return "士气卡";
    case "试炼卡":
      return "试炼卡";
    case "主城":
      return "主城卡";
    case "衍生卡":
      return "衍生卡";
    default:
      return "其他";
  }
}

export function getCardFactionLabel(card: Card): string {
  const rawFaction = safeText(card.faction);
  return CARD_FACTION_OPTIONS.includes(rawFaction as (typeof CARD_FACTION_OPTIONS)[number]) ? rawFaction : "";
}
