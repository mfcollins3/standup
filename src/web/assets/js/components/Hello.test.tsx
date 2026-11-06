import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { Hello } from "./Hello";

describe("Hello", () => {
  it("greets the name from the server", () => {
    render(<Hello name="Ada" pushEvent={vi.fn()} />);

    expect(screen.getByText(/Hello, Ada!/)).toBeInTheDocument();
  });

  it("pushes a clicked event with the new count", async () => {
    const pushEvent = vi.fn();
    render(<Hello name="Ada" pushEvent={pushEvent} />);

    await userEvent.click(screen.getByRole("button", { name: /clicked 0 times/i }));
    await userEvent.click(screen.getByRole("button", { name: /clicked 1 times/i }));

    expect(pushEvent).toHaveBeenNthCalledWith(1, "clicked", { count: 1 });
    expect(pushEvent).toHaveBeenNthCalledWith(2, "clicked", { count: 2 });
  });
});
