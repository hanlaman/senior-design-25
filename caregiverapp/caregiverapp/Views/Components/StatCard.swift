//
//  StatCard.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: REUSABLE COMPONENTS AND DEFAULT PARAMETER VALUES
//  ═══════════════════════════════════════════════════════════════════════════════
//
//  Building reusable components is a key SwiftUI pattern.
//  Small, focused views that can be composed into larger ones.
//

import SwiftUI

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ REUSABLE COMPONENT                                                          │
// │                                                                             │
// │ StatCard is a small, reusable view for displaying statistics.              │
// │ It takes parameters for customization but provides good defaults.          │
// │                                                                             │
// │ DESIGN PRINCIPLES:                                                          │
// │   1. Single responsibility - just displays one stat                        │
// │   2. Configurable - accepts different icons, colors, values                │
// │   3. Self-contained - handles its own styling                              │
// │   4. No state - purely presentational (receives all data as parameters)   │
// └─────────────────────────────────────────────────────────────────────────────┘
struct StatCard: View {

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ STORED PROPERTIES (INPUT PARAMETERS)                                    │
    // │                                                                         │
    // │ These are the component's "props" or "inputs".                         │
    // │ 'let' means they can't be changed after initialization.                │
    // │                                                                         │
    // │ No @State needed because this view doesn't manage its own state.       │
    // │ It just displays what it's given.                                      │
    // └─────────────────────────────────────────────────────────────────────────┘
    let icon: String     // SF Symbol name
    let title: String    // Label text
    let value: String    // The main value to display
    let unit: String     // Optional unit suffix (e.g., "BPM", "kcal")
    let color: Color     // Accent color for the icon

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ CUSTOM INITIALIZER WITH DEFAULTS                                        │
    // │                                                                         │
    // │ Default parameter values let callers omit optional parameters:         │
    // │                                                                         │
    // │   StatCard(icon: "heart", title: "HR", value: "72")  // Uses defaults  │
    // │   StatCard(icon: "heart", title: "HR", value: "72", unit: "BPM")       │
    // │   StatCard(icon: "heart", title: "HR", value: "72", color: .red)       │
    // │                                                                         │
    // │ Parameters with defaults should come AFTER required parameters.        │
    // └─────────────────────────────────────────────────────────────────────────┘
    init(icon: String, title: String, value: String, unit: String = "", color: Color = .blue) {
        self.icon = icon; self.title = title; self.value = value; self.unit = unit; self.color = color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // ┌─────────────────────────────────────────────────────────────┐
                // │ TEXT MODIFIERS                                              │
                // │                                                             │
                // │ .font(.title2) - Predefined font size                       │
                // │ .fontWeight(.bold) - Make text bold                         │
                // │ .monospacedDigit() - Equal-width numbers (prevents jumping) │
                // │                                                             │
                // │ monospacedDigit is important for numbers that change -      │
                // │ without it, "111" and "999" would have different widths,    │
                // │ causing layout shifts during updates.                       │
                // └─────────────────────────────────────────────────────────────┘
                Text(value).font(.title2).fontWeight(.bold).monospacedDigit()

                // ┌─────────────────────────────────────────────────────────────┐
                // │ CONDITIONAL VIEW WITH isEmpty                               │
                // │                                                             │
                // │ Only show unit text if unit string is not empty.           │
                // │ !unit.isEmpty = "unit is not empty"                        │
                // └─────────────────────────────────────────────────────────────┘
                if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
        }
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ .frame(maxWidth: .infinity, alignment: .leading)                    │
        // │                                                                     │
        // │ maxWidth: .infinity - Expand to fill available horizontal space    │
        // │ alignment: .leading - Align content to the left within that space  │
        // │                                                                     │
        // │ This ensures all StatCards in a grid are the same size.           │
        // └─────────────────────────────────────────────────────────────────────┘
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ SEMANTIC COLORS                                                     │
        // │                                                                     │
        // │ Color(.systemBackground) uses SEMANTIC colors from UIKit.          │
        // │ These automatically adapt to Light/Dark mode:                      │
        // │   .systemBackground - Primary background (white/black)             │
        // │   .secondarySystemBackground - Secondary (gray tints)              │
        // │   .systemGroupedBackground - For grouped content                   │
        // │                                                                     │
        // │ SwiftUI also has .background modifier with Material:              │
        // │   .background(.regularMaterial) - Frosted glass effect            │
        // │   .background(.ultraThinMaterial) - More transparent              │
        // └─────────────────────────────────────────────────────────────────────┘
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ ANOTHER SIMPLE COMPONENT                                                    │
// │                                                                             │
// │ StatItem is even simpler - just icon, value, and label vertically stacked.│
// │ Used in the dashboard's patient status card.                               │
// └─────────────────────────────────────────────────────────────────────────────┘
struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(.blue)
            Text(value).font(.subheadline).fontWeight(.semibold).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ .frame(maxWidth: .infinity)                                         │
        // │                                                                     │
        // │ Makes this view expand horizontally. When multiple StatItems       │
        // │ are in an HStack, they'll share the space equally.                 │
        // └─────────────────────────────────────────────────────────────────────┘
        .frame(maxWidth: .infinity)
    }
}
