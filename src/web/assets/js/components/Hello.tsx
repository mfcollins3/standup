import { useState } from "react";

import type { IslandProps } from "@/js/hooks/react_island";

type HelloProps = IslandProps<{ name: string }>;

/**
 * A sample island that shows props from the server and sends an event back.
 * It is only used by the development-only page at `/dev/react-island`.
 */
export function Hello({ name, pushEvent }: HelloProps) {
  const [count, setCount] = useState(0);

  return (
    <div className="space-y-2">
      <p>Hello, {name}! This is a React component.</p>
      <button
        type="button"
        className="btn btn-primary"
        onClick={() => {
          const next = count + 1;
          setCount(next);
          pushEvent("clicked", { count: next });
        }}
      >
        Clicked {count} times
      </button>
    </div>
  );
}
