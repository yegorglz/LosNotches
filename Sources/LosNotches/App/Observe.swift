import Observation

/// Calls `onChange` (on the main actor) every time anything read inside `read` changes,
/// for as long as `while` returns true.
@MainActor func observeChanges(_ read: @escaping @MainActor () -> Void, while alive: @escaping @MainActor () -> Bool = { true },
                               onChange: @escaping @MainActor () -> Void) {
    withObservationTracking { read() } onChange: {
        Task { @MainActor in
            guard alive() else { return }
            onChange()
            observeChanges(read, while: alive, onChange: onChange)
        }
    }
}
