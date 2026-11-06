import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

// Tests only need React. The Phoenix and Tailwind plugins in vite.config.mjs
// are left out because they are for the asset build.
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": import.meta.dirname,
    },
  },
  test: {
    environment: "jsdom",
    globals: true,
    include: ["js/**/*.test.{ts,tsx}"],
    setupFiles: ["./js/test/setup.ts"],
  },
});
