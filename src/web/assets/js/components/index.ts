import type { ComponentType } from "react";

import type { IslandProps } from "@/js/hooks/react_island";

import { Hello } from "./Hello";

/**
 * The React components that can be mounted with `<.react_island component="…">`.
 *
 * Add a component here to make it available to the server. The key is the name
 * used in HEEx templates.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const components: Record<string, ComponentType<IslandProps<any>>> = {
  Hello,
};
