import Foundation
import Testing

@testable import CacheKit

@Suite
struct CachePolicyTests {
    private let policy = CachePolicy.standard
    private let base = Date(timeIntervalSince1970: 1_000_000)

    @Test func freshHit() {
        #expect(policy.isFresh(mtime: base.addingTimeInterval(-3600), now: base))
    }

    @Test func staleMiss() {
        #expect(!policy.isFresh(mtime: base.addingTimeInterval(-90_000), now: base))
    }

    @Test func ttlZeroNeverReuses() {
        let p = CachePolicy(ttl: 0)
        #expect(!p.isFresh(mtime: base, now: base))
    }

    @Test func refreshBypasses() {
        #expect(!policy.isFresh(mtime: base, now: base, refresh: true))
    }

    @Test func futureSkewTolerated() {
        #expect(policy.isFresh(mtime: base.addingTimeInterval(100), now: base))
    }

    @Test func futureBeyondSkewIsStale() {
        #expect(!policy.isFresh(mtime: base.addingTimeInterval(400), now: base))
    }

    @Test func decideActions() {
        let fresh = base.addingTimeInterval(-3600)
        let stale = base.addingTimeInterval(-90_000)
        #expect(policy.decide(mtime: fresh, now: base, refresh: false, offline: false, hasStale: true) == .hit)
        #expect(policy.decide(mtime: fresh, now: base, refresh: true, offline: false, hasStale: true) == .refresh)
        #expect(policy.decide(mtime: stale, now: base, refresh: false, offline: false, hasStale: true) == .miss)
        #expect(policy.decide(mtime: stale, now: base, refresh: false, offline: true, hasStale: true) == .fallback)
        #expect(policy.decide(mtime: stale, now: base, refresh: false, offline: true, hasStale: false) == .error)
        #expect(policy.decide(mtime: nil, now: base, refresh: false, offline: true, hasStale: false) == .error)
    }
}
