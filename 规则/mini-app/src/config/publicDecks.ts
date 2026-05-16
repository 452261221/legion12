// Fill this with the deployed public deck API root, for example:
// https://your-site.example.com
// or https://your-worker.example.workers.dev
const PUBLIC_DECKS_API_BASE = "https://twelve-legions-card-lookup.pages.dev";

function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, "");
}

export function getPublicDecksApiBase(): string {
  return trimTrailingSlash(PUBLIC_DECKS_API_BASE.trim());
}

export function hasPublicDecksApiBase(): boolean {
  return Boolean(getPublicDecksApiBase());
}
