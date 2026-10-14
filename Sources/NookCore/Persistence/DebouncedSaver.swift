import Foundation

/// Coalesces rapid edits into one save after `delay`; `flush()` saves the pending value now.
public final class DebouncedSaver<Value> {
    private let delay: TimeInterval
    private let queue: DispatchQueue
    private let save: (Value) -> Void
    private let lock = NSLock()
    private var pending: Value?
    private var work: DispatchWorkItem?

    public init(delay: TimeInterval, queue: DispatchQueue = .main, save: @escaping (Value) -> Void) {
        self.delay = delay
        self.queue = queue
        self.save = save
    }

    public func submit(_ value: Value) {
        lock.lock()
        pending = value
        work?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.flush() }
        work = item
        lock.unlock()
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    public func flush() {
        lock.lock()
        let value = pending
        pending = nil
        work?.cancel()
        work = nil
        lock.unlock()
        if let value { save(value) }
    }
}
