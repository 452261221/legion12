import { computed, ref } from "vue";

import cardsJson from "@/static/data/cards.json";
import faqJson from "@/static/data/faq.json";
import type { Card, FaqEntry } from "@/types";
import { useDeck } from "@/composables/useDeck";

const cards = ref<Card[]>([]);
const faqItems = ref<FaqEntry[]>([]);
const loading = ref(false);
const ready = ref(false);
const { reconcileCardKeys } = useDeck();

let initPromise: Promise<void> | null = null;

async function init() {
  if (ready.value) {
    return;
  }

  if (!initPromise) {
    loading.value = true;
    initPromise = Promise.resolve()
      .then(() => {
        cards.value = cardsJson as Card[];
        reconcileCardKeys(cards.value);
        faqItems.value = faqJson as FaqEntry[];
        ready.value = true;
      })
      .finally(() => {
        loading.value = false;
      });
  }

  await initPromise;
}

export function useLibraryData() {
  return {
    cards,
    faqItems,
    loading,
    ready: computed(() => ready.value),
    init
  };
}
