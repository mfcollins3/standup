// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

import Testing
@testable import Standup

@Suite("CountdownTimerView — TimerState urgency mapping")
struct CountdownTimerTests {

	// MARK: - Normal zone

	@Test("urgency is .normal well above 10 seconds")
	func normalUrgencyWellAbove10() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 25.0)
		#expect(state.urgency == .normal)
	}

	@Test("urgency is .normal just above the 10-second boundary")
	func normalUrgencyJustAbove10() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 10.1)
		#expect(state.urgency == .normal)
	}

	// MARK: - Warning zone (5 < remaining <= 10)

	@Test("urgency transitions to .warning at exactly 10 seconds")
	func warningUrgencyAtExactly10() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 10.0)
		#expect(state.urgency == .warning)
	}

	@Test("urgency is .warning at 7 seconds")
	func warningUrgencyAt7() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 7.0)
		#expect(state.urgency == .warning)
	}

	@Test("urgency is .warning just above the 5-second boundary")
	func warningUrgencyJustAbove5() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 5.1)
		#expect(state.urgency == .warning)
	}

	// MARK: - Critical zone (remaining <= 5)

	@Test("urgency transitions to .critical at exactly 5 seconds")
	func criticalUrgencyAtExactly5() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 5.0)
		#expect(state.urgency == .critical)
	}

	@Test("urgency is .critical at 2 seconds")
	func criticalUrgencyAt2() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 2.0)
		#expect(state.urgency == .critical)
	}

	@Test("urgency is .critical at 0 seconds")
	func criticalUrgencyAtZero() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 0.0)
		#expect(state.urgency == .critical)
	}

	// MARK: - Progress

	@Test("progress equals 1.0 at full time remaining")
	func progressFullAtStart() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 30.0)
		#expect(state.progress == 1.0)
	}

	@Test("progress equals 0.5 at half time remaining")
	func progressHalfAtMidpoint() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 15.0)
		#expect(state.progress == 0.5)
	}

	@Test("progress equals 0.0 at zero remaining")
	func progressZeroAtEnd() {
		let state = TimerState(totalDuration: 30.0, remainingTime: 0.0)
		#expect(state.progress == 0.0)
	}

	@Test("progress is clamped to 0.0 when totalDuration is zero")
	func progressZeroWhenTotalDurationIsZero() {
		let state = TimerState(totalDuration: 0.0, remainingTime: 0.0)
		#expect(state.progress == 0.0)
	}
}
