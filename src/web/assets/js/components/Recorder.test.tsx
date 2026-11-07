import { act, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi, type Mock } from "vitest";

import type { PushEvent } from "@/js/hooks/react_island";
import { clearRecording, getRecording } from "@/js/recording/recordingStore";
import {
  installFakeMedia,
  installFakePermissions,
  type FakeMedia,
  type FakePermissions,
} from "../test/fakeMedia";
import { Recorder } from "./Recorder";

const PROJECT = "7d1c8d3a-1f4e-4a53-8f0b-5f0e2d9a1b01";
const OTHER_PROJECT = "7d1c8d3a-1f4e-4a53-8f0b-5f0e2d9a1b02";

const CHROME =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
const SAFARI =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15";

describe("Recorder", () => {
  let media: FakeMedia;
  let permissions: FakePermissions | undefined;
  let pushEvent: Mock<PushEvent>;

  beforeEach(() => {
    media = installFakeMedia({ supportedTypes: ["video/webm;codecs=vp9,opus", "video/webm"] });
    pushEvent = vi.fn<PushEvent>();
  });

  afterEach(() => {
    media.restore();
    permissions?.restore();
    permissions = undefined;
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

  describe("when the camera cannot be used", () => {
    async function fail(name: string) {
      const user = userEvent.setup();
      media.rejectWith(name);
      renderRecorder();
      await user.click(enable());
      return { user, alert: await screen.findByRole("alert") };
    }

    it.each([
      ["NotAllowedError", /blocked the camera and microphone/],
      ["NotFoundError", /No camera or microphone was found/],
      ["NotReadableError", /being used by another app/],
      ["AbortError", /could not be started/],
    ])("tells the user what happened for %s", async (name, title) => {
      const { alert } = await fail(name);

      expect(alert).toHaveTextContent(title);
      expect(screen.queryByLabelText("Camera preview")).not.toBeInTheDocument();
    });

    it.each(["NotAllowedError", "NotFoundError", "NotReadableError", "AbortError"])(
      "says what to do, in numbered steps, for %s",
      async (name) => {
        const { alert } = await fail(name);

        const steps = within(alert).getAllByRole("listitem");
        expect(steps.length).toBeGreaterThanOrEqual(2);
        expect(alert).toHaveTextContent(/Press Try again/);
      },
    );

    it("gives Chrome's steps to a user of Chrome", async () => {
      vi.spyOn(navigator, "userAgent", "get").mockReturnValue(CHROME);

      const { alert } = await fail("NotAllowedError");

      expect(alert).toHaveTextContent(/address bar/);
      expect(alert).not.toHaveTextContent(/Settings for This Website/);
    });

    it("gives Safari's steps to a user of Safari", async () => {
      vi.spyOn(navigator, "userAgent", "get").mockReturnValue(SAFARI);

      const { alert } = await fail("NotAllowedError");

      expect(alert).toHaveTextContent(/Settings for This Website/);
      expect(alert).not.toHaveTextContent(/address bar/);
    });

    it("offers Try again, which turns the camera on once the problem is fixed", async () => {
      const { user } = await fail("NotAllowedError");
      expect(screen.queryByRole("button", { name: "Enable camera and microphone" })).toBeNull();

      await user.click(screen.getByRole("button", { name: "Try again" }));

      expect(await screen.findByRole("button", { name: "Start recording" })).toBeInTheDocument();
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    });

    it("explains an unsupported browser, and cannot be tried again", () => {
      media.restore();
      media = installFakeMedia({ withMediaDevices: false });

      renderRecorder();

      const alert = screen.getByRole("alert");
      expect(alert).toHaveTextContent(/can't record video/);
      expect(alert).toHaveTextContent(/Chrome, Edge or Safari/);
      expect(alert).toHaveTextContent(/https/);
      expect(screen.queryByRole("button")).not.toBeInTheDocument();
    });
  });

  describe("when the browser says that the camera is blocked", () => {
    const blockedHelp = () => screen.queryByText(/blocked the camera and microphone/);

    it("explains how to allow it before the user clicks anything", async () => {
      permissions = installFakePermissions({ states: { camera: "denied" } });

      renderRecorder();

      const help = await screen.findByText(/blocked the camera and microphone/);
      expect(help.closest("[role=status]")).toHaveTextContent(/Press Try again/);
      expect(media.getUserMedia).not.toHaveBeenCalled();
    });

    it("says nothing when the camera is not blocked", async () => {
      permissions = installFakePermissions({ states: { camera: "granted" } });

      renderRecorder();
      await vi.waitFor(() => expect(permissions?.query).toHaveBeenCalledTimes(2));

      expect(blockedHelp()).not.toBeInTheDocument();
    });

    it("takes the explanation away when the user allows the camera", async () => {
      permissions = installFakePermissions({ states: { camera: "denied" } });
      renderRecorder();
      await screen.findByText(/blocked the camera and microphone/);

      act(() => permissions?.set("camera", "granted"));

      expect(blockedHelp()).not.toBeInTheDocument();
    });

    it("shows the explanation once, not twice, after a blocked click", async () => {
      const user = userEvent.setup();
      permissions = installFakePermissions({ states: { camera: "denied" } });
      media.rejectWith("NotAllowedError");
      renderRecorder();
      await screen.findByText(/blocked the camera and microphone/);

      await user.click(enable());
      await screen.findByRole("alert");

      expect(screen.getAllByText(/blocked the camera and microphone/)).toHaveLength(1);
    });

    it("clears the out-of-date error when the user allows the camera afterwards", async () => {
      const user = userEvent.setup();
      permissions = installFakePermissions({ states: { camera: "denied" } });
      media.rejectWith("NotAllowedError");
      renderRecorder();
      await screen.findByText(/blocked the camera and microphone/);
      await user.click(enable());
      await screen.findByRole("alert");

      act(() => permissions?.set("camera", "granted"));

      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
      expect(enable()).toBeEnabled();
    });
  });

  describe("when the camera stops during a recording", () => {
    it("ends the recording, keeps it, and tells the user", async () => {
      const { user } = await renderAndStart();

      act(() => media.streams[0]?.tracks[0]?.end());

      const alert = await screen.findByRole("alert");
      expect(alert).toHaveTextContent(/stopped during the recording/);
      expect(alert).toHaveTextContent(/ended early/);
      expect(alert).toHaveTextContent(/kept/);
      expect(getRecording(PROJECT)).toBeDefined();
      expect(pushEvent).toHaveBeenCalledWith("recording_complete", expect.objectContaining({ project_id: PROJECT }));
      expect(screen.queryByRole("button", { name: "Stop recording" })).not.toBeInTheDocument();
      expect(screen.getByRole("button", { name: "Record another" })).toBeEnabled();
      await user.click(screen.getByRole("button", { name: "Record another" }));
      expect(await screen.findByRole("button", { name: "Start recording" })).toBeInTheDocument();
      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    });

    it("does not warn when the user stops the recording", async () => {
      const { user } = await renderAndStart();

      await user.click(screen.getByRole("button", { name: "Stop recording" }));

      expect(screen.queryByRole("alert")).not.toBeInTheDocument();
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
