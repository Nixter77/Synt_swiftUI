//
//  FXSlotCard.swift
//  Synt_swiftUI
//
//  One effect: a header (title, optional preset menu, optional enable toggle)
//  and a body that collapses to the header row.
//

import SwiftUI

/// Collapse memory: -1 follows the preset (expanded only while the effect is on),
/// 0 is forced open, 1 is forced shut.
struct FXSlotCard<Menu: View, Content: View>: View {
    @Environment(\.theme) private var theme

    let title: String
    var enabled: Binding<Bool>?
    let accent: Color
    let storageName: String
    /// Used only while the user has never clicked this header (`collapseMode == -1`).
    let startsExpanded: Bool
    @ViewBuilder var menu: () -> Menu
    @ViewBuilder var content: () -> Content

    @AppStorage private var collapseMode: Int

    init(
        title: String,
        enabled: Binding<Bool>? = nil,
        accent: Color,
        storageName: String,
        startsExpanded: Bool,
        @ViewBuilder menu: @escaping () -> Menu,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.enabled = enabled
        self.accent = accent
        self.storageName = storageName
        self.startsExpanded = startsExpanded
        self.menu = menu
        self.content = content
        self._collapseMode = AppStorage(wrappedValue: -1, "fx.collapsed.\(storageName)")
    }

    private var showsBody: Bool {
        switch collapseMode {
        case 1: return false
        case 0: return true
        default: return startsExpanded
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if showsBody {
                content()
            }
        }
        .padding(8)
        .appleCard(cornerRadius: theme.rCard, accent: accent)
        .accessibilityIdentifier("fx.slot.\(storageName)")
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button {
                collapseMode = showsBody ? 1 : 0
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showsBody ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.textDim)
                        .frame(width: 10)
                    AppleSectionHeader(title: title, accent: accent)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(showsBody ? "expanded" : "collapsed")

            menu()

            if let enabled {
                ThemeToggle(isOn: Binding(
                    get: { enabled.wrappedValue },
                    set: { newValue in
                        enabled.wrappedValue = newValue
                        if newValue { collapseMode = 0 }
                    }
                ))
            }
        }
    }
}
