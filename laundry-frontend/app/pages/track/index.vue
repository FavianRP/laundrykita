<script setup lang="ts">
definePageMeta({ layout: 'blank' })

const code = ref('')
const router = useRouter()

function go() {
  if (!code.value.trim()) return
  router.push(`/track/${code.value.trim().toUpperCase()}`)
}
</script>

<template>
  <div class="w-full max-w-sm">
    <div class="text-center mb-8">
      <p class="font-mono text-xs tracking-widest uppercase text-[var(--color-ink-soft)] mb-2">Lacak Cucian</p>
      <h1 class="font-display text-3xl text-[var(--color-soap-deep)]">Ke mana cucianmu?</h1>
      <p class="text-sm text-[var(--color-ink-soft)] mt-2">Masukkan kode struk untuk melihat status terkini.</p>
    </div>

    <form class="bg-white/70 border border-[var(--color-line)] rounded-xl p-6 shadow-sm" @submit.prevent="go">
      <label class="block text-xs font-medium text-[var(--color-ink-soft)] mb-1.5" for="code">Kode pelacakan</label>
      <input
        id="code"
        v-model="code"
        type="text"
        placeholder="LND-3006-001"
        class="w-full rounded-md border border-[var(--color-line)] bg-white px-3 py-2.5 text-sm font-mono tracking-wider focus:outline-none focus:ring-2 focus:ring-[var(--color-soap)]"
      >
      <button
        type="submit"
        class="w-full mt-4 rounded-md bg-[var(--color-soap)] text-white text-sm font-medium py-2.5 hover:bg-[var(--color-soap-deep)] transition-colors"
      >
        Lacak Pesanan
      </button>
    </form>

    <p class="text-center mt-6 text-xs text-[var(--color-ink-soft)]">
      <NuxtLink to="/login" class="text-[var(--color-soap-deep)] font-medium underline underline-offset-2">Masuk sebagai staf</NuxtLink>
    </p>
  </div>
</template>
