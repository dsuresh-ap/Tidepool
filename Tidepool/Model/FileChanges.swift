import Foundation

/// Reports when a file changes on disk, including when a tool replaces it with a new file.
nonisolated enum FileChanges {
    static func stream(for url: URL) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let watcher = Watcher(url: url) { continuation.yield() }
            continuation.onTermination = { _ in watcher.stop() }
            watcher.start()
        }
    }

    private final class Watcher: @unchecked Sendable {
        private let url: URL
        private let onChange: @Sendable () -> Void
        private let queue = DispatchQueue(label: "io.github.dsuresh-ap.tidepool.file-changes")
        private var source: DispatchSourceFileSystemObject?
        private var isStopped = false

        init(url: URL, onChange: @escaping @Sendable () -> Void) {
            self.url = url
            self.onChange = onChange
        }

        func start() {
            queue.async { self.watch(retries: 20) }
        }

        func stop() {
            queue.async {
                self.isStopped = true
                self.source?.cancel()
                self.source = nil
            }
        }

        /// Watches the file at `url`. Many tools save by writing a new file and renaming it
        /// over the old one, so after a rename or delete the watcher opens the new file.
        private func watch(retries: Int) {
            guard !isStopped else { return }
            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor >= 0 else {
                if retries > 0 {
                    queue.asyncAfter(deadline: .now() + 0.1) { self.watch(retries: retries - 1) }
                }
                return
            }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor, eventMask: [.write, .extend, .rename, .delete], queue: queue
            )
            source.setEventHandler { [unowned source] in
                let replaced = !source.data.isDisjoint(with: [.rename, .delete])
                if replaced {
                    source.cancel()
                    self.queue.asyncAfter(deadline: .now() + 0.05) {
                        self.onChange()
                        self.watch(retries: 20)
                    }
                } else {
                    self.onChange()
                }
            }
            source.setCancelHandler { close(descriptor) }
            self.source = source
            source.resume()
        }
    }
}
