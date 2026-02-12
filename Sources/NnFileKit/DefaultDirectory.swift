//
//  DefaultDirectory.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

import Foundation

public struct DefaultDirectory: Directory, Sendable {
    public let path: String

    public init(path: String) {
        self.path = path.hasSuffix("/") ? path : path + "/"
    }
}


// MARK: - Static Helpers
public extension DefaultDirectory {
    static var temporary: DefaultDirectory {
        DefaultDirectory(path: NSTemporaryDirectory())
    }

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
