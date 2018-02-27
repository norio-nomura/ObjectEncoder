//
//  JSON.swift
//  ObjectEncoderPackageDescription
//
//  Created by Norio Nomura on 1/26/18.
//  Copyright (c) 2018 ObjectEncoder. All rights reserved.
//

import Foundation

public final class JSONObjectEncoder {
    public init() {}

    public func encode<T>(_ value: T) throws -> Data where T: Encodable {
        var encoder = ObjectEncoder()
        encoder.encodingStrategies = encodingStrategies
        let encoded = try encoder.encode(value, userInfo: userInfo)
        let writingOptions = JSONSerialization.WritingOptions(rawValue: self.outputFormatting.rawValue)
        guard JSONSerialization.isValidJSONObject(encoded) else {
            throw _invalidValue(value)
        }
        do {
            return try JSONSerialization.data(withJSONObject: encoded, options: writingOptions)
        } catch {
            throw _invalidValue(value, with: error)
        }
    }

    /// The output format to produce. Defaults to `[]`.
    public typealias OutputFormatting = JSONEncoder.OutputFormatting
    public var outputFormatting: OutputFormatting = []

    /// The strategies to use for encoding values.
    public var encodingStrategies: ObjectEncoder.EncodingStrategies = {
        var strategies = ObjectEncoder.EncodingStrategies()
        strategies[Decimal.self] = .compatibleWithJSONEncoder
        strategies[Double.self] = .throwOnNonConformingFloat
        strategies[Float.self] = .throwOnNonConformingFloat
        strategies[URL.self] = .compatibleWithJSONEncoder
        return strategies
    }()

    public typealias DataEncodingStrategy = ObjectEncoder.DataEncodingStrategy?
    public var dataEncodingStrategy: DataEncodingStrategy = .deferredToData {
        didSet { encodingStrategies[Data.self] = dataEncodingStrategy }
    }

    public typealias DateEncodingStrategy = ObjectEncoder.DateEncodingStrategy?
    public var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate {
        didSet { encodingStrategies[Date.self] = dateEncodingStrategy }
    }

    /// The strategy to use for non-JSON-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatEncodingStrategy {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case `throw`

        /// Encode the values using the given representation strings.
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    public var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throw {
        didSet {
            switch nonConformingFloatEncodingStrategy {
            case .throw:
                encodingStrategies[Double.self] = .throwOnNonConformingFloat
                encodingStrategies[Float.self] = .throwOnNonConformingFloat
            case let .convertToString(posInf, negInf, nan):
                encodingStrategies[Double.self] = .convertNonConformingFloatToString(posInf, negInf, nan)
                encodingStrategies[Float.self] = .convertNonConformingFloatToString(posInf, negInf, nan)
            }
        }
    }

    public var userInfo: [CodingUserInfoKey: Any] = [:]

    private func _invalidValue(_ value: Any, with error: Error? = nil) -> EncodingError {
        let debugDescription = "Unable to encode the given top-level value to JSON."
        return .invalidValue(value, .init(codingPath: [], debugDescription: debugDescription, underlyingError: error))
    }
}

public final class JSONObjectDecoder {
    public init() {}

    public func decode<T: Decodable>(_ type: T.Type = T.self, from data: Data) throws -> T {
        let topLevel: Any
        do {
        #if _runtime(_ObjC)
            topLevel = try JSONSerialization.jsonObject(with: data)
        #else
            let useReferenceNumericTypes = JSONSerialization.ReadingOptions(rawValue: 1 << 15)
            topLevel = try JSONSerialization.jsonObject(with: data, options: useReferenceNumericTypes)
        #endif
        } catch {
            throw _dataCorrupted(at: [], "The given data was not valid JSON.", error)
        }

        var decoder = ObjectDecoder()
        decoder.decodingStrategies = decodingStrategies
        return try decoder.decode(type, from: topLevel, userInfo: userInfo)
    }

    public var decodingStrategies: ObjectDecoder.DecodingStrategies = {
        var strategies = ObjectDecoder.DecodingStrategies()
        strategies[Decimal.self] = .compatibleWithJSONDecoder
        strategies[Double.self] = .deferredToDouble
        strategies[Float.self] = .deferredToFloat
        strategies[URL.self] = .compatibleWithJSONDecoder
        return strategies
    }()

    public typealias DataDecodingStrategy = ObjectDecoder.DataDecodingStrategy?
    public var dataDecodingStrategy: DataDecodingStrategy = .deferredToData {
        didSet { decodingStrategies[Data.self] = dataDecodingStrategy }
    }

    public typealias DateDecodingStrategy = ObjectDecoder.DateDecodingStrategy?
    public var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate {
        didSet { decodingStrategies[Date.self] = dateDecodingStrategy }
    }

    /// The strategy to use for non-JSON-conforming floating-point values (IEEE 754 infinity and NaN).
    public enum NonConformingFloatDecodingStrategy {
        /// Throw upon encountering non-conforming values. This is the default strategy.
        case `throw`

        /// Decode the values from the given representation strings.
        case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }

    public var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy = .throw {
        didSet {
            switch nonConformingFloatDecodingStrategy {
            case .throw:
                decodingStrategies[Double.self] = .deferredToDouble
                decodingStrategies[Float.self] = .deferredToFloat
            case let .convertFromString(posInf, negInf, nan):
                decodingStrategies[Double.self] = .convertNonConformingFloatFromString(posInf, negInf, nan)
                decodingStrategies[Float.self] = .convertNonConformingFloatFromString(posInf, negInf, nan)
            }
        }
    }

    public var userInfo: [CodingUserInfoKey: Any] = [:]
}
