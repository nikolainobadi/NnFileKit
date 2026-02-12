//
//  Directory.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

public protocol Directory {
    var path: String { get }
    var name: String { get }
    var `extension`: String? { get }
    var subdirectories: [any Directory] { get }

    func delete() throws
    func move(to parent: any Directory) throws
    func containsFile(named name: String) -> Bool
    func subdirectory(named name: String) throws -> any Directory
    func createSubdirectory(named name: String) throws -> any Directory
    func createSubfolderIfNeeded(named name: String) throws -> any Directory
    func deleteFile(named name: String) throws
    @discardableResult
    func createFile(named name: String, contents: String) throws -> String
    func readFile(named name: String) throws -> String
    func findFiles(withExtension extension: String?, recursive: Bool) throws -> [String]
}


// MARK: - Convenience
public extension Directory {
    func containsSubdirectory(named name: String) -> Bool {
        return (try? subdirectory(named: name)) != nil
    }
}
