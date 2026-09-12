//
//  Directory.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

/// Represents a directory on disk and provides operations for managing its files and subdirectories.
public protocol Directory {
    /// The absolute path of this directory.
    var path: String { get }

    /// The directory's name (last path component).
    var name: String { get }

    /// The directory's file extension, or `nil` if none.
    var `extension`: String? { get }

    /// The immediate subdirectories contained in this directory.
    var subdirectories: [any Directory] { get }

    /// Deletes this directory and all of its contents.
    func delete() throws

    /// Moves this directory into the specified parent directory.
    /// - Parameter parent: The destination parent directory.
    func move(to parent: any Directory) throws

    /// Copies this directory, as a tree, into the specified parent directory under its own name.
    /// Preserves binary content, nested structure, and symlinks. The parent must already exist.
    /// `overwrite` is not atomic — the existing destination is removed before the copy begins.
    /// - Parameters:
    ///   - parent: The destination parent directory.
    ///   - overwrite: Pass `true` to replace an existing destination; `false` throws instead.
    /// - Returns: The newly created copy.
    @discardableResult
    func copy(to parent: any Directory, overwrite: Bool) throws -> any Directory

    /// Returns whether a file with the given name exists in this directory.
    /// - Parameter name: The file name to check.
    /// - Returns: `true` if the file exists; otherwise `false`.
    func containsFile(named name: String) -> Bool

    /// Returns the subdirectory with the given name.
    /// - Parameter name: The subdirectory name.
    /// - Returns: The matching subdirectory.
    /// - Throws: An error if no subdirectory with that name exists.
    func subdirectory(named name: String) throws -> any Directory

    /// Creates a new subdirectory with the given name.
    /// - Parameter name: The name for the new subdirectory.
    /// - Returns: The newly created subdirectory.
    func createSubdirectory(named name: String) throws -> any Directory

    /// Returns an existing subdirectory with the given name, creating one if it does not exist.
    /// - Parameter name: The subdirectory name.
    /// - Returns: The existing or newly created subdirectory.
    func createSubfolderIfNeeded(named name: String) throws -> any Directory

    /// Deletes the file with the given name from this directory.
    /// - Parameter name: The name of the file to delete.
    func deleteFile(named name: String) throws

    /// Creates a file with the given name and contents, returning its path.
    /// - Parameters:
    ///   - name: The file name.
    ///   - contents: The string to write into the file.
    /// - Returns: The absolute path of the created file.
    @discardableResult
    func createFile(named name: String, contents: String) throws -> String

    /// Copies a file from this directory into another directory under the same name.
    /// Bytes are relocated without decoding, so binary content is preserved. The destination must
    /// already exist. `overwrite` is not atomic — the existing file is removed before the copy.
    /// - Parameters:
    ///   - name: The name of the file to copy.
    ///   - destination: The directory to copy the file into.
    ///   - overwrite: Pass `true` to replace an existing file; `false` throws instead.
    /// - Returns: The absolute path of the copied file.
    @discardableResult
    func copyFile(named name: String, to destination: any Directory, overwrite: Bool) throws -> String

    /// Reads the contents of a file as a UTF-8 string.
    /// - Parameter name: The file name.
    /// - Returns: The file's contents.
    func readFile(named name: String) throws -> String

    /// Finds files in this directory, optionally filtering by extension and searching recursively.
    /// - Parameters:
    ///   - extension: A file extension to filter by, or `nil` to include all files.
    ///   - recursive: Pass `true` to search subdirectories recursively.
    /// - Returns: An array of absolute file paths matching the criteria.
    func findFiles(withExtension extension: String?, recursive: Bool) throws -> [String]
}

// MARK: - Convenience
public extension Directory {
    /// Returns whether a subdirectory with the given name exists.
    /// - Parameter name: The subdirectory name to check.
    /// - Returns: `true` if the subdirectory exists; otherwise `false`.
    func containsSubdirectory(named name: String) -> Bool {
        return (try? subdirectory(named: name)) != nil
    }
}
