import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi, type Mock } from "vitest";

import type { PushEvent } from "@/js/hooks/react_island";
import { clearRecording, getRecording } from "@/js/recording/recordingStore";
import { installFakeMedia, type FakeMedia } from "../test/fakeMedia";
import { Recorder } from "./Recorder";

const PROJECT = "7d1c8d3a-1f4e-4a53-8f0b-5f0e2d9a1b01";
const OTHER_PROJECT = "7d1c8d3a-1f4e-4a53-8f0b-5f0e2d9a1b02";

describe("Recorder", () => {
  let media: FakeMedia;
  let pushEvent: Mock<PushEvent>;

  beforeEach(() => {
    media = installFakeMedia({ supportedTypes: ["video/webm;codecs=vp9,opus", "video/webm"] });
    pushEvent = vi.fn<PushEvent>();
  });

  afterEach(() => {
    media.restore();
    clearRecording(PROJECT);
    clearRecording(OTHER_PROJECT);
    vi.restoreAllMocks();
  });

  const enable = () => screen.getByRole("button", { name: "Enable camera and microphone" });

  function renderRecorder(projectId: string | null = PROJECT) {
    return render(<Recorder projectId={projectId} pushEvent={pushEvent} />);
  }

  /** Renders the recorder, turns the camera on, and starts recording. */
  async function renderAndStart(projectId: string | null = PROJECT) {
    const user = userEvent.setup();
    const view = renderRecorder(projectId);

    await user.click(enable());
    await user.click(await screen.findByRole("button", { name: "Start recording" }));

    return { user, ...view };
  }

  describe("before a project is chosen", () => {
    it("asks the user to choose one, and cannot be turned on", () => {
      renderRecorder(null);

      expect(screen.getByRole("status")).toHaveTextContent("Choose a project to start.");
      expect(enable()).toBeDisabled();
    });

    it("can be turned on once a project is chosen", () => {
      const { rerender } = renderRecorder(null);

      rerender(<Recorder projectId={PROJECT} pushEvent={pushEvent} />);

      expect(enable()).toBeEnabled();
    });
  });

  describe("asking for permission", () => {
    it("does not ask for the camera until the user clicks", () => {
      renderRecorder();

      expect(media.getUserMedia).not.toHaveBeenCalled();
    });

    it("asks for the camera and microphone, and shows a live preview", async () => {
      const user = userEvent.setup();
      renderRecorder();

      await user.click(enable());

      const preview = await screen.findByLabelText("Camera preview");
      expect(media.getUserMedia).toHaveBeenCalledTimes(1);
      expect(preview).toBeVisible();
      expect((preview as HTMLVideoElement).srcObject).toBe(media.streams[0]);
      expect(preview).toHaveProperty("muted", true);
      expect(screen.getByRole("status")).toHaveTextContent(/Press Start recording/);
    });

    it("does not offer screen recording", async () => {
      await renderAndStart();

      expect(media.getDisplayMedia).not.toHaveBeenCalled();
      expect(screen.queryByText(/screen/i)).not.toBeInTheDocument();
    });
  });

  describe("when permission cannot be given", () => {
    it.each([
      ["NotAllowedError", /denied/],
      ["NotFoundError", /No camera or microphone was found/],
      ["NotReadableError", /used by another app/],
    ])("tells the user about %s", async (name, message) => {
      const user = userEvent.setup();
      media.rejectWith(name);
      renderRecorder();

      await user.click(enable());

      expect(await screen.findByRole("alert")).toHaveTextContent(message);
      expect(screen.queryByLabelText("Camera preview")).not.toBeInTheDocument();
    });

    it("lets the user try again", async () => {
      const user = userEvent.setup();
      media.rejectWith("NotAllowedError");
      renderRecorder();
      await user.click(enable());
      await screen.findByRole("alert");

      await user.click(enable());

      expect(await screen.findByRole("button", { name: "Start recording" })).toBeInTheDocument();
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    });

    it("explains an unsupported browser and offers no controls", () => {
      media.restore();
      media = installFakeMedia({ withMediaDevices: false });

      renderRecorder();

      expect(screen.getByRole("alert")).toHaveTextContent(/can't record video/);
      expect(screen.queryByRole("button")).not.toBeInTheDocument();
    });
  });

  describe("recording", () => {
    it("cannot start without a project", async () => {
      const user = userEvent.setup();
      const { rerender } = renderRecorder();
      await user.click(enable());
      await screen.findByRole("button", { name: "Start recording" });

      rerender(<Recorder projectId={null} pushEvent={pushEvent} />);

      expect(screen.getByRole("button", { name: "Start recording" })).toBeDisabled();
    });

    it("shows a stop control while recording", async () => {
      await renderAndStart();

      expect(screen.getByRole("status")).toHaveTextContent("Recording.");
      expect(screen.getByRole("button", { name: "Stop recording" })).toBeEnabled();
      expect(media.recorders[0]?.start).toHaveBeenCalledTimes(1);
    });

    it("keeps the recording and tells the server when it stops", async () => {
      const now = vi.spyOn(performance, "now");
      now.mockReturnValue(2000);
      const { user } = await renderAndStart();
      now.mockReturnValue(5500);

      await user.click(screen.getByRole("button", { name: "Stop recording" }));

      expect(pushEvent).toHaveBeenCalledWith("recording_complete", {
        project_id: PROJECT,
        mime_type: "video/webm;codecs=vp9,opus",
        size: "video-bytes".length,
        duration_ms: 3500,
      });
      expect(getRecording(PROJECT)).toMatchObject({
        mimeType: "video/webm;codecs=vp9,opus",
        durationMs: 3500,
      });
      expect(getRecording(PROJECT)?.blob.size).toBe("video-bytes".length);
    });

    it("turns the camera off and removes the preview when it stops", async () => {
      const { user } = await renderAndStart();

      await user.click(screen.getByRole("button", { name: "Stop recording" }));

      expect(media.streams[0]?.allTracksStopped).toBe(true);
      expect(screen.queryByLabelText("Camera preview")).not.toBeInTheDocument();
      expect(screen.getByRole("status")).toHaveTextContent("Recording finished.");
    });

    it("keeps the recording for the project it was started for", async () => {
      const { user, rerender } = await renderAndStart();

      // The page changes the project while the recording is still going. (The
      // real page does not allow that, but the recording must not depend on it.)
      rerender(<Recorder projectId={OTHER_PROJECT} pushEvent={pushEvent} />);

      await user.click(screen.getByRole("button", { name: "Stop recording" }));

      expect(getRecording(PROJECT)).toBeDefined();
      expect(getRecording(OTHER_PROJECT)).toBeUndefined();
    });

    it("can record another report", async () => {
      const { user } = await renderAndStart();
      await user.click(screen.getByRole("button", { name: "Stop recording" }));

      await user.click(screen.getByRole("button", { name: "Record another" }));

      expect(await screen.findByRole("button", { name: "Start recording" })).toBeInTheDocument();
      expect(media.streams).toHaveLength(2);
    });
  });

  describe("telling the server where the recorder is", () => {
    it("reports each state once, and not the starting state", async () => {
      const { user } = await renderAndStart();
      await user.click(screen.getByRole("button", { name: "Stop recording" }));

      const states = pushEvent.mock.calls
        .filter(([event]) => event === "recorder_state")
        .map(([, payload]) => (payload as { state: string }).state);

      expect(states).toEqual(["requesting", "previewing", "recording", "recorded"]);
    });
  });
});
