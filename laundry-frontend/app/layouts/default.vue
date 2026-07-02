<script setup lang="ts">
const auth = useAuthStore();
const route = useRoute();

const navItems = computed(() => {
    const items = [
        { to: "/orders", label: "Pesanan", icon: "M3 7h18M3 12h18M3 17h18" },
        {
            to: "/customers",
            label: "Pelanggan",
            icon: "M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14c-4 0-7 2-7 5h14c0-3-3-5-7-5z",
        },
        {
            to: "/edit-requests",
            label: "Pengajuan",
            icon: "M4 20l4-1 11-11-3-3L5 16l-1 4z",
        },
    ];
    if (auth.isOwner) {
        items.push({
            to: "/analytics",
            label: "Laporan",
            icon: "M4 19V5M10 19V9M16 19v-7M22 19H2",
        });
    }
    return items;
});

const isActive = (to: string) => route.path.startsWith(to);
</script>

<template>
    <div class="min-h-screen flex flex-col lg:flex-row">
        <aside
            class="lg:w-60 shrink-0 border-b lg:border-b-0 lg:border-r border-[var(--color-line)] bg-[var(--color-paper-dim)]/60"
        >
            <div
                class="flex items-center justify-between lg:flex-col lg:items-start px-5 py-4 lg:py-6"
            >
                <NuxtLink to="/orders" class="flex items-center gap-2">
                    <span
                        class="font-display text-xl tracking-tight text-[var(--color-soap-deep)]"
                        >LaundryKita</span
                    >
                </NuxtLink>
                <span
                    class="hidden lg:block mt-1 text-xs font-mono text-[var(--color-ink-soft)] tracking-wide"
                    >Laundry Management</span
                >
            </div>

            <nav
                class="px-3 pb-3 lg:pb-0 flex lg:flex-col gap-1 overflow-x-auto"
            >
                <NuxtLink
                    v-for="(item, i) in navItems"
                    :key="item.to"
                    :to="item.to"
                    class="group flex items-center gap-3 px-3 py-2.5 rounded-md text-sm transition-colors whitespace-nowrap"
                    :class="
                        isActive(item.to)
                            ? 'bg-[var(--color-soap)] text-white'
                            : 'text-[var(--color-ink-soft)] hover:bg-[var(--color-soap-light)] hover:text-[var(--color-soap-deep)]'
                    "
                >
                    <span class="font-mono text-[10px] opacity-60">{{
                        String(i + 1).padStart(2, "0")
                    }}</span>
                    <span class="font-medium">{{ item.label }}</span>
                </NuxtLink>
            </nav>

            <div
                class="hidden lg:block mt-auto px-5 py-4 absolute bottom-0 w-60"
            >
                <div class="ticket-edge pb-3 mb-3 text-xs">
                    <p class="text-[var(--color-ink-soft)]">Masuk sebagai</p>
                    <p class="font-medium text-[var(--color-ink)]">
                        {{ auth.user?.username }}
                    </p>
                    <span
                        class="inline-block mt-1 px-2 py-0.5 rounded text-[10px] font-mono uppercase tracking-wide"
                        :class="
                            auth.isOwner
                                ? 'bg-[var(--color-stamp-light)] text-[var(--color-stamp)]'
                                : 'bg-[var(--color-soap-light)] text-[var(--color-soap-deep)]'
                        "
                        >{{ auth.user?.role }}</span
                    >
                </div>
                <button
                    class="text-xs font-medium text-[var(--color-ink-soft)] hover:text-[var(--color-stamp)] transition-colors"
                    @click="auth.logout()"
                >
                    Keluar →
                </button>
            </div>
        </aside>

        <div
            class="lg:hidden flex items-center justify-between px-5 py-3 border-b border-[var(--color-line)]"
        >
            <div class="text-xs">
                <span class="text-[var(--color-ink-soft)]">Masuk sebagai </span>
                <span class="font-medium">{{ auth.user?.username }}</span>
                <span
                    class="ml-1 font-mono text-[10px] uppercase text-[var(--color-soap-deep)]"
                    >({{ auth.user?.role }})</span
                >
            </div>
            <button
                class="text-xs font-medium text-[var(--color-stamp)]"
                @click="auth.logout()"
            >
                Keluar
            </button>
        </div>

        <main
            class="flex-1 px-5 py-6 lg:px-10 lg:py-10 max-w-6xl w-full mx-auto"
        >
            <slot />
        </main>
    </div>
</template>
