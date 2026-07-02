<script setup lang="ts">
definePageMeta({ layout: "blank" });

const username = ref("");
const password = ref("");
const loading = ref(false);
const error = ref("");

const api = useApi();
const auth = useAuthStore();

async function handleLogin() {
    error.value = "";
    loading.value = true;
    try {
        const res = await api.post<{
            access_token: string;
            token_type: string;
            role: "kasir" | "owner";
            user_id: number;
        }>("/auth/login", {
            username: username.value,
            password: password.value,
        });
        auth.setSession(res.access_token, {
            id: res.user_id,
            username: username.value,
            role: res.role,
        });
        await navigateTo("/orders");
    } catch (e: any) {
        error.value = e.message || "Username atau kata sandi salah.";
    } finally {
        loading.value = false;
    }
}
</script>

<template>
    <div class="w-full max-w-sm">
        <div class="text-center mb-8">
            <p
                class="font-mono text-xs tracking-widest uppercase text-[var(--color-ink-soft)] mb-2"
            >
                Laundry Management
            </p>
            <h1 class="font-display text-3xl text-[var(--color-soap-deep)]">
                LaundryKita
            </h1>
        </div>

        <form
            class="bg-white/70 border border-[var(--color-line)] rounded-xl p-6 shadow-sm"
            @submit.prevent="handleLogin"
        >
            <div class="mb-4">
                <label
                    class="block text-xs font-medium text-[var(--color-ink-soft)] mb-1.5"
                    for="username"
                    >Nama pengguna</label
                >
                <input
                    id="username"
                    v-model="username"
                    type="text"
                    required
                    autocomplete="username"
                    class="w-full rounded-md border border-[var(--color-line)] bg-white px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--color-soap)]"
                    placeholder="owner / kasir1"
                />
            </div>
            <div class="mb-5">
                <label
                    class="block text-xs font-medium text-[var(--color-ink-soft)] mb-1.5"
                    for="password"
                    >Kata sandi</label
                >
                <input
                    id="password"
                    v-model="password"
                    type="password"
                    required
                    autocomplete="current-password"
                    class="w-full rounded-md border border-[var(--color-line)] bg-white px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--color-soap)]"
                    placeholder="••••••••"
                />
            </div>

            <p v-if="error" class="mb-4 text-sm text-[var(--color-stamp)]">
                {{ error }}
            </p>

            <button
                type="submit"
                :disabled="loading"
                class="w-full rounded-md bg-[var(--color-soap)] text-white text-sm font-medium py-2.5 hover:bg-[var(--color-soap-deep)] transition-colors disabled:opacity-60"
            >
                {{ loading ? "Memproses…" : "Masuk" }}
            </button>
        </form>

        <p class="text-center mt-6 text-xs text-[var(--color-ink-soft)]">
            Mencari status cucian?
            <NuxtLink
                to="/track"
                class="text-[var(--color-soap-deep)] font-medium underline underline-offset-2"
                >Lacak pesanan</NuxtLink
            >
        </p>
    </div>
</template>
