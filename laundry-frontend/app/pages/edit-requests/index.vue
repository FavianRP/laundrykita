<script setup lang="ts">
import type { EditRequest, Paginated, ApprovalStatus } from '~/types'

definePageMeta({ layout: 'default' })

const api = useApi()
const requests = ref<EditRequest[]>([])
const loading = ref(true)
const error = ref('')
const statusFilter = ref<ApprovalStatus | ''>('Pending')

async function load() {
  loading.value = true
  error.value = ''
  try {
    const params: Record<string, any> = { page_size: 50 }
    if (statusFilter.value) params.approval_status = statusFilter.value
    const res = await api.get<Paginated<EditRequest>>('/edit-requests', params)
    requests.value = res.data
  } catch (e: any) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
watch(statusFilter, load)
onMounted(load)
</script>

<template>
  <div>
    <p class="font-mono text-xs uppercase tracking-widest text-[var(--color-ink-soft)] mb-1">Tata Kelola</p>
    <h1 class="font-display text-3xl text-[var(--color-ink)] mb-6">Pengajuan Perbaikan &amp; Pembatalan</h1>

    <div class="flex gap-2 mb-5">
      <button
        v-for="s in (['Pending', 'Approved', 'Rejected', ''] as const)"
        :key="s || 'all'"
        class="text-xs font-mono uppercase px-3 py-1.5 rounded-full border transition-colors"
        :class="statusFilter === s ? 'bg-[var(--color-soap)] text-white border-[var(--color-soap)]' : 'border-[var(--color-line)] text-[var(--color-ink-soft)] hover:border-[var(--color-soap)]'"
        @click="statusFilter = s"
      >{{ s || 'Semua' }}</button>
    </div>

    <p v-if="error" class="text-sm text-[var(--color-stamp)] mb-4">{{ error }}</p>
    <div v-if="loading" class="text-sm text-[var(--color-ink-soft)]">Memuat pengajuan…</div>

    <div v-else-if="!requests.length" class="border border-dashed border-[var(--color-line)] rounded-xl py-16 text-center">
      <p class="font-display text-lg text-[var(--color-ink-soft)]">Tidak ada pengajuan</p>
    </div>

    <div v-else class="space-y-3">
      <NuxtLink
        v-for="r in requests"
        :key="r.id"
        :to="`/edit-requests/${r.id}`"
        class="block bg-white border border-[var(--color-line)] rounded-lg px-5 py-4 hover:border-[var(--color-soap)] transition-colors"
      >
        <div class="flex items-center justify-between gap-3 flex-wrap">
          <div>
            <p class="font-medium text-[var(--color-ink)]">
              {{ r.is_cancellation_request ? 'Permintaan Pembatalan' : 'Permintaan Perbaikan Data' }}
              <span class="text-[var(--color-ink-soft)] font-normal">· Order #{{ r.order_id }}</span>
            </p>
            <p class="text-sm text-[var(--color-ink-soft)] mt-1">{{ r.reason }}</p>
          </div>
          <ApprovalBadge :status="r.approval_status" />
        </div>
        <p class="text-[11px] font-mono text-[var(--color-ink-soft)] mt-2">{{ formatDate(r.created_at) }}</p>
      </NuxtLink>
    </div>
  </div>
</template>
