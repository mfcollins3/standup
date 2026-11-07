import { useEffect, useRef, useState } from "react";

import type { IslandProps } from "@/js/hooks/react_island";
import { detectBrowser } from "@/js/recording/browser";
import {
  describeLimit,
  formatClock,
  milestoneMessage,
  useElapsedSeconds,
} from "@/js/recording/clock";
import { MAX_RECORDING_MS } from "@/js/recording/constraints";
import { describeBlocked, describeError, describeWarning } from "@/js/recording/errors";
import { isRecordingSupported } from "@/js/recording/mediaSupport";
import { useCameraBlocked } from "@/js/recording/permissions";
import {
  clearRecording,
  getRecording,
  hasRecordings,
  saveRecording,
} from "@/js/recording/recordingStore";
import { useRecorder, type Recording, type RecorderState } from "@/js/recording/useRecorder";
import { HelpMessage } from "./HelpMessage";

type RecorderProps = IslandProps<{
  /** The project the report is for, or null until the user chooses one. */
  projectId: string | null;
  /** The longest recording, in milliseconds. The server sets it from config. */
  maxDurationMs?: number;
}>;

function statusText(
  state: RecorderState,
  hasProject: boolean,
  milestone: string | null,
  limitReached: boolean,
  maxDurationMs: number,
): string {
  switch (state) {
    case "idle":
    case "error":
      return hasProject
        ? "Turn on your camera and microphone to see a preview."
        : "Choose a project to start.";
    case "requesting":
      return "Waiting for permission to use your camera and microphone.";
    case "previewing":
      return "Your camera and microphone are on. Press Start recording when you are ready.";
    case "recording":
      return milestone ?? "Recording.";
    case "recorded":
      return limitReached
        ? `Recording stopped at the ${describeLimit(maxDurationMs)} limit.`
        : "Recording finished.";
  }
}

/** What the user is being asked to confirm. Both throw the recording away. */
type Confirming = "discard" | "record-again";

/**
 * Records a status report with the camera and microphone.
 *
 * The user chooses a project (on the server's page, which passes `projectId`),
 * turns the camera and microphone on, sees a live preview, and records. When the
 * recording stops it is kept in memory with its project, and the server is told
 * its size and length. Screen recording is not offered.
 */
export function Recorder({ projectId, maxDurationMs = MAX_RECORDING_MS, pushEvent }: RecorderProps) {
  const {
    state,
    error,
    warning,
    startedAt,
    stream,
    recording,
    requestAccess,
    start,
    stop,
    dismissError,
    reset,
    load,
  } = useRecorder(maxDurationMs);
  const elapsedSeconds = useElapsedSeconds(state === "recording" ? startedAt : null);
  const limitSeconds = Math.ceil(maxDurationMs / 1000);
  const remainingSeconds = Math.max(0, limitSeconds - elapsedSeconds);
  const blocked = useCameraBlocked();
  const browser = detectBrowser();

  const videoRef = useRef<HTMLVideoElement>(null);
  const previousState = useRef<RecorderState>("idle");
  const projectAtStart = useRef<string | null>(null);
  const reported = useRef<Recording | null>(null);
  const [confirming, setConfirming] = useState<Confirming | null>(null);
  const [playbackUrl, setPlaybackUrl] = useState<string | null>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);
  const discardRef = useRef<HTMLButtonElement>(null);
  const recordAgainRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (videoRef.current) videoRef.current.srcObject = stream;
  }, [stream]);

  // Tell the server where the recorder is, so that the page can stop the project
  // from being changed in the middle of a recording.
  useEffect(() => {
    if (previousState.current === state) return;

    previousState.current = state;
    pushEvent("recorder_state", { state });
  }, [state, pushEvent]);

  // Keep the recording for the project it was started for, and tell the server.
  useEffect(() => {
    const recordedFor = projectAtStart.current;
    if (!recording) {
      reported.current = null;
      return;
    }
    if (reported.current === recording || recordedFor === null) return;

    reported.current = recording;
    saveRecording(recordedFor, recording);
    pushEvent("recording_complete", {
      project_id: recordedFor,
      mime_type: recording.mimeType,
      size: recording.blob.size,
      duration_ms: recording.durationMs,
      stopped_by: recording.stoppedBy,
    });
  }, [recording, pushEvent]);

  // Play the recording back from an object URL, and let go of it as soon as the
  // recording is not shown any more (discarded, replaced, or the page is left).
  useEffect(() => {
    if (state !== "recorded" || !recording) {
      setPlaybackUrl(null);
      return;
    }

    const url = URL.createObjectURL(recording.blob);
    setPlaybackUrl(url);

    return () => URL.revokeObjectURL(url);
  }, [state, recording]);

  // Choosing another project leaves the first project's recording where it is,
  // in the store, and shows the new project's: its own recording if it has one,
  // or the start. Choosing the first project again brings its recording back.
  useEffect(() => {
    if (state === "recorded" && projectAtStart.current !== projectId) {
      setConfirming(null);
      reset();
    } else if (state === "idle" && projectId !== null) {
      const kept = getRecording(projectId);
      if (kept) {
        projectAtStart.current = projectId;
        load(kept);
      }
    }
  }, [state, projectId, reset, load]);

  // A kept recording only exists in this browser tab, so ask before it is lost.
  useEffect(() => {
    const onBeforeUnload = (event: BeforeUnloadEvent) => {
      if (!hasRecordings()) return;

      event.preventDefault();
      event.returnValue = "";
    };

    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, []);

  // Move the focus into the confirmation when it opens.
  useEffect(() => {
    if (confirming) cancelRef.current?.focus();
  }, [confirming]);

  // The user allowed the camera in the browser's settings after being told it was
  // blocked, so the message is out of date. Clear it, so they can try again.
  const wasBlocked = useRef(false);
  useEffect(() => {
    if (wasBlocked.current && !blocked && error === "permission-denied") dismissError();
    wasBlocked.current = blocked;
  }, [blocked, error, dismissError]);

  if (!isRecordingSupported()) {
    return <HelpMessage help={describeError("unsupported", browser)} role="alert" tone="error" />;
  }

  const noProject = projectId === null;

  const errorHelp = state === "error" && error ? describeError(error, browser) : null;
  // Before the user has clicked, say that the camera is blocked and how to allow
  // it. After a click that was blocked, the error says the same, so only one shows.
  const blockedHelp = blocked && state === "idle" ? describeBlocked(browser) : null;
  const canRetry = state !== "error" || (errorHelp?.canRetry ?? true);

  const cancelConfirmation = () => {
    const trigger = confirming === "discard" ? discardRef : recordAgainRef;
    setConfirming(null);
    // The buttons come back on the next render, so wait for them.
    requestAnimationFrame(() => trigger.current?.focus());
  };

  const confirmThrowAway = () => {
    const action = confirming;
    const discarded = projectAtStart.current;
    setConfirming(null);

    if (discarded !== null) {
      clearRecording(discarded);
      pushEvent("recording_discarded", { project_id: discarded });
    }
    reset();
    if (action === "record-again") void requestAccess();
  };

  const startRecording = () => {
    projectAtStart.current = projectId;
    start();
  };

  return (
    <div className="space-y-4">
      {stream && (
        <video
          ref={videoRef}
          aria-label="Camera preview"
          className="aspect-video w-full rounded-box bg-base-300"
          autoPlay
          muted
          playsInline
        />
      )}

      {state === "recorded" && playbackUrl && (
        <video
          key={playbackUrl}
          src={playbackUrl}
          aria-label="Your recording"
          className="aspect-video w-full rounded-box bg-base-300"
          controls
          playsInline
          preload="metadata"
        />
      )}

      <p role="status" aria-live="polite">
        {statusText(
          state,
          !noProject,
          milestoneMessage(remainingSeconds, limitSeconds),
          recording?.stoppedBy === "limit",
          maxDurationMs,
        )}
      </p>

      {blockedHelp && <HelpMessage help={blockedHelp} role="status" tone="warning" />}

      {errorHelp && <HelpMessage help={errorHelp} role="alert" tone="error" />}

      {state === "recorded" && warning && (
        <HelpMessage help={describeWarning(warning)} role="alert" tone="warning" />
      )}

      {state === "recorded" && confirming && (
        <div
          role="alertdialog"
          aria-labelledby="confirm-title"
          aria-describedby="confirm-description"
          className="space-y-3 rounded-box border border-warning p-4"
          onKeyDown={(event) => {
            if (event.key === "Escape") cancelConfirmation();
          }}
        >
          <p id="confirm-title" className="font-semibold">
            {confirming === "discard" ? "Discard this recording?" : "Record again?"}
          </p>
          <p id="confirm-description">
            {confirming === "discard"
              ? "The recording will be deleted. You cannot get it back."
              : "The recording will be deleted and replaced by a new one. You cannot get it back."}
          </p>
          <div className="flex gap-2">
            <button ref={cancelRef} type="button" className="btn" onClick={cancelConfirmation}>
              Keep recording
            </button>
            <button type="button" className="btn btn-error" onClick={confirmThrowAway}>
              {confirming === "discard" ? "Discard recording" : "Delete and record again"}
            </button>
          </div>
        </div>
      )}

      <div className="flex gap-2">
        {(state === "idle" || state === "error" || state === "requesting") && canRetry && (
          <button
            type="button"
            className="btn btn-primary"
            disabled={noProject || state === "requesting"}
            onClick={() => void requestAccess()}
          >
            {state === "error" ? "Try again" : "Enable camera and microphone"}
          </button>
        )}

        {state === "recorded" && !confirming && (
          <>
            <button
              ref={recordAgainRef}
              type="button"
              className="btn btn-primary"
              onClick={() => setConfirming("record-again")}
            >
              Record again
            </button>
            <button
              ref={discardRef}
              type="button"
              className="btn btn-outline btn-error"
              onClick={() => setConfirming("discard")}
            >
              Discard
            </button>
          </>
        )}

        {state === "previewing" && (
          <button type="button" className="btn btn-primary" disabled={noProject} onClick={startRecording}>
            Start recording
          </button>
        )}

        {state === "recording" && (
          <>
            <button type="button" className="btn btn-error" onClick={stop}>
              Stop recording
            </button>

            {/* Not a live region: a screen reader hears the milestones in the status instead. */}
            <p role="timer" aria-live="off" className="flex items-center gap-4 tabular-nums">
              <span>Elapsed {formatClock(elapsedSeconds)}</span>
              <span>Remaining {formatClock(remainingSeconds)}</span>
            </p>
          </>
        )}
      </div>
    </div>
  );
}
