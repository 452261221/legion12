import path from "node:path";

import { defineConfig } from "vite";
import uniModule from "@dcloudio/vite-plugin-uni";

const uni = typeof uniModule === "function" ? uniModule : uniModule.default;

export default defineConfig({
  plugins: [uni()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src")
    }
  }
});
