<script setup lang="ts">
definePageMeta({ layout: "default" });

const api = useApi();

function defaultFrom() {
    const d = new Date();
    d.setDate(d.getDate() - 30);
    return d.toISOString().slice(0, 10);
}
function defaultTo() {
    return new Date().toISOString().slice(0, 10);
}

const dateFrom = ref(defaultFrom());
const dateTo = ref(defaultTo());
const financial = ref<any>(null);
const breakdown = ref<any[]>([]);
const loading = ref(true);
const error = ref("");

async function load() {
    loading.value = true;
    error.value = "";
    try {
        const [f, b] = await Promise.all([
            api.get<any>("/analytics/financial", {
                date_from: dateFrom.value,
                date_to: dateTo.value,
            }),
            api.get<any>("/analytics/service-breakdown", {
                date_from: dateFrom.value,
                date_to: dateTo.value,
            }),
        ]);

        financial.value = f;
        breakdown.value = b.breakdown || [];
    } catch (e: any) {
        error.value = e.message;
    } finally {
        loading.value = false;
    }
}
onMounted(load);

// Perbaikan: Menggunakan subtotal sebagai basis perhitungan max
const maxRevenue = computed(() =>
    Math.max(
        1,
        ...(financial.value?.summaries.map(
            (s: any) => s.total_revenue || 0,
        ) || [1]),
    ),
);

const maxBreakdown = computed(() =>
    Math.max(1, ...breakdown.value.map((b: any) => b.total_revenue || 0)),
);
</script>

<template>
    <div>
        <h1 class="font-display text-3xl text-[var(--color-ink)] mb-6">
            Laporan Keuangan
        </h1>

        <form
            class="flex flex-wrap items-end gap-3 mb-6"
            @submit.prevent="load"
        >
            <div>
                <label
                    class="block text-[11px] text-[var(--color-ink-soft)] mb-1"
                    >Dari</label
                >
                <input
                    v-model="dateFrom"
                    type="date"
                    class="rounded-md border border-[var(--color-line)] px-3 py-2 text-sm"
                />
            </div>
            <div>
                <label
                    class="block text-[11px] text-[var(--color-ink-soft)] mb-1"
                    >Sampai</label
                >
                <input
                    v-model="dateTo"
                    type="date"
                    class="rounded-md border border-[var(--color-line)] px-3 py-2 text-sm"
                />
            </div>
            <button
                type="submit"
                class="rounded-md bg-[var(--color-soap)] text-white text-sm font-medium px-4 py-2.5"
            >
                Terapkan
            </button>
        </form>

        <div v-if="loading">Memuat laporan…</div>

        <template v-else-if="financial">
            <div class="grid sm:grid-cols-2 gap-4 mb-6">
                <div class="bg-white border p-5 rounded-xl">
                    <p class="text-xs text-[var(--color-ink-soft)]">
                        Total Pendapatan
                    </p>
                    <p class="font-display text-2xl">
                        {{
                            formatRupiah(financial.overall.total_subtotal || 0)
                        }}
                    </p>
                </div>
                <div class="bg-white border p-5 rounded-xl">
                    <p class="text-xs text-[var(--color-ink-soft)]">
                        Jumlah Pesanan
                    </p>
                    <p class="font-display text-2xl">
                        {{ financial.overall.total_orders || 0 }}
                    </p>
                </div>
            </div>

            <div class="bg-white border p-5 rounded-xl mb-6">
                <h2 class="text-sm font-semibold mb-4">
                    Pendapatan per Periode
                </h2>
                <div
                    v-for="s in financial.summaries"
                    :key="s.period_label"
                    class="flex items-center gap-3 mb-2"
                >
                    <span class="text-xs w-24">{{ s.period_label }}</span>
                    <div class="flex-1 h-5 bg-gray-100 rounded overflow-hidden">
                        <div
                            class="h-full bg-[var(--color-soap)]"
                            :style="{
                                /* Ganti s.revenue menjadi s.subtotal */
                                width: `${((s.total_revenue || 0) / maxRevenue) * 100}%`,
                            }"
                        />
                    </div>
                    <span class="text-xs font-mono w-28 text-right">
                        {{ formatRupiah(s.total_revenue || 0) }}
                    </span>
                </div>
            </div>

            <div class="bg-white border p-5 rounded-xl">
                <h2 class="text-sm font-semibold mb-4">
                    Pendapatan per Tipe Layanan
                </h2>
                <div
                    v-for="b in breakdown"
                    :key="b.service_type"
                    class="flex items-center gap-3 mb-2"
                >
                    <span class="text-xs w-20">{{ b.service_type }}</span>
                    <div class="flex-1 h-5 bg-gray-100 rounded overflow-hidden">
                        <div
                            class="h-full bg-[var(--color-stamp)]"
                            :style="{
                                width: `${((b.total_revenue || 0) / maxBreakdown) * 100}%`,
                            }"
                        />
                    </div>
                    <span class="text-xs font-mono w-28 text-right">{{
                        formatRupiah(b.total_revenue || 0)
                    }}</span>
                </div>
            </div>
        </template>
    </div>
</template>
