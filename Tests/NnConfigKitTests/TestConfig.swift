//
//  TestConfig.swift
//  NnConfigKitTests
//
//  Created by Nikolai Nobadi on 9/12/26.
//

/// A minimal `Codable` configuration shared by the NnConfigManager suites.
struct TestConfig: Codable, Equatable {
    let firstSetting: Int
    let secondSetting: String
}
