import type { Recording } from "./useRecorder";

/**
 * Keeps the most recent recording for each project, in memory.
 *
 * Nothing leaves the browser yet. Reviewing a recording reads from here, and
 * so will uploading it (NS-015). A recording stays until the user discards it,
 * even if they choose another project meanwhile, and the video is gone when the
 * page is closed.
 */
const recordings = new Map<string, Recording>();

export function saveRecording(projectId: string, recording: Recording): void {
  recordings.set(projectId, recording);
}

export function getRecording(projectId: string): Recording | undefined {
  return recordings.get(projectId);
}

export function clearRecording(projectId: string): void {
  recordings.delete(projectId);
}

/** Whether any recording is being kept, so that leaving the page would lose it. */
export function hasRecordings(): boolean {
  return recordings.size > 0;
}
