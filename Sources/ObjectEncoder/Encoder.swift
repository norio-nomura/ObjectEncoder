//
//  Encoder.swift
//  ObjectEncoder
//
//  Created by Norio Nomura on 10/21/17.
//  Copyright (c) 2017 ObjectEncoder. All rights reserved.
//

import Foundation

public struct ObjectEncoder {
    public init() {}
    public func encode<T>(_ value: T, userInfo: [CodingUserInfoKey: Any] = [:]) throws -> Any where T: Swift.Encodable {
        do {
            let encoder = ObjectEncoder.Encoder(options, userInfo)
            var container = encoder.singleValueContainer()
            try container.encode(value)
            return encoder.object
        } catch let error as EncodingError {
            throw error
        } catch {
            let description = "Unable to encode the given top-level value to Object."
            let context = EncodingError.Context(codingPath: [],
                                                debugDescription: description,
                                                underlyingError: error)
            throw EncodingError.invalidValue(value, context)
        }
    }

    public struct EncodingStrategy<T: Encodable> {
        public typealias Closure = (T, Swift.Encoder) throws -> Void
        public init(identifiers: [ObjectIdentifier], closure: @escaping Closure) {
            self.identifiers = identifiers
            self.closure = closure
        }

        fileprivate let identifiers: [ObjectIdentifier]
        fileprivate let closure: Closure
    }

    public struct EncodingStrategies {
        var strategies = [ObjectIdentifier: Any]()
        public subscript<T>(type: T.Type) -> EncodingStrategy<T>? {
            get { return strategies[ObjectIdentifier(type)] as? EncodingStrategy<T> }
            set {
                if let newValue = newValue {
                    precondition(newValue.identifiers.contains(ObjectIdentifier(type)))
                    newValue.identifiers.forEach { strategies[$0] = newValue }
                } else {
                    if let strategy = strategies[ObjectIdentifier(type)] as? EncodingStrategy<T> {
                        strategy.identifiers.forEach { strategies[$0] = nil }
                    }
                    strategies[ObjectIdentifier(type)] = nil
                }
            }
        }
        public subscript<T>(types: [Any.Type]) -> EncodingStrategy<T>? {
            get { return types.first.map { strategies[ObjectIdentifier($0)] } as? EncodingStrategy<T> }
            set { types.forEach { strategies[ObjectIdentifier($0)] = newValue } }
        }
    }

    /// The strategies to use for encoding values.
    public var encodingStrategies: EncodingStrategies {
        get { return options.encodingStrategies }
        set { options.encodingStrategies = newValue }
    }

    // MARK: -

    fileprivate struct Options {
        fileprivate var encodingStrategies = EncodingStrategies()
    }

    fileprivate var options = Options()
}

extension ObjectEncoder {
    class Encoder: Swift.Encoder {
        fileprivate var object: Any = [:]

        fileprivate typealias Options = ObjectEncoder.Options
        fileprivate let options: Options

        fileprivate init(_ options: Options, _ userInfo: [CodingUserInfoKey: Any], _ codingPath: [CodingKey] = []) {
            self.options = options
            self.userInfo = userInfo
            self.codingPath = codingPath
        }

        // MARK: - Swift.Encoder Methods

        let codingPath: [CodingKey]
        let userInfo: [CodingUserInfoKey: Any]
    }
}

extension ObjectEncoder.Encoder {
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        if canEncodeNewValue {
            object = [:]
        } else {
            precondition(
                object is [String: Any],
                "Attempt to push new keyed encoding container when already previously encoded at this path."
            )
        }
        return .init(_KeyedEncodingContainer<Key>(referencing: self))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if canEncodeNewValue {
            object = []
        } else {
            precondition(
                object is [Any],
                "Attempt to push new keyed encoding container when already previously encoded at this path."
            )
        }
        return _UnkeyedEncodingContainer(referencing: self)
    }

    func singleValueContainer() -> SingleValueEncodingContainer { return self }

    // MARK: -

    fileprivate var dictionary: [String: Any] {
        get { return object as? [String: Any] ?? [:] }
        set { object = newValue }
    }

    fileprivate var array: [Any] {
        get { return object as? [Any] ?? [] }
        set { object = newValue }
    }

    fileprivate func encoder(for key: CodingKey) -> _KeyReferencingEncoder {
        return .init(referencing: self, key: key)
    }

    fileprivate func encoder(at index: Int) -> _IndexReferencingEncoder {
        return .init(referencing: self, at: index)
    }

    private func box<T: Encodable>(_ value: T) throws {
        assertCanEncodeNewValue()
        if let strategy = options.encodingStrategies[T.self] {
            try strategy.closure(value, self)
        } else {
            object = value
        }
    }

    private var canEncodeNewValue: Bool {
        if let dictionary = object as? [String: Any], dictionary.isEmpty {
            return true
        }
        return false
    }
}

private class _KeyReferencingEncoder: ObjectEncoder.Encoder {
    let encoder: ObjectEncoder.Encoder
    let key: String

    fileprivate init(referencing encoder: ObjectEncoder.Encoder, key: CodingKey) {
        self.encoder = encoder
        self.key = key.stringValue
        super.init(encoder.options, encoder.userInfo, encoder.codingPath + [key])
    }

    deinit {
        encoder.dictionary[key] = object
    }
}

private class _IndexReferencingEncoder: ObjectEncoder.Encoder {
    let encoder: ObjectEncoder.Encoder
    let index: Int

    fileprivate init(referencing encoder: ObjectEncoder.Encoder, at index: Int) {
        self.encoder = encoder
        self.index = index
        super.init(encoder.options, encoder.userInfo, encoder.codingPath + [_ObjectCodingKey(index: index)])
    }

    deinit {
        encoder.array[index] = object
    }
}

struct _KeyedEncodingContainer<K: CodingKey> : KeyedEncodingContainerProtocol { // swiftlint:disable:this type_name
    typealias Key = K

    private let encoder: ObjectEncoder.Encoder

    fileprivate init(referencing encoder: ObjectEncoder.Encoder) {
        self.encoder = encoder
    }

    // MARK: - Swift.KeyedEncodingContainerProtocol Methods

    var codingPath: [CodingKey] { return encoder.codingPath }
    func encodeNil(forKey key: Key)               throws { encoder.dictionary[key.stringValue] = NSNull() }
    func encode(_ value: Bool, forKey key: Key)   throws { try box(value, for: key) }
    func encode(_ value: Int, forKey key: Key)    throws { try box(value, for: key) }
    func encode(_ value: Int8, forKey key: Key)   throws { try box(value, for: key) }
    func encode(_ value: Int16, forKey key: Key)  throws { try box(value, for: key) }
    func encode(_ value: Int32, forKey key: Key)  throws { try box(value, for: key) }
    func encode(_ value: Int64, forKey key: Key)  throws { try box(value, for: key) }
    func encode(_ value: UInt, forKey key: Key)   throws { try box(value, for: key) }
    func encode(_ value: UInt8, forKey key: Key)  throws { try box(value, for: key) }
    func encode(_ value: UInt16, forKey key: Key) throws { try box(value, for: key) }
    func encode(_ value: UInt32, forKey key: Key) throws { try box(value, for: key) }
    func encode(_ value: UInt64, forKey key: Key) throws { try box(value, for: key) }
    func encode(_ value: Float, forKey key: Key)  throws { try box(value, for: key) }
    func encode(_ value: Double, forKey key: Key) throws { try box(value, for: key) }
    func encode(_ value: String, forKey key: Key) throws { try box(value, for: key) }
    func encode<T>(_ value: T, forKey key: Key)   throws where T: Encodable { try encoder(for: key).encode(value) }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type,
                                    forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        return encoder(for: key).container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return encoder(for: key).unkeyedContainer()
    }

    func superEncoder() -> Encoder { return encoder(for: _ObjectCodingKey.super) }
    func superEncoder(forKey key: Key) -> Encoder { return encoder(for: key) }

    // MARK: -

    private func encoder(for key: CodingKey) -> _KeyReferencingEncoder { return encoder.encoder(for: key) }

    private func box<T: Encodable>(_ value: T, for key: CodingKey) throws {
        if let strategy = encoder.options.encodingStrategies[T.self] {
            try strategy.closure(value, encoder(for: key))
        } else {
            encoder.dictionary[key.stringValue] = value
        }
    }
}

struct _UnkeyedEncodingContainer: UnkeyedEncodingContainer { // swiftlint:disable:this type_name
    private let encoder: ObjectEncoder.Encoder

    fileprivate init(referencing encoder: ObjectEncoder.Encoder) {
        self.encoder = encoder
    }

    // MARK: - Swift.UnkeyedEncodingContainer Methods

    var codingPath: [CodingKey] { return encoder.codingPath }
    var count: Int { return encoder.array.count }
    func encodeNil()             throws { encoder.array.append(NSNull()) }
    func encode(_ value: Bool)   throws { try box(value) }
    func encode(_ value: Int)    throws { try box(value) }
    func encode(_ value: Int8)   throws { try box(value) }
    func encode(_ value: Int16)  throws { try box(value) }
    func encode(_ value: Int32)  throws { try box(value) }
    func encode(_ value: Int64)  throws { try box(value) }
    func encode(_ value: UInt)   throws { try box(value) }
    func encode(_ value: UInt8)  throws { try box(value) }
    func encode(_ value: UInt16) throws { try box(value) }
    func encode(_ value: UInt32) throws { try box(value) }
    func encode(_ value: UInt64) throws { try box(value) }
    func encode(_ value: Float)  throws { try box(value) }
    func encode(_ value: Double) throws { try box(value) }
    func encode(_ value: String) throws { try box(value) }
    func encode<T>(_ value: T)   throws where T: Encodable { try currentEncoder.encode(value) }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        return currentEncoder.container(keyedBy: keyType)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer { return currentEncoder.unkeyedContainer() }
    func superEncoder() -> Encoder { return currentEncoder }

    // MARK: -

    private var currentEncoder: _IndexReferencingEncoder {
        defer { encoder.array.append("") }
        return encoder.encoder(at: count)
    }

    private func box<T: Encodable>(_ value: T) throws {
        if let strategy = encoder.options.encodingStrategies[T.self] {
            try strategy.closure(value, currentEncoder)
        } else {
            encoder.array.append(value)
        }
    }
}

extension ObjectEncoder.Encoder: SingleValueEncodingContainer {

    // MARK: - Swift.SingleValueEncodingContainer Methods

    func encodeNil()             throws { assertCanEncodeNewValue(); object = NSNull() }
    func encode(_ value: Bool)   throws { try box(value) }
    func encode(_ value: Int)    throws { try box(value) }
    func encode(_ value: Int8)   throws { try box(value) }
    func encode(_ value: Int16)  throws { try box(value) }
    func encode(_ value: Int32)  throws { try box(value) }
    func encode(_ value: Int64)  throws { try box(value) }
    func encode(_ value: UInt)   throws { try box(value) }
    func encode(_ value: UInt8)  throws { try box(value) }
    func encode(_ value: UInt16) throws { try box(value) }
    func encode(_ value: UInt32) throws { try box(value) }
    func encode(_ value: UInt64) throws { try box(value) }
    func encode(_ value: Float)  throws { try box(value) }
    func encode(_ value: Double) throws { try box(value) }
    func encode(_ value: String) throws { try box(value) }

    func encode<T>(_ value: T) throws where T: Encodable {
        assertCanEncodeNewValue()
        if let strategy = options.encodingStrategies[T.self] {
            try strategy.closure(value, self)
        } else {
            try value.encode(to: self)
        }
    }

    // MARK: -

    /// Asserts that a single value can be encoded at the current coding path
    /// (i.e. that one has not already been encoded through this container).
    /// `preconditionFailure()`s if one cannot be encoded.
    private func assertCanEncodeNewValue() {
        precondition(
            canEncodeNewValue,
            "Attempt to encode value through single value container when previously value already encoded."
        )
    }
}

// MARK: - CodingKey for `_UnkeyedEncodingContainer`, `_UnkeyedDecodingContainer`, `superEncoders` or `superDecoders`

struct _ObjectCodingKey: CodingKey { // swiftlint:disable:this type_name
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }

    static let `super` = _ObjectCodingKey(stringValue: "super")!
}

// MARK: - EncodingError helpers

private func _invalidFloatingPointValue<T: FloatingPoint>(_ value: T, at codingPath: [CodingKey]) -> EncodingError {
    let valueDescription: String
    if value == T.infinity {
        valueDescription = "\(T.self).infinity"
    } else if value == -T.infinity {
        valueDescription = "-\(T.self).infinity"
    } else {
        valueDescription = "\(T.self).nan"
    }

    let debugDescription = """
    Unable to encode \(valueDescription) directly in JSONObjectEncoder. \
    Use JSONObjectEncoder.NonConformingFloatEncodingStrategy.convertToString to specify how the value should be encoded.
    """
    return .invalidValue(value, .init(codingPath: codingPath, debugDescription: debugDescription))
}

// MARK: - ObjectEncoder.EncodingStrategy

extension ObjectEncoder {
    /// The strategy to use for encoding `Data` values.
    public typealias DataEncodingStrategy = EncodingStrategy<Data>
    /// The strategy to use for encoding `Date` values.
    public typealias DateEncodingStrategy = EncodingStrategy<Date>

    /// The strategy to use for encoding `Double` values.
    public typealias DoubleEncodingStrategy = EncodingStrategy<Double>
    /// The strategy to use for encoding `Float` values.
    public typealias FloatEncodingStrategy = EncodingStrategy<Float>
}

extension ObjectEncoder.EncodingStrategy {
    /// Encode the `T` as a custom value encoded by the given closure.
    ///
    /// If the closure fails to encode a value into the given encoder,
    /// the encoder will encode an empty automatic container in its place.
    public static func custom(_ types: [Any.Type] = [T.self],
                              _ closure: @escaping Closure) -> ObjectEncoder.EncodingStrategy<T> {
        return .init(identifiers: types.map(ObjectIdentifier.init), closure: closure)
    }
}

extension ObjectEncoder.EncodingStrategy where T == Data {
    /// Defer to `Data` for choosing an encoding.
    public static let deferredToData: ObjectEncoder.DataEncodingStrategy? = nil

    /// Encoded the `Data` as a Base64-encoded string. This is the default strategy.
    public static let base64 = ObjectEncoder.DataEncodingStrategy.custom {
        try $0.base64EncodedString().encode(to: $1)
    }

    /// Encode the `Data` as a custom value encoded by the given closure.
    ///
    /// If the closure fails to encode a value into the given encoder,
    /// the encoder will encode an empty automatic container in its place.
    public static func custom(_ closure: @escaping Closure) -> ObjectEncoder.DataEncodingStrategy {
        return .init(identifiers: identifiers, closure: closure)
    }

    private static let identifiers = [Data.self, NSData.self].map(ObjectIdentifier.init)
}

@available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
var iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

extension ObjectEncoder.EncodingStrategy where T == Date {
    /// Defer to `Date` for choosing an encoding. This is the default strategy.
    public static let deferredToDate: ObjectEncoder.DateEncodingStrategy? = nil

    /// Encode the `Date` as a UNIX timestamp (as a `Double`).
    public static let secondsSince1970 = ObjectEncoder.DateEncodingStrategy.custom {
        var container = $1.singleValueContainer()
        try container.encode($0.timeIntervalSince1970)
    }

    /// Encode the `Date` as UNIX millisecond timestamp (as a `Double`).
    public static let millisecondsSince1970 = ObjectEncoder.DateEncodingStrategy.custom {
        var container = $1.singleValueContainer()
        try container.encode(1000.0 * $0.timeIntervalSince1970)
    }

    /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    public static let iso8601 = ObjectEncoder.DateEncodingStrategy.custom {
        var container = $1.singleValueContainer()
        try container.encode(iso8601Formatter.string(from: $0))
    }

    /// Encode the `Date` as a string formatted by the given formatter.
    public static func formatted(_ formatter: DateFormatter) -> ObjectEncoder.DateEncodingStrategy {
        return .custom {
            var container = $1.singleValueContainer()
            try container.encode(formatter.string(from: $0))
        }
    }

    /// Encode the `Date` as a custom value encoded by the given closure.
    ///
    /// If the closure fails to encode a value into the given encoder,
    /// the encoder will encode an empty automatic container in its place.
    public static func custom(_ closure: @escaping Closure) -> ObjectEncoder.DateEncodingStrategy {
        return .init(identifiers: identifiers, closure: closure)
    }

    private static let identifiers = [Date.self, NSDate.self].map(ObjectIdentifier.init)
}

extension ObjectEncoder.EncodingStrategy where T == Decimal {
    public static let compatibleWithJSONEncoder = ObjectEncoder.EncodingStrategy<Decimal>.custom {
        guard let encoder = $1 as? ObjectEncoder.Encoder else {
            fatalError("unreachable")
        }
        encoder.object = NSDecimalNumber(decimal: $0)
    }

    public static func custom(_ closure: @escaping Closure) -> ObjectEncoder.EncodingStrategy<Decimal> {
        return .init(identifiers: identifiers, closure: closure)
    }

    private static let identifiers = [Decimal.self, NSDecimalNumber.self].map(ObjectIdentifier.init)
}

extension ObjectEncoder.EncodingStrategy where T == Double {
    public static let throwOnNonConformingFloat = ObjectEncoder.DoubleEncodingStrategy.custom {
        guard let encoder = $1 as? ObjectEncoder.Encoder else {
            fatalError("unreachable")
        }
        guard !$0.isInfinite && !$0.isNaN else {
            throw _invalidFloatingPointValue($0, at: encoder.codingPath)
        }
        encoder.object = NSNumber(value: $0)
    }

    public static func convertNonConformingFloatToString(_ positiveInfinity: String,
                                                         _ negativeInfinity: String,
                                                         _ nan: String) -> ObjectEncoder.DoubleEncodingStrategy {
        return .custom {
            guard let encoder = $1 as? ObjectEncoder.Encoder else {
                fatalError("unreachable")
            }
            if $0 == .infinity {
                encoder.object = positiveInfinity
            } else if $0 == -.infinity {
                encoder.object = negativeInfinity
            } else if $0.isNaN {
                encoder.object = nan
            } else {
                encoder.object = NSNumber(value: $0)
            }
        }
    }

    public static func custom(_ closure: @escaping Closure) -> ObjectEncoder.DoubleEncodingStrategy {
        return .init(identifiers: identifiers, closure: closure)
    }

    private static let identifiers = [Double.self].map(ObjectIdentifier.init)
}

extension ObjectEncoder.EncodingStrategy where T == Float {
    public static let throwOnNonConformingFloat = ObjectEncoder.FloatEncodingStrategy.custom {
        guard let encoder = $1 as? ObjectEncoder.Encoder else {
            fatalError("unreachable")
        }
        guard !$0.isInfinite && !$0.isNaN else {
            throw _invalidFloatingPointValue($0, at: encoder.codingPath)
        }
        encoder.object = NSNumber(value: $0)
    }

    public static func convertNonConformingFloatToString(_ positiveInfinity: String,
                                                         _ negativeInfinity: String,
                                                         _ nan: String) -> ObjectEncoder.FloatEncodingStrategy {
        return .custom {
            guard let encoder = $1 as? ObjectEncoder.Encoder else {
                fatalError("unreachable")
            }
            if $0 == .infinity {
                encoder.object = positiveInfinity
            } else if $0 == -.infinity {
                encoder.object = negativeInfinity
            } else if $0.isNaN {
                encoder.object = nan
            } else {
                encoder.object = NSNumber(value: $0)
            }
        }
    }

    public static func custom(_ closure: @escaping Closure) -> ObjectEncoder.FloatEncodingStrategy {
        return .init(identifiers: identifiers, closure: closure)
    }

    private static let identifiers = [Float.self].map(ObjectIdentifier.init)
}

extension ObjectEncoder.EncodingStrategy where T == URL {
    public static let compatibleWithJSONEncoder = ObjectEncoder.EncodingStrategy<URL>.custom {
        var container = $1.singleValueContainer()
        try container.encode($0.absoluteString)
    }

    public static func custom(_ closure: @escaping Closure) -> ObjectEncoder.EncodingStrategy<URL> {
        return .init(identifiers: identifiers, closure: closure)
    }

    private static let identifiers = [URL.self, NSURL.self].map(ObjectIdentifier.init)
} // swiftlint:disable:this file_length
