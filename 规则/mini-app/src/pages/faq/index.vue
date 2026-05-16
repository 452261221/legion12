<script setup lang="ts">
import { computed, onMounted, ref } from "vue";

import { useLibraryData } from "@/composables/useLibraryData";

const keyword = ref("");
const { faqItems, init, loading } = useLibraryData();

onMounted(() => {
  void init();
});

const filteredFaq = computed(() => {
  const value = keyword.value.trim().toLowerCase();
  if (!value) {
    return faqItems.value;
  }
  return faqItems.value.filter((item) => item.question.toLowerCase().includes(value) || item.answer.toLowerCase().includes(value) || item.keywords.some((tag) => tag.toLowerCase().includes(value)));
});

function backToCards() {
  if (getCurrentPages().length > 1) {
    uni.navigateBack();
    return;
  }

  uni.redirectTo({ url: "/pages/cards/index" });
}
</script>

<template>
  <view class="page-shell">
    <view class="page-header">
      <view>
        <text class="page-title">规则问答</text>
        <text class="page-note">{{ filteredFaq.length }} 条</text>
      </view>
      <button class="page-link" @click="backToCards">返回卡牌</button>
    </view>

    <view class="search-box">
      <input v-model="keyword" class="search-input" confirm-type="search" placeholder="输入问题、答案或关键词" />
    </view>

    <text v-if="loading" class="page-empty">正在读取 FAQ 数据...</text>

    <view v-else class="faq-list">
      <view v-for="item in filteredFaq" :key="item.id" class="faq-card">
        <text user-select class="faq-card__question">{{ item.question }}</text>
        <text user-select class="faq-card__answer">{{ item.answer }}</text>
        <view v-if="item.keywords.length" class="faq-card__tags">
          <text v-for="tag in item.keywords" :key="tag" class="faq-card__tag">{{ tag }}</text>
        </view>
      </view>
      <text v-if="!filteredFaq.length" class="page-empty">没有命中 FAQ。</text>
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
  gap: 24rpx;
  align-items: center;
  margin-bottom: 24rpx;
}

.page-title {
  display: block;
  font-size: 40rpx;
  font-weight: 700;
}

.page-note {
  margin-top: 8rpx;
  display: block;
  color: #64748b;
}

.page-link {
  padding: 16rpx 24rpx;
  border-radius: 999rpx;
  background: #e2e8f0;
  color: #334155;
  font-size: 24rpx;
}

.search-box {
  margin-bottom: 24rpx;
}

.search-input {
  width: 100%;
  height: 84rpx;
  padding: 0 24rpx;
  border-radius: 24rpx;
  background: #ffffff;
}

.faq-list {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
}

.faq-card {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
  padding: 24rpx;
  border-radius: 24rpx;
  background: #ffffff;
}

.faq-card__question {
  font-size: 30rpx;
  font-weight: 700;
  color: #0f172a;
  line-height: 1.5;
}

.faq-card__answer {
  color: #334155;
  line-height: 1.7;
}

.faq-card__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
}

.faq-card__tag {
  padding: 8rpx 16rpx;
  border-radius: 999rpx;
  background: #eff6ff;
  color: #2563eb;
  font-size: 22rpx;
}

.page-empty {
  display: block;
  padding: 48rpx 0;
  text-align: center;
  color: #64748b;
}
</style>
