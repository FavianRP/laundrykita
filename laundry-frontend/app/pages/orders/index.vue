<script setup lang="ts">
import type {
    Order,
    Paginated,
    ProductionStatus,
    PaymentStatus,
} from "~/types";
import { PRODUCTION_FLOW } from "~/types";

definePageMeta({ layout: "default" });

const api = useApi();
const orders = ref<Order[]>([]);
const loading = ref(true);
const error = ref("");

const page = ref(1);
const totalPages = ref(1);
const statusFilter = ref<ProductionStatus | "">("");
const paymentFilter = ref<PaymentStatus | "">("");
const includeCancelled = ref(false);

async function load() {
    loading.value = true;
    error.value = "";
    try {
        const params: Record<string, any> = {
            page: page.value,
            page_size: 20,
            include_cancelled: includeCancelled.value,
        };
        if (statusFilter.value) params.current_status = statusFilter.value;
        if (paymentFilter.value) params.payment_status = paymentFilter.value;
        const res = await api.get<Paginated<Order>>("/orders", params);
        orders.value = res.data;
        totalPages.value = res.pagination.total_pages;
    } catch (e: any) {
        error.value = e.message;
    } finally {
        loading.value = false;
    }
}

watch([statusFilter, paymentFilter, includeCancelled], () => {
    page.value = 1;
    load();
});
watch(page, load);
onMounted(load);
</script>

<template>
    <div class="px-4 sm:px-0">
        <div
            class="flex flex-col sm:flex-row sm:items-end justify-between gap-4 mb-6"
        >
            <div>
                <p
                    class="font-mono text-xs uppercase tracking-widest text-[var(--color-ink-soft)] mb-1"
                >
                    Buku Pesanan
                </p>
                <h1 class="font-display text-3xl text-[var(--color-ink)]">
                    Pesanan
                </h1>
            </div>
            <NuxtLink
                to="/orders/new"
                class="w-full sm:w-auto text-center rounded-md bg-[var(--color-soap)] text-white text-sm font-medium px-4 py-2.5 hover:bg-[var(--color-soap-deep)] transition-colors"
            >
                + Pesanan Baru
            </NuxtLink>
        </div>

        <div class="flex flex-col sm:flex-row flex-wrap gap-3 mb-5">
            <select
                v-model="statusFilter"
                class="w-full sm:w-auto rounded-md border border-[var(--color-line)] bg-white px-3 py-2 text-sm"
            >
                <option value="">Semua status produksi</option>
                <option v-for="s in PRODUCTION_FLOW" :key="s" :value="s">
                    {{ s }}
                </option>
            </select>
            <select
                v-model="paymentFilter"
                class="w-full sm:w-auto rounded-md border border-[var(--color-line)] bg-white px-3 py-2 text-sm"
            >
                <option value="">Semua status bayar</option>
                <option value="Belum Lunas">Belum Lunas</option>
                <option value="Lunas">Lunas</option>
            </select>
            <label
                class="flex items-center gap-2 text-sm text-[var(--color-ink-soft)] px-1 py-1"
            >
                <input
                    v-model="includeCancelled"
                    type="checkbox"
                    class="rounded"
                />
                Tampilkan yang dibatalkan
            </label>
        </div>

        <p v-if="error" class="text-sm text-[var(--color-stamp)] mb-4">
            {{ error }}
        </p>
        <div v-if="loading" class="text-sm text-[var(--color-ink-soft)]">
            Memuat pesanan…
        </div>

        <div
            v-else-if="!orders.length"
            class="border border-dashed border-[var(--color-line)] rounded-xl py-16 text-center"
        >
            <p class="font-display text-lg text-[var(--color-ink-soft)]">
                Belum ada pesanan di sini
            </p>
            <p class="text-sm text-[var(--color-ink-soft)] mt-1">
                Buat pesanan baru untuk memulai antrean.
            </p>
        </div>

        <div v-else class="space-y-4">
            <NuxtLink
                v-for="order in orders"
                :key="order.id"
                :to="`/orders/${order.order_id}`"
                class="block bg-white border border-[var(--color-line)] rounded-lg px-4 py-4 sm:px-5 hover:border-[var(--color-soap)] transition-colors"
                :class="{ 'opacity-60': order.is_cancelled }"
            >
                <div
                    class="flex flex-col sm:flex-row sm:items-center justify-between gap-3"
                >
                    <div>
                        <p
                            class="font-mono text-xs text-[var(--color-soap-deep)] tracking-wide"
                        >
                            {{ order.tracking_code }}
                        </p>
                        <p class="font-medium text-[var(--color-ink)]">
                            {{ order.customer_name }}
                        </p>
                    </div>

                    <div
                        class="flex items-center justify-between sm:justify-end gap-3 w-full sm:w-auto"
                    >
                        <span
                            class="px-2 py-1 rounded text-[11px] font-mono uppercase"
                            :class="
                                order.payment_status === 'Lunas'
                                    ? 'bg-[var(--color-go-light)] text-[var(--color-go)]'
                                    : 'bg-[var(--color-pending-light)] text-[var(--color-pending)]'
                            "
                            >{{ order.payment_status }}</span
                        >
                        <span class="font-mono text-sm font-semibold">{{
                            formatRupiah(order.grand_total)
                        }}</span>
                    </div>
                </div>

                <div
                    class="mt-4 overflow-x-auto pb-1 -mx-2 px-2 sm:mx-0 sm:px-0"
                >
                    <div class="min-w-max sm:min-w-0">
                        <StatusStepper
                            :status="order.current_status"
                            :cancelled="order.is_cancelled"
                        />
                    </div>
                </div>
            </NuxtLink>
        </div>

        <div
            v-if="totalPages > 1"
            class="flex flex-wrap items-center justify-center gap-3 mt-8"
        >
            <button
                class="text-sm px-3 py-1.5 rounded border border-[var(--color-line)] disabled:opacity-40"
                :disabled="page <= 1"
                @click="page--"
            >
                ← Sebelumnya
            </button>
            <span class="text-xs font-mono text-[var(--color-ink-soft)]"
                >{{ page }} / {{ totalPages }}</span
            >
            <button
                class="text-sm px-3 py-1.5 rounded border border-[var(--color-line)] disabled:opacity-40"
                :disabled="page >= totalPages"
                @click="page++"
            >
                Berikutnya →
            </button>
        </div>
    </div>
</template>
