<script setup lang="ts">
import type { ApprovalStatus } from '~/types'
defineProps<{ status: ApprovalStatus }>()

const styles: Record<ApprovalStatus, string> = {
  Pending: 'bg-[var(--color-pending-light)] text-[var(--color-pending)]',
  Approved: 'bg-[var(--color-go-light)] text-[var(--color-go)]',
  Rejected: 'bg-[var(--color-stamp-light)] text-[var(--color-stamp)]',
}
</script>

<template>
  <span class="inline-block px-2.5 py-1 rounded text-[11px] font-mono uppercase tracking-wide" :class="styles[status]">
    {{ status }}
  </span>
</template>
