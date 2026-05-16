<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { onLoad } from "@dcloudio/uni-app";

import { useDeck } from "@/composables/useDeck";
import { useLibraryData } from "@/composables/useLibraryData";
import { resolveCardImage, resolveCardThumbnail } from "@/utils/cardImage";
import { buildCardKey, matchCardKey } from "@/utils/cardKey";
import { buildDeckCode, DECK_EXPORT_CANVAS_WIDTH, exportDeckOverview, getDeckExportCanvasHeight } from "@/utils/deckExport";

const deckId = ref("");
const { cards, init } = useLibraryData();
const { getDeckById, loadDeckToDraft } = useDeck();

onLoad((options) => {
  deckId.value = String(options?.deckId ?? "");
});

onMounted(() => {
  void init();
});

const deck = computed(() => getDeckById(deckId.value));

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

const coverImage = computed(() => {
  if (!deck.value) {
    return "";
  }
  if (deck.value.coverImage) {
    return deck.value.coverImage;
  }
  return rows.value[0]?.card ? resolveCardImage(rows.value[0].card) : "";
});

const totalCount = computed(() => rows.value.reduce((sum, item) => sum + item.count, 0));
const summary = computed(() => rows.value.map((row) => `${row.card!.name}×${row.count}`).join("，"));
const exportCanvasHeight = computed(() => getDeckExportCanvasHeight(rows.value.length));
const exporting = ref(false);

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

function editDeck() {
  if (!deck.value) {
    return;
  }
  if (!loadDeckToDraft(deck.value.id)) {
    return;
  }
  uni.navigateTo({ url: "/pages/deck-edit/index" });
}

function openCardDetail(cardKey: string) {
  uni.navigateTo({ url: `/pages/card-detail/index?cardKey=${encodeURIComponent(cardKey)}` });
}

function handleExport() {
  if (!deck.value || !rows.value.length || exporting.value) {
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
      totalCount: totalCount.value,
      summary: summary.value,
      resolvedCards: rows.value
    }, "deck-detail-export-canvas");
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
</script>

<template>
  <view class="page-shell">
    <view class="page-header">
      <button class="page-link" @click="backToDecks">返回</button>
      <button v-if="deck" class="page-link" :disabled="exporting" @click="handleExport">
        {{ exporting ? "导出中" : "导出" }}
      </button>
      <button v-if="deck" class="page-link page-link--primary" @click="editDeck">编辑</button>
    </view>

    <text v-if="!deck" class="page-empty">未找到对应卡组。</text>

    <template v-else>
      <view class="deck-detail-card">
        <image v-if="coverImage" class="deck-detail-card__image" :src="coverImage" mode="widthFix" />
        <view v-else class="deck-detail-card__image deck-detail-card__image--empty">
          <text>无封面</text>
        </view>

        <view class="deck-detail-card__body">
          <text user-select class="deck-detail-card__title">{{ deck.name }}</text>
          <text user-select class="deck-detail-card__desc">上手难度：{{ formatDifficulty(deck.difficulty) }}</text>
          <text user-select class="deck-detail-card__desc">{{ deck.description || "暂无介绍" }}</text>
          <text user-select class="deck-detail-card__count">{{ totalCount }} 张卡牌</text>
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

      <canvas
        canvas-id="deck-detail-export-canvas"
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

.deck-detail-card__desc,
.deck-detail-card__count,
.deck-detail-row__desc {
  color: #64748b;
  line-height: 1.6;
}

.deck-detail-list {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
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

.export-canvas {
  position: fixed;
  left: -2000px;
  top: -2000px;
  opacity: 0;
  pointer-events: none;
}

.page-empty {
  display: block;
  padding: 48rpx 0;
  text-align: center;
  color: #64748b;
}
</style>
