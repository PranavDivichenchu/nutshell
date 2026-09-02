import Foundation

/// Open Food Facts is a crowd-sourced database with a loosely-typed API: the same
/// field can arrive as `3`, `3.0`, or `"3"` depending on which client wrote it, and
/// missing data is represented interchangeably by `null`, an absent key, or `""`.
///
/// These helpers absorb that variance at the decoding boundary so the rest of the app
/// can work with ordinary Swift optionals.
enum Lenient {

    /// Decodes a number that may be encoded as `Double`, `Int`, `Bool`, or `String`.
    static func double(from container: SingleValueDecodingContainer) -> Double? {
        if let value = try? container.decode(Double.self) { return value }
        if let value = try? container.decode(Int.self) { return Double(value) }
        if let value = try? container.decode(String.self) { return Double(value.trimmed) }
        return nil
    }

    /// Decodes an integer that may be encoded as `Int`, `Double`, or `String`.
    static func int(from container: SingleValueDecodingContainer) -> Int? {
        if let value = try? container.decode(Int.self) { return value }
        if let value = try? container.decode(Double.self) { return Int(value) }
        if let value = try? container.decode(String.self) { return Int(value.trimmed) }
        return nil
    }
}

/// A `Double` that tolerates the API's mixed numeric encodings.
struct LenientDouble: Codable, Hashable, Sendable {
    let value: Double?

    init(_ value: Double?) { self.value = value }

    init(from decoder: Decoder) throws {
        value = Lenient.double(from: try decoder.singleValueContainer())
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value { try container.encode(value) } else { try container.encodeNil() }
    }
}

/// An `Int` that tolerates the API's mixed numeric encodings.
struct LenientInt: Codable, Hashable, Sendable {
    let value: Int?

    init(_ value: Int?) { self.value = value }

    init(from decoder: Decoder) throws {
        value = Lenient.int(from: try decoder.singleValueContainer())
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value { try container.encode(value) } else { try container.encodeNil() }
    }
}

/// A `CodingKey` for containers whose keys are not known at compile time.
struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
    init(_ string: String) { self.stringValue = string }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Treats the empty string as missing data, which the API uses liberally.
    var nilIfBlank: String? { trimmed.isEmpty ? nil : trimmed }
}
