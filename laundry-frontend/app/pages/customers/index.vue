<script setup lang="ts">
import type { Customer, Paginated } from '~/types'

definePageMeta({ layout: 'default' })

const api = useApi()
const customers = ref<Customer[]>([])
const loading = ref(true)
const error = ref('')
const search = ref('')
const page = ref(1)
const totalPages = ref(1)

async function load() {
  loading.value = true
  error.value = ''
  try {
    // Memanggil API pelanggan
    const res = await api.get<Paginated<Customer>>('/customers', {
      search: search.value || undefined,
      page: page.value,
      page_size: 20
    })
    customers.value = res.data
    totalPages.value = res.pagination.total_pages
  } catch (e: any) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

let debounceTimer: ReturnType<typeof setTimeout>
watch(search, () => {
  clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => { page.value = 1; load() }, 350)
})
watch(page, load)
onMounted(load)
</script>

<template>
  <div>
    <p class="font-mono text-xs uppercase tracking-widest text-[var(--color-ink-soft)] mb-1">Buku Alamat</p>
    <h1 class="font-display text-3xl text-[var(--color-ink)] mb-6">Pelanggan</h1>

    <input
      v-model="search"
      type="text"
      placeholder="Cari nama atau nomor HP…"
      class="w-full max-w-sm rounded-md border border-[var(--color-line)] bg-white px-3 py-2.5 text-sm mb-5"
    >

    <p v-if="error" class="text-sm text-[var(--color-stamp)] mb-4">{{ error }}</p>
    <div v-if="loading" class="text-sm text-[var(--color-ink-soft)]">Memuat pelanggan…</div>

    <div v-else-if="!customers.length" class="border border-dashed border-[var(--color-line)] rounded-xl py-16 text-center">
      <p class="font-display text-lg text-[var(--color-ink-soft)]">Tidak ada pelanggan ditemukan</p>
    </div>

    <div v-else class="grid sm:grid-cols-2 gap-3">
      <NuxtLink
        v-for="c in customers"
        :key="c.customer_id"
        :to="`/customers/${c.customer_id}`"
        class="bg-white border border-[var(--color-line)] rounded-lg px-5 py-4 hover:border-[var(--color-soap)] transition-colors"
      >
        <p class="font-medium text-[var(--color-ink)]">{{ c.name }}</p>
        <p class="text-sm text-[var(--color-ink-soft)] font-mono mt-0.5">{{ c.phone }}</p>
      </NuxtLink>
    </div>
    <div v-if="totalPages > 1" class="flex items-center justify-center gap-3 mt-6">
      <button class="text-sm px-3 py-1.5 rounded border border-[var(--color-line)] disabled:opacity-40" :disabled="page <= 1" @click="page--">← Sebelumnya</button>
      <span class="text-xs font-mono text-[var(--color-ink-soft)]">{{ page }} / {{ totalPages }}</span>
      <button class="text-sm px-3 py-1.5 rounded border border-[var(--color-line)] disabled:opacity-40" :disabled="page >= totalPages" @click="page++">Berikutnya →</button>
    </div>
  </div>
</template>
