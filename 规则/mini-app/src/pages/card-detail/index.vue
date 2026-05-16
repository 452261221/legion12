<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { onLoad, onShareAppMessage, onShow } from "@dcloudio/uni-app";

import EffectTextBlock from "@/components/EffectTextBlock.vue";
import { useLibraryData } from "@/composables/useLibraryData";
import { getCardFactionLabel, getCardTypeLabel } from "@/utils/cardCategory";
import { resolveCardImage } from "@/utils/cardImage";
import { matchCardKey } from "@/utils/cardKey";
import { faqRelatesToCard } from "@/utils/faqRelation";
import { showFriendShareMenu } from "@/utils/share";

const cardKey = ref("");
const { cards, faqItems, init, loading } = useLibraryData();

onLoad((options) => {
  cardKey.value = String(options?.cardKey ?? "");
});

onMounted(() => {
  void init();
});

onShow(() => {
  showFriendShareMenu();
});

const card = computed(() => cards.value.find((item) => item.image.trim() && matchCardKey(item, cardKey.value)));

const relatedFaq = computed(() => {
  if (!card.value) {
    return [];
  }
  const exactFaqIds = new Set(card.value.faqIds);
  return faqItems.value.filter((item) => exactFaqIds.has(item.id) || faqRelatesToCard(item, card.value!, cards.value));
});

function backToList() {
  if (getCurrentPages().length > 1) {
    uni.navigateBack();
    return;
  }

  uni.redirectTo({ url: "/pages/cards/index" });
}

function openFaq() {
  uni.navigateTo({ url: "/pages/faq/index" });
}

onShareAppMessage(() => ({
  title: card.value ? `${card.value.name} - LEGION12查卡器` : "LEGION12查卡器",
  path: cardKey.value ? `/pages/card-detail/index?cardKey=${encodeURIComponent(cardKey.value)}` : "/pages/cards/index"
}));
</script>

<template>
  <view class="page-shell">
    <view class="page-header">
      <button class="page-link" @click="backToList">返回列表</button>
      <button class="page-link page-link--primary" @click="openFaq">查看 FAQ</button>
    </view>

    <text v-if="loading" class="page-empty">正在读取卡牌数据...</text>

    <view v-else-if="card" class="detail-card">
      <image v-if="resolveCardImage(card)" class="detail-card__image" :src="resolveCardImage(card)" mode="widthFix" />
      <view v-else class="detail-card__image detail-card__image--empty">
        <text>暂无卡图</text>
      </view>

      <view class="detail-card__body">
        <view class="detail-card__title-row">
          <view>
            <text user-select class="detail-card__title">{{ card.name }}</text>
            <text user-select class="detail-card__subtitle">{{ getCardTypeLabel(card) }} / {{ getCardFactionLabel(card) || card.faction }}</text>
          </view>
          <text user-select class="detail-card__cost">费用 {{ card.cost ?? '-' }}</text>
        </view>

        <view class="detail-card__meta-list">
          <text user-select>系列：{{ card.series }}</text>
          <text user-select>编号：{{ card.cardNo }}</text>
          <text v-if="card.attack !== null || card.health !== null" user-select>攻防：{{ card.attack ?? '-' }} / {{ card.health ?? '-' }}</text>
        </view>

        <view class="detail-card__section">
          <text class="detail-card__section-title">效果</text>
          <EffectTextBlock :text="card.effectText" />
        </view>

        <view v-if="card.flavorText" class="detail-card__section">
          <text class="detail-card__section-title">补充说明</text>
          <text user-select class="detail-card__paragraph">{{ card.flavorText }}</text>
        </view>

        <view v-if="relatedFaq.length" class="detail-card__section">
          <text class="detail-card__section-title">相关 FAQ</text>
          <view v-for="item in relatedFaq" :key="item.id" class="faq-card">
            <text user-select class="faq-card__question">{{ item.question }}</text>
            <text user-select class="faq-card__answer">{{ item.answer }}</text>
          </view>
        </view>
      </view>
    </view>

    <text v-else class="page-empty">没有找到这张卡，返回列表重新选择。</text>
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

.detail-card {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
}

.detail-card__image {
  width: 100%;
  border-radius: 28rpx;
  background: #dbe4f0;
}

.detail-card__image--empty {
  height: 760rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #64748b;
}

.detail-card__body {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
  padding: 28rpx;
  border-radius: 28rpx;
  background: #ffffff;
}

.detail-card__title-row {
  display: flex;
  justify-content: space-between;
  gap: 20rpx;
}

.detail-card__title {
  display: block;
  font-size: 42rpx;
  font-weight: 700;
  color: #0f172a;
}

.detail-card__subtitle,
.detail-card__cost,
.detail-card__meta-list {
  color: #64748b;
  font-size: 24rpx;
}

.detail-card__meta-list {
  display: flex;
  flex-direction: column;
  gap: 10rpx;
}

.detail-card__section {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.detail-card__section-title {
  font-size: 28rpx;
  font-weight: 700;
  color: #0f172a;
}

.detail-card__paragraph,
.faq-card__answer {
  color: #334155;
  line-height: 1.7;
}

.faq-card {
  display: flex;
  flex-direction: column;
  gap: 10rpx;
  padding: 20rpx;
  border-radius: 20rpx;
  background: #f8fafc;
}

.faq-card__question {
  font-weight: 700;
  color: #0f172a;
}

.page-empty {
  display: block;
  padding: 48rpx 0;
  text-align: center;
  color: #64748b;
}
</style>
