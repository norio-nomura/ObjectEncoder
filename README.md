# ObjectEncoder for Swift
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)
[![SwiftPM](https://github.com/norio-nomura/ObjectEncoder/workflows/SwiftPM/badge.svg)](https://launch-editor.github.com/actions?workflowID=SwiftPM&event=pull_request&nwo=norio-nomura%2FObjectEncoder)
[![Nightly](https://github.com/norio-nomura/ObjectEncoder/workflows/Nightly/badge.svg)](https://launch-editor.github.com/actions?workflowID=Nightly&event=pull_request&nwo=norio-nomura%2FObjectEncoder)
[![xcodebuild](https://github.com/norio-nomura/ObjectEncoder/workflows/xcodebuild/badge.svg)](https://launch-editor.github.com/actions?workflowID=xcodebuild&event=pull_request&nwo=norio-nomura%2FObjectEncoder)
[![pod lib lint](https://github.com/norio-nomura/ObjectEncoder/workflows/pod%20lib%20lint/badge.svg)](https://launch-editor.github.com/actions?workflowID=pod%20lib%20lint&event=pull_request&nwo=norio-nomura%2FObjectEncoder)
[![codecov](https://codecov.io/gh/norio-nomura/ObjectEncoder/branch/master/graph/badge.svg)](https://codecov.io/gh/norio-nomura/ObjectEncoder)

[SE-0167 Swift Encoders](https://github.com/apple/swift-evolution/blob/master/proposals/0167-swift-encoders.md) implementation using `[String: Any]`, `[Any]` or `Any` as payload.

## Usage

```swift
import Foundation
import ObjectEncoder

// single value
let string = "Hello, ObjectEncoder"
let encodedString = try ObjectEncoder().encode(string)
(encodedString as AnyObject).isEqual(to: string) // true
let decodedString = try ObjectDecoder().decode(String.self, from: encodedString)

// dictionary
struct S: Codable { let p1: String }
let s = S(p1: "string")
guard let encodedS = try ObjectEncoder().encode(s) as? [String: Any] else { fatalError() }
encodedS["p1"] // "string"
let decodedS = try ObjectDecoder().decode(S.self, from: encodedS)
decodedS.p1 // "string"

// array
let array: [S] = [s, s]
guard let encoded = try ObjectEncoder().encode(array) as? [[String: Any]] else { fatalError() }
encoded[0]["p1"] // "string"
let decoded = try ObjectDecoder().decode([S].self, from: encoded)
decoded[0].p1   // "string"
```

## Requirements

* Swift 4.0+ on Darwin, Swift 4.0.2+ on swift-corelibs-foundation

## Author

Norio Nomura

## License

ObjectEncoder is available under the MIT license. See the LICENSE file for more info.
