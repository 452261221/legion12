interface DeckCard {
  cardKey: string;
  count: number;
}

interface D1PreparedStatement {
  bind(...values: unknown[]): D1PreparedStatement;
  run(): Promise<unknown>;
  first<T = unknown>(): Promise<T | null>;
  all<T = unknown>(): Promise<{ results?: T[] }>;
}

interface D1DatabaseLike {
  prepare(query: string): D1PreparedStatement;
}

interface PublicDeckRecord {
  id: string;
  name: string;
  description: string;
  first_card_key: string;
  card_count: number;
  cards_json: string;
  created_at: string;
  updated_at: string;
}

interface Env {
  PUBLIC_DECKS_DB: D1DatabaseLike;
}

const MAX_DECK_SIZE = 51;
const MAX_CARD_COPIES = 3;
const MAX_NAME_LENGTH = 30;
const MAX_DESCRIPTION_LENGTH = 200;
const MAX_REQUEST_BYTES = 32 * 1024;

function buildCorsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
  };
}

function json(data: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...buildCorsHeaders(),
      ...(init.headers ?? {})
    }
  });
}

function errorResponse(status: number, message: string): Response {
  return json({ ok: false, message }, { status });
}

function createDeckId(): string {
  return crypto.randomUUID();
}

function sanitizeSingleLineText(value: unknown): string {
  return typeof value === "string"
    ? value.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim()
    : "";
}

function sanitizeMultiLineText(value: unknown): string {
  return typeof value === "string"
    ? value
        .replace(/\r\n/g, "\n")
        .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]+/g, "")
        .trim()
    : "";
}

function normalizeCards(value: unknown): DeckCard[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const merged = new Map<string, number>();

  for (const item of value) {
    if (!item || typeof item !== "object") {
      continue;
    }

    const cardKey = sanitizeSingleLineText((item as { cardKey?: unknown }).cardKey);
    const count = (item as { count?: unknown }).count;

    if (!cardKey || !Number.isInteger(count)) {
      continue;
    }

    merged.set(cardKey, (merged.get(cardKey) ?? 0) + Number(count));
  }

  return Array.from(merged.entries()).map(([cardKey, count]) => ({ cardKey, count }));
}

function toPublicDeck(record: PublicDeckRecord) {
  return {
    id: record.id,
    name: record.name,
    description: record.description,
    firstCardKey: record.first_card_key,
    cardCount: record.card_count,
    cards: JSON.parse(record.cards_json) as DeckCard[],
    createdAt: record.created_at,
    updatedAt: record.updated_at
  };
}

function validateDeckCards(cards: DeckCard[]): string | null {
  const totalCount = cards.reduce((sum, item) => sum + item.count, 0);
  if (!cards.length || totalCount <= 0) {
    return "卡组不能为空。";
  }

  if (totalCount > MAX_DECK_SIZE) {
    return `卡组总数不能超过 ${MAX_DECK_SIZE} 张。`;
  }

  for (const item of cards) {
    if (!item.cardKey?.trim()) {
      return "存在无效卡牌。";
    }
    if (item.cardKey.length > 120) {
      return "存在过长的卡牌标识。";
    }
    if (!Number.isInteger(item.count) || item.count <= 0) {
      return "卡牌数量必须是正整数。";
    }
    if (item.count > MAX_CARD_COPIES) {
      return `单张卡牌最多只能选择 ${MAX_CARD_COPIES} 张。`;
    }
  }

  return null;
}

async function listPublicDecks(env: Env): Promise<Response> {
  const result = await env.PUBLIC_DECKS_DB.prepare(
    `SELECT id, name, description, first_card_key, card_count, cards_json, created_at, updated_at
     FROM public_decks
     ORDER BY created_at DESC`
  ).all<PublicDeckRecord>();

  return json((result.results ?? []).map((item) => toPublicDeck(item)));
}

async function getPublicDeck(env: Env, deckId: string): Promise<Response> {
  const record = await env.PUBLIC_DECKS_DB.prepare(
    `SELECT id, name, description, first_card_key, card_count, cards_json, created_at, updated_at
     FROM public_decks
     WHERE id = ?1`
  )
    .bind(deckId)
    .first<PublicDeckRecord>();

  if (!record) {
    return errorResponse(404, "未找到对应公开卡组。");
  }

  return json(toPublicDeck(record));
}

async function createPublicDeck(request: Request, env: Env): Promise<Response> {
  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > MAX_REQUEST_BYTES) {
    return errorResponse(413, "请求内容过大。");
  }

  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return errorResponse(415, "请求类型必须为 application/json。");
  }

  let payload: { name?: unknown; description?: unknown; cards?: unknown };

  try {
    payload = (await request.json()) as typeof payload;
  } catch {
    return errorResponse(400, "请求体必须是合法 JSON。");
  }

  const name = sanitizeSingleLineText(payload.name);
  const description = sanitizeMultiLineText(payload.description);
  const cards = normalizeCards(payload.cards);

  if (!name) {
    return errorResponse(400, "卡组名称不能为空。");
  }

  if (name.length > MAX_NAME_LENGTH) {
    return errorResponse(400, `卡组名称不能超过 ${MAX_NAME_LENGTH} 个字符。`);
  }

  if (description.length > MAX_DESCRIPTION_LENGTH) {
    return errorResponse(400, `卡组介绍不能超过 ${MAX_DESCRIPTION_LENGTH} 个字符。`);
  }

  const validationError = validateDeckCards(cards);
  if (validationError) {
    return errorResponse(400, validationError);
  }

  const now = new Date().toISOString();
  const deckId = createDeckId();
  const firstCardKey = cards[0].cardKey;
  const cardCount = cards.reduce((sum, item) => sum + item.count, 0);

  await env.PUBLIC_DECKS_DB.prepare(
    `INSERT INTO public_decks (id, name, description, first_card_key, card_count, cards_json, created_at, updated_at)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)`
  )
    .bind(deckId, name, description, firstCardKey, cardCount, JSON.stringify(cards), now, now)
    .run();

  return json(
    {
      id: deckId,
      name,
      description,
      firstCardKey,
      cardCount,
      cards,
      createdAt: now,
      updatedAt: now
    },
    { status: 201 }
  );
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      if (request.method === "OPTIONS") {
        return new Response(null, {
          status: 204,
          headers: buildCorsHeaders()
        });
      }

      const url = new URL(request.url);
      const pathname = url.pathname.replace(/\/+$/, "") || "/";

      if (pathname === "/api/public-decks") {
        if (request.method === "GET") {
          return listPublicDecks(env);
        }
        if (request.method === "POST") {
          return createPublicDeck(request, env);
        }
      }

      if (pathname.startsWith("/api/public-decks/") && request.method === "GET") {
        const deckId = decodeURIComponent(pathname.slice("/api/public-decks/".length));
        if (!deckId) {
          return errorResponse(400, "缺少卡组 ID。");
        }
        return getPublicDeck(env, deckId);
      }

      if (pathname === "/healthz") {
        return json({ ok: true, service: "legion-public-decks-worker" });
      }

      return errorResponse(404, "Not found");
    } catch (error) {
      const message = error instanceof Error ? error.message : "Internal server error";
      return errorResponse(500, message);
    }
  }
};
