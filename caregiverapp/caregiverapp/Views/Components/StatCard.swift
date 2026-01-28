//
//  StatCard.swift
//  caregiverapp
//

import SwiftUI

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color

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
                Text(value).font(.title2).fontWeight(.bold).monospacedDigit()
                if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

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
        .frame(maxWidth: .infinity)
    }
}
