<script setup lang="ts">
import { PRODUCTION_FLOW, type ProductionStatus } from '~/types'

const props = defineProps<{ status: ProductionStatus; cancelled?: boolean }>()

const currentIndex = computed(() => PRODUCTION_FLOW.indexOf(props.status))
</script>

<template>
  <div v-if="cancelled" class="flex items-center gap-2">
    <span class="stamp inline-block px-3 py-1 text-xs font-mono uppercase text-[var(--color-stamp)]">Dibatalkan</span>
  </div>
  <ol v-else class="flex items-center gap-1.5">
    <li
      v-for="(step, i) in PRODUCTION_FLOW"
      :key="step"
      class="flex items-center gap-1.5"
    >
      <span
        class="w-2.5 h-2.5 rounded-full shrink-0"
        :class="i <= currentIndex ? 'bg-[var(--color-soap)]' : 'bg-[var(--color-line)]'"
      />
      <span
        class="text-[11px] font-mono whitespace-nowrap"
        :class="i === currentIndex ? 'text-[var(--color-soap-deep)] font-semibold' : 'text-[var(--color-ink-soft)]'"
      >{{ step }}</span>
      <span v-if="i < PRODUCTION_FLOW.length - 1" class="w-3 h-px bg-[var(--color-line)]" />
    </li>
  </ol>
</template>
