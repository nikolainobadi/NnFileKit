/// A minimal `Codable` configuration shared by the NnConfigManager suites.
struct TestConfig: Codable, Equatable {
    let firstSetting: Int
    let secondSetting: String
}
