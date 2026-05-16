import { getPublicDecksApiBase, hasPublicDecksApiBase } from "@/config/publicDecks";
import type { CreatePublicDeckPayload, PublicDeck, UpdatePublicDeckPayload } from "@/types";

function resolveApiBase(): string {
  const apiBase = getPublicDecksApiBase();
  if (apiBase) {
    return apiBase;
  }

  throw new Error("未配置公开卡组接口地址，请先在 src/config/publicDecks.ts 填写线上 API 根地址。");
}

function requestJson<T>(path: string, options?: { method?: "GET" | "POST" | "PUT" | "DELETE"; body?: Record<string, unknown> }) {
  return new Promise<T>((resolve, reject) => {
    const url = `${resolveApiBase()}${path}`;
    uni.request({
      url,
      method: options?.method ?? "GET",
      header: {
        ...(options?.body ? { "Content-Type": "application/json" } : {}),
        "X-Card-Key-Version": "legacy"
      },
      data: options?.body,
      success: (response) => {
        const statusCode = Number(response.statusCode ?? 0);
        const payload = response.data as { message?: string } | T;
        if (statusCode >= 200 && statusCode < 300) {
          resolve(payload as T);
          return;
        }

        const message = typeof payload === "object" && payload && "message" in payload && typeof payload.message === "string"
          ? payload.message
          : `公开卡组请求失败（${statusCode}）。`;
        reject(new Error(message));
      },
      fail: () => {
        reject(new Error("公开卡组接口请求失败，请检查网络和合法域名配置。"));
      }
    });
  });
}

export function isPublicDeckApiReady() {
  return hasPublicDecksApiBase();
}

export function listPublicDecks() {
  return requestJson<PublicDeck[]>("/api/public-decks");
}

export function getPublicDeck(deckId: string) {
  return requestJson<PublicDeck>(`/api/public-decks/${encodeURIComponent(deckId)}`);
}

export function createPublicDeck(payload: CreatePublicDeckPayload) {
  return requestJson<PublicDeck>("/api/public-decks", {
    method: "POST",
    body: payload
  });
}

export function updatePublicDeck(deckId: string, payload: UpdatePublicDeckPayload) {
  return requestJson<PublicDeck>(`/api/public-decks/${encodeURIComponent(deckId)}`, {
    method: "PUT",
    body: payload
  });
}

export function deletePublicDeck(deckId: string, password: string) {
  return requestJson<{ ok: true }>(`/api/public-decks/${encodeURIComponent(deckId)}`, {
    method: "DELETE",
    body: { password }
  });
}

export function verifyPublicDeckPassword(deckId: string, password: string) {
  return requestJson<{ ok: true }>(`/api/public-decks/${encodeURIComponent(deckId)}/verify-password`, {
    method: "POST",
    body: { password }
  });
}
