<script setup lang="ts">
import { SERVICE_TYPES, type ServiceType } from '~/types'

definePageMeta({ layout: 'default' })

const api = useApi()
const router = useRouter()

const customerName = ref('')
const customerPhone = ref('')
const discount = ref(0)
const taxRate = ref(0)

interface DraftItem { service_type: ServiceType; weight_quantity: number; price_per_unit: number }
const items = ref<DraftItem[]>([{ service_type: 'Kiloan', weight_quantity: 1, price_per_unit: 0 }])

const submitting = ref(false)
const error = ref('')

function addItem() {
  items.value.push({ service_type: 'Kiloan', weight_quantity: 1, price_per_unit: 0 })
}
function removeItem(i: number) {
  items.value.splice(i, 1)
}

const subtotalPreview = computed(() =>
  items.value.reduce((sum, it) => sum + (Number(it.weight_quantity) || 0) * (Number(it.price_per_unit) || 0), 0),
)
const taxPreview = computed(() => subtotalPreview.value * (Number(taxRate.value) || 0))
const grandTotalPreview = computed(() => Math.max(0, subtotalPreview.value - (Number(discount.value) || 0) + taxPreview.value))

async function submit() {
  error.value = ''

  if (!customerName.value.trim() || !customerPhone.value.trim()) {
    error.value = 'Nama dan nomor HP pelanggan wajib diisi.'
    return
  }
  if (customerPhone.value.length < 8) {
    error.value = 'Nomor HP minimal 8 digit.'
    return
  }
  if (!items.value.length) {
    error.value = 'Tambahkan minimal satu item layanan.'
    return
  }

  submitting.value = true

  try {
    const payload = {
      customer_name: customerName.value,
      customer_phone: customerPhone.value,
      items: items.value,
      discount: Number(discount.value) || 0,
      tax_rate: Number(taxRate.value) || 0,
    }

    // PERBAIKAN: Sesuaikan tipe balikan dengan respons aslinya yaitu order_id
    const order = await api.post<{ order_id: number; tracking_code: string }>('/orders', payload)

    // PERBAIKAN: Gunakan order_id untuk pindah halaman
    await router.push(`/orders/${order.order_id}`)

  } catch (e: any) {
    console.error(e)
    error.value = e?.data?.detail || e?.message || 'Terjadi kesalahan saat menyimpan pesanan.'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl">
    <p class="font-mono text-xs uppercase tracking-widest text-[var(--color-ink-soft)] mb-1">Kasir</p>
    <h1 class="font-display text-3xl text-[var(--color-ink)] mb-6">Pesanan Baru</h1>

    <form class="space-y-6" @submit.prevent="submit">
      <div class="bg-white border border-[var(--color-line)] rounded-xl p-5">
        <h2 class="text-sm font-semibold mb-4">Data Pelanggan</h2>
        <div class="grid sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-medium text-[var(--color-ink-soft)] mb-1.5">Nama pelanggan</label>
            <input v-model="customerName" type="text" required class="w-full rounded-md border border-[var(--color-line)] px-3 py-2 text-sm">
          </div>
          <div>
            <label class="block text-xs font-medium text-[var(--color-ink-soft)] mb-1.5">Nomor HP</label>
            <input v-model="customerPhone" type="tel" required class="w-full rounded-md border border-[var(--color-line)] px-3 py-2 text-sm">
          </div>
        </div>
        <p class="text-xs text-[var(--color-ink-soft)] mt-2">Pelanggan baru akan otomatis dibuatkan profil berdasarkan nomor HP.</p>
      </div>

      <div class="bg-white border border-[var(--color-line)] rounded-xl p-5">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-sm font-semibold">Item Layanan</h2>
          <button type="button" class="text-xs font-medium text-[var(--color-soap-deep)]" @click="addItem">+ Tambah item</button>
        </div>

        <div v-for="(item, i) in items" :key="i" class="grid grid-cols-12 gap-2 items-end mb-3 pb-3 border-b border-[var(--color-line)] last:border-0 last:mb-0 last:pb-0">
          <div class="col-span-4">
            <label class="block text-[11px] text-[var(--color-ink-soft)] mb-1">Tipe</label>
            <select v-model="item.service_type" class="w-full rounded-md border border-[var(--color-line)] px-2 py-2 text-sm">
              <option v-for="s in SERVICE_TYPES" :key="s" :value="s">{{ s }}</option>
            </select>
          </div>
          <div class="col-span-3">
            <label class="block text-[11px] text-[var(--color-ink-soft)] mb-1">Jumlah / Berat</label>
            <input v-model.number="item.weight_quantity" type="number" min="0" step="0.1" required class="w-full rounded-md border border-[var(--color-line)] px-2 py-2 text-sm">
          </div>
          <div class="col-span-4">
            <label class="block text-[11px] text-[var(--color-ink-soft)] mb-1">Harga / satuan</label>
            <input v-model.number="item.price_per_unit" type="number" min="0" step="500" required class="w-full rounded-md border border-[var(--color-line)] px-2 py-2 text-sm">
          </div>
          <div class="col-span-1 flex justify-end pb-2">
            <button type="button" :disabled="items.length === 1" class="text-[var(--color-stamp)] text-sm disabled:opacity-30" @click="removeItem(i)">✕</button>
          </div>
        </div>
      </div>

      <div class="bg-white border border-[var(--color-line)] rounded-xl p-5">
        <h2 class="text-sm font-semibold mb-4">Diskon &amp; Pajak</h2>
        <div class="grid sm:grid-cols-2 gap-4 mb-5">
          <div>
            <label class="block text-xs font-medium text-[var(--color-ink-soft)] mb-1.5">Diskon (Rp)</label>
            <input v-model.number="discount" type="number" min="0" class="w-full rounded-md border border-[var(--color-line)] px-3 py-2 text-sm">
          </div>
          <div>
            <label class="block text-xs font-medium text-[var(--color-ink-soft)] mb-1.5">Tarif pajak (mis. 0.1 = 10%)</label>
            <input v-model.number="taxRate" type="number" min="0" step="0.01" class="w-full rounded-md border border-[var(--color-line)] px-3 py-2 text-sm">
          </div>
        </div>

        <div class="ticket-edge pb-4 mb-1 space-y-1.5 text-sm">
          <div class="flex justify-between text-[var(--color-ink-soft)]"><span>Subtotal (perkiraan)</span><span class="font-mono">{{ formatRupiah(subtotalPreview) }}</span></div>
          <div class="flex justify-between text-[var(--color-ink-soft)]"><span>Pajak (perkiraan)</span><span class="font-mono">{{ formatRupiah(taxPreview) }}</span></div>
          <div class="flex justify-between font-semibold pt-2"><span>Total (perkiraan)</span><span class="font-mono text-[var(--color-soap-deep)]">{{ formatRupiah(grandTotalPreview) }}</span></div>
        </div>
        <p class="text-[11px] text-[var(--color-ink-soft)] mt-3">Nilai akhir dihitung ulang oleh server saat pesanan disimpan.</p>
      </div>

      <p v-if="error" class="text-sm text-[var(--color-stamp)]">{{ error }}</p>

      <div class="flex gap-3">
        <button
          type="submit"
          :disabled="submitting"
          class="rounded-md bg-[var(--color-soap)] text-white text-sm font-medium px-5 py-2.5 hover:bg-[var(--color-soap-deep)] transition-colors disabled:opacity-60"
        >{{ submitting ? 'Menyimpan…' : 'Simpan Pesanan' }}</button>
        <NuxtLink to="/orders" class="text-sm font-medium text-[var(--color-ink-soft)] px-4 py-2.5">Batal</NuxtLink>
      </div>
    </form>
  </div>
</template>
