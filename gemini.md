# Registro de Cambios - Solución PWA (Instalación como aplicación)

Se identificó y solucionó el inconveniente por el cual los navegadores basados en Chromium solo mostraban la opción de "Crear un icono" en lugar de "Instalar como aplicación".

## Cambios realizados

### 1. Inyección del Manifiesto PWA
* **Archivo modificado**: [app/app.vue](file:///dev2/electroluis/app/app.vue)
* **Descripción**: Se añadió el componente `<VitePwaManifest />` en la raíz de la aplicación para inyectar correctamente la etiqueta `<link rel="manifest" href="...">` en el `<head>` del HTML. Sin esto, el navegador no podía descubrir el manifiesto y deshabilitaba la instalación.

### 2. Soporte de PWA en Entorno de Desarrollo
* **Archivo modificado**: [nuxt.config.ts](file:///dev2/electroluis/nuxt.config.ts)
* **Descripción**: Se configuró `devOptions.enabled` en `true` para permitir el registro del Service Worker y habilitar las pruebas de instalación en modo de desarrollo (`npm run dev`).

### 3. Propósito de los Iconos (Compatibilidad de Manifiesto)
* **Archivo modificado**: [nuxt.config.ts](file:///dev2/electroluis/nuxt.config.ts)
* **Descripción**: Se separaron las definiciones de iconos con propósitos compuestos (`purpose: 'any maskable'`) en entradas individuales (`purpose: 'any'` y `purpose: 'maskable'`). Esto evita incompatibilidades de análisis en motores Chromium estrictos.

### 4. Redirección de Autenticación del Lado del Cliente (Middleware Global)
* **Archivo modificado/creado**: [app/middleware/auth.global.ts](file:///dev2/electroluis/app/middleware/auth.global.ts) y [nuxt.config.ts](file:///dev2/electroluis/nuxt.config.ts)
* **Descripción**: Se desactivó la redirección automática del servidor de `@nuxtjs/supabase` (`redirect: false`) y se implementó un middleware global del lado del cliente. Esto evita que el servidor responda con un código de redirección `307` al acceder a la URL de inicio (`start_url: '/'`), permitiendo que el navegador reciba un `200 OK` y pueda validar/cachear el manifiesto e instalar la PWA correctamente.

## Despliegue en Vercel
Para probar los cambios directamente en el entorno de Vercel, se realizaron los siguientes pasos en Git:
1. Commit de los archivos modificados/creados: `app/app.vue`, `nuxt.config.ts`, `app/middleware/auth.global.ts` y este archivo `gemini.md`.
2. Push a la rama principal (`main`) para disparar el despliegue automático en Vercel.
