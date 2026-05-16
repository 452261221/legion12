<script setup lang="ts">
import { computed, onMounted, ref } from "vue";

import { MAX_CARD_COPIES, MAX_DECK_SIZE, useDeck } from "@/composables/useDeck";
import { useLibraryData } from "@/composables/useLibraryData";
import { CARD_FACTION_OPTIONS, CARD_TYPE_OPTIONS, getCardFactionLabel, getCardTypeLabel } from "@/utils/cardCategory";
import { resolveCardThumbnail } from "@/utils/cardImage";
import { buildCardKey, matchCardKey } from "@/utils/cardKey";

const keyword = ref("");
const selectedType = ref("");
const selectedFaction = ref("");
const selectionError = ref("");

const { cards, init, loading } = useLibraryData();
const { addCard, clearDraftCards, deck, decreaseCard, totalCount } = useDeck();

onMounted(() => {
  void init();
});

const visibleCards = computed(() => cards.value.filter((card) => typeof card.image === "string" && card.image.trim().length > 0));

const typeOptions = computed(() =>
  CARD_TYPE_OPTIONS.filter((type) => visibleCards.value.some((card) => getCardTypeLabel(card) === type))
);

const factionOptions = computed(() =>
  CARD_FACTION_OPTIONS.filter((faction) => visibleCards.value.some((card) => getCardFactionLabel(card) === faction))
);

const deckCountMap = computed(() => new Map(deck.value.map((item) => [item.cardKey, item.count])));

const selectedSummary = computed(() => {
  if (!deck.value.length) {
    return "还没有选择卡牌。";
  }

  return deck.value
    .map((item) => {
      const card = cards.value.find((currentCard) => matchCardKey(currentCard, item.cardKey));
      return `${card?.name ?? item.cardKey}×${item.count}`;
    })
    .join("，");
});

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

function getDeckCount(cardKey: string) {
  return deckCountMap.value.get(cardKey) ?? 0;
}

function handleClearDraftCards() {
  selectionError.value = "";
  clearDraftCards();
}

function handleAddCard(cardKey: string) {
  const result = addCard(cardKey);
  selectionError.value = result.ok ? "" : (result.reason ?? "");
}

function handleDecreaseCard(cardKey: string) {
  selectionError.value = "";
  decreaseCard(cardKey);
}

function goNextStep() {
  if (getCurrentPages().length > 1) {
    uni.navigateBack();
    return;
  }

  uni.redirectTo({ url: "/pages/deck-edit/index" });
}
</script>

<template>
  <view class="page-shell">
    <view class="page-header">
      <button class="page-link" @click="handleClearDraftCards">清空</button>
      <button class="page-link page-link--primary" @click="goNextStep">确定</button>
    </view>

    <view class="summary-card">
      <text class="summary-card__title">当前已选</text>
      <text class="summary-card__desc">{{ totalCount }} / {{ MAX_DECK_SIZE }} 张卡牌</text>
      <text class="summary-card__desc">{{ selectedSummary }}</text>
      <text class="summary-card__hint">每张卡最多 {{ MAX_CARD_COPIES }} 张。</text>
      <text v-if="selectionError" class="summary-card__error">{{ selectionError }}</text>
    </view>

    <view class="search-box">
      <input v-model="keyword" class="search-input" confirm-type="search" placeholder="输入卡牌关键词" />
    </view>

    <view class="filter-section">
      <text class="filter-label">卡牌类型</text>
      <scroll-view scroll-x class="filter-scroll">
        <view class="filter-row">
          <button :class="['chip', !selectedType ? 'chip--active' : '']" @click="selectedType = ''">全部</button>
          <button v-for="type in typeOptions" :key="type" :class="['chip', selectedType === type ? 'chip--active' : '']" @click="selectedType = type">
            {{ type }}
          </button>
        </view>
      </scroll-view>
    </view>

    <view class="filter-section">
      <text class="filter-label">阵营</text>
      <scroll-view scroll-x class="filter-scroll">
        <view class="filter-row">
          <button :class="['chip', !selectedFaction ? 'chip--active' : '']" @click="selectedFaction = ''">全部</button>
          <button
            v-for="faction in factionOptions"
            :key="faction"
            :class="['chip', selectedFaction === faction ? 'chip--active' : '']"
            @click="selectedFaction = faction"
          >
            {{ faction }}
          </button>
        </view>
      </scroll-view>
    </view>

    <text v-if="loading" class="page-empty">正在读取卡牌数据...</text>
    <text v-else-if="!filteredCards.length" class="page-empty">当前筛选下没有可加入的卡牌。</text>

    <view v-else class="card-list">
      <view v-for="(card, index) in filteredCards" :key="`${buildCardKey(card)}-${card.id}-${index}`" class="card-row">
        <image class="card-row__thumb" :src="resolveCardThumbnail(card)" mode="aspectFill" lazy-load />
        <view class="card-row__body">
          <text class="card-row__title">{{ card.name }}</text>
          <text class="card-row__meta">{{ getCardTypeLabel(card) }} / {{ getCardFactionLabel(card) || card.faction }}</text>
          <view class="card-row__actions">
            <button class="step-button" @click="handleDecreaseCard(buildCardKey(card))">-</button>
            <text class="step-value">{{ getDeckCount(buildCardKey(card)) }}</text>
            <button
              class="step-button"
              :disabled="getDeckCount(buildCardKey(card)) >= MAX_CARD_COPIES || totalCount >= MAX_DECK_SIZE"
              @click="handleAddCard(buildCardKey(card))"
            >
              +
            </button>
          </view>
        </view>
      </view>
    </view>
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

.summary-card {
  display: flex;
  flex-direction: column;
  gap: 10rpx;
  padding: 24rpx;
  border-radius: 24rpx;
  background: #ffffff;
  margin-bottom: 24rpx;
}

.summary-card__title {
  font-size: 30rpx;
  font-weight: 700;
  color: #0f172a;
}

.summary-card__desc,
.summary-card__hint {
  color: #64748b;
  line-height: 1.6;
}

.summary-card__error {
  color: #dc2626;
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
  gap: 16rpx;
}

.card-row {
  display: flex;
  gap: 20rpx;
  padding: 20rpx;
  border-radius: 24rpx;
  background: #ffffff;
}

.card-row__thumb {
  width: 120rpx;
  min-width: 120rpx;
  height: 168rpx;
  border-radius: 16rpx;
  background: #dbe4f0;
}

.card-row__body {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 10rpx;
}

.card-row__title {
  font-size: 30rpx;
  font-weight: 700;
  color: #0f172a;
}

.card-row__meta {
  color: #64748b;
}

.card-row__actions {
  display: flex;
  align-items: center;
  gap: 14rpx;
}

.step-button {
  width: 56rpx;
  height: 56rpx;
  border-radius: 999rpx;
  background: #eff6ff;
  color: #2563eb;
  font-size: 32rpx;
}

.step-value {
  min-width: 32rpx;
  text-align: center;
  color: #0f172a;
  font-weight: 700;
}

.page-empty {
  display: block;
  padding: 48rpx 0;
  text-align: center;
  color: #64748b;
}
</style>
