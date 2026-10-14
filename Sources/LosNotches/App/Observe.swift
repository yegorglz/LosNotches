import Observation

/// Calls `onChange` (on the main actor) every time anything read inside `read` changes.
@MainActor func observeChanges(_ read: @escaping @MainActor () -> Void, onChange: @escaping @MainActor () -> Void) {
    withObservationTracking { read() } onChange: {
        Task { @MainActor in
            onChange()
            observeChanges(read, onChange: onChange)
        }
    }
}
