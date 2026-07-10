<script setup lang="ts">
import {
    PRODUCTION_FLOW,
    SERVICE_TYPES,
    type Order,
    type EditRequest,
    type Paginated,
    type ServiceType,
} from "~/types";

definePageMeta({ layout: "default" });

const route = useRoute();
const api = useApi();

const order = ref<Order | null>(null);
const pendingRequests = ref<EditRequest[]>([]);
const loading = ref(true);
const error = ref("");
const statusUpdating = ref(false);

async function load() {
    loading.value = true;
    error.value = "";
    try {
        const [o, reqs] = await Promise.all([
            api.get<Order>(`/orders/${route.params.id}`),
            api.get<Paginated<EditRequest>>("/edit-requests", {
                order_id: route.params.id,
                approval_status: "Pending",
            }),
        ]);
        order.value = o;
        pendingRequests.value = reqs.data;
    } catch (e: any) {
        error.value = e.message;
    } finally {
        loading.value = false;
    }
}
onMounted(load);

const currentIndex = computed(() =>
    order.value ? PRODUCTION_FLOW.indexOf(order.value.current_status) : -1,
);
const nextStatus = computed(() =>
    currentIndex.value >= 0 && currentIndex.value < PRODUCTION_FLOW.length - 1
        ? PRODUCTION_FLOW[currentIndex.value + 1]
        : null,
);

async function advanceStatus() {
    if (!order.value || !nextStatus.value) return;
    statusUpdating.value = true;
    error.value = "";
    try {
        order.value = await api.patch<Order>(
            `/orders/${order.value.order_id}/status`,
            { current_status: nextStatus.value },
        );
    } catch (e: any) {
        error.value = e.message;
    } finally {
        statusUpdating.value = false;
    }
}

const paymentUpdating = ref(false);

async function markAsPaid() {
    if (!order.value) return;
    paymentUpdating.value = true;
    error.value = "";
    try {
        // Memanggil endpoint update pembayaran
        await api.patch(`/orders/${order.value.order_id}/payment`, {
            payment_status: "Lunas",
        });

        // Update state lokal agar UI langsung berubah tanpa perlu reload halaman
        order.value.payment_status = "Lunas";
    } catch (e: any) {
        error.value = e.message;
    } finally {
        paymentUpdating.value = false;
    }
}

// --- Edit request form state ---
const showEditForm = ref(false);
const editReason = ref("");
interface DraftEditItem {
    order_item_id: number;
    service_type: ServiceType;
    new_weight_quantity: number;
    new_price_per_unit: number;
}
const editItems = ref<DraftEditItem[]>([]);
const submittingEdit = ref(false);
const editError = ref("");

function openEditForm() {
    if (!order.value?.items) return;
    editItems.value = order.value.items.map((it) => ({
        order_item_id: Number(it.item_id),
        service_type: it.service_type,
        new_weight_quantity: Number(it.weight_quantity),
        new_price_per_unit: Number(it.price_per_unit),
    }));
    editReason.value = "";
    editError.value = "";
    showEditForm.value = true;
}

async function submitEditRequest() {
    if (!order.value) return;
    if (!editReason.value.trim()) {
        editError.value = "Alasan perbaikan wajib diisi.";
        return;
    }
    submittingEdit.value = true;
    editError.value = "";
    try {
        await api.post("/edit-requests", {
            order_id: order.value.order_id,
            reason: editReason.value,
            items: editItems.value,
        });
        showEditForm.value = false;
        await load();
    } catch (e: any) {
        editError.value = e.message;
    } finally {
        submittingEdit.value = false;
    }
}

// --- Cancel request ---
const showCancelForm = ref(false);
const cancelReason = ref("");
const submittingCancel = ref(false);
const cancelError = ref("");

async function submitCancelRequest() {
    if (!order.value) return;

    // Tambahkan validasi panjang karakter di sini
    if (cancelReason.value.trim().length < 10) {
        cancelError.value = "Alasan pembatalan minimal 10 karakter.";
        return;
    }

    submittingCancel.value = true;
    cancelError.value = "";
    try {
        await api.post("/edit-requests/cancel", {
            order_id: order.value.order_id,
            reason: cancelReason.value,
        });
        showCancelForm.value = false;
        await load();
    } catch (e: any) {
        cancelError.value = e.message;
    } finally {
        submittingCancel.value = false;
    }
}

const hasPendingRequest = computed(() => pendingRequests.value.length > 0);
</script>

<template>
    <div class="px-4 sm:px-0">
        <div v-if="loading" class="text-sm text-[var(--color-ink-soft)]">
            Memuat detail pesanan…
        </div>
        <div
            v-else-if="error && !order"
            class="text-sm text-[var(--color-stamp)]"
        >
            {{ error }}
        </div>

        <div v-else-if="order" class="max-w-3xl pb-20">
            <NuxtLink
                to="/orders"
                class="text-xs font-medium text-[var(--color-ink-soft)] hover:text-[var(--color-soap-deep)] inline-block mb-2"
                >← Kembali ke daftar pesanan</NuxtLink
            >

            <div
                class="flex flex-col sm:flex-row sm:items-start justify-between gap-4 mt-3 mb-6"
            >
                <div>
                    <p
                        class="font-mono text-xs uppercase tracking-widest text-[var(--color-soap-deep)] mb-1"
                    >
                        {{ order.tracking_code }}
                    </p>
                    <h1 class="font-display text-3xl text-[var(--color-ink)]">
                        {{ order.customer_name }}
                    </h1>
                    <p class="text-sm text-[var(--color-ink-soft)] mt-1">
                        {{ order.customer_phone }} ·
                        {{ formatDate(order.order_date) }}
                    </p>
                </div>

                <div class="flex flex-wrap items-center gap-2 h-fit">
                    <span
                        class="px-2.5 py-1 rounded text-[11px] font-mono uppercase"
                        :class="
                            order.payment_status === 'Lunas'
                                ? 'bg-[var(--color-go-light)] text-[var(--color-go)]'
                                : 'bg-[var(--color-pending-light)] text-[var(--color-pending)]'
                        "
                    >
                        {{ order.payment_status }}
                    </span>

                    <button
                        v-if="
                            !order.is_cancelled &&
                            order.payment_status === 'Belum Lunas'
                        "
                        @click="markAsPaid"
                        :disabled="paymentUpdating"
                        class="px-2.5 py-1 rounded text-[11px] font-medium border border-[var(--color-line)] bg-white hover:border-[var(--color-go)] hover:text-[var(--color-go)] transition-colors disabled:opacity-50"
                    >
                        {{
                            paymentUpdating ? "Memproses..." : "Tandai Lunas ✓"
                        }}
                    </button>
                </div>
            </div>

            <div v-if="order.is_cancelled" class="mb-6">
                <span
                    class="stamp inline-block px-4 py-2 text-sm font-mono uppercase text-[var(--color-stamp)] border-2 border-[var(--color-stamp)] rounded"
                >
                    Pesanan Dibatalkan
                </span>
            </div>

            <div
                v-if="hasPendingRequest"
                class="mb-6 rounded-lg bg-[var(--color-pending-light)] px-4 py-3 flex flex-col sm:flex-row sm:items-center justify-between gap-2"
            >
                <p class="text-sm text-[var(--color-pending)] font-medium">
                    Menunggu Persetujuan Owner
                </p>
                <NuxtLink
                    :to="`/edit-requests/${pendingRequests[0].request_id}`"
                    class="text-xs font-medium text-[var(--color-pending)] underline underline-offset-2"
                    >Lihat pengajuan</NuxtLink
                >
            </div>

            <div
                v-if="!order.is_cancelled"
                class="bg-white border border-[var(--color-line)] rounded-xl p-4 sm:p-5 mb-5"
            >
                <h2 class="text-sm font-semibold mb-4">Status Produksi</h2>

                <div class="overflow-x-auto pb-2 -mx-2 px-2 sm:mx-0 sm:px-0">
                    <div class="min-w-max sm:min-w-0">
                        <StatusStepper :status="order.current_status" />
                    </div>
                </div>

                <button
                    v-if="nextStatus"
                    class="w-full sm:w-auto mt-4 rounded-md bg-[var(--color-soap)] text-white text-sm font-medium px-4 py-2 hover:bg-[var(--color-soap-deep)] transition-colors disabled:opacity-60"
                    :disabled="statusUpdating"
                    @click="advanceStatus"
                >
                    {{
                        statusUpdating
                            ? "Memperbarui…"
                            : `Tandai sebagai "${nextStatus}"`
                    }}
                </button>
                <p
                    v-else
                    class="mt-4 text-sm text-[var(--color-go)] font-medium"
                >
                    Pesanan telah selesai.
                </p>
            </div>

            <div
                v-if="!order.is_cancelled && !hasPendingRequest"
                class="flex flex-col sm:flex-row flex-wrap gap-3 mt-6"
            >
                <button
                    @click="openEditForm"
                    class="w-full sm:w-auto text-sm px-4 py-2.5 sm:py-2 rounded-md border border-[var(--color-line)] bg-white text-[var(--color-ink)] hover:border-[var(--color-soap)] transition-colors text-center"
                >
                    Ajukan Perbaikan Data
                </button>
                <button
                    @click="showCancelForm = true"
                    class="w-full sm:w-auto text-sm px-4 py-2.5 sm:py-2 rounded-md border border-[var(--color-stamp)] text-[var(--color-stamp)] hover:bg-[var(--color-stamp)] hover:text-white transition-colors text-center"
                >
                    Ajukan Pembatalan
                </button>
            </div>

            <p v-if="error" class="text-sm text-[var(--color-stamp)] mt-4">
                {{ error }}
            </p>

            <div
                v-if="showEditForm"
                class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
            >
                <div
                    class="bg-white rounded-xl shadow-xl w-full max-w-lg p-5 sm:p-6 overflow-y-auto max-h-[90vh]"
                >
                    <h3
                        class="font-display text-xl text-[var(--color-ink)] mb-4"
                    >
                        Ajukan Perbaikan Data
                    </h3>

                    <div
                        v-for="(item, idx) in editItems"
                        :key="item.order_item_id"
                        class="mb-4 p-4 border border-[var(--color-line)] rounded-lg"
                    >
                        <p class="text-xs font-mono mb-2">
                            Item #{{ idx + 1 }}
                        </p>
                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                            <div>
                                <label
                                    class="block text-xs text-[var(--color-ink-soft)] mb-1"
                                    >Tipe Layanan</label
                                >
                                <select
                                    v-model="item.service_type"
                                    class="w-full text-sm border border-[var(--color-line)] rounded p-2"
                                >
                                    <option
                                        v-for="t in SERVICE_TYPES"
                                        :key="t"
                                        :value="t"
                                    >
                                        {{ t }}
                                    </option>
                                </select>
                            </div>
                            <div>
                                <label
                                    class="block text-xs text-[var(--color-ink-soft)] mb-1"
                                    >Berat/Kuantitas</label
                                >
                                <input
                                    v-model.number="item.new_weight_quantity"
                                    type="number"
                                    step="0.1"
                                    class="w-full text-sm border border-[var(--color-line)] rounded p-2"
                                />
                            </div>
                            <div class="sm:col-span-2">
                                <label
                                    class="block text-xs text-[var(--color-ink-soft)] mb-1"
                                    >Harga Satuan (Rp)</label
                                >
                                <input
                                    v-model.number="item.new_price_per_unit"
                                    type="number"
                                    class="w-full text-sm border border-[var(--color-line)] rounded p-2"
                                />
                            </div>
                        </div>
                    </div>

                    <div class="mb-5">
                        <label
                            class="block text-xs text-[var(--color-ink-soft)] mb-1"
                        >
                            Alasan Perbaikan
                            <span class="text-[var(--color-stamp)]">*</span>
                        </label>
                        <textarea
                            v-model="editReason"
                            rows="2"
                            class="w-full text-sm border border-[var(--color-line)] rounded p-2"
                            placeholder="Contoh: Salah input berat cucian..."
                        ></textarea>
                    </div>

                    <p
                        v-if="editError"
                        class="text-xs text-[var(--color-stamp)] mb-4"
                    >
                        {{ editError }}
                    </p>

                    <div
                        class="flex flex-col sm:flex-row justify-end gap-2 mt-2"
                    >
                        <button
                            @click="showEditForm = false"
                            class="order-2 sm:order-1 text-sm px-4 py-2 text-[var(--color-ink-soft)] border border-[var(--color-line)] sm:border-transparent rounded-md"
                        >
                            Batal
                        </button>
                        <button
                            @click="submitEditRequest"
                            :disabled="submittingEdit"
                            class="order-1 sm:order-2 text-sm px-4 py-2 bg-[var(--color-soap)] text-white rounded-md disabled:opacity-50"
                        >
                            {{
                                submittingEdit
                                    ? "Mengirim..."
                                    : "Kirim Pengajuan"
                            }}
                        </button>
                    </div>
                </div>
            </div>

            <div
                v-if="showCancelForm"
                class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
            >
                <div
                    class="bg-white rounded-xl shadow-xl w-full max-w-md p-5 sm:p-6"
                >
                    <h3
                        class="font-display text-xl text-[var(--color-ink)] mb-4"
                    >
                        Ajukan Pembatalan Pesanan
                    </h3>

                    <p class="text-sm text-[var(--color-ink-soft)] mb-4">
                        Pesanan tidak akan dihapus, namun statusnya akan diubah
                        menjadi "Dibatalkan" jika disetujui oleh Owner.
                    </p>

                    <div class="mb-5">
                        <label
                            class="block text-xs text-[var(--color-ink-soft)] mb-1"
                        >
                            Alasan Pembatalan
                            <span class="text-[var(--color-stamp)]">*</span>
                        </label>
                        <textarea
                            v-model="cancelReason"
                            rows="3"
                            class="w-full text-sm border border-[var(--color-line)] rounded p-2"
                            placeholder="Contoh: Pelanggan tidak jadi mencuci..."
                        ></textarea>
                    </div>

                    <p
                        v-if="cancelError"
                        class="text-xs text-[var(--color-stamp)] mb-4"
                    >
                        {{ cancelError }}
                    </p>

                    <div
                        class="flex flex-col sm:flex-row justify-end gap-2 mt-2"
                    >
                        <button
                            @click="showCancelForm = false"
                            class="order-2 sm:order-1 text-sm px-4 py-2 text-[var(--color-ink-soft)] border border-[var(--color-line)] sm:border-transparent rounded-md"
                        >
                            Batal
                        </button>
                        <button
                            @click="submitCancelRequest"
                            :disabled="submittingCancel"
                            class="order-1 sm:order-2 text-sm px-4 py-2 bg-[var(--color-stamp)] text-white rounded-md disabled:opacity-50"
                        >
                            {{
                                submittingCancel
                                    ? "Mengirim..."
                                    : "Ajukan Pembatalan"
                            }}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>
