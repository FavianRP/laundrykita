<script setup lang="ts">
import { PRODUCTION_FLOW, SERVICE_TYPES, type Order, type EditRequest, type Paginated, type ServiceType } from '~/types'

definePageMeta({ layout: 'default' })

const route = useRoute()
const api = useApi()

const order = ref<Order | null>(null)
const pendingRequests = ref<EditRequest[]>([])
const loading = ref(true)
const error = ref('')
const statusUpdating = ref(false)

async function load() {
  loading.value = true
  error.value = ''
  try {
    // Pastikan menggunakan route.params.id yang benar
    const [o, reqs] = await Promise.all([
      api.get<Order>(`/orders/${route.params.id}`),
      api.get<Paginated<EditRequest>>('/edit-requests', { order_id: route.params.id, approval_status: 'Pending' }),
    ])
    order.value = o
    pendingRequests.value = reqs.data
  } catch (e: any) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
onMounted(load)

const currentIndex = computed(() => order.value ? PRODUCTION_FLOW.indexOf(order.value.current_status) : -1)
const nextStatus = computed(() => currentIndex.value >= 0 && currentIndex.value < PRODUCTION_FLOW.length - 1 ? PRODUCTION_FLOW[currentIndex.value + 1] : null)

async function advanceStatus() {
  // PERBAIKAN: Gunakan order.value.order_id, bukan order.value.id
  if (!order.value || !nextStatus.value) return
  statusUpdating.value = true
  error.value = ''
  try {
    order.value = await api.patch<Order>(`/orders/${order.value.order_id}/status`, { current_status: nextStatus.value })
  } catch (e: any) {
    error.value = e.message
  } finally {
    statusUpdating.value = false
  }
}

// --- Edit request form state ---
const showEditForm = ref(false)
const editReason = ref('')
interface DraftEditItem { order_item_id: number; service_type: ServiceType; new_weight_quantity: number; new_price_per_unit: number }
const editItems = ref<DraftEditItem[]>([])
const submittingEdit = ref(false)
const editError = ref('')

function openEditForm() {
  if (!order.value?.items) return
  editItems.value = order.value.items.map(it => ({
    order_item_id: it.id!,
    service_type: it.service_type,
    new_weight_quantity: it.weight_quantity,
    new_price_per_unit: it.price_per_unit,
  }))
  editReason.value = ''
  editError.value = ''
  showEditForm.value = true
}

async function submitEditRequest() {
  if (!order.value) return
  if (!editReason.value.trim()) { editError.value = 'Alasan perbaikan wajib diisi.'; return }
  submittingEdit.value = true
  editError.value = ''
  try {
    // PERBAIKAN: Gunakan order.value.order_id
    await api.post('/edit-requests', {
      order_id: order.value.order_id,
      reason: editReason.value,
      items: editItems.value,
    })
    showEditForm.value = false
    await load()
  } catch (e: any) {
    editError.value = e.message
  } finally {
    submittingEdit.value = false
  }
}

// --- Cancel request ---
const showCancelForm = ref(false)
const cancelReason = ref('')
const submittingCancel = ref(false)
const cancelError = ref('')

async function submitCancelRequest() {
  if (!order.value) return
  if (!cancelReason.value.trim()) { cancelError.value = 'Alasan pembatalan wajib diisi.'; return }
  submittingCancel.value = true
  cancelError.value = ''
  try {
    // PERBAIKAN: Gunakan order.value.order_id
    await api.post('/edit-requests/cancel', { order_id: order.value.order_id, reason: cancelReason.value })
    showCancelForm.value = false
    await load()
  } catch (e: any) {
    cancelError.value = e.message
  } finally {
    submittingCancel.value = false
  }
}

const hasPendingRequest = computed(() => pendingRequests.value.length > 0)
</script>

<template>
  <div v-if="loading" class="text-sm text-[var(--color-ink-soft)]">Memuat detail pesanan…</div>
  <div v-else-if="error && !order" class="text-sm text-[var(--color-stamp)]">{{ error }}</div>

  <div v-else-if="order" class="max-w-3xl">
    <NuxtLink to="/orders" class="text-xs font-medium text-[var(--color-ink-soft)] hover:text-[var(--color-soap-deep)]">← Kembali ke daftar pesanan</NuxtLink>

    <div class="flex flex-wrap items-start justify-between gap-4 mt-3 mb-6">
      <div>
        <p class="font-mono text-xs uppercase tracking-widest text-[var(--color-soap-deep)] mb-1">{{ order.tracking_code }}</p>
        <h1 class="font-display text-3xl text-[var(--color-ink)]">{{ order.customer_name }}</h1>
        <p class="text-sm text-[var(--color-ink-soft)] mt-1">{{ order.customer_phone }} · {{ formatDate(order.order_date) }}</p>
      </div>
      <span
        class="px-2.5 py-1 rounded text-[11px] font-mono uppercase h-fit"
        :class="order.payment_status === 'Lunas' ? 'bg-[var(--color-go-light)] text-[var(--color-go)]' : 'bg-[var(--color-pending-light)] text-[var(--color-pending)]'"
      >{{ order.payment_status }}</span>
    </div>

    <div v-if="order.is_cancelled" class="mb-6">
      <span class="stamp inline-block px-4 py-2 text-sm font-mono uppercase text-[var(--color-stamp)]">Pesanan Dibatalkan</span>
    </div>

    <div v-if="hasPendingRequest" class="mb-6 rounded-lg bg-[var(--color-pending-light)] px-4 py-3 flex items-center justify-between flex-wrap gap-2">
      <p class="text-sm text-[var(--color-pending)] font-medium">Menunggu Persetujuan Owner</p>
      <NuxtLink :to="`/edit-requests/${pendingRequests[0].id}`" class="text-xs font-medium text-[var(--color-pending)] underline underline-offset-2">Lihat pengajuan</NuxtLink>
    </div>

    <div v-if="!order.is_cancelled" class="bg-white border border-[var(--color-line)] rounded-xl p-5 mb-5">
      <h2 class="text-sm font-semibold mb-4">Status Produksi</h2>
      <StatusStepper :status="order.current_status" />
      <button
        v-if="nextStatus"
        class="mt-4 rounded-md bg-[var(--color-soap)] text-white text-sm font-medium px-4 py-2 hover:bg-[var(--color-soap-deep)] transition-colors disabled:opacity-60"
        :disabled="statusUpdating"
        @click="advanceStatus"
      >
        {{ statusUpdating ? 'Memperbarui…' : `Tandai sebagai "${nextStatus}"` }}
      </button>
      <p v-else class="mt-4 text-sm text-[var(--color-go)] font-medium">Pesanan telah selesai.</p>
    </div>

    <p v-if="error" class="text-sm text-[var(--color-stamp)]">{{ error }}</p>
  </div>
</template>
