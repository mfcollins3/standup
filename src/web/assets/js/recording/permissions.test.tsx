import { act, renderHook, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

import { installFakePermissions, type FakePermissions } from "../test/fakeMedia";
import { useCameraBlocked } from "./permissions";

describe("useCameraBlocked", () => {
  let permissions: FakePermissions | undefined;

  afterEach(() => {
    permissions?.restore();
    permissions = undefined;
  });

  it("is false when the browser has no Permissions API", () => {
    const { result } = renderHook(() => useCameraBlocked());

    expect(result.current).toBe(false);
  });

  it("is false when nothing is blocked", async () => {
    permissions = installFakePermissions({ states: { camera: "granted", microphone: "prompt" } });

    const { result } = renderHook(() => useCameraBlocked());
    await waitFor(() => expect(permissions?.query).toHaveBeenCalledTimes(2));

    expect(result.current).toBe(false);
  });

  it("asks about the camera and the microphone, which does not show a prompt", async () => {
    permissions = installFakePermissions();

    renderHook(() => useCameraBlocked());
    await waitFor(() => expect(permissions?.query).toHaveBeenCalledTimes(2));

    expect(permissions.query).toHaveBeenCalledWith({ name: "camera" });
    expect(permissions.query).toHaveBeenCalledWith({ name: "microphone" });
  });

  it.each(["camera", "microphone"] as const)("is true when the %s is blocked", async (name) => {
    permissions = installFakePermissions({ states: { [name]: "denied" } });

    const { result } = renderHook(() => useCameraBlocked());

    await waitFor(() => expect(result.current).toBe(true));
  });

  it("notices when the user blocks the camera, and when they allow it again", async () => {
    permissions = installFakePermissions({ states: { camera: "granted" } });
    const { result } = renderHook(() => useCameraBlocked());
    await waitFor(() => expect(permissions?.query).toHaveBeenCalledTimes(2));
    expect(result.current).toBe(false);

    act(() => permissions?.set("camera", "denied"));
    expect(result.current).toBe(true);

    act(() => permissions?.set("camera", "granted"));
    expect(result.current).toBe(false);
  });

  it("is false when the browser does not know the permission, as in Firefox", async () => {
    permissions = installFakePermissions({ rejectQuery: true });

    const { result } = renderHook(() => useCameraBlocked());
    await waitFor(() => expect(permissions?.query).toHaveBeenCalledTimes(2));

    expect(result.current).toBe(false);
  });

  it("stops listening when the component goes away", async () => {
    permissions = installFakePermissions({ states: { camera: "granted" } });
    const removed = vi.spyOn(EventTarget.prototype, "removeEventListener");
    const { unmount } = renderHook(() => useCameraBlocked());
    await waitFor(() => expect(permissions?.query).toHaveBeenCalledTimes(2));

    unmount();

    expect(removed).toHaveBeenCalledWith("change", expect.any(Function));
    removed.mockRestore();
  });
});
