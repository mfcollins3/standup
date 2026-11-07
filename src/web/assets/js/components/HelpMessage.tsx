import type { Help } from "@/js/recording/errors";

/** The look of each kind of message. The class names are written out in full so that Tailwind finds them. */
const TONES = {
  error: "alert alert-error alert-vertical items-start",
  warning: "alert alert-warning alert-vertical items-start",
} as const;

interface HelpMessageProps {
  help: Help;
  /**
   * `alert` is announced to screen readers at once, which is right for something
   * that just went wrong. `status` is announced politely, which is right for help
   * that was on the page before the user did anything.
   */
  role: "alert" | "status";
  tone: keyof typeof TONES;
}

/** Tells the user what happened and what to do, as a sentence and numbered steps. */
export function HelpMessage({ help, role, tone }: HelpMessageProps) {
  return (
    <div role={role} className={TONES[tone]}>
      <p className="font-semibold">{help.title}</p>
      {help.steps.length > 0 && (
        <ol className="list-decimal space-y-1 pl-5">
          {help.steps.map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ol>
      )}
    </div>
  );
}
