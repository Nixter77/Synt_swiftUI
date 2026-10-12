//
//  FontNameCacheTests.swift
//  Studio/Retro fonts are resolved once, not on every body pass.
//

import SwiftUI
import Testing
@testable import Synt_swiftUI

struct FontNameCacheTests {
    @Test func repeatedFontRequestsDoNotLookUpAgain() {
        let cache = FontNameCache.shared
        func pass() {
            _ = Theme.all[.studio].captionFont(size: 10)
            _ = Theme.all[.studio].monoFont(size: 11, weight: .bold)
            _ = Theme.all[.retro].captionFont(size: 12)
            _ = Theme.all[.retro].monoFont(size: 9)
            _ = Theme.all[.studio].labelFont
            _ = Theme.all[.retro].titleFont
        }
        pass()
        let before = cache.lookups
        for _ in 0..<200 {
            _ = Theme.all[.studio].captionFont(size: 10)
            _ = Theme.all[.studio].monoFont(size: 11, weight: .bold)
            _ = Theme.all[.retro].captionFont(size: 12)
            _ = Theme.all[.retro].monoFont(size: 9)
            _ = Theme.all[.studio].labelFont
            _ = Theme.all[.retro].titleFont
        }
        #expect(cache.lookups == before, "lookups grew by \(cache.lookups - before)")
    }

    @Test func missingFamiliesResolveToNil() {
        #expect(FontNameCache.shared.firstInstalled(["No Such Font XYZ"]) == nil)
        #expect(FontNameCache.shared.firstInstalled(["No Such Font XYZ"]) == nil)
    }
}
