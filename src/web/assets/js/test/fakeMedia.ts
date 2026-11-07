import { vi, type Mock } from "vitest";

/**
 * Fakes for the browser's media APIs, which jsdom does not have: `getUserMedia`,
 * `MediaStream` and `MediaRecorder`. They record what the code under test does
 * with them.
 */

export class FakeTrack extends EventTarget {
  readonly stop = vi.fn();

  constructor(readonly kind: "video" | "audio") {
    super();
  }

  /**
   * Ends the track by itself, as when a camera is unplugged. Unlike `stop()`, which
   * the app calls, this fires the `ended` event.
   */
  end(): void {
    this.dispatchEvent(new Event("ended"));
  }
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

export class FakePermissionStatus extends EventTarget {
  constructor(public state: PermissionState) {
    super();
  }
}

export type DevicePermission = "camera" | "microphone";

export interface FakePermissions {
  /** What the app calls to ask the browser about a permission. */
  query: Mock<(descriptor: { name: string }) => Promise<FakePermissionStatus>>;
  /** Changes a permission, as when the user allows or blocks the camera in the browser's settings. */
  set(name: DevicePermission, state: PermissionState): void;
  restore(): void;
}

export interface FakePermissionsOptions {
  /** The state of each permission, `prompt` unless it is given. */
  states?: Partial<Record<DevicePermission, PermissionState>>;
  /** Make `query` reject, as Firefox does for the camera and microphone. */
  rejectQuery?: boolean;
}

/** Installs a fake Permissions API. Call `restore()` in `afterEach`. */
export function installFakePermissions({
  states = {},
  rejectQuery = false,
}: FakePermissionsOptions = {}): FakePermissions {
  const statuses: Record<DevicePermission, FakePermissionStatus> = {
    camera: new FakePermissionStatus(states.camera ?? "prompt"),
    microphone: new FakePermissionStatus(states.microphone ?? "prompt"),
  };

  const query = vi.fn(async (descriptor: { name: string }) => {
    if (rejectQuery) throw new TypeError(`'${descriptor.name}' is not a valid permission name`);

    return statuses[descriptor.name as DevicePermission];
  });

  Object.defineProperty(navigator, "permissions", { configurable: true, value: { query } });

  return {
    query,
    set: (name, state) => {
      statuses[name].state = state;
      statuses[name].dispatchEvent(new Event("change"));
    },
    restore: () => {
      Reflect.deleteProperty(navigator, "permissions");
    },
  };
}
