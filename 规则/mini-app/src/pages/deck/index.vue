<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { onShareAppMessage, onShow } from "@dcloudio/uni-app";

import { deletePublicDeck, isPublicDeckApiReady, listPublicDecks, verifyPublicDeckPassword } from "@/api/publicDecks";
import { useDeck } from "@/composables/useDeck";
import { useLibraryData } from "@/composables/useLibraryData";
import type { Card, PublicDeck } from "@/types";
import { resolveCardThumbnail } from "@/utils/cardImage";
import { matchCardKey } from "@/utils/cardKey";
import { buildDeckCode, DECK_EXPORT_CANVAS_WIDTH, exportDeckOverview, getDeckExportCanvasHeight, type ExportDeckPayload } from "@/utils/deckExport";
import { showFriendShareMenu } from "@/utils/share";

interface DeckRow extends ExportDeckPayload {
  coverImage: string;
  createdAt: string;
  difficulty: number;
  isPublic: boolean;
  compatibilityStatus?: "full" | "partial" | "none";
  incompatibleCardCount?: number;
}

const { cards, init } = useLibraryData();
const { decks, loadDeckToDraft, loadPublicDeckToDraft, removeCreatedDeck } = useDeck();

const copiedDeckId = ref("");
const exportingDeckId = ref("");
const publicDecks = ref<PublicDeck[]>([]);
const publicDeckLoading = ref(false);
const publicDeckError = ref("");
const publicKeyword = ref("");
const publicSortOptions = [
  { label: "最新创建", value: "latest" },
  { label: "最早创建", value: "oldest" },
  { label: "名称排序", value: "name" },
  { label: "卡牌数量", value: "count" }
];
const publicDifficultyOptions = [
  { label: "上手难度", value: "all" },
  { label: "1 星", value: "1" },
  { label: "2 星", value: "2" },
  { label: "3 星", value: "3" }
];
const publicSortIndex = ref(0);
const publicDifficultyIndex = ref(0);
const publicActionLoadingId = ref("");

onMounted(() => {
  void init();
});

onShow(() => {
  showFriendShareMenu();
  void loadPublicDeckRows();
});

onShareAppMessage(() => ({
  title: "LEGION12卡组列表",
  path: "/pages/deck/index"
}));

function formatDifficulty(difficulty: number) {
  const level = Number.isInteger(difficulty) && difficulty >= 1 && difficulty <= 3 ? difficulty : 1;
  return `${"★".repeat(level)}${"☆".repeat(3 - level)}`;
}

function buildSummary(resolvedCards: Array<{ card: Card; count: number }>) {
  if (!resolvedCards.length) {
    return "卡牌数据暂未接通。";
  }

  return resolvedCards.map((item) => `${item.card.name}×${item.count}`).join("，");
}

function buildLocalRow(deck: (typeof decks.value)[number]) {
  const resolvedCards = deck.cards
    .map((item) => ({
      ...item,
      card: cards.value.find((card) => matchCardKey(card, item.cardKey))
    }))
    .filter((item): item is typeof item & { card: Card } => Boolean(item.card?.image.trim()));

  const previewCard = resolvedCards[0]?.card;
  return {
    id: deck.id,
    name: deck.name,
    description: deck.description,
    difficulty: deck.difficulty,
    createdAt: deck.createdAt,
    coverImage: deck.coverImage || (previewCard ? resolveCardThumbnail(previewCard) : ""),
    totalCount: deck.cards.reduce((sum, item) => sum + item.count, 0),
    summary: buildSummary(resolvedCards),
    resolvedCards,
    isPublic: false,
    compatibilityStatus: "full",
    incompatibleCardCount: 0
  };
}

function buildPublicRow(deck: PublicDeck) {
  const resolvedCards = deck.cards
    .map((item) => ({
      ...item,
      card: cards.value.find((card) => matchCardKey(card, item.cardKey))
    }))
    .filter((item): item is typeof item & { card: Card } => Boolean(item.card?.image.trim()));

  const previewCard = cards.value.find((card) => matchCardKey(card, deck.firstCardKey)) ?? resolvedCards[0]?.card;
  return {
    id: deck.id,
    name: deck.name,
    description: deck.description,
    difficulty: deck.difficulty,
    createdAt: deck.createdAt,
    coverImage: previewCard ? resolveCardThumbnail(previewCard) : "",
    totalCount: deck.cardCount,
    summary: buildSummary(resolvedCards),
    resolvedCards,
    isPublic: true,
    compatibilityStatus: deck.compatibilityStatus,
    incompatibleCardCount: deck.incompatibleCardCount ?? 0
  };
}

function getCompatibilityWarning(row: Pick<DeckRow, "incompatibleCardCount">) {
  if (!row.incompatibleCardCount) {
    return "";
  }
  return `含 ${row.incompatibleCardCount} 张待手动处理的旧卡`;
}

const localRows = computed(() => decks.value.map((deck) => buildLocalRow(deck)));
const publicRows = computed(() => publicDecks.value.map((deck) => buildPublicRow(deck)));
const exportCanvasHeight = computed(() => {
  const maxCardRows = Math.max(
    1,
    ...localRows.value.map((row) => row.resolvedCards.length),
    ...publicRows.value.map((row) => row.resolvedCards.length)
  );
  return getDeckExportCanvasHeight(maxCardRows);
});
const filteredPublicRows = computed(() => {
  const keyword = publicKeyword.value.trim().toLowerCase();
  const difficulty = publicDifficultyOptions[publicDifficultyIndex.value]?.value ?? "all";
  const sort = publicSortOptions[publicSortIndex.value]?.value ?? "latest";
  const rows = publicRows.value.filter((row) => {
    if (difficulty !== "all" && row.difficulty !== Number(difficulty)) {
      return false;
    }

    if (!keyword) {
      return true;
    }

    return `${row.name} ${row.description} ${row.summary}`.toLowerCase().includes(keyword);
  });

  return rows.slice().sort((left, right) => {
    switch (sort) {
      case "oldest":
        return left.createdAt.localeCompare(right.createdAt);
      case "name":
        return left.name.localeCompare(right.name, "zh-CN");
      case "count":
        return right.totalCount - left.totalCount;
      case "latest":
      default:
        return right.createdAt.localeCompare(left.createdAt);
    }
  });
});

async function loadPublicDeckRows() {
  if (!isPublicDeckApiReady()) {
    publicDecks.value = [];
    publicDeckError.value = "未配置公开卡组接口地址。";
    return;
  }

  publicDeckLoading.value = true;
  publicDeckError.value = "";

  try {
    publicDecks.value = await listPublicDecks();
  } catch (error) {
    publicDeckError.value = error instanceof Error ? error.message : "公开卡组读取失败。";
  } finally {
    publicDeckLoading.value = false;
  }
}

function openCreateDeck() {
  uni.navigateTo({ url: "/pages/deck-edit/index" });
}

function openDeckDetail(deckId: string) {
  uni.navigateTo({ url: `/pages/deck-detail/index?deckId=${encodeURIComponent(deckId)}` });
}

function openPublicDeckDetail(deckId: string) {
  uni.navigateTo({ url: `/pages/public-deck-detail/index?deckId=${encodeURIComponent(deckId)}` });
}

function openCards() {
  if (getCurrentPages().length > 1) {
    uni.navigateBack();
    return;
  }

  uni.redirectTo({ url: "/pages/cards/index" });
}

async function copyDeckSummary(deckId: string, summary: string) {
  if (!summary) {
    return;
  }

  await uni.setClipboardData({ data: summary });
  uni.showToast({
    title: "已复制",
    icon: "success"
  });
  copiedDeckId.value = deckId;
  setTimeout(() => {
    if (copiedDeckId.value === deckId) {
      copiedDeckId.value = "";
    }
  }, 1500);
}

function handleExport(row: DeckRow) {
  if (!row.resolvedCards.length) {
    return;
  }
  if (row.isPublic && row.incompatibleCardCount) {
    uni.showModal({
      title: "暂不支持导出",
      content: "该公开卡组仍有旧卡标识未完成兼容，小程序端导出会遗漏这些卡，请改用网页版处理后再导出。",
      showCancel: false
    });
    return;
  }

  uni.showActionSheet({
    itemList: ["导出图片", "导出代码"],
    success: async (result) => {
      if (result.tapIndex === 0) {
        await doExportImage(row);
        return;
      }

      if (result.tapIndex === 1) {
        doExportCode(row);
      }
    }
  });
}

async function doExportImage(row: DeckRow) {
  exportingDeckId.value = row.id;
  try {
    const tempFilePath = await exportDeckOverview(row, "deck-list-export-canvas");
    await uni.saveImageToPhotosAlbum({ filePath: tempFilePath });
    uni.showToast({
      title: "已保存到相册",
      icon: "success"
    });
  } catch (error) {
    uni.showModal({
      title: "导出失败",
      content: error instanceof Error ? error.message : "导出图片失败。",
      showCancel: false
    });
  } finally {
    exportingDeckId.value = "";
  }
}

function doExportCode(row: DeckRow) {
  const deckCode = buildDeckCode(row.resolvedCards);
  if (!deckCode) {
    uni.showModal({
      title: "无法导出",
      content: "当前卡组暂无可导出的编号代码。",
      showCancel: false
    });
    return;
  }

  uni.setClipboardData({
    data: deckCode,
    success: () => {
      uni.showModal({
        title: "卡组代码已复制",
        content: deckCode,
        showCancel: false
      });
    }
  });
}

function editDeck(deckId: string) {
  const loaded = loadDeckToDraft(deckId);
  if (!loaded) {
    return;
  }

  uni.navigateTo({ url: "/pages/deck-edit/index" });
}

function deleteDeck(deckId: string, deckName: string) {
  uni.showModal({
    title: "删除卡组",
    content: `确认删除卡组“${deckName}”吗？`,
    success: (result) => {
      if (result.confirm) {
        removeCreatedDeck(deckId);
      }
    }
  });
}

function promptPassword(title: string, placeholderText: string) {
  return new Promise<string | null>((resolve) => {
    uni.showModal({
      title,
      editable: true,
      placeholderText,
      success: (result) => {
        if (!result.confirm) {
          resolve(null);
          return;
        }

        resolve(String(result.content ?? "").trim());
      },
      fail: () => resolve(null)
    });
  });
}

function confirmDelete(deckName: string) {
  return new Promise<boolean>((resolve) => {
    uni.showModal({
      title: "删除公开卡组",
      content: `确认删除公开卡组“${deckName}”吗？`,
      success: (result) => resolve(Boolean(result.confirm)),
      fail: () => resolve(false)
    });
  });
}

async function editPublicDeck(deck: PublicDeck) {
  if (deck.incompatibleCardCount) {
    uni.showModal({
      title: "请先在网页版处理",
      content: "该公开卡组仍有旧卡标识未完成兼容，小程序端编辑会丢失这些卡，请先在网页版处理后再编辑。",
      showCancel: false
    });
    return;
  }

  const password = await promptPassword(`编辑“${deck.name}”`, "输入公开卡组密码");
  if (password === null) {
    return;
  }

  publicActionLoadingId.value = `edit:${deck.id}`;
  publicDeckError.value = "";

  try {
    await verifyPublicDeckPassword(deck.id, password);
    loadPublicDeckToDraft({
      id: deck.id,
      name: deck.name,
      description: deck.description,
      difficulty: deck.difficulty,
      cards: deck.cards,
      password
    });
    uni.navigateTo({ url: "/pages/deck-edit/index" });
  } catch (error) {
    publicDeckError.value = error instanceof Error ? error.message : "公开卡组校验失败。";
  } finally {
    publicActionLoadingId.value = "";
  }
}

async function removePublicDeck(deck: PublicDeck) {
  const password = await promptPassword(`删除“${deck.name}”`, "输入公开卡组密码");
  if (password === null) {
    return;
  }

  const confirmed = await confirmDelete(deck.name);
  if (!confirmed) {
    return;
  }

  publicActionLoadingId.value = `delete:${deck.id}`;
  publicDeckError.value = "";

  try {
    await deletePublicDeck(deck.id, password);
    publicDecks.value = publicDecks.value.filter((item) => item.id !== deck.id);
  } catch (error) {
    publicDeckError.value = error instanceof Error ? error.message : "公开卡组删除失败。";
  } finally {
    publicActionLoadingId.value = "";
  }
}
</script>

<template>
  <view class="page-shell">
    <view class="page-header">
      <button class="page-link" @click="openCards">返回卡牌</button>
      <button class="page-link page-link--primary" @click="openCreateDeck">创建卡组</button>
    </view>

    <view class="deck-section">
      <view class="deck-section__header">
        <view>
          <text class="deck-section__title">我的本地卡组</text>
        </view>
      </view>

      <view v-if="localRows.length" class="deck-list">
        <view v-for="row in localRows" :key="row.id" class="deck-card">
          <image v-if="row.coverImage" class="deck-card__image" :src="row.coverImage" mode="aspectFill" lazy-load />
          <view v-else class="deck-card__image deck-card__image--empty">
            <text>无封面</text>
          </view>

          <view class="deck-card__body">
            <view class="deck-card__title-row">
              <text class="deck-card__title">{{ row.name }}</text>
              <text class="deck-card__difficulty">上手难度：{{ formatDifficulty(row.difficulty) }}</text>
            </view>
            <text class="deck-card__desc">{{ row.description || "暂无介绍" }}</text>
            <text class="deck-card__count">{{ row.totalCount }} 张卡牌</text>
            <text v-if="row.incompatibleCardCount" class="deck-card__warning">{{ getCompatibilityWarning(row) }}</text>
            <button class="deck-card__summary" @click="copyDeckSummary(row.id, row.summary)">
              {{ copiedDeckId === row.id ? "已复制卡组摘要" : row.summary || "点击复制卡组摘要" }}
            </button>

            <view class="deck-card__actions">
              <button class="page-link page-link--ghost" @click="openDeckDetail(row.id)">查看</button>
              <button class="page-link page-link--ghost" :disabled="exportingDeckId === row.id" @click="handleExport(row)">
                {{ exportingDeckId === row.id ? "导出中" : "导出" }}
              </button>
              <button class="page-link page-link--ghost" @click="editDeck(row.id)">编辑</button>
              <button class="page-link page-link--ghost" @click="deleteDeck(row.id, row.name)">删除</button>
            </view>
          </view>
        </view>
      </view>
      <text v-else class="page-empty">暂无卡组，点击右上角创建卡组。</text>
    </view>

    <view class="deck-section">
      <view class="deck-section__header">
        <view>
          <text class="deck-section__title">公开卡组</text>
          <text class="deck-section__note">公开发布后，所有人都能查看。</text>
        </view>
        <button class="page-link page-link--ghost" :disabled="publicDeckLoading" @click="loadPublicDeckRows">
          {{ publicDeckLoading ? "刷新中" : "刷新" }}
        </button>
      </view>

      <text v-if="publicDeckError" class="page-error">{{ publicDeckError }}</text>
      <text v-else-if="publicDeckLoading" class="page-empty">正在读取公开卡组...</text>

      <template v-else-if="publicRows.length">
        <view class="toolbar-card">
          <input v-model="publicKeyword" class="search-input" confirm-type="search" placeholder="搜索卡组名称、介绍" />
          <view class="toolbar-row">
            <picker :range="publicSortOptions" range-key="label" :value="publicSortIndex" @change="publicSortIndex = Number(($event.detail as { value: string }).value)">
              <view class="picker-chip">{{ publicSortOptions[publicSortIndex]?.label ?? "排序" }}</view>
            </picker>
            <picker
              :range="publicDifficultyOptions"
              range-key="label"
              :value="publicDifficultyIndex"
              @change="publicDifficultyIndex = Number(($event.detail as { value: string }).value)"
            >
              <view class="picker-chip">{{ publicDifficultyOptions[publicDifficultyIndex]?.label ?? "上手难度" }}</view>
            </picker>
          </view>
          <text class="deck-section__note">当前命中 {{ filteredPublicRows.length }} / {{ publicRows.length }} 套公开卡组。</text>
        </view>

        <view v-if="filteredPublicRows.length" class="deck-list">
          <view v-for="row in filteredPublicRows" :key="row.id" class="deck-card">
            <image v-if="row.coverImage" class="deck-card__image" :src="row.coverImage" mode="aspectFill" lazy-load />
            <view v-else class="deck-card__image deck-card__image--empty">
              <text>无封面</text>
            </view>

            <view class="deck-card__body">
              <view class="deck-card__title-row">
                <text class="deck-card__title">{{ row.name }}</text>
                <text class="deck-card__difficulty">上手难度：{{ formatDifficulty(row.difficulty) }}</text>
              </view>
              <text class="deck-card__desc">{{ row.description || "暂无介绍" }}</text>
              <text class="deck-card__count">{{ row.totalCount }} 张卡牌</text>
              <text v-if="row.incompatibleCardCount" class="deck-card__warning">{{ getCompatibilityWarning(row) }}</text>
              <button class="deck-card__summary" @click="copyDeckSummary(row.id, row.summary)">
                {{ copiedDeckId === row.id ? "已复制卡组摘要" : row.summary || "点击复制卡组摘要" }}
              </button>

              <view class="deck-card__actions">
                <button class="page-link page-link--ghost" @click="openPublicDeckDetail(row.id)">查看</button>
                <button class="page-link page-link--ghost" :disabled="exportingDeckId === row.id" @click="handleExport(row)">
                  {{ exportingDeckId === row.id ? "导出中" : "导出" }}
                </button>
                <button
                  class="page-link page-link--ghost"
                  :disabled="publicActionLoadingId === `edit:${row.id}` || publicActionLoadingId.startsWith('delete:')"
                  @click="editPublicDeck(publicDecks.find((item) => item.id === row.id)!)"
                >
                  {{ publicActionLoadingId === `edit:${row.id}` ? "校验中" : "编辑" }}
                </button>
                <button
                  class="page-link page-link--ghost"
                  :disabled="publicActionLoadingId === `delete:${row.id}` || publicActionLoadingId.startsWith('edit:')"
                  @click="removePublicDeck(publicDecks.find((item) => item.id === row.id)!)"
                >
                  {{ publicActionLoadingId === `delete:${row.id}` ? "删除中" : "删除" }}
                </button>
              </view>
            </view>
          </view>
        </view>
        <text v-else class="page-empty">当前搜索和筛选条件下没有公开卡组。</text>
      </template>

      <text v-else class="page-empty">暂无公开卡组。</text>
    </view>

    <canvas
      canvas-id="deck-list-export-canvas"
      class="export-canvas"
      :style="{ width: `${DECK_EXPORT_CANVAS_WIDTH}px`, height: `${exportCanvasHeight}px` }"
    />
  </view>
</template>

<style scoped>
.page-shell {
  padding: 28rpx;
}

.page-header,
.deck-section__header,
.toolbar-row,
.deck-card__title-row,
.deck-card__actions {
  display: flex;
}

.page-header,
.deck-section__header {
  justify-content: space-between;
  gap: 20rpx;
}

.page-header {
  margin-bottom: 24rpx;
}

.deck-section {
  margin-bottom: 28rpx;
}

.deck-section__header {
  align-items: center;
  margin-bottom: 20rpx;
}

.deck-section__title {
  display: block;
  font-size: 32rpx;
  font-weight: 700;
  color: #0f172a;
}

.deck-section__note {
  display: block;
  margin-top: 8rpx;
  color: #64748b;
  line-height: 1.6;
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

.export-canvas {
  position: fixed;
  left: -2000px;
  top: -2000px;
  opacity: 0;
  pointer-events: none;
}

.toolbar-card,
.deck-card {
  background: #ffffff;
}

.toolbar-card {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
  padding: 24rpx;
  border-radius: 24rpx;
  margin-bottom: 20rpx;
}

.search-input {
  width: 100%;
  height: 84rpx;
  padding: 0 24rpx;
  border-radius: 24rpx;
  background: #f8fafc;
}

.toolbar-row {
  gap: 16rpx;
  flex-wrap: wrap;
}

.picker-chip {
  padding: 14rpx 24rpx;
  border-radius: 999rpx;
  background: #eff6ff;
  color: #2563eb;
  font-size: 24rpx;
}

.deck-list {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
}

.deck-card {
  display: flex;
  gap: 20rpx;
  padding: 20rpx;
  border-radius: 28rpx;
}

.deck-card__image {
  width: 180rpx;
  min-width: 180rpx;
  height: 252rpx;
  border-radius: 18rpx;
  background: #dbe4f0;
}

.deck-card__image--empty {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #64748b;
  font-size: 22rpx;
}

.deck-card__body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.deck-card__title-row {
  justify-content: space-between;
  gap: 16rpx;
}

.deck-card__title {
  font-size: 32rpx;
  font-weight: 700;
  color: #0f172a;
}

.deck-card__difficulty,
.deck-card__desc,
.deck-card__count {
  color: #64748b;
  line-height: 1.6;
}

.deck-card__warning {
  color: #b45309;
  line-height: 1.6;
}

.deck-card__summary {
  padding: 16rpx 20rpx;
  border-radius: 20rpx;
  background: #f8fafc;
  color: #334155;
  text-align: left;
  line-height: 1.5;
}

.deck-card__actions {
  gap: 12rpx;
  flex-wrap: wrap;
}

.page-empty,
.page-error {
  display: block;
  padding: 48rpx 0;
  text-align: center;
}

.page-empty {
  color: #64748b;
}

.page-error {
  color: #dc2626;
}
</style>
