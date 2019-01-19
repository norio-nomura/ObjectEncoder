import XCTest
import ObjectEncoder

// swiftlint:disable identifier_name

class ObjectEncoderTests: XCTestCase {
    func testValuesInSingleValueContainer() throws {
        _testRoundTrip(of: true, expectedObject: true)
        _testRoundTrip(of: false, expectedObject: false)

        _testFixedWidthInteger(type: Int.self)
        _testFixedWidthInteger(type: Int8.self)
        _testFixedWidthInteger(type: Int16.self)
        _testFixedWidthInteger(type: Int32.self)
        _testFixedWidthInteger(type: Int64.self)
        _testFixedWidthInteger(type: UInt.self)
        _testFixedWidthInteger(type: UInt8.self)
        _testFixedWidthInteger(type: UInt16.self)
        _testFixedWidthInteger(type: UInt32.self)
        _testFixedWidthInteger(type: UInt64.self)

        _testFloatingPoint(type: Float.self)
        _testFloatingPoint(type: Double.self)

        _testRoundTrip(of: "", expectedObject: "")
        _testRoundTrip(of: URL(string: "https://apple.com")!, expectedObject: ["relative": "https://apple.com"])
    }

    func testValuesInKeyedContainer() throws {
        _testRoundTrip(of: KeyedSynthesized(
            bool: true, int: .max, int8: .max, int16: .max, int32: .max, int64: .max,
            uint: .max, uint8: .max, uint16: .max, uint32: .max, uint64: .max,
            float: .greatestFiniteMagnitude, double: .greatestFiniteMagnitude, string: "", optionalString: nil,
            url: URL(string: "https://apple.com")!
        ))
    }

    func testValuesInUnkeyedContainer() throws {
        _testRoundTrip(of: Unkeyed(
            bool: true, int: .max, int8: .max, int16: .max, int32: .max, int64: .max,
            uint: .max, uint8: .max, uint16: .max, uint32: .max, uint64: .max,
            float: .greatestFiniteMagnitude, double: .greatestFiniteMagnitude, string: "", optionalString: nil,
            url: URL(string: "https://apple.com")!
        ))
    }

    func testNestedContainerCodingPaths() {
        _testRoundTrip(of: NestedContainersTestType())
    }

    func testSuperEncoderCodingPaths() {
        _testRoundTrip(of: NestedContainersTestType(testSuperCoder: true))
    }

    // MARK: - Date Strategy Tests
    func testEncodingDate() {
        _testRoundTrip(of: Date())
    }

    func testEncodingDateSecondsSince1970() {
        // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
        _testRoundTrip(of: Date(timeIntervalSince1970: 1000),
                       expectedObject: 1000.0,
                       dateEncodingStrategy: .secondsSince1970,
                       dateDecodingStrategy: .secondsSince1970)
    }

    func testEncodingDateMillisecondsSince1970() {
        // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
        _testRoundTrip(of: Date(timeIntervalSince1970: 1000),
                       expectedObject: 1000000.0,
                       dateEncodingStrategy: .millisecondsSince1970,
                       dateDecodingStrategy: .millisecondsSince1970)
    }

    func testEncodingDateISO8601() {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
            // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
            _testRoundTrip(of: Date(timeIntervalSince1970: 1000),
                           expectedObject: "1970-01-01T00:16:40Z",
                           dateEncodingStrategy: .iso8601,
                           dateDecodingStrategy: .iso8601)
        }
    }

    func testEncodingDateFormatted() {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
    #if _runtime(_ObjC)
        let expected = "Thursday, January 1, 1970 at 12:16:40 AM Greenwich Mean Time"
    #else
        #if swift(>=4.1.50)
            #if compiler(>=5)
                let expected = "Thursday, January 1, 1970 at 12:16:40 AM Greenwich Mean Time"
            #else
                let expected = "Thursday, January 1, 1970 at 12:16:40 AM GMT"
            #endif
        #else
            let expected = "Thursday, January 1, 1970 at 12:16:40 AM GMT"
        #endif
    #endif
        // Cannot encode an arbitrary number of seconds since we've lost precision since 1970.
        _testRoundTrip(of: Date(timeIntervalSince1970: 1000),
                       expectedObject: expected,
                       dateEncodingStrategy: .formatted(formatter),
                       dateDecodingStrategy: .formatted(formatter))
    }

    func testEncodingDateCustom() {
        let timestamp = Date()
        // We'll encode a number instead of a date.
        let encodeNumber = { (_ data: Date, _ encoder: Encoder) throws -> Void in
            var container = encoder.singleValueContainer()
            try container.encode(42)
        }
        let decodeNumber = { (_: Decoder) throws -> Date in return timestamp }
        _testRoundTrip(of: timestamp,
                       expectedObject: 42,
                       dateEncodingStrategy: .custom(encodeNumber),
                       dateDecodingStrategy: .custom(decodeNumber))
    }

    func testEncodingDateCustomEmpty() {
        let timestamp = Date()
        // Encoding nothing should encode an empty keyed container ({}).
        let encodeEmpty = { (_: Date, _: Encoder) throws -> Void in }
        let decodeEmpty = { (_: Decoder) throws -> Date in return timestamp }
        _testRoundTrip(of: timestamp,
                       dateEncodingStrategy: .custom(encodeEmpty),
                       dateDecodingStrategy: .custom(decodeEmpty))
    }

    // MARK: - Data Strategy Tests
    func testEncodingData() {
        let data = Data(bytes: [0xDE, 0xAD, 0xBE, 0xEF])

        let expectedObject = [0xDE, 0xAD, 0xBE, 0xEF]
        _testRoundTrip(of: data,
                       expectedObject: expectedObject,
                       dataEncodingStrategy: .deferredToData,
                       dataDecodingStrategy: .deferredToData)
    }

    func testEncodingDataBase64() {
        let data = Data(bytes: [0xDE, 0xAD, 0xBE, 0xEF])

        let expectedObject = "3q2+7w=="
        _testRoundTrip(of: data,
                       expectedObject: expectedObject,
                       dataEncodingStrategy: .base64,
                       dataDecodingStrategy: .base64)
    }

    func testEncodingDataCustom() {
        // We'll encode a number instead of data.
        let encode = { (_ data: Data, _ encoder: Encoder) throws -> Void in
            var container = encoder.singleValueContainer()
            try container.encode(42)
        }
        let decode = { (_: Decoder) throws -> Data in return Data() }

        let expectedObject = 42
        _testRoundTrip(of: Data(),
                       expectedObject: expectedObject,
                       dataEncodingStrategy: .custom(encode),
                       dataDecodingStrategy: .custom(decode))
    }

    func testEncodingDataCustomEmpty() {
        // Encoding nothing should encode an empty keyed container ({}).
        let encode = { (_: Data, _: Encoder) throws -> Void in }
        let decode = { (_: Decoder) throws -> Data in return Data() }

        _testRoundTrip(of: Data(),
                       dataEncodingStrategy: .custom(encode),
                       dataDecodingStrategy: .custom(decode))
    }

    func testDecodingConcreteTypeParameter() {

        let encoder = ObjectEncoder()
        guard let json = try? encoder.encode(Employee.testValue) else {
            XCTFail("Unable to encode Employee.")
            return
        }

        let decoder = ObjectDecoder()
        guard let decoded = try? decoder.decode(Employee.self as Person.Type, from: json) else {
            XCTFail("Failed to decode Employee as Person from Any.")
            return
        }

        XCTAssertTrue(type(of: decoded) == Employee.self,
                      "Expected decoded value to be of type Employee; got \(type(of: decoded)) instead.")
    }

    // MARK: -

    private func _testFixedWidthInteger<T>(type: T.Type,
                                           file: StaticString = #file,
                                           line: UInt = #line) where T: FixedWidthInteger & Codable {
        _testRoundTrip(of: type.min, expectedObject: type.min, file: file, line: line)
        _testRoundTrip(of: type.max, expectedObject: type.max, file: file, line: line)
    }

    private func _testFloatingPoint<T>(type: T.Type,
                                       file: StaticString = #file,
                                       line: UInt = #line) where T: FloatingPoint & Codable {
        _testRoundTrip(of: type.leastNormalMagnitude, expectedObject: type.leastNormalMagnitude, file: file, line: line)
        _testRoundTrip(of: type.greatestFiniteMagnitude,
                       expectedObject: type.greatestFiniteMagnitude, file: file, line: line)
        _testRoundTrip(of: type.infinity, expectedObject: type.infinity, file: file, line: line)
    }

    private func _testRoundTrip<T>(of object: T,
                                   expectedObject: Any? = nil,
                                   dateEncodingStrategy: ObjectEncoder.DateEncodingStrategy? = nil,
                                   dateDecodingStrategy: ObjectDecoder.DateDecodingStrategy? = nil,
                                   dataEncodingStrategy: ObjectEncoder.DataEncodingStrategy? = nil,
                                   dataDecodingStrategy: ObjectDecoder.DataDecodingStrategy? = nil,
                                   file: StaticString = #file,
                                   line: UInt = #line) where T: Codable, T: Equatable {
        do {
            var encoder = ObjectEncoder()
            encoder.encodingStrategies[Date.self] = dateEncodingStrategy
            encoder.encodingStrategies[Data.self] = dataEncodingStrategy
            let producedObject = try encoder.encode(object)
            if let produced = producedObject as? NSObject, let expected = expectedObject as? NSObject {
                XCTAssertEqual(produced, expected, file: file, line: line)
            }
            var decoder = ObjectDecoder()
            decoder.decodingStrategies[Date.self] = dateDecodingStrategy
            decoder.decodingStrategies[Data.self] = dataDecodingStrategy
            let decoded = try decoder.decode(T.self, from: producedObject)
            XCTAssertEqual(decoded, object, "\(T.self) did not round-trip to an equal value.",
                file: file, line: line)

        } catch let error as EncodingError {
            XCTFail("Failed to encode \(T.self) from Object by error: \(error)", file: file, line: line)
        } catch let error as DecodingError {
            XCTFail("Failed to decode \(T.self) from Object by error: \(error)", file: file, line: line)
        } catch {
            XCTFail("Rout trip test of \(T.self) failed with error: \(error)", file: file, line: line)
        }
    }

    static var allTests = [
        ("testValuesInSingleValueContainer", testValuesInSingleValueContainer),
        ("testValuesInKeyedContainer", testValuesInKeyedContainer),
        ("testValuesInUnkeyedContainer", testValuesInUnkeyedContainer),
        ("testNestedContainerCodingPaths", testNestedContainerCodingPaths),
        ("testSuperEncoderCodingPaths", testSuperEncoderCodingPaths),
        ("testEncodingDate", testEncodingDate),
        ("testEncodingDateSecondsSince1970", testEncodingDateSecondsSince1970),
        ("testEncodingDateMillisecondsSince1970", testEncodingDateMillisecondsSince1970),
        ("testEncodingDateISO8601", testEncodingDateISO8601),
        ("testEncodingDateFormatted", testEncodingDateFormatted),
        ("testEncodingDateCustom", testEncodingDateCustom),
        ("testEncodingDateCustomEmpty", testEncodingDateCustomEmpty),
        ("testEncodingData", testEncodingData),
        ("testEncodingDataBase64", testEncodingDataBase64),
        ("testEncodingDataCustom", testEncodingDataCustom),
        ("testEncodingDataCustomEmpty", testEncodingDataCustomEmpty),
        ("testDecodingConcreteTypeParameter", testDecodingConcreteTypeParameter)
    ]
}

private struct KeyedSynthesized: Codable, Equatable {
    static func == (lhs: KeyedSynthesized, rhs: KeyedSynthesized) -> Bool {
        return lhs.bool == rhs.bool &&
            lhs.int == rhs.int && lhs.int8 == rhs.int8 &&  lhs.int16 == rhs.int16 &&
            lhs.int32 == rhs.int32 && lhs.int64 == rhs.int64 &&
            lhs.uint == rhs.uint && lhs.uint8 == rhs.uint8 &&  lhs.uint16 == rhs.uint16 &&
            lhs.uint32 == rhs.uint32 && lhs.uint64 == rhs.uint64 &&
            lhs.float == rhs.float && lhs.double == rhs.double &&
            lhs.string == rhs.string && lhs.optionalString == rhs.optionalString &&
            lhs.url == rhs.url
    }

    var bool: Bool = true
    let int: Int
    let int8: Int8
    let int16: Int16
    let int32: Int32
    let int64: Int64
    let uint: UInt
    let uint8: UInt8
    let uint16: UInt16
    let uint32: UInt32
    let uint64: UInt64
    let float: Float
    let double: Double
    let string: String
    let optionalString: String?
    let url: URL
}

private struct Unkeyed: Codable, Equatable {
    static func == (lhs: Unkeyed, rhs: Unkeyed) -> Bool {
        return lhs.bool == rhs.bool &&
            lhs.int == rhs.int && lhs.int8 == rhs.int8 &&  lhs.int16 == rhs.int16 &&
            lhs.int32 == rhs.int32 && lhs.int64 == rhs.int64 &&
            lhs.uint == rhs.uint && lhs.uint8 == rhs.uint8 &&  lhs.uint16 == rhs.uint16 &&
            lhs.uint32 == rhs.uint32 && lhs.uint64 == rhs.uint64 &&
            lhs.float == rhs.float && lhs.double == rhs.double &&
            lhs.string == rhs.string && lhs.optionalString == rhs.optionalString &&
            lhs.url == rhs.url
    }

    let bool: Bool
    let int: Int
    let int8: Int8
    let int16: Int16
    let int32: Int32
    let int64: Int64
    let uint: UInt
    let uint8: UInt8
    let uint16: UInt16
    let uint32: UInt32
    let uint64: UInt64
    let float: Float
    let double: Double
    let string: String
    let optionalString: String?
    let url: URL

    init(
        bool: Bool, int: Int, int8: Int8, int16: Int16, int32: Int32, int64: Int64,
        uint: UInt, uint8: UInt8, uint16: UInt16, uint32: UInt32, uint64: UInt64,
        float: Float, double: Double, string: String, optionalString: String?, url: URL) {
        self.bool = bool
        self.int = int
        self.int8 = int8
        self.int16 = int16
        self.int32 = int32
        self.int64 = int64
        self.uint = uint
        self.uint8 = uint8
        self.uint16 = uint16
        self.uint32 = uint32
        self.uint64 = uint64
        self.float = float
        self.double = double
        self.string = string
        self.optionalString = optionalString
        self.url = url
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        bool = try container.decode(Bool.self)
        int = try container.decode(Int.self)
        int8 = try container.decode(Int8.self)
        int16 = try container.decode(Int16.self)
        int32 = try container.decode(Int32.self)
        int64 = try container.decode(Int64.self)
        uint = try container.decode(UInt.self)
        uint8 = try container.decode(UInt8.self)
        uint16 = try container.decode(UInt16.self)
        uint32 = try container.decode(UInt32.self)
        uint64 = try container.decode(UInt64.self)
        float = try container.decode(Float.self)
        double = try container.decode(Double.self)
        string = try container.decode(String.self)
        optionalString = try container.decode(String?.self)
        url = try container.decode(URL.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(bool)
        try container.encode(int)
        try container.encode(int8)
        try container.encode(int16)
        try container.encode(int32)
        try container.encode(int64)
        try container.encode(uint)
        try container.encode(uint8)
        try container.encode(uint16)
        try container.encode(uint32)
        try container.encode(uint64)
        try container.encode(float)
        try container.encode(double)
        try container.encode(string)
        try container.encode(optionalString)
        try container.encode(url)
    }
}

// Copied from https://github.com/apple/swift/blob/master/test/stdlib/TestJSONEncoder.swift
func expectEqualPaths(_ lhs: [CodingKey],
                      _ rhs: [CodingKey],
                      _ prefix: String,
                      file: StaticString = #file,
                      line: UInt = #line) {
    if lhs.count != rhs.count {
        XCTFail("\(prefix) [CodingKey].count mismatch: \(lhs.count) != \(rhs.count)", file: file, line: line)
        return
    }

    for (key1, key2) in zip(lhs, rhs) {
        switch (key1.intValue, key2.intValue) {
        case (.none, .none): break
        case (.some(let i1), .none):
            XCTFail("\(prefix) CodingKey.intValue mismatch: \(type(of: key1))(\(i1)) != nil", file: file, line: line)
            return
        case (.none, .some(let i2)):
            XCTFail("\(prefix) CodingKey.intValue mismatch: nil != \(type(of: key2))(\(i2))", file: file, line: line)
            return
        case (.some(let i1), .some(let i2)):
            guard i1 == i2 else {
                XCTFail("\(prefix) CodingKey.intValue mismatch: \(type(of: key1))(\(i1)) != \(type(of: key2))(\(i2))",
                    file: file, line: line)
                return
            }
        }

        XCTAssertEqual(key1.stringValue, key2.stringValue, """
            \(prefix) CodingKey.stringValue mismatch: \
            \(type(of: key1))('\(key1.stringValue)') != \(type(of: key2))('\(key2.stringValue)')
            """, file: file, line: line)
    }
}

private struct _TestKey: CodingKey {
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

    static let `super` = _TestKey(stringValue: "super")!
}

private struct NestedContainersTestType: Codable, Equatable {
    let testSuperCoder: Bool

    static func == (lhs: NestedContainersTestType, rhs: NestedContainersTestType) -> Bool {
        return lhs.testSuperCoder == rhs.testSuperCoder
    }

    init(testSuperCoder: Bool = false) {
        self.testSuperCoder = testSuperCoder
    }

    enum TopLevelCodingKeys: Int, CodingKey {
        case testSuperCoder
        case a
        case b
        case c
    }

    enum IntermediateCodingKeys: Int, CodingKey {
        case one
        case two
    }

    // swiftlint:disable line_length
    func encode(to encoder: Encoder) throws {
        var topLevelContainer = encoder.container(keyedBy: TopLevelCodingKeys.self)
        try topLevelContainer.encode(testSuperCoder, forKey: .testSuperCoder)

        if self.testSuperCoder {
            expectEqualPaths(encoder.codingPath, [], "Top-level Encoder's codingPath changed.")
            expectEqualPaths(topLevelContainer.codingPath, [], "New first-level keyed container has non-empty codingPath.")

            let superEncoder = topLevelContainer.superEncoder(forKey: .a)
            expectEqualPaths(encoder.codingPath, [], "Top-level Encoder's codingPath changed.")
            expectEqualPaths(topLevelContainer.codingPath, [], "First-level keyed container's codingPath changed.")
            expectEqualPaths(superEncoder.codingPath, [TopLevelCodingKeys.a], "New superEncoder had unexpected codingPath.")
            _testNestedContainers(in: superEncoder, baseCodingPath: [TopLevelCodingKeys.a])
        } else {
            _testNestedContainers(in: encoder, baseCodingPath: [])
        }
    }

    func _testNestedContainers(in encoder: Encoder, baseCodingPath: [CodingKey]) {
        expectEqualPaths(encoder.codingPath, baseCodingPath, "New encoder has non-empty codingPath.")

        // codingPath should not change upon fetching a non-nested container.
        var firstLevelContainer = encoder.container(keyedBy: TopLevelCodingKeys.self)
        expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
        expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "New first-level keyed container has non-empty codingPath.")

        // Nested Keyed Container
        do {
            // Nested container for key should have a new key pushed on.
            var secondLevelContainer = firstLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self, forKey: .a)
            expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "New second-level keyed container had unexpected codingPath.")

            // Inserting a keyed container should not change existing coding paths.
            let thirdLevelContainerKeyed = secondLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self, forKey: .one)
            expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "Second-level keyed container's codingPath changed.")
            expectEqualPaths(thirdLevelContainerKeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.one], "New third-level keyed container had unexpected codingPath.")

            // Inserting an unkeyed container should not change existing coding paths.
            let thirdLevelContainerUnkeyed = secondLevelContainer.nestedUnkeyedContainer(forKey: .two)
            expectEqualPaths(encoder.codingPath, baseCodingPath + [], "Top-level Encoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath + [], "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "Second-level keyed container's codingPath changed.")
            expectEqualPaths(thirdLevelContainerUnkeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.two], "New third-level unkeyed container had unexpected codingPath.")
        }

        // Nested Unkeyed Container
        do {
            // Nested container for key should have a new key pushed on.
            var secondLevelContainer = firstLevelContainer.nestedUnkeyedContainer(forKey: .b)
            expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "New second-level keyed container had unexpected codingPath.")

            // Appending a keyed container should not change existing coding paths.
            let thirdLevelContainerKeyed = secondLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self)
            expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "Second-level unkeyed container's codingPath changed.")
            expectEqualPaths(thirdLevelContainerKeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 0)], "New third-level keyed container had unexpected codingPath.")

            // Appending an unkeyed container should not change existing coding paths.
            let thirdLevelContainerUnkeyed = secondLevelContainer.nestedUnkeyedContainer()
            expectEqualPaths(encoder.codingPath, baseCodingPath, "Top-level Encoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "Second-level unkeyed container's codingPath changed.")
            expectEqualPaths(thirdLevelContainerUnkeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 1)], "New third-level unkeyed container had unexpected codingPath.")
        }
    }

    init(from decoder: Decoder) throws {
        let topLevelContainer = try decoder.container(keyedBy: TopLevelCodingKeys.self)
        testSuperCoder = try topLevelContainer.decode(Bool.self, forKey: .testSuperCoder)
        if self.testSuperCoder {
            expectEqualPaths(decoder.codingPath, [], "Top-level Decoder's codingPath changed.")
            expectEqualPaths(topLevelContainer.codingPath, [], "New first-level keyed container has non-empty codingPath.")

            let superDecoder = try topLevelContainer.superDecoder(forKey: .a)
            expectEqualPaths(decoder.codingPath, [], "Top-level Decoder's codingPath changed.")
            expectEqualPaths(topLevelContainer.codingPath, [], "First-level keyed container's codingPath changed.")
            expectEqualPaths(superDecoder.codingPath, [TopLevelCodingKeys.a], "New superDecoder had unexpected codingPath.")
            try _testNestedContainers(in: superDecoder, baseCodingPath: [TopLevelCodingKeys.a])
        } else {
            try _testNestedContainers(in: decoder, baseCodingPath: [])
        }
    }

    func _testNestedContainers(in decoder: Decoder, baseCodingPath: [CodingKey]) throws {
        expectEqualPaths(decoder.codingPath, baseCodingPath, "New decoder has non-empty codingPath.")

        // codingPath should not change upon fetching a non-nested container.
        let firstLevelContainer = try decoder.container(keyedBy: TopLevelCodingKeys.self)
        expectEqualPaths(decoder.codingPath, baseCodingPath, "Top-level Decoder's codingPath changed.")
        expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "New first-level keyed container has non-empty codingPath.")

        // Nested Keyed Container
        do {
            // Nested container for key should have a new key pushed on.
            let secondLevelContainer = try firstLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self, forKey: .a)
            expectEqualPaths(decoder.codingPath, baseCodingPath, "Top-level Decoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "New second-level keyed container had unexpected codingPath.")

            // Inserting a keyed container should not change existing coding paths.
            let thirdLevelContainerKeyed = try secondLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self, forKey: .one)
            expectEqualPaths(decoder.codingPath, baseCodingPath, "Top-level Decoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "Second-level keyed container's codingPath changed.")
            expectEqualPaths(thirdLevelContainerKeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.one], "New third-level keyed container had unexpected codingPath.")

            // Inserting an unkeyed container should not change existing coding paths.
            let thirdLevelContainerUnkeyed = try secondLevelContainer.nestedUnkeyedContainer(forKey: .two)
            expectEqualPaths(decoder.codingPath, baseCodingPath + [], "Top-level Decoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath + [], "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.a], "Second-level keyed container's codingPath changed.")
            expectEqualPaths(thirdLevelContainerUnkeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.a, IntermediateCodingKeys.two], "New third-level unkeyed container had unexpected codingPath.")
        }

        // Nested Unkeyed Container
        do {
            // Nested container for key should have a new key pushed on.
            var secondLevelContainer = try firstLevelContainer.nestedUnkeyedContainer(forKey: .b)
            expectEqualPaths(decoder.codingPath, baseCodingPath, "Top-level Decoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "New second-level keyed container had unexpected codingPath.")

            // Appending a keyed container should not change existing coding paths.
            let thirdLevelContainerKeyed = try secondLevelContainer.nestedContainer(keyedBy: IntermediateCodingKeys.self)
            expectEqualPaths(decoder.codingPath, baseCodingPath, "Top-level Decoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "Second-level unkeyed container's codingPath changed.")
            expectEqualPaths(thirdLevelContainerKeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 0)], "New third-level keyed container had unexpected codingPath.")

            // Appending an unkeyed container should not change existing coding paths.
            let thirdLevelContainerUnkeyed = try secondLevelContainer.nestedUnkeyedContainer()
            expectEqualPaths(decoder.codingPath, baseCodingPath, "Top-level Decoder's codingPath changed.")
            expectEqualPaths(firstLevelContainer.codingPath, baseCodingPath, "First-level keyed container's codingPath changed.")
            expectEqualPaths(secondLevelContainer.codingPath, baseCodingPath + [TopLevelCodingKeys.b], "Second-level unkeyed container's codingPath changed.")
            expectEqualPaths(thirdLevelContainerUnkeyed.codingPath, baseCodingPath + [TopLevelCodingKeys.b, _TestKey(index: 1)], "New third-level unkeyed container had unexpected codingPath.")
        }
    }
}

/// A simple person class that encodes as a dictionary of values.
private class Person: Codable, Equatable {
    let name: String
    let email: String
    let website: URL?

    init(name: String, email: String, website: URL? = nil) {
        self.name = name
        self.email = email
        self.website = website
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case email
        case website
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        website = try container.decodeIfPresent(URL.self, forKey: .website)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(website, forKey: .website)
    }

    func isEqual(_ other: Person) -> Bool {
        return self.name == other.name &&
            self.email == other.email &&
            self.website == other.website
    }

    static func == (_ lhs: Person, _ rhs: Person) -> Bool {
        return lhs.isEqual(rhs)
    }

    class var testValue: Person {
        return Person(name: "Johnny Appleseed", email: "appleseed@apple.com")
    }
}

/// A class which shares its encoder and decoder with its superclass.
private class Employee: Person {
    let id: Int

    init(name: String, email: String, website: URL? = nil, id: Int) {
        self.id = id
        super.init(name: name, email: email, website: website)
    }

    enum CodingKeys: String, CodingKey {
        case id
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try super.encode(to: encoder)
    }

    override func isEqual(_ other: Person) -> Bool {
        if let employee = other as? Employee {
            guard self.id == employee.id else { return false }
        }

        return super.isEqual(other)
    }

    override class var testValue: Employee {
        return Employee(name: "Johnny Appleseed", email: "appleseed@apple.com", id: 42)
    }
}

// swiftlint:disable:this file_length
