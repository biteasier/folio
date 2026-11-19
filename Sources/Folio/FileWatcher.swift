import Foundation

/// Calls `onChange` when a file is written, including editors that save by
/// writing a new file and renaming it over the old one.
final class FileWatcher {
    private let url: () -> URL?
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    init(url: @escaping () -> URL?, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        watch()
    }

    deinit { source?.cancel() }

    private func watch(retries: Int = 20) {
        source?.cancel()
        source = nil
        guard let path = url()?.path else { return }
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            // Mid atomic-save the file can briefly not exist.
            if retries > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.watch(retries: retries - 1) }
            }
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename], queue: .main)
        src.setEventHandler { [weak self, weak src] in
            guard let self, let src else { return }
            if !src.data.isDisjoint(with: [.delete, .rename]) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.watch() }
            }
            self.schedule()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    private func schedule() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: item)
    }
}
