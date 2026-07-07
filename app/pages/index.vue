<script setup lang="ts">
const user = useSupabaseUser()
</script>

<template>
  <div>
    <h1 class="text-2xl font-semibold text-slate-800 mb-2">Bienvenido</h1>
    <p class="text-slate-600">Sesion iniciada como {{ user?.email }}</p>
  </div>
</template>
