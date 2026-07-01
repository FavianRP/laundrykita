export default defineNuxtRouteMiddleware((to) => {
  if (import.meta.server) return

  const publicPaths = ['/login']
  const isTrackPage = to.path.startsWith('/track')
  if (publicPaths.includes(to.path) || isTrackPage) return

  const auth = useAuthStore()
  if (!auth.token) {
    // hydrate hasn't necessarily run before middleware on first client nav; check storage directly
    const token = localStorage.getItem('laundry_token')
    if (!token) {
      return navigateTo('/login')
    }
  }

  if (to.path.startsWith('/analytics') && auth.user && auth.user.role !== 'owner') {
    return navigateTo('/orders')
  }
})
