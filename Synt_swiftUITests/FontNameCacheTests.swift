//
//  FontNameCacheTests.swift
//  Studio/Retro fonts are resolved once, not on every body pass.
//

import SwiftUI
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

struct FontNameCacheTests {
    @Test func repeatedFontRequestsDoNotLookUpAgain() {
        let cache = FontNameCache()
        let familyA = ["Menlo", "Courier"]
        let familyB = ["Helvetica Neue", "Arial"]
        _ = cache.firstInstalled(familyA)
        _ = cache.firstInstalled(familyB)
        let before = cache.lookups
        #expect(before == 2)
        for _ in 0..<200 {
            _ = cache.firstInstalled(familyA)
            _ = cache.firstInstalled(familyB)
        }
        #expect(cache.lookups == before, "lookups grew by \(cache.lookups - before)")
    }

    @Test func missingFamiliesResolveToNil() {
        #expect(FontNameCache.shared.firstInstalled(["No Such Font XYZ"]) == nil)
        #expect(FontNameCache.shared.firstInstalled(["No Such Font XYZ"]) == nil)
    }
}
