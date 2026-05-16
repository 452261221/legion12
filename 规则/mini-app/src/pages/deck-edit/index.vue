<script setup lang="ts">
import { computed, onMounted, ref } from "vue";

import { createPublicDeck, isPublicDeckApiReady, updatePublicDeck } from "@/api/publicDecks";
import { MAX_CARD_COPIES, MAX_DECK_SIZE, useDeck, validateDeckCards } from "@/composables/useDeck";
import { useLibraryData } from "@/composables/useLibraryData";
import type { DeckCard } from "@/types";
import { buildCardKey, matchCardKey } from "@/utils/cardKey";
import { findCardByDeckText, getDeckComposition, sortDeckCardsWithDominionFirst, validateDeckWithLibrary } from "@/utils/deckRules";

interface ParseManualCardsResult {
  cards: DeckCard[];
  skippedEntries: string[];
}

const { cards, init } = useLibraryData();
const { clearDraft, createDeck, draft, setDraftDetails, totalCount } = useDeck();

const creating = ref(false);
const manualCardError = ref("");
const createError = ref("");

onMounted(() => {
  void init();
});

const selectedRows = computed(() =>
  draft.value.cards
    .map((item) => ({
      ...item,
      card: cards.value.find((card) => matchCardKey(card, item.cardKey))
    }))
    .filter((item) => item.card)
);

const draftComposition = computed(() => getDeckComposition(draft.value.cards, cards.value));

const selectedSummary = computed(() => {
  if (!selectedRows.value.length) {
    return "还没有选择主宰卡和手牌。";
  }

  return selectedRows.value.map((item) => `${item.card!.name}×${item.count}`).join("，");
});

const canCreate = computed(() => draft.value.name.trim().length > 0 && (totalCount.value > 0 || draft.value.manualCardText.trim().length > 0));
const submitLabel = computed(() => {
  if (draft.value.editingPublicDeckId) {
    return "保存";
  }
  return draft.value.isPublic ? "发布" : "创建";
});

function onNameInput(event: { detail: { value: string } }) {
  setDraftDetails({ name: event.detail.value });
}

function onDescriptionInput(event: { detail: { value: string } }) {
  setDraftDetails({ description: event.detail.value });
}

function onManualCardInput(event: { detail: { value: string } }) {
  manualCardError.value = "";
  createError.value = "";
  setDraftDetails({ manualCardText: event.detail.value });
}

function onPasswordInput(event: { detail: { value: string } }) {
  createError.value = "";
  setDraftDetails({ deckPassword: event.detail.value });
}

function updateDifficulty(level: number) {
  setDraftDetails({ difficulty: level });
}

function onPublicChange(event: { detail: { value: boolean } }) {
  createError.value = "";
  const isPublic = Boolean(event.detail.value);
  setDraftDetails({
    isPublic,
    coverImage: isPublic ? "" : draft.value.coverImage
  });
}

function chooseCover() {
  uni.chooseImage({
    count: 1,
    sizeType: ["compressed"],
    sourceType: ["album"],
    success: (result) => {
      const imagePath = result.tempFilePaths[0] ?? "";
      setDraftDetails({ coverImage: imagePath });
    }
  });
}

function clearCover() {
  setDraftDetails({ coverImage: "" });
}

function findCardByName(inputName: string) {
  return findCardByDeckText(inputName, cards.value);
}

function parseManualCards(): ParseManualCardsResult | null {
  const rawValue = draft.value.manualCardText.trim();
  if (!rawValue) {
    manualCardError.value = "请选择卡牌，或输入卡牌文本。";
    return null;
  }

  const countMap = new Map<string, number>();
  const skippedEntries: string[] = [];
  const tokens = rawValue.split(/\s+/).filter(Boolean);
  const looksLikeCodeFormat =
    tokens.length > 0 &&
    tokens.every((token) => /^S\d{2}-[0-9A-Z]{4}$/i.test(token));

  if (looksLikeCodeFormat) {
    for (const token of tokens) {
      const card = findCardByName(token);
      if (!card) {
        if (!skippedEntries.includes(token)) {
          skippedEntries.push(token);
        }
        continue;
      }

      const cardKey = buildCardKey(card);
      countMap.set(cardKey, (countMap.get(cardKey) ?? 0) + 1);
    }
  }

  if (!looksLikeCodeFormat) {
    const items = rawValue
      .split(/[，,\n；;]+/)
      .map((item) => item.trim())
      .filter(Boolean);

    for (const item of items) {
      const match = item.match(/^(.+?)(?:\s*[×xX*]\s*(\d+))?$/);
      if (!match) {
        manualCardError.value = `无法识别：${item}`;
        return null;
      }

      const cardName = match[1]?.trim() ?? "";
      const count = Number(match[2] ?? "1");
      const card = findCardByName(cardName);

      if (!card) {
        if (!skippedEntries.includes(cardName)) {
          skippedEntries.push(cardName);
        }
        continue;
      }

      if (!Number.isFinite(count) || count <= 0) {
        manualCardError.value = `数量不正确：${item}`;
        return null;
      }

      if (count > MAX_CARD_COPIES) {
        manualCardError.value = `单张卡牌最多只能选择 ${MAX_CARD_COPIES} 张。`;
        return null;
      }

      const cardKey = buildCardKey(card);
      countMap.set(cardKey, (countMap.get(cardKey) ?? 0) + count);
    }
  }

  const parsedCards = Array.from(countMap.entries()).map(([cardKey, count]) => ({ cardKey, count }));
  if (!parsedCards.length) {
    manualCardError.value = skippedEntries.length ? `输入内容均未找到，已跳过：${skippedEntries.join("、")}` : "请选择卡牌，或输入卡牌文本。";
    return null;
  }

  const validationMessage = validateDeckCards(parsedCards);
  if (validationMessage) {
    manualCardError.value = validationMessage;
    return null;
  }

  const deckValidation = validateDeckWithLibrary(parsedCards, cards.value);
  if (deckValidation) {
    manualCardError.value = deckValidation;
    return null;
  }

  return {
    cards: sortDeckCardsWithDominionFirst(parsedCards, cards.value),
    skippedEntries
  };
}

async function submitDeck() {
  if (!canCreate.value || creating.value) {
    return;
  }

  manualCardError.value = "";
  createError.value = "";

  let cardsOverride: DeckCard[] | undefined;
  let skippedEntries: string[] = [];
  if (!totalCount.value) {
    const parsedResult = parseManualCards();
    cardsOverride = parsedResult?.cards;
    skippedEntries = parsedResult?.skippedEntries ?? [];
    if (!cardsOverride?.length) {
      return;
    }
  }

  const sourceCards = cardsOverride?.length ? cardsOverride : draft.value.cards;
  const genericValidation = validateDeckCards(sourceCards);
  if (genericValidation) {
    createError.value = genericValidation;
    return;
  }

  const deckValidation = validateDeckWithLibrary(sourceCards, cards.value);
  if (deckValidation) {
    createError.value = deckValidation;
    return;
  }

  const normalizedCards = sortDeckCardsWithDominionFirst(sourceCards, cards.value);

  creating.value = true;
  try {
    if (draft.value.editingPublicDeckId && !draft.value.isPublic) {
      createError.value = "公开卡组编辑时不能直接改为本地卡组，请保持勾选公开卡组。";
      return;
    }

    if (draft.value.isPublic) {
      if (!isPublicDeckApiReady()) {
        createError.value = "未配置公开卡组接口地址，请先在 src/config/publicDecks.ts 填写线上 API 根地址。";
        return;
      }

      if (draft.value.editingPublicDeckId) {
        await updatePublicDeck(draft.value.editingPublicDeckId, {
          name: draft.value.name.trim(),
          description: draft.value.description.trim(),
          difficulty: draft.value.difficulty,
          deckPassword: draft.value.deckPassword.trim(),
          password: draft.value.deckPassword.trim(),
          cards: normalizedCards
        });
      } else {
        await createPublicDeck({
          name: draft.value.name.trim(),
          description: draft.value.description.trim(),
          difficulty: draft.value.difficulty,
          deckPassword: draft.value.deckPassword.trim(),
          cards: normalizedCards
        });
      }

      clearDraft();
    } else {
      const createdDeck = createDeck(normalizedCards);
      if (!createdDeck) {
        createError.value = `创建失败，请检查 1 张主宰卡、至少 1 张手牌，且总数不超过 ${MAX_DECK_SIZE} 张。`;
        return;
      }
    }

    if (skippedEntries.length) {
      uni.showModal({
        title: "已跳过未找到的卡牌",
        content: skippedEntries.join("、"),
        showCancel: false,
        complete: () => {
          uni.redirectTo({ url: "/pages/deck/index" });
        }
      });
      return;
    }

    uni.redirectTo({ url: "/pages/deck/index" });
  } catch (error) {
    createError.value = error instanceof Error ? error.message : "卡组提交失败。";
  } finally {
    creating.value = false;
  }
}

function openDeckList() {
  if (getCurrentPages().length > 1) {
    uni.navigateBack();
    return;
  }

  uni.redirectTo({ url: "/pages/deck/index" });
}

function openSelectCards() {
  uni.navigateTo({ url: "/pages/deck-select/index" });
}
</script>

<template>
  <view class="page-shell">
    <view class="page-header">
      <button class="page-link" @click="openDeckList">返回</button>
      <button class="page-link" @click="openSelectCards">选择卡牌</button>
      <button class="page-link page-link--primary" :disabled="!canCreate" @click="submitDeck">
        {{ creating ? "提交中" : submitLabel }}
      </button>
    </view>

    <view class="summary-card">
      <text class="summary-card__title">当前已选</text>
      <text class="summary-card__desc">主宰卡 {{ draftComposition.dominionCards.length ? "1 / 1" : "0 / 1" }}，手牌 {{ draftComposition.handCount }} 张</text>
      <text class="summary-card__desc">{{ draftComposition.totalCount }} 张卡牌</text>
      <text class="summary-card__desc">{{ selectedSummary }}</text>
    </view>

    <view class="form-card">
      <view class="field-block">
        <text class="field-label">卡组名称</text>
        <input :value="draft.name" class="field-input" maxlength="30" placeholder="输入卡组名称" @input="onNameInput" />
      </view>

      <view class="field-block">
        <text class="field-label">卡组介绍</text>
        <textarea :value="draft.description" class="field-textarea" maxlength="200" placeholder="输入卡组介绍" @input="onDescriptionInput" />
      </view>

      <view class="field-block">
        <text class="field-label">上手难度</text>
        <view class="difficulty-row">
          <button
            v-for="level in 3"
            :key="level"
            :class="['difficulty-star', draft.difficulty >= level ? 'difficulty-star--active' : '']"
            @click="updateDifficulty(level)"
          >
            {{ draft.difficulty >= level ? "★" : "☆" }}
          </button>
        </view>
      </view>

      <view class="field-block">
        <text class="field-label">设置密码</text>
        <input :value="draft.deckPassword" class="field-input" password maxlength="40" placeholder="公开卡组编辑、删除时使用" @input="onPasswordInput" />
      </view>

      <view class="field-block">
        <text class="field-label">公开卡组</text>
        <view class="switch-row">
          <switch :checked="draft.isPublic" color="#2563eb" @change="onPublicChange" />
          <text class="field-hint">勾选后发布到公开卡组列表。</text>
        </view>
      </view>

      <view class="field-block">
        <text class="field-label">{{ draft.isPublic ? "公开封面" : "卡组封面" }}</text>
        <template v-if="draft.isPublic">
          <text class="field-hint">公开卡组当前仍会默认显示首张卡图。</text>
        </template>
        <template v-else>
          <image v-if="draft.coverImage" class="cover-image" :src="draft.coverImage" mode="aspectFill" />
          <text v-else class="field-hint">未上传封面时，卡组列表会默认显示首张卡图。</text>
          <view class="action-row">
            <button class="page-link page-link--ghost" @click="chooseCover">上传封面</button>
            <button v-if="draft.coverImage" class="page-link page-link--ghost" @click="clearCover">移除封面</button>
          </view>
        </template>
      </view>

      <view class="field-block">
        <text class="field-label">快速录入卡牌</text>
        <textarea
          :value="draft.manualCardText"
          class="field-textarea"
          placeholder="支持卡牌名称（如：诸葛亮×1，乾坤 阳×2）或导出代码（如：S02-0105 S01-0106 S01-0106）"
          @input="onManualCardInput"
        />
        <text class="field-hint">不需要再选牌；如果已经选了牌，则仍以已选卡牌为准。快速录入里也必须包含 1 张主宰卡。</text>
        <text v-if="manualCardError" class="field-error">{{ manualCardError }}</text>
      </view>

      <text v-if="createError" class="field-error">{{ createError }}</text>
    </view>
  </view>
</template>

<style scoped>
.page-shell {
  padding: 28rpx;
}

.page-header {
  display: flex;
  gap: 16rpx;
  flex-wrap: wrap;
  margin-bottom: 24rpx;
}

.page-link {
  padding: 16rpx 24rpx;
  border-radius: 999rpx;
  background: #e2e8f0;
  color: #334155;
  font-size: 24rpx;
}

.page-link--primary {
  background: #2563eb;
  color: #ffffff;
}

.page-link--ghost {
  background: #f8fafc;
}

.summary-card,
.form-card {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
  padding: 24rpx;
  border-radius: 24rpx;
  background: #ffffff;
  margin-bottom: 24rpx;
}

.summary-card__title,
.field-label {
  font-size: 30rpx;
  font-weight: 700;
  color: #0f172a;
}

.summary-card__desc,
.field-hint {
  color: #64748b;
  line-height: 1.6;
}

.field-block {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.field-input,
.field-textarea {
  width: 100%;
  padding: 20rpx 24rpx;
  border-radius: 20rpx;
  background: #f8fafc;
}

.field-textarea {
  min-height: 180rpx;
}

.difficulty-row,
.action-row,
.switch-row {
  display: flex;
  align-items: center;
  gap: 12rpx;
  flex-wrap: wrap;
}

.difficulty-star {
  width: 72rpx;
  height: 72rpx;
  border-radius: 999rpx;
  background: #eff6ff;
  color: #94a3b8;
  font-size: 36rpx;
}

.difficulty-star--active {
  color: #2563eb;
}

.cover-image {
  width: 220rpx;
  height: 308rpx;
  border-radius: 20rpx;
  background: #dbe4f0;
}

.field-error {
  color: #dc2626;
  line-height: 1.6;
}
</style>
