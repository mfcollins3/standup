import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { phoenixVitePlugin } from 'phoenix_vite'
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  server: {
    port: 5173,
    strictPort: true,
    // No `cors` option on purpose. Vite's default allows pages on localhost and
    // 127.0.0.1 on any port, and nothing else. The page is not always on port
    // 4000: Aspire serves the app through a proxy on a random port, so allowing
    // only http://localhost:4000 blocks the scripts there.
  },
  optimizeDeps: {
    // https://vitejs.dev/guide/dep-pre-bundling#monorepos-and-linked-dependencies
    include: ["phoenix", "phoenix_html", "phoenix_live_view"],
  },
  build: {
    manifest: true,
    rollupOptions: {
      input: ["js/app.ts", "css/app.css"],
    },
    outDir: "../priv/static",
    emptyOutDir: true,
  },
  // LV Colocated JS and Hooks
  // https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.ColocatedJS.html#module-internals
  resolve: {
    alias: {
      "@": import.meta.dirname,
      "phoenix-colocated": `${process.env.MIX_BUILD_PATH}/phoenix-colocated`,
    },
  },
  plugins: [
    react(),
    tailwindcss(),
    phoenixVitePlugin({
      pattern: /\.(ex|heex)$/
    })
  ],
});
