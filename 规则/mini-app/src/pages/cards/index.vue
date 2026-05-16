<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { onShareAppMessage, onShow } from "@dcloudio/uni-app";

import { useLibraryData } from "@/composables/useLibraryData";
import { CARD_FACTION_OPTIONS, CARD_TYPE_OPTIONS, getCardFactionLabel, getCardTypeLabel } from "@/utils/cardCategory";
import { resolveCardThumbnail } from "@/utils/cardImage";
import { buildCardKey } from "@/utils/cardKey";
import { showFriendShareMenu } from "@/utils/share";

const keyword = ref("");
const selectedType = ref("");
const selectedFaction = ref("");
const { cards, init, loading } = useLibraryData();

onMounted(() => {
  void init();
});

onShow(() => {
  showFriendShareMenu();
});

onShareAppMessage(() => ({
  title: "LEGION12查卡器",
  path: "/pages/cards/index"
}));

const visibleCards = computed(() => cards.value.filter((card) => typeof card.image === "string" && card.image.trim().length > 0));

const typeOptions = computed(() => CARD_TYPE_OPTIONS.filter((type) => visibleCards.value.some((card) => getCardTypeLabel(card) === type)));

const factionOptions = computed(() => CARD_FACTION_OPTIONS.filter((faction) => visibleCards.value.some((card) => getCardFactionLabel(card) === faction)));

const filteredCards = computed(() => {
  const value = keyword.value.trim().toLowerCase();

  return visibleCards.value.filter((card) => {
    if (selectedType.value && getCardTypeLabel(card) !== selectedType.value) {
      return false;
    }
    if (selectedFaction.value && getCardFactionLabel(card) !== selectedFaction.value) {
      return false;
    }
    if (!value) {
      return true;
    }
    return card.searchText.toLowerCase().includes(value);
  });
});

function toggleType(type: string) {
  selectedType.value = selectedType.value === type ? "" : type;
}

function toggleFaction(faction: string) {
  selectedFaction.value = selectedFaction.value === faction ? "" : faction;
}

function openDetail(cardKey: string) {
  uni.navigateTo({
    url: `/pages/card-detail/index?cardKey=${encodeURIComponent(cardKey)}`
  });
}

function openFaq() {
  uni.navigateTo({ url: "/pages/faq/index" });
}

function openDeck() {
  uni.navigateTo({ url: "/pages/deck/index" });
}
</script>

<template>
  <view class="page-shell">
    <view class="page-header">
      <view>
        <text class="page-title">卡牌检索</text>
        <text class="page-note">{{ filteredCards.length }} 张</text>
      </view>
      <view class="page-header__actions">
        <button class="page-link" @click="openDeck">卡组列表</button>
        <button class="page-link page-link--primary" @click="openFaq">规则问答</button>
      </view>
    </view>

    <view class="search-box">
      <input v-model="keyword" class="search-input" confirm-type="search" placeholder="输入卡名、标签或效果关键字" />
    </view>

    <view class="filter-section">
      <text class="filter-label">卡牌类型</text>
      <scroll-view scroll-x class="filter-scroll">
        <view class="filter-row">
          <button v-for="type in typeOptions" :key="type" :class="['chip', selectedType === type ? 'chip--active' : '']" @click="toggleType(type)">
            {{ type }}
          </button>
        </view>
      </scroll-view>
    </view>

    <view class="filter-section">
      <text class="filter-label">阵营</text>
      <scroll-view scroll-x class="filter-scroll">
        <view class="filter-row">
          <button v-for="faction in factionOptions" :key="faction" :class="['chip', selectedFaction === faction ? 'chip--active' : '']" @click="toggleFaction(faction)">
            {{ faction }}
          </button>
        </view>
      </scroll-view>
    </view>

    <text v-if="loading" class="page-empty">正在读取卡牌数据...</text>

    <view v-else class="card-list">
      <button v-for="card in filteredCards" :key="buildCardKey(card)" class="card-row" @click="openDetail(buildCardKey(card))">
        <image v-if="resolveCardThumbnail(card)" class="card-row__thumb" :src="resolveCardThumbnail(card)" mode="aspectFill" lazy-load />
        <view v-else class="card-row__thumb card-row__thumb--empty">
          <text>暂无卡图</text>
        </view>
        <view class="card-row__body">
          <view class="card-row__title-row">
            <text class="card-row__title">{{ card.name }}</text>
            <text class="card-row__cost">费用 {{ card.cost ?? '-' }}</text>
          </view>
          <text class="card-row__meta">{{ getCardTypeLabel(card) }} / {{ getCardFactionLabel(card) || card.faction }}</text>
          <text user-select class="card-row__desc">{{ card.effectText || '暂无效果文本。' }}</text>
        </view>
      </button>
      <text v-if="!filteredCards.length" class="page-empty">没有命中卡牌。</text>
    </view>
  </view>
</template>

<style scoped>
.page-shell {
  padding: 28rpx;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24rpx;
  margin-bottom: 24rpx;
}

.page-title {
  display: block;
  font-size: 40rpx;
  font-weight: 700;
}

.page-header__actions {
  display: flex;
  gap: 12rpx;
}

.page-note {
  margin-top: 8rpx;
  display: block;
  color: #64748b;
}

.page-link {
  padding: 16rpx 24rpx;
  border-radius: 999rpx;
  font-size: 24rpx;
  color: #334155;
  background: #e2e8f0;
}

.page-link--primary {
  color: #ffffff;
  background: #2563eb;
}

.search-box,
.filter-section {
  margin-bottom: 24rpx;
}

.search-input {
  width: 100%;
  height: 84rpx;
  padding: 0 24rpx;
  border-radius: 24rpx;
  background: #ffffff;
}

.filter-label {
  display: block;
  margin-bottom: 12rpx;
  color: #475569;
  font-size: 24rpx;
}

.filter-scroll {
  white-space: nowrap;
}

.filter-row {
  display: inline-flex;
  gap: 16rpx;
}

.chip {
  padding: 14rpx 24rpx;
  border-radius: 999rpx;
  background: #ffffff;
  color: #475569;
  font-size: 24rpx;
}

.chip--active {
  color: #ffffff;
  background: #2563eb;
}

.card-list {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
}

.card-row {
  display: flex;
  gap: 20rpx;
  align-items: stretch;
  width: 100%;
  padding: 20rpx;
  border-radius: 28rpx;
  background: #ffffff;
  text-align: left;
}

.card-row__thumb {
  width: 144rpx;
  min-width: 144rpx;
  height: 202rpx;
  border-radius: 18rpx;
  background: #dbe4f0;
}

.card-row__thumb--empty {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #64748b;
  font-size: 22rpx;
}

.card-row__body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.card-row__title-row {
  display: flex;
  justify-content: space-between;
  gap: 16rpx;
}

.card-row__title {
  font-size: 32rpx;
  font-weight: 700;
  color: #0f172a;
}

.card-row__cost,
.card-row__meta {
  color: #64748b;
  font-size: 24rpx;
}

.card-row__desc {
  color: #334155;
  font-size: 24rpx;
  line-height: 1.6;
}

.page-empty {
  display: block;
  padding: 48rpx 0;
  text-align: center;
  color: #64748b;
}
</style>
