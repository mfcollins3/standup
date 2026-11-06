// LiveView writes the colocated hooks to `_build/<env>/phoenix-colocated/<app>`
// at compile time. Vite resolves that through the "phoenix-colocated" alias, so
// TypeScript only needs to know the shape of the module.
declare module "phoenix-colocated/standup" {
  import type { HooksOptions } from "phoenix_live_view";

  export const hooks: HooksOptions;
}
