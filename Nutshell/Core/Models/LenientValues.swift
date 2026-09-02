import Foundation

/// Open Food Facts is a crowd-sourced database with a loosely-typed API: the same
/// field can arrive as `3`, `3.0`, or `"3"` depending on which client wrote it, and
/// missing data is represented interchangeably by `null`, an absent key, or `""`.
///
/// These helpers absorb that variance at the decoding boundary so the rest of the app
/// can work with ordinary Swift optionals.
enum Lenient {

    /// Decodes a number that may be encoded as `Double`, `Int`, `Bool`, or `String`.
    ///
    /// Non-finite values are rejected. `JSONEncoder` cannot represent NaN or infinity, so
    /// letting one through would silently break the saved-products file on every
    /// subsequent write — the list would simply stop persisting, with no error anywhere.
    static func double(from container: SingleValueDecodingContainer) -> Double? {
        if let value = try? container.decode(Double.self) { return value.isFinite ? value : nil }
        if let value = try? container.decode(Int.self) { return Double(value) }
        if let value = try? container.decode(String.self) {
            return Double(value.trimmed).flatMap { $0.isFinite ? $0 : nil }
        }
        return nil
    }

    /// Decodes an integer that may be encoded as `Int`, `Double`, or `String`.
    ///
    /// `Int(Double)` traps on NaN and on anything outside `Int`'s range, so the
    /// conversion is guarded rather than trusted — this is parsing hostile input.
    static func int(from container: SingleValueDecodingContainer) -> Int? {
        if let value = try? container.decode(Int.self) { return value }
        if let value = try? container.decode(Double.self) { return exactInt(value) }
        if let value = try? container.decode(String.self) {
            if let integer = Int(value.trimmed) { return integer }
            return Double(value.trimmed).flatMap(exactInt)
        }
        return nil
    }

    private static func exactInt(_ value: Double) -> Int? {
        guard value.isFinite,
              value >= Double(Int.min), value <= Double(Int.max) else { return nil }
        return Int(value)
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

/// A string that may arrive as a string or as an array of strings.
///
/// `brands` is comma-joined text on the legacy search endpoint and a real array on
/// Search-a-licious. Absorbing both here means the rest of the app never learns which
/// backend a product came from.
struct LenientString: Codable, Hashable, Sendable {
    let value: String?

    init(_ value: String?) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            value = single.nilIfBlank
        } else if let list = try? container.decode([String].self) {
            value = list.compactMap(\.nilIfBlank).joined(separator: ", ").nilIfBlank
        } else {
            value = nil
        }
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
