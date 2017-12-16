//
//  Decoder.swift
//  ObjectEncoder
//
//  Created by Norio Nomura on 10/21/17.
//  Copyright (c) 2017 ObjectEncoder. All rights reserved.
//

import Foundation

public struct ObjectDecoder {
    public init() {}
    public func decode<T>(_ type: T.Type = T.self,
                          from object: Any,
                          userInfo: [CodingUserInfoKey: Any] = [:]) throws -> T where T: Decodable {
        do {
            return try _Decoder(object, options, userInfo).singleValueContainer().decode(T.self)
        } catch let error as DecodingError {
            throw error
        } catch {
            throw _dataCorrupted(at: [], "The given data was not valid Object.", error)
        }
    }

    public struct DecodingStrategy<T: Decodable> {
        public typealias Closure = (Decoder) throws -> T
        public init(identifiers: [ObjectIdentifier], closure: @escaping Closure) {
            self.identifiers = identifiers
            self.closure = closure
        }

        fileprivate let identifiers: [ObjectIdentifier]
        fileprivate let closure: Closure
    }

    public struct DecodingStrategies {
        var strategies = [ObjectIdentifier: Any]()
        public subscript<T>(type: T.Type) -> DecodingStrategy<T>? {
            get { return strategies[ObjectIdentifier(type)] as? DecodingStrategy<T> }
            set {
                if let newValue = newValue {
                    precondition(newValue.identifiers.contains(ObjectIdentifier(type)))
                    newValue.identifiers.forEach { strategies[$0] = newValue }
                } else {
                    if let strategy = strategies[ObjectIdentifier(type)] as? DecodingStrategy<T> {
                        strategy.identifiers.forEach { strategies[$0] = nil }
                    }
                    strategies[ObjectIdentifier(type)] = nil
                }
            }
        }
        public subscript<T>(types: [Any.Type]) -> DecodingStrategy<T>? {
            get { return types.first.map { strategies[ObjectIdentifier($0)] } as? DecodingStrategy<T> }
            set { types.forEach { strategies[ObjectIdentifier($0)] = newValue } }
        }
    }

    /// The strategis to use for decoding values.
    public var decodingStrategies: DecodingStrategies {
        get { return options.decodingStrategies }
        set { options.decodingStrategies = newValue }
    }

    // MARK: -

    fileprivate struct Options {
        fileprivate var decodingStrategies = DecodingStrategies()
    }

    fileprivate var options = Options()
}

struct _Decoder: Decoder { // swiftlint:disable:this type_name

    private let object: Any

    fileprivate typealias Options = ObjectDecoder.Options
    private let options: Options

    fileprivate init(_ object: Any,
                     _ options: Options,
                     _ userInfo: [CodingUserInfoKey: Any],
                     _ codingPath: [CodingKey] = []) {
        self.object = object
        self.options = options
        self.userInfo = userInfo
        self.codingPath = codingPath
    }

    // MARK: - Swift.Decoder Methods

    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return .init(_KeyedDecodingContainer<Key>(decoder: self, wrapping: try cast(object)))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return _UnkeyedDecodingContainer(decoder: self, wrapping: try cast(object))
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer { return self }

    // MARK: -

    fileprivate func cast<T: Decodable>(_ object: Any) throws -> T {
        if let strategy = options.decodingStrategies[T.self] {
            return try strategy.closure(self)
        } else {
            guard let value = object as? T else {
                throw _typeMismatch(at: codingPath, expectation: T.self, reality: object)
            }
            return value
        }
    }

    /// create a new `_Decoder` instance referencing `object` as `key` inheriting `userInfo`
    fileprivate func decoder(referencing object: Any, `as` key: CodingKey) -> _Decoder {
        return .init(object, options, userInfo, codingPath + [key])
    }
}

struct _KeyedDecodingContainer<K: CodingKey> : KeyedDecodingContainerProtocol { // swiftlint:disable:this type_name

    typealias Key = K

    private let decoder: _Decoder
    private let dictionary: [String: Any]

    fileprivate init(decoder: _Decoder, wrapping dictionary: [String: Any]) {
        self.decoder = decoder
        self.dictionary = dictionary
    }

    // MARK: - Swift.KeyedDecodingContainerProtocol Methods

    var codingPath: [CodingKey] { return decoder.codingPath }
    var allKeys: [Key] { return dictionary.keys.flatMap(Key.init) }
    func contains(_ key: Key) -> Bool { return dictionary[key.stringValue] != nil }

    func decodeNil(forKey key: Key) throws -> Bool {
        return try object(for: key) is NSNull
    }

    func decode(_ type: Bool.Type, forKey key: Key)   throws -> Bool { return try unbox(for: key) }
    func decode(_ type: Int.Type, forKey key: Key)    throws -> Int { return try unbox(for: key) }
    func decode(_ type: Int8.Type, forKey key: Key)   throws -> Int8 { return try unbox(for: key) }
    func decode(_ type: Int16.Type, forKey key: Key)  throws -> Int16 { return try unbox(for: key) }
    func decode(_ type: Int32.Type, forKey key: Key)  throws -> Int32 { return try unbox(for: key) }
    func decode(_ type: Int64.Type, forKey key: Key)  throws -> Int64 { return try unbox(for: key) }
    func decode(_ type: UInt.Type, forKey key: Key)   throws -> UInt { return try unbox(for: key) }
    func decode(_ type: UInt8.Type, forKey key: Key)  throws -> UInt8 { return try unbox(for: key) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { return try unbox(for: key) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { return try unbox(for: key) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { return try unbox(for: key) }
    func decode(_ type: Float.Type, forKey key: Key)  throws -> Float { return try unbox(for: key) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { return try unbox(for: key) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { return try unbox(for: key) }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        return try decoder(for: key).decode(T.self)
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type,
                                    forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        return try decoder(for: key).container(keyedBy: NestedKey.self)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return try decoder(for: key).unkeyedContainer()
    }

    func superDecoder() throws -> Decoder { return try decoder(for: _ObjectCodingKey.super) }
    func superDecoder(forKey key: Key) throws -> Decoder { return try decoder(for: key) }

    // MARK: -

    private func object(for key: CodingKey) throws -> Any {
        guard let object = dictionary[key.stringValue] else {
            throw _keyNotFound(at: codingPath, key, "No value associated with key \(key) (\"\(key.stringValue)\").")
        }
        return object
    }

    private func decoder(for key: CodingKey) throws -> _Decoder {
        return decoder.decoder(referencing: try object(for: key), as: key)
    }

    private func unbox<T: Decodable>(for key: Key) throws -> T {
        return try decoder(for: key).cast(object(for: key))
    }
}

struct _UnkeyedDecodingContainer: UnkeyedDecodingContainer { // swiftlint:disable:this type_name

    private let decoder: _Decoder
    private let array: [Any]

    fileprivate init(decoder: _Decoder, wrapping array: [Any]) {
        self.decoder = decoder
        self.array = array
        self.currentIndex = 0
    }

    // MARK: - Swift.UnkeyedDecodingContainer Methods

    var codingPath: [CodingKey] { return decoder.codingPath }
    var count: Int? { return array.count }
    var isAtEnd: Bool { return currentIndex >= array.count }
    var currentIndex: Int

    mutating func decodeNil() throws -> Bool {
        try throwErrorIfAtEnd(Any?.self)
        if currentObject is NSNull {
            currentIndex += 1
            return true
        } else {
            return false
        }
    }

    mutating func decode(_ type: Bool.Type)   throws -> Bool { return try unbox() }
    mutating func decode(_ type: Int.Type)    throws -> Int { return try unbox() }
    mutating func decode(_ type: Int8.Type)   throws -> Int8 { return try unbox() }
    mutating func decode(_ type: Int16.Type)  throws -> Int16 { return try unbox() }
    mutating func decode(_ type: Int32.Type)  throws -> Int32 { return try unbox() }
    mutating func decode(_ type: Int64.Type)  throws -> Int64 { return try unbox() }
    mutating func decode(_ type: UInt.Type)   throws -> UInt { return try unbox() }
    mutating func decode(_ type: UInt8.Type)  throws -> UInt8 { return try unbox() }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { return try unbox() }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { return try unbox() }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { return try unbox() }
    mutating func decode(_ type: Float.Type)  throws -> Float { return try unbox() }
    mutating func decode(_ type: Double.Type) throws -> Double { return try unbox() }
    mutating func decode(_ type: String.Type) throws -> String { return try unbox() }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        try throwErrorIfAtEnd(type)
        let value = try currentDecoder.decode(T.self)
        currentIndex += 1
        return value
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        try throwErrorIfAtEnd(KeyedDecodingContainer<NestedKey>.self)
        let container = try currentDecoder.container(keyedBy: type)
        currentIndex += 1
        return container
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        try throwErrorIfAtEnd(UnkeyedDecodingContainer.self)
        let container = try currentDecoder.unkeyedContainer()
        currentIndex += 1
        return container
    }

    mutating func superDecoder() throws -> Decoder {
        try throwErrorIfAtEnd(Decoder.self)
        defer { currentIndex += 1 }
        return currentDecoder
    }

    // MARK: -

    private var currentKey: CodingKey { return _ObjectCodingKey(index: currentIndex) }
    private var currentObject: Any { return array[currentIndex] }
    private var currentDecoder: _Decoder { return decoder.decoder(referencing: currentObject, as: currentKey) }

    private func throwErrorIfAtEnd<T>(_ type: T.Type) throws {
        if isAtEnd { throw _valueNotFound(at: codingPath + [currentKey], type, "Unkeyed container is at end.") }
    }

    private mutating func unbox<T: Decodable>() throws -> T {
        try throwErrorIfAtEnd(T.self)
        let decoded: T = try currentDecoder.cast(currentObject)
        currentIndex += 1
        return decoded
    }
}

extension _Decoder: SingleValueDecodingContainer {

    // MARK: - Swift.SingleValueDecodingContainer Methods

    func decodeNil() -> Bool { return object is NSNull }
    func decode(_ type: Bool.Type)   throws -> Bool { return try cast(object) }
    func decode(_ type: Int.Type)    throws -> Int { return try cast(object) }
    func decode(_ type: Int8.Type)   throws -> Int8 { return try cast(object) }
    func decode(_ type: Int16.Type)  throws -> Int16 { return try cast(object) }
    func decode(_ type: Int32.Type)  throws -> Int32 { return try cast(object) }
    func decode(_ type: Int64.Type)  throws -> Int64 { return try cast(object) }
    func decode(_ type: UInt.Type)   throws -> UInt { return try cast(object) }
    func decode(_ type: UInt8.Type)  throws -> UInt8 { return try cast(object) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return try cast(object) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return try cast(object) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return try cast(object) }
    func decode(_ type: Float.Type)  throws -> Float { return try cast(object) }
    func decode(_ type: Double.Type) throws -> Double { return try cast(object) }
    func decode(_ type: String.Type) throws -> String { return try cast(object) }
    func decode<T>(_ type: T.Type)   throws -> T where T: Decodable {
        if let strategy = options.decodingStrategies[type] {
            return try strategy.closure(self)
        } else {
            return try T(from: self)
        }
    }
}

// MARK: - DecodingError helpers

private func _dataCorrupted(at codingPath: [CodingKey], _ description: String, _ error: Error? = nil) -> DecodingError {
    let context = DecodingError.Context(codingPath: codingPath, debugDescription: description, underlyingError: error)
    return .dataCorrupted(context)
}

private func _keyNotFound(at codingPath: [CodingKey], _ key: CodingKey, _ description: String) -> DecodingError {
    let context = DecodingError.Context(codingPath: codingPath, debugDescription: description)
    return.keyNotFound(key, context)
}

private func _valueNotFound(at codingPath: [CodingKey], _ type: Any.Type, _ description: String) -> DecodingError {
    let context = DecodingError.Context(codingPath: codingPath, debugDescription: description)
    return .valueNotFound(type, context)
}

private func _typeMismatch(at codingPath: [CodingKey], expectation: Any.Type, reality: Any) -> DecodingError {
    let description = "Expected to decode \(expectation) but found \(type(of: reality)) instead."
    let context = DecodingError.Context(codingPath: codingPath, debugDescription: description)
    return .typeMismatch(expectation, context)
}

// MARK: - ObjectDecoder.DecodingStrategy

extension ObjectDecoder {
    /// The strategy to use for decoding `Data` values.
    public typealias DataDecodingStrategy = DecodingStrategy<Data>
    /// The strategy to use for decoding `Date` values.
    public typealias DateDecodingStrategy = DecodingStrategy<Date>
}

extension ObjectDecoder.DecodingStrategy {
    /// Decode the `T` as a custom value decoded by the given closure.
    public static func custom(_ types: [Any.Type] = [T.self],
                              _ closure: @escaping Closure) -> ObjectDecoder.DecodingStrategy<T> {
        return .init(identifiers: types.map(ObjectIdentifier.init), closure: closure)
    }
}

extension ObjectDecoder.DecodingStrategy where T == Data {
    /// Defer to `Data` for decoding.
    public static let deferredToData: ObjectDecoder.DataDecodingStrategy? = nil

    /// Decode the `Data` from a Base64-encoded string. This is the default strategy.
    public static let base64 = ObjectDecoder.DataDecodingStrategy.custom {
        guard let data = Data(base64Encoded: try String(from: $0)) else {
            throw _dataCorrupted(at: $0.codingPath, "Encountered Data is not valid Base64.")
        }
        return data
    }

    /// Decode the `Data` as a custom value decoded by the given closure.
    public static func custom(_ closure: @escaping Closure) -> ObjectDecoder.DataDecodingStrategy {
        return .init(identifiers: ObjectDecoder.DataDecodingStrategy.identifiers, closure: closure)
    }

    private static let identifiers = [Data.self, NSData.self].map(ObjectIdentifier.init)
}

extension ObjectDecoder.DecodingStrategy where T == Date {
    /// Defer to `Date` for decoding.
    public static let deferredToDate: ObjectDecoder.DateDecodingStrategy? = nil

    /// Decode the `Date` as a UNIX timestamp from a `Double`.
    public static let secondsSince1970 = ObjectDecoder.DateDecodingStrategy.custom {
        Date(timeIntervalSince1970: try Double(from: $0))
    }

    /// Decode the `Date` as UNIX millisecond timestamp from a `Double`.
    public static let millisecondsSince1970 = ObjectDecoder.DateDecodingStrategy.custom {
        Date(timeIntervalSince1970: try Double(from: $0) / 1000.0)
    }
    /// Decode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
    public static let iso8601 = ObjectDecoder.DateDecodingStrategy.custom {
        guard let date = iso8601Formatter.date(from: try String(from: $0)) else {
            throw _dataCorrupted(at: $0.codingPath, "Expected date string to be ISO8601-formatted.")
        }
        return date
    }

    /// Decode the `Date` as a string parsed by the given formatter.
    public static func formatted(_ formatter: DateFormatter) -> ObjectDecoder.DateDecodingStrategy {
        return .custom {
            guard let date = formatter.date(from: try String(from: $0)) else {
                throw _dataCorrupted(at: $0.codingPath, "Date string does not match format expected by formatter.")
            }
            return date
        }
    }

    /// Decode the `Date` as a custom value decoded by the given closure.
    public static func custom(_ closure: @escaping Closure) -> ObjectDecoder.DateDecodingStrategy {
        return .init(identifiers: ObjectDecoder.DateDecodingStrategy.identifiers, closure: closure)
    }

    private static let identifiers = [Date.self, NSDate.self].map(ObjectIdentifier.init)
} // swiftlint:disable:this file_length
