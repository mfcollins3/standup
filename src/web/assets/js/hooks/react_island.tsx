import { ViewHook } from "phoenix_live_view";
import { createRoot, type Root } from "react-dom/client";

import { components } from "@/js/components";

/**
 * Mounts a React component inside a LiveView page (an "island").
 *
 * The server renders the island with the `<.react_island>` function component,
 * which produces:
 *
 *     <div id="..." phx-hook="ReactIsland" data-component="Name" data-props="{...}">
 *       <div id="...-root" phx-update="ignore"></div>
 *     </div>
 *
 * React owns the inner `-root` element, and `phx-update="ignore"` stops
 * LiveView from patching it. The outer element is still patched by LiveView, so
 * when the server changes `data-props` the `updated` callback re-renders the
 * component with the new props.
 *
 * The component receives its props plus a `pushEvent` function that sends an
 * event to the LiveView.
 */

export type PushEvent = (event: string, payload?: Record<string, unknown>) => void;

/** The props of an island component: the props from the server plus `pushEvent`. */
export type IslandProps<P extends object = object> = P & {
  pushEvent: PushEvent;
};

function readProps(el: HTMLElement): Record<string, unknown> {
  const raw = el.dataset.props;
  if (!raw) return {};

  const parsed: unknown = JSON.parse(raw);
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(`react_island: data-props of #${el.id} must be a JSON object`);
  }

  return parsed as Record<string, unknown>;
}

export class ReactIsland extends ViewHook {
  private root: Root | null = null;

  mounted() {
    const container = this.el.querySelector<HTMLElement>(`#${CSS.escape(this.el.id)}-root`);
    if (!container) {
      throw new Error(`react_island: missing #${this.el.id}-root container`);
    }

    this.root = createRoot(container);
    this.render();
  }

  updated() {
    this.render();
  }

  destroyed() {
    this.root?.unmount();
    this.root = null;
  }

  private render() {
    const name = this.el.dataset.component;
    const Component = name ? components[name] : undefined;
    if (!Component) {
      throw new Error(`react_island: unknown component "${name}"`);
    }

    const pushEvent: PushEvent = (event, payload) => {
      void this.pushEvent(event, payload);
    };

    this.root?.render(<Component {...readProps(this.el)} pushEvent={pushEvent} />);
  }
}
