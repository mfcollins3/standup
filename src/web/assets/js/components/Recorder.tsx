import { useEffect, useRef } from "react";

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
import { saveRecording } from "@/js/recording/recordingStore";
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
    if (!recording || reported.current === recording || recordedFor === null) return;

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

      <div className="flex gap-2">
        {(state === "idle" || state === "error" || state === "requesting" || state === "recorded") &&
          canRetry && (
            <button
              type="button"
              className="btn btn-primary"
              disabled={noProject || state === "requesting"}
              onClick={() => void requestAccess()}
            >
              {state === "recorded"
                ? "Record another"
                : state === "error"
                  ? "Try again"
                  : "Enable camera and microphone"}
            </button>
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
