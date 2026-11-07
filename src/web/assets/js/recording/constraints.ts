/**
 * What to ask the browser for, and how to record it.
 *
 * The numbers are named so that the recording limits and quality work (NS-014)
 * can tune them in one place. They keep a typical 30-second report small: 720p
 * at 30 frames per second with a capped bitrate.
 */

/** The camera and microphone to ask for. The camera facing the user is preferred. */
export const MEDIA_CONSTRAINTS: MediaStreamConstraints = {
  video: {
    width: { ideal: 1280 },
    height: { ideal: 720 },
    frameRate: { ideal: 30 },
    facingMode: "user",
  },
  audio: {
    echoCancellation: true,
    noiseSuppression: true,
  },
};

/** The video bitrate cap, in bits per second, to control storage cost. */
export const VIDEO_BITS_PER_SECOND = 1_500_000;

/** The audio bitrate, in bits per second. */
export const AUDIO_BITS_PER_SECOND = 64_000;

/** How often, in milliseconds, the recorder hands over the video recorded so far. */
export const TIMESLICE_MS = 1000;

/**
 * The longest recording, in milliseconds (5 minutes). The server passes the real
 * limit to the recorder from application config (NS-014), and this is what the
 * recorder uses when it is not given one. The limit is for the user: the server
 * is the one that enforces it.
 */
export const MAX_RECORDING_MS = 5 * 60 * 1000;

/** The options that cap the recording's bitrate. */
export const RECORDER_OPTIONS = {
  videoBitsPerSecond: VIDEO_BITS_PER_SECOND,
  audioBitsPerSecond: AUDIO_BITS_PER_SECOND,
} as const;
