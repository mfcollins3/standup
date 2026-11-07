import { useEffect, useState } from "react";

/** How many seconds are left when the screen reader is told, longest first. */
export const MILESTONES_SECONDS = [60, 30, 10] as const;

/** How often, in milliseconds, the clock looks at the time. It only renders when the second changes. */
const CHECK_MS = 250;

/** Formats seconds as `m:ss`. */
export function formatClock(totalSeconds: number): string {
  const seconds = Math.max(0, Math.floor(totalSeconds));
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}

/** The whole seconds that have passed since `startedAt`, or 0 when nothing is recording. */
export function useElapsedSeconds(startedAt: number | null): number {
  const read = () => (startedAt === null ? 0 : Math.floor((performance.now() - startedAt) / 1000));
  const [seconds, setSeconds] = useState(read);

  useEffect(() => {
    // Read the time from the clock each time, rather than counting ticks, so the
    // timer cannot drift, and a tab in the background catches up when it wakes.
    const update = () => setSeconds(read());
    update();

    if (startedAt === null) return;

    const timer = setInterval(update, CHECK_MS);
    document.addEventListener("visibilitychange", update);

    return () => {
      clearInterval(timer);
      document.removeEventListener("visibilitychange", update);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [startedAt]);

  return seconds;
}

/**
 * What to tell a screen reader about the time left: the last milestone that has
 * been passed, or null before the first. Only milestones that are shorter than
 * the limit count, so a short limit does not announce at the start.
 */
export function milestoneMessage(remainingSeconds: number, limitSeconds: number): string | null {
  const reached = MILESTONES_SECONDS.filter(
    (milestone) => milestone < limitSeconds && remainingSeconds <= milestone,
  ).at(-1);

  if (reached === undefined) return null;

  return reached === 60 ? "1 minute left." : `${reached} seconds left.`;
}

/** The limit in words, for example `5 minute` or `20 second`. */
export function describeLimit(limitMs: number): string {
  const seconds = Math.round(limitMs / 1000);
  return seconds % 60 === 0 ? `${seconds / 60} minute` : `${seconds} second`;
}
