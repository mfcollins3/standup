import { act, renderHook } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { FakeMediaStream, installFakeMedia, type FakeMedia } from "../test/fakeMedia";
import { MAX_RECORDING_MS, MEDIA_CONSTRAINTS, TIMESLICE_MS } from "./constraints";
import { useRecorder } from "./useRecorder";

describe("useRecorder", () => {
  let media: FakeMedia;

  beforeEach(() => {
    media = installFakeMedia({ supportedTypes: ["video/webm;codecs=vp9,opus", "video/webm"] });
  });

  afterEach(() => {
    media.restore();
    vi.restoreAllMocks();
  });

  /** Makes the next `getUserMedia` wait until the returned function is called. */
  function holdNextRequest(): (stream: FakeMediaStream) => void {
    let allow: (stream: FakeMediaStream) => void = () => {};
    media.getUserMedia.mockImplementationOnce(
      () => new Promise<FakeMediaStream>((resolve) => (allow = resolve)),
    );
    return (stream) => allow(stream);
  }

  async function previewing() {
    const hook = renderHook(() => useRecorder());
    await act(async () => hook.result.current.requestAccess());
    return hook;
  }

  async function recording() {
    const hook = await previewing();
    act(() => hook.result.current.start());
    return hook;
  }

  describe("asking for access", () => {
    it("starts idle and does not ask for the camera until it is told to", () => {
      const { result } = renderHook(() => useRecorder());

      expect(result.current.state).toBe("idle");
      expect(result.current.stream).toBeNull();
      expect(media.getUserMedia).not.toHaveBeenCalled();
    });

    it("asks for the camera and microphone and shows a preview", async () => {
      const { result } = await previewing();

      expect(media.getUserMedia).toHaveBeenCalledExactlyOnceWith(MEDIA_CONSTRAINTS);
      expect(result.current.state).toBe("previewing");
      expect(result.current.stream).toBe(media.streams[0]);
    });

    it("waits in the requesting state while the user decides", async () => {
      const allow = holdNextRequest();

      const { result } = renderHook(() => useRecorder());
      act(() => void result.current.requestAccess());

      expect(result.current.state).toBe("requesting");

      await act(async () => allow(new FakeMediaStream()));

      expect(result.current.state).toBe("previewing");
    });

    it("does not ask again while it already has the camera", async () => {
      const { result } = await previewing();

      await act(async () => result.current.requestAccess());

      expect(media.getUserMedia).toHaveBeenCalledTimes(1);
    });

    it.each([
      ["NotAllowedError", "permission-denied"],
      ["NotFoundError", "no-device"],
      ["NotReadableError", "device-busy"],
      ["AbortError", "unknown"],
    ])("reports %s as %s", async (name, code) => {
      media.rejectWith(name);

      const { result } = renderHook(() => useRecorder());
      await act(async () => result.current.requestAccess());

      expect(result.current.state).toBe("error");
      expect(result.current.error).toBe(code);
      expect(result.current.stream).toBeNull();
    });

    it("can try again after an error", async () => {
      media.rejectWith("NotAllowedError");
      const { result } = renderHook(() => useRecorder());
      await act(async () => result.current.requestAccess());
      expect(result.current.state).toBe("error");

      await act(async () => result.current.requestAccess());

      expect(result.current.state).toBe("previewing");
      expect(result.current.error).toBeNull();
    });

    it("reports an unsupported browser without asking for the camera", async () => {
      media.restore();
      media = installFakeMedia({ withMediaRecorder: false });

      const { result } = renderHook(() => useRecorder());
      await act(async () => result.current.requestAccess());

      expect(result.current.state).toBe("error");
      expect(result.current.error).toBe("unsupported");
      expect(media.getUserMedia).not.toHaveBeenCalled();
    });
  });

  describe("recording", () => {
    it("records with the best supported format and a capped bitrate", async () => {
      await recording();

      const [recorder] = media.recorders;
      expect(recorder?.options).toEqual({
        mimeType: "video/webm;codecs=vp9,opus",
        videoBitsPerSecond: 1_500_000,
        audioBitsPerSecond: 64_000,
      });
      expect(recorder?.start).toHaveBeenCalledExactlyOnceWith(TIMESLICE_MS);
    });

    it("lets the browser choose the format when none is supported", async () => {
      media.restore();
      media = installFakeMedia({ supportedTypes: [] });

      await recording();

      expect(media.recorders[0]?.options).not.toHaveProperty("mimeType");
    });

    it("is recording after start", async () => {
      const { result } = await recording();

      expect(result.current.state).toBe("recording");
    });

    it("produces a recording of the right format, size and length when it stops", async () => {
      const now = vi.spyOn(performance, "now");
      now.mockReturnValue(1000);
      const { result } = await recording();
      now.mockReturnValue(4200);

      act(() => result.current.stop());

      expect(result.current.state).toBe("recorded");
      expect(result.current.recording).toMatchObject({
        mimeType: "video/webm;codecs=vp9,opus",
        durationMs: 3200,
      });
      expect(result.current.recording?.blob.type).toBe("video/webm;codecs=vp9,opus");
      expect(result.current.recording?.blob.size).toBe("video-bytes".length);
    });

    it("turns the camera off after it stops", async () => {
      const { result } = await recording();
      expect(media.streams[0]?.allTracksStopped).toBe(false);

      act(() => result.current.stop());

      expect(media.streams[0]?.allTracksStopped).toBe(true);
      expect(result.current.stream).toBeNull();
    });

    it("can record again after a recording", async () => {
      const { result } = await recording();
      act(() => result.current.stop());

      await act(async () => result.current.requestAccess());
      act(() => result.current.start());
      act(() => result.current.stop());

      expect(result.current.state).toBe("recorded");
      expect(media.streams).toHaveLength(2);
      expect(media.recorders).toHaveLength(2);
    });

    it("only starts from the preview", async () => {
      const { result } = renderHook(() => useRecorder());

      act(() => result.current.start());

      expect(result.current.state).toBe("idle");
      expect(media.recorders).toHaveLength(0);
    });

    it("only stops while recording", async () => {
      const { result } = await previewing();

      act(() => result.current.stop());

      expect(result.current.state).toBe("previewing");
    });

    it("reports an error and turns the camera off if the recorder fails", async () => {
      const { result } = await recording();

      act(() => media.recorders[0]?.onerror?.());

      expect(result.current.state).toBe("error");
      expect(result.current.error).toBe("unknown");
      expect(media.streams[0]?.allTracksStopped).toBe(true);
    });

    it("reports an unsupported browser if the recorder cannot be created", async () => {
      const { result } = await previewing();
      vi.stubGlobal(
        "MediaRecorder",
        class {
          static isTypeSupported = () => true;
          constructor() {
            throw new Error("not supported");
          }
        },
      );

      act(() => result.current.start());

      expect(result.current.state).toBe("error");
      expect(result.current.error).toBe("unsupported");
      expect(media.streams[0]?.allTracksStopped).toBe(true);
    });
  });

  describe("when the camera or microphone stops during a recording", () => {
    it.each(["video", "audio"] as const)(
      "ends the recording and keeps it when the %s track ends",
      async (kind) => {
        const { result } = await recording();

        act(() => media.streams[0]?.tracks.find((track) => track.kind === kind)?.end());

        expect(media.recorders[0]?.stop).toHaveBeenCalledTimes(1);
        expect(result.current.state).toBe("recorded");
        expect(result.current.recording).not.toBeNull();
        expect(result.current.warning).toBe("device-lost");
        expect(media.streams[0]?.allTracksStopped).toBe(true);
      },
    );

    it("has no warning when the user stops the recording", async () => {
      const { result } = await recording();

      act(() => result.current.stop());

      expect(result.current.warning).toBeNull();
    });

    it("does not warn about a track that ends after the recording was stopped", async () => {
      const { result } = await recording();
      act(() => result.current.stop());

      act(() => media.streams[0]?.tracks[0]?.end());

      expect(result.current.warning).toBeNull();
      expect(media.recorders[0]?.stop).toHaveBeenCalledTimes(1);
    });

    it("clears the warning when the user records again", async () => {
      const { result } = await recording();
      act(() => media.streams[0]?.tracks[0]?.end());
      expect(result.current.warning).toBe("device-lost");

      await act(async () => result.current.requestAccess());

      expect(result.current.warning).toBeNull();
    });

    it("clears the warning when the next recording starts", async () => {
      const { result } = await recording();
      act(() => media.streams[0]?.tracks[0]?.end());
      await act(async () => result.current.requestAccess());
      act(() => result.current.start());

      act(() => result.current.stop());

      expect(result.current.warning).toBeNull();
    });
  });

  describe("dismissing an error", () => {
    it("goes back to the start so the user can try again", async () => {
      media.rejectWith("NotAllowedError");
      const { result } = renderHook(() => useRecorder());
      await act(async () => result.current.requestAccess());
      expect(result.current.state).toBe("error");

      act(() => result.current.dismissError());

      expect(result.current.state).toBe("idle");
      expect(result.current.error).toBeNull();
    });

    it("does nothing when there is no error", async () => {
      const { result } = await previewing();

      act(() => result.current.dismissError());

      expect(result.current.state).toBe("previewing");
    });
  });

  describe("when the component goes away", () => {
    it("turns the camera off while previewing", async () => {
      const { unmount } = await previewing();

      unmount();

      expect(media.streams[0]?.allTracksStopped).toBe(true);
    });

    it("stops the recorder and the camera while recording, without a recording", async () => {
      const { result, unmount } = await recording();

      unmount();

      expect(media.recorders[0]?.stop).toHaveBeenCalledTimes(1);
      expect(media.streams[0]?.allTracksStopped).toBe(true);
      expect(result.current.recording).toBeNull();
    });

    it("turns the camera off if the user allows it after the component is gone", async () => {
      const allow = holdNextRequest();
      const late = new FakeMediaStream();

      const { result, unmount } = renderHook(() => useRecorder());
      act(() => void result.current.requestAccess());
      unmount();
      await act(async () => allow(late));

      expect(late.allTracksStopped).toBe(true);
    });
  });

  describe("the time limit", () => {
    const LIMIT_MS = 60_000;

    async function recordingWithLimit(limit = LIMIT_MS) {
      const hook = renderHook(() => useRecorder(limit));
      await act(async () => hook.result.current.requestAccess());
      act(() => hook.result.current.start());
      return hook;
    }

    afterEach(() => {
      vi.useRealTimers();
    });

    it("limits a recording to 5 minutes unless it is told otherwise", async () => {
      vi.useFakeTimers();
      const { result } = await recording();

      act(() => vi.advanceTimersByTime(MAX_RECORDING_MS - 1));
      expect(result.current.state).toBe("recording");

      act(() => vi.advanceTimersByTime(1));
      expect(result.current.state).toBe("recorded");
      expect(result.current.recording?.stoppedBy).toBe("limit");
    });

    it("stops at the limit, keeps what was recorded, and turns the camera off", async () => {
      vi.useFakeTimers();
      const { result } = await recordingWithLimit();

      act(() => vi.advanceTimersByTime(LIMIT_MS - 1));
      expect(result.current.state).toBe("recording");

      act(() => vi.advanceTimersByTime(1));

      expect(result.current.state).toBe("recorded");
      expect(result.current.recording).toMatchObject({ stoppedBy: "limit", durationMs: LIMIT_MS });
      expect(result.current.recording?.blob.size).toBeGreaterThan(0);
      expect(media.streams[0]?.allTracksStopped).toBe(true);
    });

    it("reports a stop by the user as the user", async () => {
      vi.useFakeTimers();
      const { result } = await recordingWithLimit();

      act(() => vi.advanceTimersByTime(10_000));
      act(() => result.current.stop());

      expect(result.current.recording?.stoppedBy).toBe("user");
    });

    it("does not stop again at the limit after the user stopped it", async () => {
      vi.useFakeTimers();
      const { result } = await recordingWithLimit();

      act(() => result.current.stop());
      act(() => vi.advanceTimersByTime(LIMIT_MS * 2));

      expect(media.recorders[0]?.stop).toHaveBeenCalledTimes(1);
      expect(result.current.recording?.stoppedBy).toBe("user");
    });

    it("times a second recording from its own start", async () => {
      vi.useFakeTimers();
      const { result } = await recordingWithLimit();
      act(() => vi.advanceTimersByTime(LIMIT_MS));

      await act(async () => result.current.requestAccess());
      act(() => result.current.start());
      act(() => vi.advanceTimersByTime(LIMIT_MS - 1));
      expect(result.current.state).toBe("recording");

      act(() => vi.advanceTimersByTime(1));
      expect(result.current.state).toBe("recorded");
    });

    it("stops from the recorder's own data event when the timer is late, as in a background tab", async () => {
      // Fake timers are not used: the limit timer never fires, as if the tab were asleep.
      const now = vi.spyOn(performance, "now");
      now.mockReturnValue(1000);
      const { result } = await recordingWithLimit();
      const recorder = media.recorders[0]!;

      now.mockReturnValue(1000 + LIMIT_MS - 1);
      act(() => recorder.ondataavailable?.({ data: new Blob(["chunk"]) }));
      expect(result.current.state).toBe("recording");

      now.mockReturnValue(1000 + LIMIT_MS + 400);
      act(() => recorder.ondataavailable?.({ data: new Blob(["chunk"]) }));

      expect(result.current.state).toBe("recorded");
      expect(result.current.recording?.stoppedBy).toBe("limit");
    });

    it("clears the timer when the component goes away", async () => {
      vi.useFakeTimers();
      const { unmount } = await recordingWithLimit();

      unmount();

      expect(vi.getTimerCount()).toBe(0);
    });
  });
});
