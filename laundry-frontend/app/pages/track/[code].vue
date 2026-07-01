<script setup lang="ts">
import type { TrackingInfo } from '~/types'

definePageMeta({ layout: 'blank' })

const route = useRoute()
const api = useApi()

const tracking = ref<TrackingInfo | null>(null)
const loading = ref(true)
const error = ref('')

async function load() {
  loading.value = true
  error.value = ''
  try {
    tracking.value = await api.get<TrackingInfo>(`/track/${route.params.code}`)
  } catch (e: any) {
    error.value = e.message || 'Kode pelacakan tidak ditemukan.'
  } finally {
    loading.value = false
  }
}
onMounted(load)
</script>

<template>
  <div class="w-full max-w-md">
    <div v-if="loading" class="text-center text-sm text-[var(--color-ink-soft)]">Memuat status pesanan…</div>

    <div v-else-if="error" class="text-center">
      <p class="font-display text-xl text-[var(--color-stamp)] mb-2">Tidak ditemukan</p>
      <p class="text-sm text-[var(--color-ink-soft)] mb-5">{{ error }}</p>
      <NuxtLink to="/track" class="text-sm font-medium text-[var(--color-soap-deep)] underline underline-offset-2">Coba kode lain</NuxtLink>
    </div>

    <div v-else-if="tracking" class="bg-white border border-[var(--color-line)] rounded-xl shadow-sm overflow-hidden">
      <div class="ticket-edge px-6 pt-6 pb-5 bg-[var(--color-soap-light)]">
        <p class="font-mono text-xs tracking-widest text-[var(--color-soap-deep)] uppercase">{{ tracking.tracking_code }}</p>
        <h1 class="font-display text-2xl text-[var(--color-ink)] mt-1">{{ tracking.customer_name }}</h1>
        <p class="text-xs text-[var(--color-ink-soft)] mt-1">{{ formatDate(tracking.order_date) }}</p>
      </div>

      <div class="px-6 py-5">
        <div v-if="tracking.is_cancelled" class="text-center py-4">
          <span class="stamp inline-block px-4 py-2 text-sm font-mono uppercase text-[var(--color-stamp)]">Pesanan Dibatalkan</span>
        </div>

        <template v-else>
          <p class="text-sm font-semibold text-[var(--color-soap-deep)] mb-2">{{ tracking.current_status }}</p>
          <div class="w-full h-2 rounded-full bg-[var(--color-line)] overflow-hidden mb-1.5">
            <div
              class="h-full bg-[var(--color-soap)] transition-all duration-500"
              :style="{ width: `${tracking.status_progress}%` }"
            />
          </div>
          <p class="text-xs text-[var(--color-ink-soft)] mb-4">{{ tracking.status_progress }}% selesai</p>

          <div
            v-if="tracking.current_status === 'Antrean' && tracking.queue_position"
            class="rounded-lg bg-[var(--color-pending-light)] px-4 py-3 mb-4 text-sm"
          >
            <p class="text-[var(--color-pending)] font-medium">Antrean ke-{{ tracking.queue_position }}</p>
            <p class="text-[var(--color-ink-soft)] text-xs mt-0.5">{{ tracking.queue_ahead }} pesanan di depanmu</p>
          </div>
        </template>

        <div class="ticket-edge pb-4 mb-4">
          <p class="text-xs font-medium text-[var(--color-ink-soft)] mb-2">Rincian item</p>
          <ul class="space-y-1.5">
            <li v-for="(item, i) in tracking.items" :key="i" class="flex justify-between text-sm">
              <span>{{ item.service_type }} · {{ item.weight_quantity }}</span>
              <span class="font-mono">{{ formatRupiah(item.weight_quantity * item.price_per_unit) }}</span>
            </li>
          </ul>
        </div>

        <div class="space-y-1 text-sm">
          <div class="flex justify-between text-[var(--color-ink-soft)]">
            <span>Subtotal</span><span class="font-mono">{{ formatRupiah(tracking.subtotal) }}</span>
          </div>
          <div v-if="tracking.discount" class="flex justify-between text-[var(--color-ink-soft)]">
            <span>Diskon</span><span class="font-mono">-{{ formatRupiah(tracking.discount) }}</span>
          </div>
          <div v-if="tracking.tax" class="flex justify-between text-[var(--color-ink-soft)]">
            <span>Pajak</span><span class="font-mono">{{ formatRupiah(tracking.tax) }}</span>
          </div>
          <div class="flex justify-between font-semibold text-base pt-1.5 border-t border-[var(--color-line)] mt-1.5">
            <span>Total</span><span class="font-mono text-[var(--color-soap-deep)]">{{ formatRupiah(tracking.grand_total) }}</span>
          </div>
        </div>
      </div>
    </div>

    <p class="text-center mt-6 text-xs text-[var(--color-ink-soft)]">
      <NuxtLink to="/track" class="text-[var(--color-soap-deep)] font-medium underline underline-offset-2">Lacak kode lain</NuxtLink>
    </p>
  </div>
</template>
