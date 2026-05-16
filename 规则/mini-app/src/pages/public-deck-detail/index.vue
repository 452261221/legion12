<script setup lang="ts">
import { computed, ref } from "vue";
import { onLoad, onShareAppMessage, onShow } from "@dcloudio/uni-app";

import { getPublicDeck, isPublicDeckApiReady } from "@/api/publicDecks";
import { useLibraryData } from "@/composables/useLibraryData";
import type { PublicDeck } from "@/types";
import { resolveCardImage, resolveCardThumbnail } from "@/utils/cardImage";
import { buildCardKey, matchCardKey } from "@/utils/cardKey";
import { buildDeckCode, DECK_EXPORT_CANVAS_WIDTH, exportDeckOverview, getDeckExportCanvasHeight } from "@/utils/deckExport";
import { showFriendShareMenu } from "@/utils/share";

const deckId = ref("");
const loading = ref(false);
const loadError = ref("");
const copied = ref(false);
const deck = ref<PublicDeck | null>(null);
const exporting = ref(false);

const { cards, init } = useLibraryData();

async function loadDeckDetail() {
  if (!deckId.value) {
    loadError.value = "缺少公开卡组 ID。";
    deck.value = null;
    return;
  }

  if (!isPublicDeckApiReady()) {
    loadError.value = "未配置公开卡组接口地址。";
    deck.value = null;
    return;
  }

  loading.value = true;
  loadError.value = "";

  try {
    deck.value = await getPublicDeck(deckId.value);
  } catch (error) {
    deck.value = null;
    loadError.value = error instanceof Error ? error.message : "公开卡组读取失败。";
  } finally {
    loading.value = false;
  }
}

onLoad((options) => {
  deckId.value = String(options?.deckId ?? "");
});

onShow(() => {
  showFriendShareMenu();
  void loadDeckDetail();
});

void init();

const rows = computed(() => {
  if (!deck.value) {
    return [];
  }

  return deck.value.cards
    .map((item) => ({
      ...item,
      card: cards.value.find((card) => matchCardKey(card, item.cardKey))
    }))
    .filter((item) => item.card);
});

const summary = computed(() => rows.value.map((row) => `${row.card!.name}×${row.count}`).join("，"));
const exportCanvasHeight = computed(() => getDeckExportCanvasHeight(rows.value.length));

const compatibilityMessage = computed(() => {
  if (!deck.value?.incompatibleCardCount) {
    return "";
  }
  return `该公开卡组有 ${deck.value.incompatibleCardCount} 张旧卡标识无法在小程序端完整兼容，请改用网页版重新处理这些卡后再导出。`;
});

const coverImage = computed(() => {
  if (!deck.value) {
    return "";
  }

  const previewCard = cards.value.find((card) => matchCardKey(card, deck.value!.firstCardKey));
  return previewCard ? resolveCardImage(previewCard) : "";
});

function formatDifficulty(difficulty: number) {
  const level = Number.isInteger(difficulty) && difficulty >= 1 && difficulty <= 3 ? difficulty : 1;
  return `${"★".repeat(level)}${"☆".repeat(3 - level)}`;
}

function backToDecks() {
  if (getCurrentPages().length > 1) {
    uni.navigateBack();
    return;
  }

  uni.redirectTo({ url: "/pages/deck/index" });
}

async function copySummary() {
  if (!summary.value) {
    return;
  }

  await uni.setClipboardData({ data: summary.value });
  copied.value = true;
  setTimeout(() => {
    copied.value = false;
  }, 1500);
}

function openCardDetail(cardKey: string) {
  uni.navigateTo({ url: `/pages/card-detail/index?cardKey=${encodeURIComponent(cardKey)}` });
}

function handleExport() {
  if (!deck.value || !rows.value.length || exporting.value) {
    return;
  }
  if (deck.value.incompatibleCardCount) {
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
        await doExportImage();
        return;
      }

      if (result.tapIndex === 1) {
        doExportCode();
      }
    }
  });
}

async function doExportImage() {
  if (!deck.value || !rows.value.length) {
    return;
  }

  exporting.value = true;
  try {
    const tempFilePath = await exportDeckOverview({
      id: deck.value.id,
      name: deck.value.name,
      description: deck.value.description,
      totalCount: deck.value.cardCount,
      summary: summary.value,
      resolvedCards: rows.value
    }, "public-deck-detail-export-canvas");
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
    exporting.value = false;
  }
}

function doExportCode() {
  const deckCode = buildDeckCode(rows.value);
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

onShareAppMessage(() => ({
  title: deck.value ? `${deck.value.name} - 公开卡组` : "LEGION12公开卡组",
  path: deckId.value ? `/pages/public-deck-detail/index?deckId=${encodeURIComponent(deckId.value)}` : "/pages/deck/index"
}));
</script>

<template>
  <view class="page-shell">
    <view class="page-header">
      <button class="page-link" @click="backToDecks">返回</button>
      <button class="page-link" :disabled="!rows.length || exporting" @click="handleExport">
        {{ exporting ? "导出中" : "导出" }}
      </button>
      <button class="page-link page-link--primary" :disabled="!summary" @click="copySummary">
        {{ copied ? "已复制" : "复制摘要" }}
      </button>
    </view>

    <text v-if="loading" class="page-empty">正在读取公开卡组...</text>
    <text v-else-if="loadError" class="page-error">{{ loadError }}</text>

    <template v-else-if="deck">
      <view class="deck-detail-card">
        <image v-if="coverImage" class="deck-detail-card__image" :src="coverImage" mode="widthFix" />
        <view v-else class="deck-detail-card__image deck-detail-card__image--empty">
          <text>无封面</text>
        </view>

        <view class="deck-detail-card__body">
          <text user-select class="deck-detail-card__title">{{ deck.name }}</text>
          <text user-select class="deck-detail-card__difficulty">上手难度：{{ formatDifficulty(deck.difficulty) }}</text>
          <text user-select class="deck-detail-card__desc">{{ deck.description || "暂无介绍" }}</text>
          <text user-select class="deck-detail-card__count">{{ deck.cardCount }} 张卡牌</text>
          <text v-if="compatibilityMessage" user-select class="deck-detail-card__warning">{{ compatibilityMessage }}</text>
          <text user-select class="deck-detail-card__summary">{{ summary || "暂无卡组摘要" }}</text>
        </view>
      </view>

      <view class="deck-detail-list">
        <button v-for="row in rows" :key="`${row.cardKey}-${row.card?.id ?? ''}`" class="deck-detail-row" @click="openCardDetail(buildCardKey(row.card!))">
          <image class="deck-detail-row__image" :src="resolveCardThumbnail(row.card!) || resolveCardImage(row.card!)" mode="aspectFill" lazy-load />
          <view class="deck-detail-row__meta">
            <text user-select class="deck-detail-row__title">{{ row.card!.name }}</text>
            <text user-select class="deck-detail-row__desc">{{ row.card!.type }} / {{ row.card!.faction }}</text>
          </view>
          <text user-select class="deck-detail-row__count">×{{ row.count }}</text>
        </button>
      </view>

      <view v-if="deck.incompatibleCards?.length" class="deck-warning-list">
        <view v-for="item in deck.incompatibleCards" :key="`${item.cardKey}-${item.reason}`" class="deck-warning-item">
          <text user-select class="deck-warning-item__title">待手动处理</text>
          <text user-select class="deck-warning-item__desc">{{ item.cardKey }} × {{ item.count }}</text>
        </view>
      </view>

      <canvas
        canvas-id="public-deck-detail-export-canvas"
        class="export-canvas"
        :style="{ width: `${DECK_EXPORT_CANVAS_WIDTH}px`, height: `${exportCanvasHeight}px` }"
      />
    </template>
  </view>
</template>

<style scoped>
.page-shell {
  padding: 28rpx;
}

.page-header {
  display: flex;
  justify-content: space-between;
  gap: 20rpx;
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

.deck-detail-card {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
  margin-bottom: 24rpx;
}

.deck-detail-card__image {
  width: 100%;
  border-radius: 28rpx;
  background: #dbe4f0;
}

.deck-detail-card__image--empty {
  height: 600rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #64748b;
}

.deck-detail-card__body {
  display: flex;
  flex-direction: column;
  gap: 12rpx;
  padding: 28rpx;
  border-radius: 28rpx;
  background: #ffffff;
}

.deck-detail-card__title {
  font-size: 38rpx;
  font-weight: 700;
  color: #0f172a;
}

.deck-detail-card__difficulty,
.deck-detail-card__desc,
.deck-detail-card__count,
.deck-detail-card__summary,
.deck-detail-row__desc {
  color: #64748b;
  line-height: 1.6;
}

.deck-detail-card__warning {
  color: #b45309;
  line-height: 1.6;
}

.deck-detail-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.deck-warning-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
  margin-top: 20rpx;
}

.deck-warning-item {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
  padding: 20rpx;
  border-radius: 24rpx;
  background: #fff7ed;
}

.deck-warning-item__title {
  font-size: 28rpx;
  font-weight: 700;
  color: #9a3412;
}

.deck-warning-item__desc {
  color: #9a3412;
  line-height: 1.6;
}

.deck-detail-row {
  display: flex;
  align-items: center;
  gap: 20rpx;
  width: 100%;
  padding: 20rpx;
  border-radius: 24rpx;
  background: #ffffff;
  text-align: left;
}

.deck-detail-row__image {
  width: 120rpx;
  min-width: 120rpx;
  height: 168rpx;
  border-radius: 16rpx;
  background: #dbe4f0;
}

.deck-detail-row__meta {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

.deck-detail-row__title {
  font-size: 30rpx;
  font-weight: 700;
  color: #0f172a;
}

.deck-detail-row__count {
  color: #0f172a;
  font-weight: 700;
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

.export-canvas {
  position: fixed;
  left: -2000px;
  top: -2000px;
  opacity: 0;
  pointer-events: none;
}
</style>
