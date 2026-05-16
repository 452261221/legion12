import type { Card } from "@/types";
import { getCardAssetBaseUrl } from "@/config/cardAssets";

function mapStaticPath(path: string): string {
  const trimmed = path.trim();
  if (!trimmed) {
    return "";
  }
  if (/^(https?:|data:)/.test(trimmed)) {
    return trimmed;
  }
  if (trimmed.startsWith("/cards/")) {
    const baseUrl = getCardAssetBaseUrl();
    return baseUrl ? `${baseUrl}${trimmed}` : "";
  }
  return trimmed;
}

export function resolveCardImage(card: Card): string {
  const rawImage = typeof card.image === "string" ? card.image.trim() : "";
  if (rawImage.startsWith("/cards/faces/")) {
    return mapStaticPath(rawImage);
  }

  return resolveCardThumbnail(card);
}

export function resolveCardThumbnail(card: Card): string {
  const rawImage = typeof card.image === "string" ? card.image.trim() : "";
  if (rawImage.startsWith("/cards/faces/")) {
    const relativeThumbPath = rawImage.replace(/^\/cards\/faces\//, "").replace(/\.png$/i, ".webp");
    return mapStaticPath(`/cards/thumbs/${relativeThumbPath}`);
  }

  if (!card.id.trim()) {
    return "";
  }
  return mapStaticPath(`/cards/thumbs/${card.id}.webp`);
}
