import { act, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { ReactIsland } from "./react_island";

type IslandHook = {
  el: HTMLElement;
  mounted(): void;
  updated(): void;
  destroyed(): void;
  pushEvent: ReturnType<typeof vi.fn>;
};

function islandHtml(props: object, component = "Hello") {
  return `
    <div id="island" data-component="${component}" data-props='${JSON.stringify(props)}'>
      <div id="island-root"></div>
    </div>`;
}

// ViewHook's constructor is internal to LiveView, so build the hook without
// running it and set the only member the island uses, `el`.
function createHook(el: HTMLElement): IslandHook {
  const hook = Object.create(ReactIsland.prototype) as IslandHook;
  hook.el = el;
  hook.pushEvent = vi.fn().mockResolvedValue({});
  return hook;
}

describe("ReactIsland", () => {
  beforeEach(() => {
    document.body.innerHTML = islandHtml({ name: "Ada" });
  });

  afterEach(() => {
    document.body.innerHTML = "";
  });

  it("renders the named component with the props from data-props", async () => {
    const hook = createHook(document.getElementById("island")!);

    await act(async () => hook.mounted());

    expect(screen.getByText(/Hello, Ada!/)).toBeInTheDocument();
  });

  it("re-renders when the server changes data-props", async () => {
    const el = document.getElementById("island")!;
    const hook = createHook(el);
    await act(async () => hook.mounted());

    el.dataset.props = JSON.stringify({ name: "Grace" });
    await act(async () => hook.updated());

    expect(screen.getByText(/Hello, Grace!/)).toBeInTheDocument();
  });

  it("forwards pushEvent to the LiveView", async () => {
    const hook = createHook(document.getElementById("island")!);
    await act(async () => hook.mounted());

    await act(async () => screen.getByRole("button").click());

    expect(hook.pushEvent).toHaveBeenCalledWith("clicked", { count: 1 });
  });

  it("unmounts the component when destroyed", async () => {
    const hook = createHook(document.getElementById("island")!);
    await act(async () => hook.mounted());

    await act(async () => hook.destroyed());

    expect(screen.queryByText(/Hello, Ada!/)).not.toBeInTheDocument();
  });

  it("throws for an unknown component", async () => {
    document.body.innerHTML = islandHtml({}, "Nope");
    const hook = createHook(document.getElementById("island")!);

    expect(() => hook.mounted()).toThrow(/unknown component "Nope"/);
  });

  it("throws when data-props is not a JSON object", async () => {
    document.body.innerHTML = `
      <div id="island" data-component="Hello" data-props='[1]'><div id="island-root"></div></div>`;
    const hook = createHook(document.getElementById("island")!);

    expect(() => hook.mounted()).toThrow(/must be a JSON object/);
  });
});
