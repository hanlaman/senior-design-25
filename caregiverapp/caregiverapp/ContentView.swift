//
//  ContentView.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: SWIFTUI VIEWS AND NAVIGATION
//  ═══════════════════════════════════════════════════════════════════════════════

import SwiftUI

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ VIEW PROTOCOL                                                               │
// │                                                                             │
// │ Every SwiftUI view must conform to the 'View' protocol.                    │
// │ This protocol requires one thing: a 'body' computed property that          │
// │ returns 'some View'.                                                        │
// │                                                                             │
// │ PROTOCOL CONFORMANCE syntax: "struct Name: Protocol"                        │
// │ It's like saying "I promise to implement everything Protocol requires"     │
// └─────────────────────────────────────────────────────────────────────────────┘
struct ContentView: View {

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ LET vs VAR                                                              │
    // │                                                                         │
    // │ let = CONSTANT (cannot be changed after initialization)                │
    // │ var = VARIABLE (can be changed)                                        │
    // │                                                                         │
    // │ Use 'let' whenever possible - it's safer and clearer.                  │
    // │ The compiler will suggest changing 'var' to 'let' if you never modify. │
    // │                                                                         │
    // │ Here, dataProvider is 'let' because we receive it once and never       │
    // │ reassign it to a different object.                                     │
    // └─────────────────────────────────────────────────────────────────────────┘
    let dataProvider: PatientDataProvider

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ @State FOR LOCAL UI STATE                                               │
    // │                                                                         │
    // │ selectedTab tracks which tab is currently selected.                    │
    // │ When this value changes (user taps a tab), SwiftUI automatically       │
    // │ re-renders the view to show the new tab.                               │
    // │                                                                         │
    // │ Why @State and not just 'var'?                                         │
    // │ - Structs are immutable by default in Swift                            │
    // │ - @State tells SwiftUI to store this value separately                  │
    // │ - This allows the view struct to remain immutable while state changes  │
    // └─────────────────────────────────────────────────────────────────────────┘
    @State private var selectedTab = 0

    var body: some View {

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ TabView - BOTTOM TAB BAR NAVIGATION                                 │
        // │                                                                     │
        // │ TabView creates a tab bar at the bottom of the screen.             │
        // │                                                                     │
        // │ 'selection: $selectedTab' creates a TWO-WAY BINDING:               │
        // │   - $ prefix creates a Binding from @State                          │
        // │   - TabView can READ selectedTab to know which tab is active       │
        // │   - TabView can WRITE to selectedTab when user taps a tab          │
        // │                                                                     │
        // │ Without $: passing the value (read-only)                            │
        // │ With $: passing a binding (read-write)                              │
        // └─────────────────────────────────────────────────────────────────────┘
        TabView(selection: $selectedTab) {

            // ┌─────────────────────────────────────────────────────────────────┐
            // │ NavigationStack - ENABLES PUSH/POP NAVIGATION                   │
            // │                                                                 │
            // │ NavigationStack allows drilling down into detail views.         │
            // │ When you tap a NavigationLink, a new view "pushes" onto        │
            // │ the stack with a back button to return.                        │
            // │                                                                 │
            // │ Each tab needs its own NavigationStack so navigation in one    │
            // │ tab doesn't affect others.                                     │
            // └─────────────────────────────────────────────────────────────────┘
            NavigationStack {
                DashboardView(dataProvider: dataProvider)
            }
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ VIEW MODIFIERS                                                  │
            // │                                                                 │
            // │ .tabItem { } is a VIEW MODIFIER - it modifies the view it's   │
            // │ attached to. Modifiers return a NEW view with the change.      │
            // │                                                                 │
            // │ SwiftUI uses a fluent/chained syntax:                           │
            // │   view.modifier1().modifier2().modifier3()                      │
            // │                                                                 │
            // │ This is actually building a nested structure:                   │
            // │   Modifier3(Modifier2(Modifier1(view)))                         │
            // │                                                                 │
            // │ Order matters! .padding().background() is different from       │
            // │ .background().padding()                                         │
            // └─────────────────────────────────────────────────────────────────┘
            .tabItem {
                // Label combines an icon and text - perfect for tab items
                // "systemImage" uses SF Symbols - Apple's free icon library
                // Browse at: https://developer.apple.com/sf-symbols/
                Label("Dashboard", systemImage: "house.fill")
            }
            // .tag() identifies this tab for the 'selection' binding
            .tag(0)

            NavigationStack {
                LocationView(dataProvider: dataProvider)
            }
            .tabItem {
                Label("Location", systemImage: "location.fill")
            }
            .tag(1)

            NavigationStack {
                HealthTabView(dataProvider: dataProvider)
            }
            .tabItem {
                Label("Health", systemImage: "heart.fill")
            }
            .tag(2)

            NavigationStack {
                RemindersListView(dataProvider: dataProvider)
            }
            .tabItem {
                Label("Reminders", systemImage: "bell.fill")
            }
            .tag(3)

            NavigationStack {
                AlertsListView(dataProvider: dataProvider)
            }
            .tabItem {
                Label("Alerts", systemImage: "exclamationmark.triangle.fill")
            }
            .tag(4)
        }
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ MULTIPLE STRUCTS IN ONE FILE                                               │
// │                                                                             │
// │ Swift allows multiple types in one file. This is useful for small,         │
// │ related views. Larger views should go in their own files.                  │
// │                                                                             │
// │ HealthTabView is a simple intermediate view that shows options to          │
// │ navigate to HeartRateView or ActivityView.                                 │
// └─────────────────────────────────────────────────────────────────────────────┘
struct HealthTabView: View {
    let dataProvider: PatientDataProvider

    var body: some View {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ List - SCROLLABLE LIST OF ITEMS                                     │
        // │                                                                     │
        // │ List is like UITableView but declarative. It automatically         │
        // │ handles scrolling, cell reuse, and styling.                        │
        // └─────────────────────────────────────────────────────────────────────┘
        List {
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ NavigationLink - TAP TO NAVIGATE                                │
            // │                                                                 │
            // │ NavigationLink has two parts:                                   │
            // │   - destination: The view to show when tapped                   │
            // │   - label: What the user sees and taps                          │
            // │                                                                 │
            // │ TRAILING CLOSURE SYNTAX:                                        │
            // │ When the last parameter is a closure, you can write it         │
            // │ outside the parentheses:                                        │
            // │                                                                 │
            // │   NavigationLink(destination: HeartRateView(...)) {            │
            // │       Label(...)  // This is the 'label' parameter              │
            // │   }                                                              │
            // │                                                                 │
            // │ With labeled closure syntax (used here):                        │
            // │   NavigationLink { destination } label: { label }              │
            // └─────────────────────────────────────────────────────────────────┘
            NavigationLink {
                HeartRateView(dataProvider: dataProvider)
            } label: {
                Label("Heart Rate", systemImage: "heart.fill")
                    // .foregroundStyle() sets the color
                    // In older SwiftUI it was .foregroundColor()
                    .foregroundStyle(.red)
            }

            NavigationLink {
                ActivityView(dataProvider: dataProvider)
            } label: {
                Label("Activity", systemImage: "figure.walk")
                    .foregroundStyle(.green)
            }
        }
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ .navigationTitle() - SETS THE HEADER TEXT                           │
        // │                                                                     │
        // │ This modifier is applied to the content INSIDE NavigationStack,    │
        // │ but the NavigationStack displays it in the navigation bar.         │
        // │ This is a common SwiftUI pattern - child views declare their       │
        // │ preferences, parent containers read and display them.              │
        // └─────────────────────────────────────────────────────────────────────┘
        .navigationTitle("Health")
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ #Preview - XCODE PREVIEW MACRO                                              │
// │                                                                             │
// │ #Preview creates a live preview in Xcode's canvas (right side panel).      │
// │ This lets you see your UI without running the full app.                    │
// │                                                                             │
// │ The preview code runs in Xcode's simulator, so you can:                    │
// │   - See UI changes instantly as you code                                   │
// │   - Test different data/states                                             │
// │   - Create multiple previews for different scenarios                       │
// │                                                                             │
// │ Previews are stripped from production builds - they're development only.   │
// └─────────────────────────────────────────────────────────────────────────────┘
#Preview {
    ContentView(dataProvider: MockDataService())
}
