<script setup lang="ts">
import type { FinancialAnalytics, ServiceBreakdownItem } from '~/types'

definePageMeta({ layout: 'default' })

const api = useApi()

function defaultFrom() {
  const d = new Date()
  d.setDate(d.getDate() - 30)
  return d.toISOString().slice(0, 10)
}
function defaultTo() {
  return new Date().toISOString().slice(0, 10)
}

const dateFrom = ref(defaultFrom())
const dateTo = ref(defaultTo())
const groupBy = ref<'day' | 'week' | 'month'>('day')

const financial = ref<FinancialAnalytics | null>(null)
const breakdown = ref<ServiceBreakdownItem[]>([])
const loading = ref(true)
const error = ref('')

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [f, b] = await Promise.all([
      api.get<FinancialAnalytics>('/analytics/financial', { date_from: dateFrom.value, date_to: dateTo.value, group_by: groupBy.value }),
      api.get<ServiceBreakdownItem[] | { data: ServiceBreakdownItem[] }>('/analytics/service-breakdown', { date_from: dateFrom.value, date_to: dateTo.value }),
    ])
    financial.value = f
    breakdown.value = Array.isArray(b) ? b : (b as any).data || []
  } catch (e: any) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
onMounted(load)

const maxRevenue = computed(() => Math.max(1, ...(financial.value?.summaries.map(s => s.revenue) || [1])))
const maxBreakdown = computed(() => Math.max(1, ...breakdown.value.map(b => b.revenue)))
</script>

<template>
  <div>
    <p class="font-mono text-xs uppercase tracking-widest text-[var(--color-ink-soft)] mb-1">Owner</p>
    <h1 class="font-display text-3xl text-[var(--color-ink)] mb-6">Laporan Keuangan</h1>

    <form class="flex flex-wrap items-end gap-3 mb-6" @submit.prevent="load">
      <div>
        <label class="block text-[11px] text-[var(--color-ink-soft)] mb-1">Dari tanggal</label>
        <input v-model="dateFrom" type="date" class="rounded-md border border-[var(--color-line)] px-3 py-2 text-sm">
      </div>
      <div>
        <label class="block text-[11px] text-[var(--color-ink-soft)] mb-1">Sampai tanggal</label>
        <input v-model="dateTo" type="date" class="rounded-md border border-[var(--color-line)] px-3 py-2 text-sm">
      </div>
      <div>
        <label class="block text-[11px] text-[var(--color-ink-soft)] mb-1">Kelompokkan</label>
        <select v-model="groupBy" class="rounded-md border border-[var(--color-line)] px-3 py-2 text-sm">
          <option value="day">Harian</option>
          <option value="week">Mingguan</option>
          <option value="month">Bulanan</option>
        </select>
      </div>
      <button type="submit" class="rounded-md bg-[var(--color-soap)] text-white text-sm font-medium px-4 py-2.5 hover:bg-[var(--color-soap-deep)]">Terapkan</button>
    </form>

    <p v-if="error" class="text-sm text-[var(--color-stamp)] mb-4">{{ error }}</p>
    <div v-if="loading" class="text-sm text-[var(--color-ink-soft)]">Memuat laporan…</div>

    <template v-else-if="financial">
      <div class="grid sm:grid-cols-2 gap-4 mb-6">
        <div class="bg-white border border-[var(--color-line)] rounded-xl p-5">
          <p class="text-xs text-[var(--color-ink-soft)] mb-1">Total Pendapatan</p>
          <p class="font-display text-2xl text-[var(--color-soap-deep)]">{{ formatRupiah(financial.overall.revenue) }}</p>
        </div>
        <div class="bg-white border border-[var(--color-line)] rounded-xl p-5">
          <p class="text-xs text-[var(--color-ink-soft)] mb-1">Jumlah Pesanan</p>
          <p class="font-display text-2xl text-[var(--color-ink)]">{{ financial.overall.order_count }}</p>
        </div>
      </div>

      <div class="bg-white border border-[var(--color-line)] rounded-xl p-5 mb-6">
        <h2 class="text-sm font-semibold mb-4">Pendapatan per Periode</h2>
        <div v-if="!financial.summaries.length" class="text-sm text-[var(--color-ink-soft)]">Tidak ada data pada rentang ini.</div>
        <div v-else class="space-y-2.5">
          <div v-for="s in financial.summaries" :key="s.period" class="flex items-center gap-3">
            <span class="text-xs font-mono text-[var(--color-ink-soft)] w-24 shrink-0">{{ s.period }}</span>
            <div class="flex-1 h-5 bg-[var(--color-paper-dim)] rounded overflow-hidden">
              <div class="h-full bg-[var(--color-soap)] rounded" :style="{ width: `${(s.revenue / maxRevenue) * 100}%` }" />
            </div>
            <span class="text-xs font-mono w-28 text-right shrink-0">{{ formatRupiah(s.revenue) }}</span>
          </div>
        </div>
      </div>

      <div class="bg-white border border-[var(--color-line)] rounded-xl p-5">
        <h2 class="text-sm font-semibold mb-4">Pendapatan per Tipe Layanan</h2>
        <div v-if="!breakdown.length" class="text-sm text-[var(--color-ink-soft)]">Tidak ada data pada rentang ini.</div>
        <div v-else class="space-y-2.5">
          <div v-for="b in breakdown" :key="b.service_type" class="flex items-center gap-3">
            <span class="text-xs font-medium w-20 shrink-0">{{ b.service_type }}</span>
            <div class="flex-1 h-5 bg-[var(--color-paper-dim)] rounded overflow-hidden">
              <div class="h-full bg-[var(--color-stamp)] rounded" :style="{ width: `${(b.revenue / maxBreakdown) * 100}%` }" />
            </div>
            <span class="text-xs font-mono w-28 text-right shrink-0">{{ formatRupiah(b.revenue) }}</span>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
