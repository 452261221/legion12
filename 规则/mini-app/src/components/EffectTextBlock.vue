<script setup lang="ts">
import { computed } from "vue";

type EffectSegment = {
  text: string;
  accent: boolean;
};

type EffectLine = {
  note: boolean;
  segments: EffectSegment[];
};

const props = withDefaults(
  defineProps<{
    text?: string;
    emptyText?: string;
  }>(),
  {
    text: "",
    emptyText: "暂无效果文本。"
  }
);

const LEADING_CUES = [
  "我方",
  "对方",
  "登场时",
  "进攻时",
  "阵亡时",
  "主动休整",
  "回合1次",
  "回合结束时",
  "规则上",
  "触发",
  "持续",
  "「位于前排」",
  "「位于后排」",
  "『位于前排』",
  "『位于后排』"
] as const;

function cleanEffectText(text: string): string {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !/^天灾等级[:：]?\s*[★☆✦✧]*$/u.test(line))
    .join("\n");
}

function startsWithCue(text: string, cue: string): boolean {
  return text === cue || text.startsWith(`${cue} `) || text.startsWith(`${cue}：`) || text.startsWith(`${cue}:`);
}

function parseLine(line: string): EffectLine {
  const segments: EffectSegment[] = [];
  let remaining = line.trim();

  while (remaining) {
    const cue = LEADING_CUES.find((item) => startsWithCue(remaining, item));
    if (!cue) {
      break;
    }

    segments.push({ text: cue, accent: true });
    remaining = remaining.slice(cue.length).trimStart();
  }

  if (remaining) {
    segments.push({ text: remaining, accent: false });
  }

  if (!segments.length) {
    segments.push({ text: line.trim(), accent: false });
  }

  return {
    note: /^[（(]/.test(line.trim()),
    segments
  };
}

const lines = computed(() => cleanEffectText(props.text).split("\n").filter(Boolean).map(parseLine));
</script>

<template>
  <view v-if="lines.length" class="effect-text">
    <view v-for="(line, index) in lines" :key="index" :class="['effect-text__line', line.note ? 'effect-text__line--note' : '']">
      <text
        v-for="(segment, segmentIndex) in line.segments"
        :key="`${index}-${segmentIndex}`"
        user-select
        :class="['effect-text__segment', segment.accent ? 'effect-text__segment--accent' : '']"
      >
        {{ segment.text }}
      </text>
    </view>
  </view>
  <text v-else user-select class="effect-text__empty">{{ emptyText }}</text>
</template>

<style scoped>
.effect-text {
  display: flex;
  flex-direction: column;
  gap: 14rpx;
}

.effect-text__line {
  color: #334155;
  line-height: 1.7;
}

.effect-text__line--note {
  color: #64748b;
}

.effect-text__segment--accent {
  color: #b45309;
  font-weight: 600;
  margin-right: 8rpx;
}

.effect-text__empty {
  color: #94a3b8;
}
</style>
