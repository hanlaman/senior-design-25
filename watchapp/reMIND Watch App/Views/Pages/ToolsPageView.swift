//
//  ToolsPageView.swift
//  reMIND Watch App
//
//  Dedicated page for managing function tools
//

import SwiftUI

struct ToolsPageView: View {
    @ObservedObject private var toolRegistry = ToolRegistry.shared

    /// Toolsets sorted alphabetically by id
    private var sortedToolsets: [Toolset] {
        toolRegistry.toolsets.sorted { $0.id < $1.id }
    }

    /// Tools for a toolset, sorted alphabetically by displayName
    private func sortedTools(for toolsetId: String) -> [LocalFunctionTool] {
        toolRegistry.tools(inToolset: toolsetId)
            .sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        List {
            ForEach(sortedToolsets) { toolset in
                Section {
                    ForEach(sortedTools(for: toolset.id)) { tool in
                        Toggle(isOn: Binding(
                            get: { tool.isEnabled },
                            set: { _ in toolRegistry.toggleTool(id: tool.id) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tool.displayName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(tool.shortDescription)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(toolset.id)
                }
            }
        }
        .navigationTitle("Tools")
        .listStyle(.carousel)
    }
}

#Preview {
    NavigationStack {
        ToolsPageView()
    }
}
