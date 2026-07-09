export default defineNuxtRouteMiddleware(async (to) => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser() // Inicializa el estado reactivo del usuario
  const publicRoutes = ['/login', '/reset-password']
  const isPublic = publicRoutes.includes(to.path)

  // Obtener la sesión actual de forma asíncrona para evitar condiciones de carrera en SPA
  const { data: { session } } = await supabase.auth.getSession()
  const isAuthenticated = !!session?.user

  // 1. Si el usuario no está autenticado y la ruta no es pública, redirigir a /login
  if (!isAuthenticated && !isPublic) {
    return navigateTo('/login')
  }

  // 2. Si el usuario está autenticado y está en la ruta de login, redirigir a la raíz
  if (isAuthenticated && to.path === '/login') {
    return navigateTo('/')
  }
})
