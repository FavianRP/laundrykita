import { defineStore } from 'pinia'
import type { User } from '~/types'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    token: null as string | null,
    user: null as User | null,
  }),
  getters: {
    isLoggedIn: (state) => !!state.token,
    isOwner: (state) => state.user?.role === 'owner',
    isKasir: (state) => state.user?.role === 'kasir',
  },
  actions: {
    hydrate() {
      if (import.meta.client) {
        const token = localStorage.getItem('laundry_token')
        const userRaw = localStorage.getItem('laundry_user')
        if (token) this.token = token
        if (userRaw) {
          try { this.user = JSON.parse(userRaw) } catch { this.user = null }
        }
      }
    },
    setSession(token: string, user: User) {
      this.token = token
      this.user = user
      if (import.meta.client) {
        localStorage.setItem('laundry_token', token)
        localStorage.setItem('laundry_user', JSON.stringify(user))
      }
    },
    logout() {
      this.token = null
      this.user = null
      if (import.meta.client) {
        localStorage.removeItem('laundry_token')
        localStorage.removeItem('laundry_user')
      }
      navigateTo('/login')
    },
  },
})
