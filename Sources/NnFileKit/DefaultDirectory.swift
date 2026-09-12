//
//  DefaultDirectory.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import Foundation

/// A `FileManager`-backed ``Directory`` implementation that performs real file system operations.
///
/// Paths are normalized to always include a trailing slash.
public struct DefaultDirectory: Directory, Sendable {
    public let path: String

    /// Creates a directory reference for the given path.
    /// - Parameter path: The absolute path. A trailing slash is appended if absent.
    public init(path: String) {
        self.path = path.hasSuffix("/") ? path : path + "/"
    }
}

// MARK: - Static Helpers
public extension DefaultDirectory {
    /// A directory pointing to the system's temporary directory.
    static var temporary: DefaultDirectory {
        DefaultDirectory(path: NSTemporaryDirectory())
    }

    /// A directory pointing to the current user's home directory.
    static var home: DefaultDirectory {
        DefaultDirectory(path: NSHomeDirectory())
    }
}


// MARK: - Directory
extension DefaultDirectory {
    public var name: String {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        return (trimmed as NSString).lastPathComponent
    }

    public var `extension`: String? {
        let ext = (name as NSString).pathExtension
        return ext.isEmpty ? nil : ext
    }

    public var subdirectories: [any Directory] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return [] }

        return contents.compactMap { itemName in
            let fullPath = (path as NSString).appendingPathComponent(itemName)
            var isDir: ObjCBool = false
            
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }
            
            return DefaultDirectory(path: fullPath)
        }
    }

    public func delete() throws {
        try FileManager.default.removeItem(atPath: path)
    }

    public func move(to parent: any Directory) throws {
        let destinationPath = (parent.path as NSString).appendingPathComponent(name)
        
        try FileManager.default.moveItem(atPath: path, toPath: destinationPath)
    }

    @discardableResult
    public func copy(to parent: any Directory, overwrite: Bool) throws -> any Directory {
        let destinationPath = (parent.path as NSString).appendingPathComponent(name)

        try performCopy(from: path, to: destinationPath, overwrite: overwrite)

        return DefaultDirectory(path: destinationPath)
    }

    public func containsFile(named name: String) -> Bool {
        let filePath = (path as NSString).appendingPathComponent(name)
        var isDir: ObjCBool = false
        
        return FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir) && !isDir.boolValue
    }

    public func subdirectory(named name: String) throws -> any Directory {
        let subdirPath = (path as NSString).appendingPathComponent(name)
        var isDir: ObjCBool = false

        guard FileManager.default.fileExists(atPath: subdirPath, isDirectory: &isDir), isDir.boolValue else {
            throw FileSystemError.directoryNotFound(subdirPath)
        }

        return DefaultDirectory(path: subdirPath)
    }

    public func createSubdirectory(named name: String) throws -> any Directory {
        let subdirPath = (path as NSString).appendingPathComponent(name)
        try FileManager.default.createDirectory(atPath: subdirPath, withIntermediateDirectories: false)
        
        return DefaultDirectory(path: subdirPath)
    }

    public func createSubfolderIfNeeded(named name: String) throws -> any Directory {
        let subdirPath = (path as NSString).appendingPathComponent(name)
        var isDir: ObjCBool = false

        if FileManager.default.fileExists(atPath: subdirPath, isDirectory: &isDir), isDir.boolValue {
            return DefaultDirectory(path: subdirPath)
        }

        try FileManager.default.createDirectory(atPath: subdirPath, withIntermediateDirectories: true)
        
        return DefaultDirectory(path: subdirPath)
    }

    public func deleteFile(named name: String) throws {
        let filePath = (path as NSString).appendingPathComponent(name)
        try FileManager.default.removeItem(atPath: filePath)
    }

    @discardableResult
    public func createFile(named name: String, contents: String) throws -> String {
        let filePath = (path as NSString).appendingPathComponent(name)
        try contents.write(toFile: filePath, atomically: true, encoding: .utf8)
        
        return filePath
    }

    @discardableResult
    public func copyFile(named name: String, to destination: any Directory, overwrite: Bool) throws -> String {
        let sourcePath = (path as NSString).appendingPathComponent(name)
        let destinationPath = (destination.path as NSString).appendingPathComponent(name)

        try performCopy(from: sourcePath, to: destinationPath, overwrite: overwrite)

        return destinationPath
    }

    public func readFile(named name: String) throws -> String {
        let filePath = (path as NSString).appendingPathComponent(name)

        guard FileManager.default.fileExists(atPath: filePath) else {
            throw FileSystemError.fileNotFound(filePath)
        }

        return try String(contentsOfFile: filePath, encoding: .utf8)
    }

    public func findFiles(withExtension ext: String?, recursive: Bool) throws -> [String] {
        let fm = FileManager.default

        if recursive {
            guard let enumerator = fm.enumerator(atPath: path) else {
                return []
            }
            
            var results: [String] = []

            while let item = enumerator.nextObject() as? String {
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                fm.fileExists(atPath: fullPath, isDirectory: &isDir)

                if !isDir.boolValue {
                    if let ext {
                        if (item as NSString).pathExtension == ext {
                            results.append(fullPath)
                        }
                    } else {
                        results.append(fullPath)
                    }
                }
            }

            return results
        } else {
            let contents = try fm.contentsOfDirectory(atPath: path)

            return contents.compactMap { itemName in
                let fullPath = (path as NSString).appendingPathComponent(itemName)
                var isDir: ObjCBool = false
                fm.fileExists(atPath: fullPath, isDirectory: &isDir)
                guard !isDir.boolValue else { return nil }

                if let ext {
                    guard (itemName as NSString).pathExtension == ext else { return nil }
                }

                return fullPath
            }
        }
    }
}

// MARK: - Private Methods
private extension DefaultDirectory {
    /// Copies an item, removing an existing destination first when `overwrite` is `true`.
    /// The existence check matters: `removeItem` throws when the path is absent.
    func performCopy(from sourcePath: String, to destinationPath: String, overwrite: Bool) throws {
        let fm = FileManager.default

        if overwrite, fm.fileExists(atPath: destinationPath) {
            try fm.removeItem(atPath: destinationPath)
        }

        try fm.copyItem(atPath: sourcePath, toPath: destinationPath)
    }
}
