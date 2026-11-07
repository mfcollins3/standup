/** The browsers that the app gives different instructions for. */
export type BrowserFamily = "chrome" | "edge" | "safari" | "other";

/**
 * Works out which browser is running, from its user agent, so that the help for
 * a blocked camera can name the right menus.
 *
 * Edge, Chrome and Safari all put "Safari" in their user agent, and Edge and
 * Opera put "Chrome" in it, so the order of the checks matters. Every browser on
 * an iPhone or iPad uses Safari's engine, and they are all set up in the Settings
 * app and not in a menu, so they count as `other`.
 */
export function detectBrowser(userAgent: string = navigator.userAgent): BrowserFamily {
  if (/\b(iPhone|iPad|iPod)\b/.test(userAgent)) return "other";
  if (/\b(CriOS|FxiOS|EdgiOS|OPiOS)\//.test(userAgent)) return "other";
  if (/\b(OPR|Opera)\//.test(userAgent)) return "other";
  if (/\bEdg(e|A)?\//.test(userAgent)) return "edge";
  // No word boundary before "Chrome": headless builds say "HeadlessChrome".
  if (/(Chrome|Chromium)\//.test(userAgent)) return "chrome";
  if (/\bSafari\//.test(userAgent) && !/\bAndroid\b/.test(userAgent)) return "safari";
  return "other";
}
