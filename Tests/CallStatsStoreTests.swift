import XCTest
@testable import Zvonilka

final class CallStatsStoreTests: XCTestCase {
    func testIncrementIncreasesCount() {
        let defaults = UserDefaults(suiteName: #file)!
        defaults.removePersistentDomain(forName: #file)

        let store = CallStatsStore(userDefaults: defaults)
        let key = "test_123"

        XCTAssertEqual(store.callsCount(for: key), 0)
        store.incrementCall(for: key)
        XCTAssertEqual(store.callsCount(for: key), 1)
    }

    func testResetClearsAllCounts() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = CallStatsStore(userDefaults: defaults)
        store.incrementCall(for: "a")
        store.incrementCall(for: "b")

        store.resetAll()

        XCTAssertEqual(store.callsCount(for: "a"), 0)
        XCTAssertEqual(store.callsCount(for: "b"), 0)
    }
}
