import { useCallback, useEffect, useRef, useState } from "react";

import { MEDIA_CONSTRAINTS, RECORDER_OPTIONS, TIMESLICE_MS } from "./constraints";
import { mapMediaError, type RecorderErrorCode } from "./errors";
import { isRecordingSupported, pickMimeType } from "./mediaSupport";

/**
 * Where the recorder is:
 *
 * - `idle`: nothing is on. This is the start, and the state after a reset.
 * - `requesting`: waiting for the user to allow the camera and microphone.
 * - `previewing`: the camera and microphone are on and showing a preview.
 * - `recording`: recording.
 * - `recorded`: a recording is ready, and the camera and microphone are off.
 * - `error`: something failed. `error` says what.
 */
export type RecorderState = "idle" | "requesting" | "previewing" | "recording" | "recorded" | "error";

/** A finished recording. It lives in memory in the browser. */
export interface Recording {
  blob: Blob;
  /** The format that the browser recorded, for example `video/webm;codecs=vp9,opus`. */
  mimeType: string;
  durationMs: number;
}

export interface UseRecorder {
  state: RecorderState;
  /** Set when `state` is `error`. */
  error: RecorderErrorCode | null;
  /** The live camera and microphone, while previewing or recording. */
  stream: MediaStream | null;
  /** The latest recording, once `state` is `recorded`. */
  recording: Recording | null;
  /** Asks for the camera and microphone. Call it from a click, never on load. */
  requestAccess: () => Promise<void>;
  start: () => void;
  stop: () => void;
}

/**
 * Records the user's camera and microphone with `getUserMedia` and
 * `MediaRecorder`.
 *
 * It never asks for access by itself: the user has to click first. It always
 * stops every track of the stream when it is done, on an error, and when the
 * component goes away, so the camera light does not stay on.
 */
export function useRecorder(): UseRecorder {
  const [state, setState] = useState<RecorderState>("idle");
  const [error, setError] = useState<RecorderErrorCode | null>(null);
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [recording, setRecording] = useState<Recording | null>(null);

  // The state is also kept in a ref, so the callbacks can check it without being
  // recreated, and so they see the latest state in the middle of an async call.
  const stateRef = useRef<RecorderState>("idle");
  const streamRef = useRef<MediaStream | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const startedAtRef = useRef(0);
  const mountedRef = useRef(true);

  const transition = useCallback((next: RecorderState) => {
    stateRef.current = next;
    setState(next);
  }, []);

  const releaseStream = useCallback(() => {
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
    setStream(null);
  }, []);

  const fail = useCallback(
    (code: RecorderErrorCode) => {
      releaseStream();
      setError(code);
      transition("error");
    },
    [releaseStream, transition],
  );

  useEffect(() => {
    mountedRef.current = true;

    return () => {
      mountedRef.current = false;

      const recorder = recorderRef.current;
      if (recorder && recorder.state !== "inactive") {
        // The component is gone, so there is nobody to give the recording to.
        recorder.ondataavailable = null;
        recorder.onstop = null;
        recorder.stop();
      }
      recorderRef.current = null;

      streamRef.current?.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    };
  }, []);

  const requestAccess = useCallback(async () => {
    const current = stateRef.current;
    if (current === "requesting" || current === "previewing" || current === "recording") return;

    setError(null);

    if (!isRecordingSupported()) {
      fail("unsupported");
      return;
    }

    transition("requesting");

    try {
      const media = await navigator.mediaDevices.getUserMedia(MEDIA_CONSTRAINTS);

      if (!mountedRef.current) {
        media.getTracks().forEach((track) => track.stop());
        return;
      }

      streamRef.current = media;
      setStream(media);
      transition("previewing");
    } catch (caught) {
      if (mountedRef.current) fail(mapMediaError(caught));
    }
  }, [fail, transition]);

  const start = useCallback(() => {
    const media = streamRef.current;
    if (stateRef.current !== "previewing" || !media) return;

    const mimeType = pickMimeType();

    let recorder: MediaRecorder;
    try {
      recorder = new MediaRecorder(media, {
        ...RECORDER_OPTIONS,
        ...(mimeType ? { mimeType } : {}),
      });
    } catch {
      fail("unsupported");
      return;
    }

    chunksRef.current = [];

    recorder.ondataavailable = (event: BlobEvent) => {
      if (event.data.size > 0) chunksRef.current.push(event.data);
    };

    recorder.onstop = () => {
      const type = recorder.mimeType || mimeType || "video/webm";
      const blob = new Blob(chunksRef.current, { type });
      const durationMs = Math.round(performance.now() - startedAtRef.current);

      chunksRef.current = [];
      recorderRef.current = null;
      releaseStream();

      if (!mountedRef.current) return;

      setRecording({ blob, mimeType: type, durationMs });
      transition("recorded");
    };

    recorder.onerror = () => {
      chunksRef.current = [];
      recorderRef.current = null;
      if (mountedRef.current) fail("unknown");
    };

    recorderRef.current = recorder;
    startedAtRef.current = performance.now();
    recorder.start(TIMESLICE_MS);
    transition("recording");
  }, [fail, releaseStream, transition]);

  const stop = useCallback(() => {
    if (stateRef.current !== "recording") return;

    // `onstop` builds the recording, once the recorder has handed over the end.
    recorderRef.current?.stop();
  }, []);

  return { state, error, stream, recording, requestAccess, start, stop };
}
