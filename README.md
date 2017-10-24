# ObjectEncoder for Swift
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE)
[![CI Status](http://img.shields.io/travis/norio-nomura/ObjectEncoder.svg?style=flat)](https://travis-ci.org/norio-nomura/ObjectEncoder)

[SE-1067 Swift Encoders](https://github.com/apple/swift-evolution/blob/master/proposals/0167-swift-encoders.md) implementation using `[String: Any]`, `[Any]` or `Any` as payload.

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

* Swift 4.0 or later

## Author

Norio Nomura

## License

ObjectEncoder is available under the MIT license. See the LICENSE file for more info.
