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

### 5. Ubicación del Directorio Public (Nuxt 4)
* **Carpeta movida**: De `app/public/` a la raíz `public/`
* **Descripción**: En Nuxt 4, la carpeta `public` debe ubicarse en la raíz del proyecto (junto a `app` y `nuxt.config.ts`), no dentro de `app/`. Al estar dentro de `app/`, el compilador ignoraba los iconos (`icon-192x192.png`, `icon-512x512.png`), de modo que no se incluían en el directorio de salida `.output/public` de Vercel. Esto causaba un error 404 al intentar cargar los iconos, impidiendo que Chromium habilitara la instalación de la aplicación.

## Cambios en la Interfaz (Julio 2026)

### 1. Ubicación del Botón de Menú
* **Archivo modificado**: [app/layouts/default.vue](file:///dev2/electroluis/app/layouts/default.vue)
* **Descripción**: Se movió el botón del menú hamburguesa al lado izquierdo del encabezado móvil y se agregó un espaciador al lado derecho para mantener el título ("electroluis") centrado de forma estética.

### 2. Simplificación de Rutas e Inicio
* **Archivos modificados/eliminados**: [app/pages/index.vue](file:///dev2/electroluis/app/pages/index.vue), [app/pages/movimientos/index.vue](file:///dev2/electroluis/app/pages/movimientos/index.vue) (eliminado), y [app/layouts/default.vue](file:///dev2/electroluis/app/layouts/default.vue)
* **Descripción**: Se eliminó la página de inicio original (que solo mostraba la bienvenida) y se trasladó el contenido de la página de movimientos para que sirva como la nueva raíz de la aplicación (`/`). En el menú lateral se eliminaron las opciones de "Inicio" y el duplicado de "Movimientos" del final, colocando "Movimientos" como la primera opción de navegación principal de la barra lateral.

### 3. Formulario de Movimientos Avanzado
* **Archivos modificados/creados**: [app/pages/index.vue](file:///dev2/electroluis/app/pages/index.vue), [app/pages/equipos/index.vue](file:///dev2/electroluis/app/pages/equipos/index.vue) y [supabase/migrations/update_equipos_serial.sql](file:///dev2/electroluis/supabase/migrations/update_equipos_serial.sql)
* **Descripción**: Se renovó completamente el formulario de movimientos, integrando:
  * **Typeahead/Búsqueda predictiva de Clientes**: Búsqueda interactiva por nombre o teléfono en lugar de un elemento `<select>` estático.
  * **Typeahead de Equipos**: Permite buscar y agregar múltiples equipos a un solo movimiento de forma dinámica. Cada equipo seleccionado cuenta con su propio campo para registrar el **número de serie**.
  * **Ubicación del Serial**: Se eliminó el campo de número de serie de la tabla de catálogo `equipos` y se movió a la tabla relacional `movimientos_equipos` mediante un script SQL, ya que el número de serie define al dispositivo traído por el cliente y no a la marca/modelo general del catálogo.
  * **Typeahead de Repuestos y Código de Barras**: Permite la carga dinámica de repuestos (añadiendo cantidades y stock disponible en tiempo real). Es compatible con escritura manual y con el lector de códigos de barras mediante el composable `useBarcodeScanner`.
  * **Eliminación interactiva**: Se añadieron botones de papelera de reciclaje (`Trash2` de Lucide) para quitar elementos de la lista fácilmente.

### 4. Componentes Reutilizables y Modales de Creación Rápida
* **Archivos modificados/creados**: [app/components/ClientForm.vue](file:///dev2/electroluis/app/components/ClientForm.vue), [app/components/EquipmentForm.vue](file:///dev2/electroluis/app/components/EquipmentForm.vue), [app/components/RepuestoForm.vue](file:///dev2/electroluis/app/components/RepuestoForm.vue), [app/pages/index.vue](file:///dev2/electroluis/app/pages/index.vue), y las páginas de catálogo [clientes/index.vue](file:///dev2/electroluis/app/pages/clientes/index.vue), [equipos/index.vue](file:///dev2/electroluis/app/pages/equipos/index.vue), [repuestos/index.vue](file:///dev2/electroluis/app/pages/repuestos/index.vue).
* **Descripción**: 
  * Se extrajeron los formularios de catálogo en tres componentes aislados y reutilizables, agregando un prop `showCancel` para ocultar el botón "Cancelar" cuando se renderizan de manera fija.
  * Se refactorizaron las páginas de catálogo (`/clientes`, `/equipos`, `/repuestos`) para que utilicen estos nuevos componentes.
  * Se integraron botones `+` junto a cada buscador predictivo en la página principal de Movimientos, abriendo modales interactivos con efecto de desenfoque (`backdrop-blur`). Al crear un elemento con éxito, se agrega de forma reactiva al catálogo local y **se auto-selecciona automáticamente** en el formulario de origen.
  * **Validación de duplicados**: Se agregó una validación del lado del cliente en el proceso de registro del movimiento que impide ingresar un número de serie duplicado para múltiples equipos asignados en la misma orden de trabajo.

## Despliegue en Vercel
Para probar los cambios directamente en el entorno de Vercel, se realizaron los siguientes pasos en Git:
1. Commit de los archivos modificados/creados/movidos: `app/app.vue`, `nuxt.config.ts`, `app/middleware/auth.global.ts`, la carpeta `public/`, `app/layouts/default.vue`, `app/pages/index.vue`, `app/pages/movimientos/index.vue`, `app/pages/equipos/index.vue`, `supabase/migrations/update_equipos_serial.sql`, los componentes en `app/components/`, las páginas de catálogo en `app/pages/` y este archivo `gemini.md`.
2. Push a la rama principal (`main`) para disparar el despliegue automático en Vercel.
