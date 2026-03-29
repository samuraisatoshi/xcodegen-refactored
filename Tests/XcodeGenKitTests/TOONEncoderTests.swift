import XCTest
import XcodeGenKit

class TOONEncoderTests: XCTestCase {

    private let enc = TOONEncoder()

    // MARK: - Simple scalars

    func testSimpleScalars() {
        let out = enc.encode(["name": "MyApp", "version": "1.0"])
        XCTAssertTrue(out.contains("name: MyApp"))
        XCTAssertTrue(out.contains("version: \"1.0\""))
    }

    func testBoolScalar() {
        let out = enc.encode(["enabled": true, "debug": false])
        XCTAssertTrue(out.contains("debug: false"))
        XCTAssertTrue(out.contains("enabled: true"))
    }

    func testIntScalar() {
        let out = enc.encode(["count": 42])
        XCTAssertTrue(out.contains("count: 42"))
    }

    // MARK: - Nested object

    func testNestedObject() {
        let out = enc.encode(["outer": ["inner": "value"] as [String: Any]])
        XCTAssertTrue(out.contains("outer:"))
        XCTAssertTrue(out.contains("  inner: value"))
    }

    func testEmptyNestedObject() {
        let out = enc.encode(["empty": [:] as [String: Any]])
        XCTAssertTrue(out.contains("empty:"))
    }

    // MARK: - Primitive array

    func testPrimitiveArray() {
        let out = enc.encode(["targets": ["App", "Tests", "Framework"]])
        XCTAssertTrue(out.contains("targets[3]: App,Tests,Framework"))
    }

    func testEmptyArray() {
        let out = enc.encode(["items": [] as [Any]])
        XCTAssertTrue(out.contains("items[0]:"))
    }

    func testIntArray() {
        let out = enc.encode(["ids": [1, 2, 3]])
        XCTAssertTrue(out.contains("ids[3]: 1,2,3"))
    }

    // MARK: - Tabular array

    func testTabularArray() {
        let rows: [[String: Any]] = [
            ["name": "App", "type": "application", "platform": "iOS"],
            ["name": "Tests", "type": "bundle.unit-test", "platform": "iOS"]
        ]
        let out = enc.encode(["targets": rows])
        // Tabular header line
        XCTAssertTrue(out.contains("targets[2]{"))
        XCTAssertTrue(out.contains("name,platform,type") || out.contains("name,type,platform"))
        // Data rows indented
        XCTAssertTrue(out.contains("  App,"))
        XCTAssertTrue(out.contains("  Tests,"))
    }

    func testTabularArraySingleRow() {
        let rows: [[String: Any]] = [["key": "SWIFT_VERSION", "value": "5.9"]]
        let out = enc.encode(["settings": rows])
        XCTAssertTrue(out.contains("settings[1]{"))
        XCTAssertTrue(out.contains("SWIFT_VERSION"))
        XCTAssertTrue(out.contains("5.9"))
    }

    // MARK: - Mixed array

    func testMixedArray() {
        let mixed: [Any] = ["scalar", ["key": "value"] as [String: Any]]
        let out = enc.encode(["items": mixed])
        XCTAssertTrue(out.contains("items[2]:"))
        XCTAssertTrue(out.contains("  - scalar"))
    }

    // MARK: - Quoting

    func testQuoteKeyword() {
        XCTAssertEqual(enc.quoteIfNeeded("true"), "\"true\"")
        XCTAssertEqual(enc.quoteIfNeeded("false"), "\"false\"")
        XCTAssertEqual(enc.quoteIfNeeded("null"), "\"null\"")
    }

    func testQuoteContainingColon() {
        XCTAssertEqual(enc.quoteIfNeeded("key:value"), "\"key:value\"")
    }

    func testQuoteContainingComma() {
        XCTAssertEqual(enc.quoteIfNeeded("a,b"), "\"a,b\"")
    }

    func testQuoteNumber() {
        XCTAssertEqual(enc.quoteIfNeeded("123"), "\"123\"")
        XCTAssertEqual(enc.quoteIfNeeded("-5"), "\"-5\"")
    }

    func testNoQuotePlainString() {
        XCTAssertEqual(enc.quoteIfNeeded("MyApp"), "MyApp")
        XCTAssertEqual(enc.quoteIfNeeded("application"), "application")
    }

    func testQuoteEmptyString() {
        XCTAssertEqual(enc.quoteIfNeeded(""), "\"\"")
    }

    func testQuoteBrackets() {
        XCTAssertEqual(enc.quoteIfNeeded("a[0]"), "\"a[0]\"")
        XCTAssertEqual(enc.quoteIfNeeded("{x}"), "\"{x}\"")
    }

    // MARK: - Key ordering

    func testKeysAreSorted() {
        let out = enc.encode(["z": "last", "a": "first", "m": "middle"])
        let aIdx = out.range(of: "a:")!.lowerBound
        let mIdx = out.range(of: "m:")!.lowerBound
        let zIdx = out.range(of: "z:")!.lowerBound
        XCTAssertTrue(aIdx < mIdx && mIdx < zIdx)
    }
}
