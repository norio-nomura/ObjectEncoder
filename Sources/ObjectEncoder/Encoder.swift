//
//  Encoder.swift
//  ObjectEncoder
//
//  Created by Norio Nomura on 10/21/17.
//  Copyright (c) 2017 ObjectEncoder. All rights reserved.
//

import Foundation

public class ObjectEncoder {
    public init() {}
    public func encode<T>(_ value: T, userInfo: [CodingUserInfoKey: Any] = [:]) throws -> Any where T: Swift.Encodable {
        do {
            let encoder = _Encoder(userInfo: userInfo)
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
}

class _Encoder: Swift.Encoder { // swiftlint:disable:this type_name

    struct Unused {
        private init() {}
        fileprivate static let unused = Unused()
    }

    var object: Any = Unused.unused

    init(userInfo: [CodingUserInfoKey: Any] = [:], codingPath: [CodingKey] = []) {
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

    private func box(_ value: Any) {
        assertCanEncodeNewValue()
        object = value
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
        super.init(userInfo: encoder.userInfo, codingPath: encoder.codingPath + [key])
    }

    fileprivate init(referencing encoder: _Encoder, at index: Int) {
        self.encoder = encoder
        reference = .sequence(index)
        super.init(userInfo: encoder.userInfo, codingPath: encoder.codingPath + [_ObjectCodingKey(index: index)])
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
    func encodeNil(forKey key: Key)               throws { box(NSNull(), for: key) }
    func encode(_ value: Bool, forKey key: Key)   throws { box(value, for: key) }
    func encode(_ value: Int, forKey key: Key)    throws { box(value, for: key) }
    func encode(_ value: Int8, forKey key: Key)   throws { box(value, for: key) }
    func encode(_ value: Int16, forKey key: Key)  throws { box(value, for: key) }
    func encode(_ value: Int32, forKey key: Key)  throws { box(value, for: key) }
    func encode(_ value: Int64, forKey key: Key)  throws { box(value, for: key) }
    func encode(_ value: UInt, forKey key: Key)   throws { box(value, for: key) }
    func encode(_ value: UInt8, forKey key: Key)  throws { box(value, for: key) }
    func encode(_ value: UInt16, forKey key: Key) throws { box(value, for: key) }
    func encode(_ value: UInt32, forKey key: Key) throws { box(value, for: key) }
    func encode(_ value: UInt64, forKey key: Key) throws { box(value, for: key) }
    func encode(_ value: Float, forKey key: Key)  throws { box(value, for: key) }
    func encode(_ value: Double, forKey key: Key) throws { box(value, for: key) }
    func encode(_ value: String, forKey key: Key) throws { box(value, for: key) }
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

    private func box(_ value: Any, for key: CodingKey) {
        encoder.dictionary[key.stringValue] = value
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
    func encodeNil()             throws { box(NSNull()) }
    func encode(_ value: Bool)   throws { box(value) }
    func encode(_ value: Int)    throws { box(value) }
    func encode(_ value: Int8)   throws { box(value) }
    func encode(_ value: Int16)  throws { box(value) }
    func encode(_ value: Int32)  throws { box(value) }
    func encode(_ value: Int64)  throws { box(value) }
    func encode(_ value: UInt)   throws { box(value) }
    func encode(_ value: UInt8)  throws { box(value) }
    func encode(_ value: UInt16) throws { box(value) }
    func encode(_ value: UInt32) throws { box(value) }
    func encode(_ value: UInt64) throws { box(value) }
    func encode(_ value: Float)  throws { box(value) }
    func encode(_ value: Double) throws { box(value) }
    func encode(_ value: String) throws { box(value) }
    func encode<T>(_ value: T)   throws where T: Encodable { try value.encode(to: currentEncoder) }

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

    private func box(_ value: Any) {
        encoder.array.append(value)
    }
}

extension _Encoder: SingleValueEncodingContainer {

    // MARK: - Swift.SingleValueEncodingContainer Methods

    func encodeNil()             throws { box(NSNull()) }
    func encode(_ value: Bool)   throws { box(value) }
    func encode(_ value: Int)    throws { box(value) }
    func encode(_ value: Int8)   throws { box(value) }
    func encode(_ value: Int16)  throws { box(value) }
    func encode(_ value: Int32)  throws { box(value) }
    func encode(_ value: Int64)  throws { box(value) }
    func encode(_ value: UInt)   throws { box(value) }
    func encode(_ value: UInt8)  throws { box(value) }
    func encode(_ value: UInt16) throws { box(value) }
    func encode(_ value: UInt32) throws { box(value) }
    func encode(_ value: UInt64) throws { box(value) }
    func encode(_ value: Float)  throws { box(value) }
    func encode(_ value: Double) throws { box(value) }
    func encode(_ value: String) throws { box(value) }

    func encode<T>(_ value: T) throws where T: Encodable {
        assertCanEncodeNewValue()
        try value.encode(to: self)
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
