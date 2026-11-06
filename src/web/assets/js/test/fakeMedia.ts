import { vi, type Mock } from "vitest";

/**
 * Fakes for the browser's media APIs, which jsdom does not have: `getUserMedia`,
 * `MediaStream` and `MediaRecorder`. They record what the code under test does
 * with them.
 */

export class FakeTrack {
  readonly stop = vi.fn();

  constructor(readonly kind: "video" | "audio") {}
}

export class FakeMediaStream {
  readonly tracks = [new FakeTrack("video"), new FakeTrack("audio")];

  getTracks(): FakeTrack[] {
    return this.tracks;
  }

  /** Whether every track has been stopped, which is what turns the camera light off. */
  get allTracksStopped(): boolean {
    return this.tracks.every((track) => track.stop.mock.calls.length > 0);
  }
}

export interface RecorderOptions {
  mimeType?: string;
  videoBitsPerSecond?: number;
  audioBitsPerSecond?: number;
}

export class FakeMediaRecorder {
  state: "inactive" | "recording" = "inactive";
  mimeType: string;
  ondataavailable: ((event: { data: Blob }) => void) | null = null;
  onstop: (() => void) | null = null;
  onerror: (() => void) | null = null;

  readonly start = vi.fn((_timeslice?: number) => {
    this.state = "recording";
  });

  /** Like a real recorder: hands over the last chunk, then reports that it stopped. */
  readonly stop = vi.fn(() => {
    this.state = "inactive";
    this.ondataavailable?.({ data: new Blob(["video-bytes"], { type: this.mimeType }) });
    this.onstop?.();
  });

  constructor(
    readonly stream: FakeMediaStream,
    readonly options: RecorderOptions = {},
  ) {
    this.mimeType = options.mimeType ?? "";
  }
}

export interface FakeMedia {
  /** What the app calls to turn on the camera and microphone. */
  getUserMedia: Mock<(constraints: MediaStreamConstraints) => Promise<FakeMediaStream>>;
  /** What the app calls to capture the screen. It must never be called. */
  getDisplayMedia: Mock;
  streams: FakeMediaStream[];
  recorders: FakeMediaRecorder[];
  /** Makes the next `getUserMedia` reject with an error of this name. */
  rejectWith(name: string): void;
  restore(): void;
}

export interface InstallOptions {
  /** The formats that `MediaRecorder.isTypeSupported` accepts. */
  supportedTypes?: string[];
  /** Install `getUserMedia` and `getDisplayMedia`. */
  withMediaDevices?: boolean;
  /** Install `MediaRecorder`. */
  withMediaRecorder?: boolean;
}

/** Installs the fakes. Call `restore()` in `afterEach`. */
export function installFakeMedia({
  supportedTypes = ["video/webm;codecs=vp9,opus", "video/webm"],
  withMediaDevices = true,
  withMediaRecorder = true,
}: InstallOptions = {}): FakeMedia {
  const streams: FakeMediaStream[] = [];
  const recorders: FakeMediaRecorder[] = [];
  let rejection: string | null = null;

  const getUserMedia = vi.fn(async (_constraints: MediaStreamConstraints) => {
    if (rejection) {
      const error = new Error("rejected");
      error.name = rejection;
      rejection = null;
      throw error;
    }

    const stream = new FakeMediaStream();
    streams.push(stream);
    return stream;
  });
  const getDisplayMedia = vi.fn();

  if (withMediaDevices) {
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: { getUserMedia, getDisplayMedia },
    });
  }

  if (withMediaRecorder) {
    class RecorderWithSupport extends FakeMediaRecorder {
      static isTypeSupported = vi.fn((type: string) => supportedTypes.includes(type));

      constructor(stream: FakeMediaStream, options?: RecorderOptions) {
        super(stream, options);
        recorders.push(this);
      }
    }

    vi.stubGlobal("MediaRecorder", RecorderWithSupport);
  }

  return {
    getUserMedia,
    getDisplayMedia,
    streams,
    recorders,
    rejectWith: (name) => {
      rejection = name;
    },
    restore: () => {
      Reflect.deleteProperty(navigator, "mediaDevices");
      vi.unstubAllGlobals();
    },
  };
}
