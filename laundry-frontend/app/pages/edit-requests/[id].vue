<script setup lang="ts">
import type { EditRequest } from '~/types'

definePageMeta({ layout: 'default' })

const route = useRoute()
const api = useApi()
const auth = useAuthStore()

const request = ref<EditRequest | null>(null)
const loading = ref(true)
const error = ref('')
const acting = ref(false)
const actionError = ref('')

async function load() {
  loading.value = true
  error.value = ''
  try {
    request.value = await api.get<EditRequest>(`/edit-requests/${route.params.id}`)
  } catch (e: any) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
onMounted(load)

async function act(action: 'approve' | 'reject') {
  if (!request.value) return
  acting.value = true
  actionError.value = ''
  try {
    request.value = await api.post<EditRequest>(`/edit-requests/${request.value.id}/${action}`)
  } catch (e: any) {
    actionError.value = e.message
  } finally {
    acting.value = false
  }
}

function diffClass(oldVal: any, newVal: any) {
  return oldVal !== newVal ? 'font-semibold' : ''
}
</script>

<template>
  <div v-if="loading" class="text-sm text-[var(--color-ink-soft)]">Memuat detail pengajuan…</div>
  <div v-else-if="error" class="text-sm text-[var(--color-stamp)]">{{ error }}</div>

  <div v-else-if="request" class="max-w-2xl">
    <NuxtLink to="/edit-requests" class="text-xs font-medium text-[var(--color-ink-soft)] hover:text-[var(--color-soap-deep)]">← Kembali ke daftar pengajuan</NuxtLink>

    <div class="flex items-start justify-between gap-4 mt-3 mb-6 flex-wrap">
      <div>
        <p class="font-mono text-xs uppercase tracking-widest text-[var(--color-ink-soft)] mb-1">
          {{ request.is_cancellation_request ? 'Permintaan Pembatalan' : 'Permintaan Perbaikan Data' }}
        </p>
        <h1 class="font-display text-2xl text-[var(--color-ink)]">
          <NuxtLink :to="`/orders/${request.order_id}`" class="hover:text-[var(--color-soap-deep)] underline underline-offset-2">Order #{{ request.order_id }}</NuxtLink>
        </h1>
      </div>
      <ApprovalBadge :status="request.approval_status" />
    </div>

    <div class="bg-white border border-[var(--color-line)] rounded-xl p-5 mb-5">
      <h2 class="text-sm font-semibold mb-2">Alasan</h2>
      <p class="text-sm text-[var(--color-ink-soft)]">{{ request.reason }}</p>
      <p class="text-[11px] font-mono text-[var(--color-ink-soft)] mt-3">Diajukan {{ formatDate(request.created_at) }}</p>
    </div>

    <div v-if="!request.is_cancellation_request && request.items?.length" class="bg-white border border-[var(--color-line)] rounded-xl p-5 mb-5">
      <h2 class="text-sm font-semibold mb-4">Perbandingan Data</h2>
      <div v-for="(item, i) in request.items" :key="i" class="mb-4 last:mb-0 pb-4 last:pb-0 border-b border-[var(--color-line)] last:border-0">
        <p class="text-xs font-mono text-[var(--color-ink-soft)] mb-2">Item #{{ item.order_item_id }}</p>
        <div class="grid grid-cols-2 gap-3">
          <div class="rounded-lg bg-[var(--color-stamp-light)] p-3">
            <p class="text-[10px] font-mono uppercase text-[var(--color-stamp)] mb-1.5">Data Sekarang</p>
            <p class="text-sm" :class="diffClass(item.old_service_type, item.new_service_type)">{{ item.old_service_type }}</p>
            <p class="text-sm" :class="diffClass(item.old_weight_quantity, item.new_weight_quantity)">{{ item.old_weight_quantity }} unit</p>
            <p class="text-sm font-mono" :class="diffClass(item.old_price_per_unit, item.new_price_per_unit)">{{ formatRupiah(item.old_price_per_unit) }}</p>
          </div>
          <div class="rounded-lg bg-[var(--color-go-light)] p-3">
            <p class="text-[10px] font-mono uppercase text-[var(--color-go)] mb-1.5">Usulan</p>
            <p class="text-sm" :class="diffClass(item.old_service_type, item.new_service_type)">{{ item.new_service_type }}</p>
            <p class="text-sm" :class="diffClass(item.old_weight_quantity, item.new_weight_quantity)">{{ item.new_weight_quantity }} unit</p>
            <p class="text-sm font-mono" :class="diffClass(item.old_price_per_unit, item.new_price_per_unit)">{{ formatRupiah(item.new_price_per_unit) }}</p>
          </div>
        </div>
      </div>
    </div>

    <div v-if="auth.isOwner && request.approval_status === 'Pending'" class="flex gap-3">
      <button
        class="rounded-md bg-[var(--color-go)] text-white text-sm font-medium px-4 py-2.5 hover:opacity-90 disabled:opacity-60"
        :disabled="acting"
        @click="act('approve')"
      >Terima</button>
      <button
        class="rounded-md bg-[var(--color-stamp)] text-white text-sm font-medium px-4 py-2.5 hover:opacity-90 disabled:opacity-60"
        :disabled="acting"
        @click="act('reject')"
      >Tolak</button>
    </div>
    <p v-else-if="request.approval_status === 'Pending'" class="text-sm text-[var(--color-ink-soft)]">Hanya owner yang dapat menyetujui atau menolak pengajuan ini.</p>

    <p v-if="actionError" class="text-sm text-[var(--color-stamp)] mt-3">{{ actionError }}</p>
  </div>
</template>
