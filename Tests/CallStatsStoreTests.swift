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
}
