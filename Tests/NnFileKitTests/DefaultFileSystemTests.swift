import Testing
import Foundation
@testable import NnFileKit

struct DefaultFileSystemTests {
    @Test
    func `Error is thrown for nonexistent directory path`() {
        let sut = makeSUT()

        #expect(throws: FileSystemError.self) {
            try sut.directory(at: "/nonexistent/path/\(UUID().uuidString)")
        }
    }

    @Test
    func `File contents are written and readable`() throws {
        let sut = makeSUT()
        let path = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString + ".txt")

        try sut.writeFile(at: path, contents: "test content")
        let contents = try sut.readFile(at: path)

        #expect(contents == "test content")
    }

    @Test
    func `Reading a missing file throws file not found with its path`() {
        let sut = makeSUT()
        let missingPath = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString + ".txt")

        let error = #expect(throws: FileSystemError.self) {
            try sut.readFile(at: missingPath)
        }

        guard case .fileNotFound(let path)? = error else {
            Issue.record("Expected fileNotFound, got \(String(describing: error))")
            return
        }

        #expect(path == missingPath)
    }
}

// MARK: - Directory Creation
extension DefaultFileSystemTests {
    @Test
    func `Every missing intermediate along a path is created`() throws {
        let sut = makeSUT()
        let parentPath = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString)

        try sut.createDirectory(at: parentPath.appendingPathComponent("child"))

        #expect(FileManager.default.fileExists(atPath: parentPath))
    }

    @Test
    func `Created directory is returned at the requested path`() throws {
        let sut = makeSUT()
        let path = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString + "/child")

        let created = try sut.createDirectory(at: path)

        #expect(created.path == path + "/")
    }

    @Test
    func `Creating an existing directory returns it without throwing`() throws {
        let sut = makeSUT()
        let path = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString)
        let first = try sut.createDirectory(at: path)

        let second = try sut.createDirectory(at: path)

        #expect(second.path == first.path)
    }

    @Test
    func `Created directory is found by path lookup`() throws {
        let sut = makeSUT()
        let path = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString + "/child")
        let created = try sut.createDirectory(at: path)

        let found = try sut.directory(at: path)

        #expect(found.path == created.path)
    }
}

// MARK: - File Locking
extension DefaultFileSystemTests {
    @Test
    func `Exclusive lock runs the body and returns its value`() throws {
        let sut = makeSUT()
        let lockPath = try makeLockPath()

        let value = try sut.withExclusiveLock(at: lockPath) { 42 }

        #expect(value == 42)
    }

    @Test
    func `Exclusive lock creates the lock file`() throws {
        let sut = makeSUT()
        let lockPath = try makeLockPath()

        try sut.withExclusiveLock(at: lockPath) { }

        #expect(FileManager.default.fileExists(atPath: lockPath))
    }

    @Test
    func `Lock is held while the body runs`() throws {
        let sut = makeSUT()
        let lockPath = try makeLockPath()

        let acquiredWhileHeld = try sut.withExclusiveLock(at: lockPath) {
            canAcquireLock(at: lockPath)
        }

        #expect(!acquiredWhileHeld)
    }

    @Test
    func `Lock is released after the body returns`() throws {
        let sut = makeSUT()
        let lockPath = try makeLockPath()

        try sut.withExclusiveLock(at: lockPath) { }

        #expect(canAcquireLock(at: lockPath))
    }

    @Test
    func `Lock is released after the body throws`() throws {
        let sut = makeSUT()
        let lockPath = try makeLockPath()

        _ = try? sut.withExclusiveLock(at: lockPath) {
            throw LockTestError.bodyFailed
        }

        #expect(canAcquireLock(at: lockPath))
    }

    @Test
    func `Body error passes through unchanged`() throws {
        let sut = makeSUT()
        let lockPath = try makeLockPath()

        #expect(throws: LockTestError.bodyFailed) {
            try sut.withExclusiveLock(at: lockPath) {
                throw LockTestError.bodyFailed
            }
        }
    }

    @Test
    func `Locking in a missing directory throws lock failed with its path`() {
        let sut = makeSUT()
        let lockPath = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString + "/missing/app.lock")

        let error = #expect(throws: FileSystemError.self) {
            try sut.withExclusiveLock(at: lockPath) { }
        }

        guard case .lockFailed(let path, _)? = error else {
            Issue.record("Expected lockFailed, got \(String(describing: error))")
            return
        }

        #expect(path == lockPath)
    }
}

// MARK: - Lock Helpers
private extension DefaultFileSystemTests {
    enum LockTestError: Error {
        case bodyFailed
    }

    func makeLockPath() throws -> String {
        let folder = NSTemporaryDirectory().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)

        return folder.appendingPathComponent("app.lock")
    }

    /// Tries a non-blocking exclusive lock through a separate file descriptor, releasing it on success.
    func canAcquireLock(at path: String) -> Bool {
        let fd = open(path, O_RDWR)

        guard fd >= 0 else {
            return false
        }

        defer { close(fd) }

        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            return false
        }

        flock(fd, LOCK_UN)

        return true
    }
}

// MARK: - SUT
private extension DefaultFileSystemTests {
    func makeSUT() -> DefaultFileSystem {
        return DefaultFileSystem()
    }
}
