// Cards are served from the Cloudflare Pages site used by the H5 app.
const CARD_ASSET_BASE_URL = "https://twelve-legions-card-lookup.pages.dev";

function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, "");
}

export function getCardAssetBaseUrl(): string {
  return trimTrailingSlash(CARD_ASSET_BASE_URL.trim());
}

export function hasRemoteCardAssets(): boolean {
  return Boolean(getCardAssetBaseUrl());
}
