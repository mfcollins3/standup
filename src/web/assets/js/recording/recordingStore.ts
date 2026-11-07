import type { Recording } from "./useRecorder";

/**
 * Keeps the most recent recording for each project, in memory.
 *
 * Nothing leaves the browser yet. Reviewing a recording and uploading it
 * (NS-010's later criteria and NS-015) read from here, and the video is gone
 * when the page is closed.
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
