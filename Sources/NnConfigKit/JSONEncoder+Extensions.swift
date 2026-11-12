import Foundation

public extension JSONEncoder {
    static func prettyOutput() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        return encoder
    }
}
