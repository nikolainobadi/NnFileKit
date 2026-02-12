//
//  FileSystemError.swift
//  NnFileKit
//
//  Created by Nikolai Nobadi on 2/12/26.
//

public enum FileSystemError: Error {
    case directoryNotFound(String)
    case fileNotFound(String)
}
