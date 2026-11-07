import { act, fireEvent, render, screen, within } from "@testing-library/react";
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

  let createObjectURL: Mock<(blob: Blob) => string>;
  let revokeObjectURL: Mock<(url: string) => void>;

  beforeEach(() => {
    let urls = 0;
    createObjectURL = vi.fn((_blob: Blob) => "blob:recording-" + ++urls);
    revokeObjectURL = vi.fn();
    URL.createObjectURL = createObjectURL;
    URL.revokeObjectURL = revokeObjectURL;
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
      expect(screen.getByRole("button", { name: "Record again" })).toBeEnabled();
      await user.click(screen.getByRole("button", { name: "Record again" }));
      await user.click(screen.getByRole("button", { name: "Delete and record again" }));
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
        stopped_by: "user",
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

  });

  describe("reviewing a recording", () => {
    async function recorded() {
      const started = await renderAndStart();
      await started.user.click(screen.getByRole("button", { name: "Stop recording" }));
      return started;
    }

    const reviewer = () => screen.getByLabelText("Your recording") as HTMLVideoElement;

    it("plays the recording back in a labelled player with controls", async () => {
      await recorded();

      expect(createObjectURL).toHaveBeenCalledWith(getRecording(PROJECT)?.blob);
      expect(reviewer()).toHaveAttribute("src", "blob:recording-1");
      expect(reviewer()).toHaveAttribute("controls");
    });

    it("offers Record again and Discard, and not Record another", async () => {
      await recorded();

      expect(screen.getByRole("button", { name: "Record again" })).toBeEnabled();
      expect(screen.getByRole("button", { name: "Discard" })).toBeEnabled();
      expect(screen.queryByRole("button", { name: "Record another" })).not.toBeInTheDocument();
    });

    it("revokes the playback URL when the page is left", async () => {
      const { unmount } = await recorded();

      unmount();

      expect(revokeObjectURL).toHaveBeenCalledWith("blob:recording-1");
    });

    describe("discarding", () => {
      it("asks first, and keeps the recording when the user cancels", async () => {
        const { user } = await recorded();

        await user.click(screen.getByRole("button", { name: "Discard" }));

        const dialog = screen.getByRole("alertdialog", { name: "Discard this recording?" });
        expect(dialog).toHaveAccessibleDescription(/cannot get it back/);
        expect(screen.getByRole("button", { name: "Keep recording" })).toHaveFocus();
        expect(getRecording(PROJECT)).toBeDefined();

        await user.click(screen.getByRole("button", { name: "Keep recording" }));

        expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
        expect(getRecording(PROJECT)).toBeDefined();
        expect(reviewer()).toBeInTheDocument();
        expect(revokeObjectURL).not.toHaveBeenCalled();
        expect(pushEvent).not.toHaveBeenCalledWith("recording_discarded", expect.anything());
      });

      it("cancels with Escape and puts the focus back on the button", async () => {
        const { user } = await recorded();
        await user.click(screen.getByRole("button", { name: "Discard" }));

        await user.keyboard("{Escape}");

        expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
        await vi.waitFor(() => expect(screen.getByRole("button", { name: "Discard" })).toHaveFocus());
        expect(getRecording(PROJECT)).toBeDefined();
      });

      it("throws the recording away once confirmed, and tells the server", async () => {
        const { user } = await recorded();
        await user.click(screen.getByRole("button", { name: "Discard" }));

        await user.click(screen.getByRole("button", { name: "Discard recording" }));

        expect(getRecording(PROJECT)).toBeUndefined();
        expect(pushEvent).toHaveBeenCalledWith("recording_discarded", { project_id: PROJECT });
        expect(revokeObjectURL).toHaveBeenCalledWith("blob:recording-1");
        expect(screen.queryByLabelText("Your recording")).not.toBeInTheDocument();
        expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
        expect(enable()).toBeEnabled();
        expect(screen.getByRole("status")).toHaveTextContent(/Turn on your camera/);
      });
    });

    describe("recording again", () => {
      it("asks first, and keeps the recording when the user cancels", async () => {
        const { user } = await recorded();

        await user.click(screen.getByRole("button", { name: "Record again" }));
        expect(screen.getByRole("alertdialog", { name: "Record again?" })).toBeInTheDocument();
        await user.click(screen.getByRole("button", { name: "Keep recording" }));

        expect(getRecording(PROJECT)).toBeDefined();
        expect(media.streams).toHaveLength(1);
        expect(reviewer()).toBeInTheDocument();
      });

      it("goes back to the camera preview for the same project once confirmed", async () => {
        const { user } = await recorded();
        await user.click(screen.getByRole("button", { name: "Record again" }));

        await user.click(screen.getByRole("button", { name: "Delete and record again" }));

        expect(await screen.findByLabelText("Camera preview")).toBeVisible();
        expect(media.streams).toHaveLength(2);
        expect(getRecording(PROJECT)).toBeUndefined();
        expect(pushEvent).toHaveBeenCalledWith("recording_discarded", { project_id: PROJECT });
        expect(revokeObjectURL).toHaveBeenCalledWith("blob:recording-1");

        await user.click(screen.getByRole("button", { name: "Start recording" }));
        await user.click(screen.getByRole("button", { name: "Stop recording" }));

        expect(getRecording(PROJECT)).toBeDefined();
        expect(reviewer()).toHaveAttribute("src", "blob:recording-2");
      });
    });

    describe("choosing another project", () => {
      it("keeps the first project's recording in memory and shows the new project's start", async () => {
        const { rerender } = await recorded();

        rerender(<Recorder projectId={OTHER_PROJECT} pushEvent={pushEvent} />);

        expect(getRecording(PROJECT)).toBeDefined();
        expect(screen.queryByLabelText("Your recording")).not.toBeInTheDocument();
        expect(enable()).toBeEnabled();
      });

      it("brings the first project's recording back when it is chosen again", async () => {
        const { rerender } = await recorded();
        rerender(<Recorder projectId={OTHER_PROJECT} pushEvent={pushEvent} />);
        pushEvent.mockClear();

        rerender(<Recorder projectId={PROJECT} pushEvent={pushEvent} />);

        expect(reviewer()).toBeInTheDocument();
        expect(pushEvent).toHaveBeenCalledWith(
          "recording_complete",
          expect.objectContaining({ project_id: PROJECT }),
        );
      });
    });

    describe("leaving the page", () => {
      const leave = () => {
        const event = new Event("beforeunload", { cancelable: true });
        window.dispatchEvent(event);
        return event;
      };

      it("asks the browser to confirm while a recording is kept", async () => {
        await recorded();

        expect(leave().defaultPrevented).toBe(true);
      });

      it("does not ask when nothing is kept", () => {
        renderRecorder();

        expect(leave().defaultPrevented).toBe(false);
      });

      it("stops asking once the recording is discarded", async () => {
        const { user } = await recorded();
        await user.click(screen.getByRole("button", { name: "Discard" }));
        await user.click(screen.getByRole("button", { name: "Discard recording" }));

        expect(leave().defaultPrevented).toBe(false);
      });
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

  describe("the clock and the time limit", () => {
    const LIMIT_MS = 120_000;

    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    /** Starts a recording with fake timers, which `userEvent` does not work well with. */
    async function startWithFakeTimers(maxDurationMs = LIMIT_MS) {
      const view = render(<Recorder projectId={PROJECT} maxDurationMs={maxDurationMs} pushEvent={pushEvent} />);

      fireEvent.click(enable());
      await act(async () => {});
      fireEvent.click(screen.getByRole("button", { name: "Start recording" }));

      return view;
    }

    const tick = (ms: number) => act(() => vi.advanceTimersByTime(ms));

    it("shows the elapsed and remaining time as m:ss next to the stop control", async () => {
      await startWithFakeTimers();

      const timer = screen.getByRole("timer");
      expect(timer).toHaveTextContent("Elapsed 0:00");
      expect(timer).toHaveTextContent("Remaining 2:00");

      tick(5_000);
      expect(timer).toHaveTextContent("Elapsed 0:05");
      expect(timer).toHaveTextContent("Remaining 1:55");

      tick(65_000);
      expect(timer).toHaveTextContent("Elapsed 1:10");
      expect(timer).toHaveTextContent("Remaining 0:50");
    });

    it("keeps the clock out of the live announcements", async () => {
      await startWithFakeTimers();

      expect(screen.getByRole("timer")).toHaveAttribute("aria-live", "off");
      expect(screen.getByRole("status")).not.toHaveTextContent("Elapsed");

      tick(5_000);

      expect(screen.getByRole("status")).toHaveTextContent("Recording.");
    });

    it("announces the time left at 1 minute, 30 seconds and 10 seconds only", async () => {
      await startWithFakeTimers();
      const status = screen.getByRole("status");
      const announced: string[] = [];

      // Look at the status after every second, as a screen reader would hear changes.
      for (let second = 0; second < 115; second++) {
        tick(1_000);
        const text = status.textContent ?? "";
        if (announced.at(-1) !== text) announced.push(text);
      }

      expect(announced).toEqual(["Recording.", "1 minute left.", "30 seconds left.", "10 seconds left."]);
    });

    it("does not announce a milestone that is longer than the limit", async () => {
      await startWithFakeTimers(20_000);

      expect(screen.getByRole("status")).toHaveTextContent("Recording.");

      tick(10_000);

      expect(screen.getByRole("status")).toHaveTextContent("10 seconds left.");
    });

    it("stops at the limit, keeps the recording, and tells the user", async () => {
      await startWithFakeTimers();

      tick(LIMIT_MS);

      expect(screen.queryByRole("button", { name: "Stop recording" })).not.toBeInTheDocument();
      expect(screen.getByRole("status")).toHaveTextContent("Recording stopped at the 2 minute limit.");
      expect(media.recorders[0]?.stop).toHaveBeenCalledTimes(1);
      expect(media.streams[0]?.allTracksStopped).toBe(true);
      expect(getRecording(PROJECT)).toMatchObject({ stoppedBy: "limit" });
      expect(pushEvent).toHaveBeenCalledWith(
        "recording_complete",
        expect.objectContaining({ project_id: PROJECT, stopped_by: "limit" }),
      );
    });

    it("says the 5 minute limit by default", async () => {
      render(<Recorder projectId={PROJECT} pushEvent={pushEvent} />);

      fireEvent.click(enable());
      await act(async () => {});
      fireEvent.click(screen.getByRole("button", { name: "Start recording" }));

      expect(screen.getByRole("timer")).toHaveTextContent("Remaining 5:00");

      tick(5 * 60 * 1000);

      expect(screen.getByRole("status")).toHaveTextContent("Recording stopped at the 5 minute limit.");
    });

    it("does not mention the limit when the user stops the recording", async () => {
      await startWithFakeTimers();
      tick(10_000);

      fireEvent.click(screen.getByRole("button", { name: "Stop recording" }));

      expect(screen.getByRole("status")).toHaveTextContent("Recording finished.");
      expect(pushEvent).toHaveBeenCalledWith(
        "recording_complete",
        expect.objectContaining({ stopped_by: "user" }),
      );
    });
  });
});
