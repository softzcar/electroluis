import Lara from '@primevue/themes/lara'
import tailwindcss from '@tailwindcss/vite'

export default defineNuxtConfig({
  ssr: false,

  future: {
    compatibilityVersion: 4
  },

  compatibilityDate: '2026-07-07',

  devServer: {
    port: 3000
  },

  vite: {
    plugins: [tailwindcss()]
  },

  modules: [
    '@vite-pwa/nuxt',
    '@nuxtjs/supabase',
    '@pinia/nuxt',
    '@primevue/nuxt-module'
  ],

  css: ['~/assets/css/main.css'],

  supabase: {
    redirect: false,
    types: false
  },

  primevue: {
    options: {
      ripple: true,
      locale: {
        decimalSeparator: '.',
        thousandsSeparator: ','
      },
      theme: {
        preset: Lara,
        options: {
          darkModeSelector: '.fake-dark',
          cssLayer: {
            name: 'primevue',
            order: 'theme, base, primevue'
          }
        }
      }
    }
  },

  app: {
    head: {
      title: 'Medic Play',
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0, viewport-fit=cover' },
        { name: 'theme-color', content: '#0f172a' }
      ],
      link: [
        { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' },
        { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' }
      ]
    }
  },

  // @ts-ignore
  pwa: {
    strategies: 'generateSW',
    registerType: 'autoUpdate',
    injectRegister: 'auto',
    manifest: {
      id: '/?standalone=true',
      name: 'Medic Play',
      short_name: 'Medic Play',
      description: 'Control de repuestos y servicio tecnico - Medic Play',
      theme_color: '#0f172a',
      background_color: '#0f172a',
      display: 'standalone',
      orientation: 'portrait',
      start_url: '/',
      scope: '/',
      icons: [
        {
          src: '/icon-192x192.png',
          sizes: '192x192',
          type: 'image/png',
          purpose: 'any'
        },
        {
          src: '/icon-192x192.png',
          sizes: '192x192',
          type: 'image/png',
          purpose: 'maskable'
        },
        {
          src: '/icon-512x512.png',
          sizes: '512x512',
          type: 'image/png',
          purpose: 'any'
        },
        {
          src: '/icon-512x512.png',
          sizes: '512x512',
          type: 'image/png',
          purpose: 'maskable'
        }
      ]
    },
    workbox: {
      navigateFallback: '/',
      globPatterns: ['**/*.{js,css,html,png,svg,ico,woff2,json}'],
      cleanupOutdatedCaches: true,
      navigateFallbackDenylist: [/^\/api\//, /^\/auth\//, /^\/_supabase\//],
      runtimeCaching: [
        {
          urlPattern: /^https:\/\/.*\.supabase\.co\/rest\/v1\/.*/,
          handler: 'NetworkFirst',
          options: {
            cacheName: 'api-cache',
            expiration: { maxEntries: 100, maxAgeSeconds: 3600 },
            networkTimeoutSeconds: 3
          }
        },
        {
          urlPattern: ({ request }: any) => request.mode === 'navigate' || request.destination === 'document',
          handler: 'NetworkFirst',
          options: {
            cacheName: 'pages-cache',
            networkTimeoutSeconds: 3,
            cacheableResponse: { statuses: [0, 200] }
          }
        },
        {
          urlPattern: ({ url }: any) => url.pathname.includes('/_nuxt/') || url.pathname.endsWith('.js') || url.pathname.endsWith('.css'),
          handler: 'StaleWhileRevalidate',
          options: {
            cacheName: 'static-resources',
            expiration: { maxEntries: 500, maxAgeSeconds: 60 * 60 * 24 * 30 }
          }
        }
      ]
    },
    client: {
      installPrompt: true,
      periodicSyncForUpdates: 3600
    },
    devOptions: {
      enabled: true,
      type: 'module'
    }
  }
})
