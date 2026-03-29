import XCTest
@testable import TradePilot

final class KeychainTests: XCTestCase {
    private var keychain: KeychainManager!
    private let testService = "com.tradepilot.test_key_\(Int.random(in: 100_000...999_999))"

    override func setUp() {
        super.setUp()
        keychain = KeychainManager()
        keychain.delete(service: testService)   // ensure clean state
    }

    override func tearDown() {
        keychain.delete(service: testService)
        super.tearDown()
    }

    // MARK: - Basic CRUD

    func testSaveAndLoad() throws {
        try keychain.save(key: "secret123", service: testService)
        XCTAssertEqual(keychain.load(service: testService), "secret123")
    }

    func testMissingKeyReturnsNil() {
        XCTAssertNil(keychain.load(service: "nonexistent_service_\(UUID().uuidString)"))
    }

    func testDelete() throws {
        try keychain.save(key: "toDelete", service: testService)
        XCTAssertNotNil(keychain.load(service: testService))
        keychain.delete(service: testService)
        XCTAssertNil(keychain.load(service: testService))
    }

    func testDeleteNonExistentIsSilent() {
        // Should not throw or crash
        keychain.delete(service: "never_existed_\(UUID().uuidString)")
    }

    // MARK: - Overwrite (update)

    func testOverwriteExistingKey() throws {
        try keychain.save(key: "first", service: testService)
        try keychain.save(key: "second", service: testService)
        XCTAssertEqual(keychain.load(service: testService), "second")
    }

    // MARK: - Multiple distinct services

    func testMultipleServices() throws {
        let service2 = testService + "_2"
        defer { keychain.delete(service: service2) }

        try keychain.save(key: "key1", service: testService)
        try keychain.save(key: "key2", service: service2)

        XCTAssertEqual(keychain.load(service: testService), "key1")
        XCTAssertEqual(keychain.load(service: service2), "key2")
    }

    // MARK: - Unicode / special characters

    func testSpecialCharacters() throws {
        let specialKey = "abc!@#$%^&*()_+😀"
        try keychain.save(key: specialKey, service: testService)
        XCTAssertEqual(keychain.load(service: testService), specialKey)
    }

    // MARK: - Known service key constants

    func testServiceKeyConstants() {
        let keys = [
            KeychainManager.ServiceKey.polygonAPIKey,
            KeychainManager.ServiceKey.unusualWhalesAPIKey,
            KeychainManager.ServiceKey.redditClientID,
            KeychainManager.ServiceKey.redditClientSecret,
            KeychainManager.ServiceKey.newsAPIKey,
            KeychainManager.ServiceKey.claudeAPIKey
        ]
        // All constants should be non-empty distinct strings
        XCTAssertEqual(Set(keys).count, keys.count, "Service key constants must be unique")
        XCTAssertTrue(keys.allSatisfy { !$0.isEmpty })
    }
}
