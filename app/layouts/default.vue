<script setup lang="ts">
import { LayoutDashboard, Users, Cpu, Wrench, ClipboardList, Tags, LogOut } from 'lucide-vue-next'

const supabase = useSupabaseClient()
const router = useRouter()

const links = [
  { to: '/', label: 'Inicio', icon: LayoutDashboard },
  { to: '/clientes', label: 'Clientes', icon: Users },
  { to: '/equipos', label: 'Equipos', icon: Cpu },
  { to: '/repuestos', label: 'Repuestos', icon: Wrench },
  { to: '/categorias', label: 'Categorias', icon: Tags },
  { to: '/movimientos', label: 'Movimientos', icon: ClipboardList }
]

const logout = async () => {
  await supabase.auth.signOut()
  router.push('/login')
}
</script>

<template>
  <div class="min-h-screen flex bg-slate-100">
    <aside class="w-56 shrink-0 bg-slate-900 text-slate-100 flex flex-col">
      <div class="px-4 py-5 text-lg font-semibold border-b border-slate-800">
        electroluis
      </div>
      <nav class="flex-1 px-2 py-4 space-y-1">
        <NuxtLink
          v-for="link in links"
          :key="link.to"
          :to="link.to"
          class="flex items-center gap-2 px-3 py-2 rounded-md text-sm hover:bg-slate-800"
          active-class="bg-slate-800 font-medium"
        >
          <component :is="link.icon" :size="18" />
          {{ link.label }}
        </NuxtLink>
      </nav>
      <button
        class="flex items-center gap-2 px-3 py-3 m-2 rounded-md text-sm hover:bg-slate-800"
        @click="logout"
      >
        <LogOut :size="18" />
        Cerrar sesion
      </button>
    </aside>
    <main class="flex-1 p-6">
      <slot />
    </main>
  </div>
</template>
