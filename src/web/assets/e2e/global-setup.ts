/**
 * Waits for the Vite dev server, which serves the page's JavaScript.
 *
 * Phoenix starts it as a watcher, and it can finish starting after Phoenix is
 * already answering, so a page that is loaded too early has no JavaScript.
 */
export default async function globalSetup(): Promise<void> {
  const url = "http://localhost:5173/@vite/client";
  const deadline = Date.now() + 120_000;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {
      // Not listening yet.
    }

    await new Promise((resolve) => setTimeout(resolve, 500));
  }

  throw new Error(`The Vite dev server did not start: ${url}`);
}
