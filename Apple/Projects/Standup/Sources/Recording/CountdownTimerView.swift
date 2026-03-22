// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import SwiftUI

// MARK: - CountdownTimerView

/// Displays remaining recording time as a circular progress arc with colour-coded urgency.
///
/// Colour alone is not used to convey urgency; a text label is also shown when the timer
/// enters the warning or critical zone, satisfying WCAG Success Criterion 1.4.1 (Use of Color).
struct CountdownTimerView: View {
	let timerState: TimerState

	var body: some View {
		ZStack {
			// Background ring
			Circle()
				.stroke(timerColor.opacity(0.25), lineWidth: 8)

			// Progress arc drawn clockwise from the top
			Circle()
				.trim(from: 0, to: timerState.progress)
				.stroke(timerColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
				.rotationEffect(.degrees(-90))
				.animation(.linear(duration: 1), value: timerState.progress)

			VStack(spacing: 2) {
				Text("\(Int(timerState.remainingTime.rounded()))")
					.font(.title)
					.fontWeight(.bold)
					.foregroundStyle(timerColor)
					.monospacedDigit()
					.contentTransition(.numericText(countsDown: true))

				// Non-colour urgency indicator (WCAG 1.4.1)
				if timerState.urgency != .normal {
					Text(urgencyLabel)
						.font(.caption2)
						.fontWeight(.semibold)
						.foregroundStyle(timerColor)
						.transition(.opacity)
				}
			}
		}
		// Single accessibility element so VoiceOver reads the combined label
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityLabel)
	}

	// MARK: - Private

	private var timerColor: Color {
		switch timerState.urgency {
		case .normal:
			return .accentColor
		case .warning:
			return .yellow
		case .critical:
			return .red
		}
	}

	private var urgencyLabel: String {
		switch timerState.urgency {
		case .normal:
			return ""
		case .warning:
			return "Almost done"
		case .critical:
			return "Wrapping up"
		}
	}

	private var accessibilityLabel: String {
		let seconds = Int(timerState.remainingTime.rounded())
		switch timerState.urgency {
		case .normal:
			return "\(seconds) seconds remaining"
		case .warning:
			return "\(seconds) seconds remaining. Almost done."
		case .critical:
			return "\(seconds) seconds remaining. Wrapping up."
		}
	}
}

// MARK: - Preview

#Preview("Countdown — Normal") {
	CountdownTimerView(timerState: TimerState(totalDuration: 30, remainingTime: 20))
		.frame(width: 140, height: 140)
		.padding()
}

#Preview("Countdown — Warning") {
	CountdownTimerView(timerState: TimerState(totalDuration: 30, remainingTime: 8))
		.frame(width: 140, height: 140)
		.padding()
}

#Preview("Countdown — Critical") {
	CountdownTimerView(timerState: TimerState(totalDuration: 30, remainingTime: 3))
		.frame(width: 140, height: 140)
		.padding()
}
