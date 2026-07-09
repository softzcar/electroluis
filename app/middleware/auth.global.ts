export default defineNuxtRouteMiddleware((to) => {
  const user = useSupabaseUser()
  const publicRoutes = ['/login']
  const isPublic = publicRoutes.includes(to.path)

  // 1. Si el usuario no está autenticado y la ruta no es pública, redirigir a /login
  if (!user.value && !isPublic) {
    return navigateTo('/login')
  }

  // 2. Si el usuario está autenticado y está en la ruta de login, redirigir a la raíz
  if (user.value && isPublic) {
    return navigateTo('/')
  }
})
