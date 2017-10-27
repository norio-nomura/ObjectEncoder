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
            return try _Decoder(referencing: object, userInfo: userInfo).singleValueContainer().decode(T.self)
        } catch let error as DecodingError {
            throw error
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: [],
                                                    debugDescription: "The given data was not valid Object.",
                                                    underlyingError: error))
        }
    }
}

struct _Decoder: Decoder { // swiftlint:disable:this type_name

    private let object: Any

    init(referencing object: Any, userInfo: [CodingUserInfoKey: Any], codingPath: [CodingKey] = []) {
        self.object = object
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

    fileprivate func cast<T>(_ object: Any) throws -> T {
        guard let value = object as? T else {
            throw _typeMismatch(at: codingPath, expectation: T.self, reality: object)
        }
        return value
    }

    /// create a new `_Decoder` instance referencing `object` as `key` inheriting `userInfo`
    fileprivate func decoder(referencing object: Any, `as` key: CodingKey) -> _Decoder {
        return .init(referencing: object, userInfo: userInfo, codingPath: codingPath + [key])
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
        return try T(from: decoder(for: key))
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
        let value = try T(from: currentDecoder)
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
    func decode<T>(_ type: T.Type)   throws -> T where T: Decodable { return try T(from: self) }
}

// MARK: - DecodingError helpers

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
