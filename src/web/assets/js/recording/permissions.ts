import { useEffect, useState } from "react";

/**
 * Whether the browser has blocked the camera or the microphone for this site.
 *
 * It asks with the Permissions API, which does not show a prompt, so the page can
 * explain what to do before the user clicks. It also notices when the user
 * changes the permission, so the explanation goes away once the camera is allowed.
 *
 * It is `false` where the browser cannot say: Firefox does not support these
 * permission names, and Safari may not. The error from `getUserMedia` is still
 * what decides the message, so this is only an early warning.
 */
export function useCameraBlocked(): boolean {
  const [blocked, setBlocked] = useState(false);

  useEffect(() => {
    const permissions = typeof navigator === "undefined" ? undefined : navigator.permissions;
    if (typeof permissions?.query !== "function") return;

    let cancelled = false;
    const statuses: PermissionStatus[] = [];

    const update = () => {
      if (!cancelled) setBlocked(statuses.some((status) => status.state === "denied"));
    };

    for (const name of ["camera", "microphone"]) {
      permissions
        .query({ name: name as PermissionName })
        .then((status) => {
          if (cancelled) return;

          statuses.push(status);
          status.addEventListener("change", update);
          update();
        })
        .catch(() => {
          // This browser does not know the permission. Nothing to show early.
        });
    }

    return () => {
      cancelled = true;
      statuses.forEach((status) => status.removeEventListener("change", update));
    };
  }, []);

  return blocked;
}
