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
            let encoder = _Encoder(options, userInfo)
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
        fileprivate let identifiers: [ObjectIdentifier]
        fileprivate let closure: (T, Encoder) throws -> Void
        public init(_ types: [Any.Type] = [T.self], closure: @escaping (T, Encoder) throws -> Void) {
            self.closure = closure
            self.identifiers = types.map(ObjectIdentifier.init)
        }
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

class _Encoder: Swift.Encoder { // swiftlint:disable:this type_name

    struct Unused {
        private init() {}
        fileprivate static let unused = Unused()
    }

    fileprivate var object: Any = Unused.unused

    fileprivate typealias Options = ObjectEncoder.Options
    fileprivate let options: Options

    fileprivate init(_ options: Options, _ userInfo: [CodingUserInfoKey: Any] = [:], _ codingPath: [CodingKey] = []) {
        self.options = options
        self.userInfo = userInfo
        self.codingPath = codingPath
    }

    // MARK: - Swift.Encoder Methods

    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

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

    fileprivate func encoder(for key: CodingKey) -> _ObjectReferencingEncoder {
        return .init(referencing: self, key: key)
    }

    fileprivate func encoder(at index: Int) -> _ObjectReferencingEncoder {
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

    private var canEncodeNewValue: Bool { return object is Unused }
}

class _ObjectReferencingEncoder: _Encoder { // swiftlint:disable:this type_name
    private enum Reference { case mapping(String), sequence(Int) }

    private let encoder: _Encoder
    private let reference: Reference

    fileprivate init(referencing encoder: _Encoder, key: CodingKey) {
        self.encoder = encoder
        reference = .mapping(key.stringValue)
        super.init(encoder.options, encoder.userInfo, encoder.codingPath + [key])
    }

    fileprivate init(referencing encoder: _Encoder, at index: Int) {
        self.encoder = encoder
        reference = .sequence(index)
        super.init(encoder.options, encoder.userInfo, encoder.codingPath + [_ObjectCodingKey(index: index)])
    }

    deinit {
        switch reference {
        case .mapping(let key):
            encoder.dictionary[key] = object
        case .sequence(let index):
            encoder.array[index] = object
        }
    }
}

struct _KeyedEncodingContainer<K: CodingKey> : KeyedEncodingContainerProtocol { // swiftlint:disable:this type_name
    typealias Key = K

    private let encoder: _Encoder

    fileprivate init(referencing encoder: _Encoder) {
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

    private func encoder(for key: CodingKey) -> _ObjectReferencingEncoder { return encoder.encoder(for: key) }

    private func box<T: Encodable>(_ value: T, for key: CodingKey) throws {
        if let strategy = encoder.options.encodingStrategies[T.self] {
            try strategy.closure(value, encoder(for: key))
        } else {
            encoder.dictionary[key.stringValue] = value
        }
    }
}

struct _UnkeyedEncodingContainer: UnkeyedEncodingContainer { // swiftlint:disable:this type_name
    private let encoder: _Encoder

    fileprivate init(referencing encoder: _Encoder) {
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
        return currentEncoder.container(keyedBy: NestedKey.self)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer { return currentEncoder.unkeyedContainer() }
    func superEncoder() -> Encoder { return currentEncoder }

    // MARK: -

    private var currentEncoder: _ObjectReferencingEncoder {
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

extension _Encoder: SingleValueEncodingContainer {

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

// MARK: - ObjectEncoder.EncodingStrategy

extension ObjectEncoder {
    /// The strategy to use for encoding `Data` values.
    public typealias DataEncodingStrategy = EncodingStrategy<Data>
    /// The strategy to use for encoding `Date` values.
    public typealias DateEncodingStrategy = EncodingStrategy<Date>
}

extension ObjectEncoder.EncodingStrategy {
    /// Encode the `T` as a custom value encoded by the given closure.
    ///
    /// If the closure fails to encode a value into the given encoder,
    /// the encoder will encode an empty automatic container in its place.
    public static func custom(_ closure: @escaping (T, Encoder) throws -> Void) -> ObjectEncoder.EncodingStrategy<T> {
        return .init(closure: closure)
    }
}

extension ObjectEncoder.EncodingStrategy where T == Data {
    /// Defer to `Data` for choosing an encoding.
    public static let deferredToData = ObjectEncoder.EncodingStrategy<Data>([Data.self, NSData.self]) {
        try $0.encode(to: $1)
    }

    /// Encoded the `Data` as a Base64-encoded string. This is the default strategy.
    public static let base64 = ObjectEncoder.EncodingStrategy<Data>([Data.self, NSData.self]) {
        try $0.base64EncodedString().encode(to: $1)
    }
}

@available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
var iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = .withInternetDateTime
    return formatter
}()

extension ObjectEncoder.EncodingStrategy where T == Date {
    /// Defer to `Date` for choosing an encoding. This is the default strategy.
    public static let deferredToDate = ObjectEncoder.EncodingStrategy<Date>([Date.self, NSDate.self]) {
        try $0.encode(to: $1)
    }

    /// Encode the `Date` as a UNIX timestamp (as a `Double`).
    public static let secondsSince1970 = ObjectEncoder.EncodingStrategy<Date>([Date.self, NSDate.self]) {
        var container = $1.singleValueContainer()
        try container.encode($0.timeIntervalSince1970)
    }

    /// Encode the `Date` as UNIX millisecond timestamp (as a `Double`).
    public static let millisecondsSince1970 = ObjectEncoder.EncodingStrategy<Date>([Date.self, NSDate.self]) {
        var container = $1.singleValueContainer()
        try container.encode(1000.0 * $0.timeIntervalSince1970)
    }

    /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    public static let iso8601 = ObjectEncoder.EncodingStrategy<Date>([Date.self, NSDate.self]) {
        var container = $1.singleValueContainer()
        try container.encode(iso8601Formatter.string(from: $0))
    }

    /// Encode the `Date` as a string formatted by the given formatter.
    public static func formatted(_ formatter: DateFormatter) -> ObjectEncoder.EncodingStrategy<Date> {
        return ObjectEncoder.EncodingStrategy([Date.self, NSDate.self]) {
            var container = $1.singleValueContainer()
            try container.encode(formatter.string(from: $0))
        }
    }
} // swiftlint:disable:this file_length
