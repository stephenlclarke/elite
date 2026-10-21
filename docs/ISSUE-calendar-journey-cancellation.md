# Cancelled journeys and resumed frame clocks

Clearing a hyperspace countdown through navigation cancellation, manual selection or route replacement leaves the admitted calendar journey behind. Startup separately preserves the saved frame time during the title, but continuing from the title never restores that time or clears its backup. Later event snapshots and saves consequently keep using the frozen backup.

Cancellation must clear the existing admission without charging travel or changing fuel or operation history. Title continuation must resume the saved frame clock, preserve physical and mission state, and allow subsequent frames to advance normally. Fresh game-over restart remains separate. See [implementation status](PR-calendar-journey-cancellation.md).
