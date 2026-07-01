<script setup lang="ts">
import type { Customer, Order, Paginated } from '~/types'

definePageMeta({ layout: 'default' })

const route = useRoute()
const api = useApi()

const customer = ref<Customer | null>(null)
const orders = ref<Order[]>([])
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  try {
    // Pastikan route.params.id sudah mengandung ID pelanggan yang benar
    const [c, o] = await Promise.all([
      api.get<Customer>(`/customers/${route.params.id}`),
      api.get<Paginated<Order>>('/orders', { customer_id: route.params.id, include_cancelled: true, page_size: 50 }),
    ])
    customer.value = c
    orders.value = o.data
  } catch (e: any) {
    error.value = e.message
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div v-if="loading" class="text-sm text-[var(--color-ink-soft)]">Memuat data pelanggan…</div>
  <div v-else-if="error" class="text-sm text-[var(--color-stamp)]">{{ error }}</div>

  <div v-else-if="customer" class="max-w-2xl">
    <NuxtLink to="/customers" class="text-xs font-medium text-[var(--color-ink-soft)] hover:text-[var(--color-soap-deep)]">← Kembali ke daftar pelanggan</NuxtLink>

    <div class="mt-3 mb-6">
      <h1 class="font-display text-3xl text-[var(--color-ink)]">{{ customer.name }}</h1>
      <p class="text-sm text-[var(--color-ink-soft)] font-mono mt-1">{{ customer.phone }}</p>
    </div>

    <h2 class="text-sm font-semibold mb-3">Riwayat Pesanan</h2>
    <div v-if="!orders.length" class="border border-dashed border-[var(--color-line)] rounded-xl py-10 text-center text-sm text-[var(--color-ink-soft)]">
      Belum ada pesanan dari pelanggan ini.
    </div>

    <div v-else class="space-y-3">
      <NuxtLink
        v-for="order in orders"
        :key="order.order_id"
        :to="`/orders/${order.order_id}`"
        class="block bg-white border border-[var(--color-line)] rounded-lg px-5 py-3.5 hover:border-[var(--color-soap)] transition-colors"
        :class="{ 'opacity-60': order.is_cancelled }"
      >
        <div class="flex items-center justify-between">
          <div>
            <p class="font-mono text-xs text-[var(--color-soap-deep)]">{{ order.tracking_code }}</p>
            <p class="text-xs text-[var(--color-ink-soft)] mt-0.5">{{ formatDateShort(order.order_date) }}</p>
          </div>
          <span class="font-mono text-sm font-semibold">{{ formatRupiah(order.grand_total) }}</span>
        </div>
      </NuxtLink>
    </div>
  </div>
</template>
