import XCTest
@testable import ObjectEncoderTests

XCTMain([
    testCase(ObjectEncoderTests.allTests),
    testCase(TestJSONEncoder.allTests)
])
