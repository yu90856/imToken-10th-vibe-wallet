import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import path from "path";
import { fileURLToPath } from "url";
import { defineConfig } from "vite";

const root = path.dirname(fileURLToPath(import.meta.url));
const uiRoot = path.resolve(root, "vendor/token-ui/packages/ui/src");

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@repo/ui/components": path.join(uiRoot, "components"),
      "@repo/ui/lib": path.join(uiRoot, "lib"),
      "@repo/ui/hooks": path.join(uiRoot, "hooks"),
    },
  },
  optimizeDeps: {
    exclude: ["@consenlabs/tcx-wasm"],
  },
});
