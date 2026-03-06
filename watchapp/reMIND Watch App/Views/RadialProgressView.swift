//
//  RadialProgressView.swift
//  reMIND Watch App
//
//  Circular progress indicator for audio playback
//

import SwiftUI

/// A circular progress ring that displays progress from top (12 o'clock position)
struct RadialProgressView: View {
    /// Progress value from 0.0 (empty) to 1.0 (full)
    let progress: Double

    /// Width of the progress stroke
    let lineWidth: CGFloat

    /// Color of the progress ring
    let color: Color

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(-90))  // Start from top (12 o'clock)
            .animation(.easeOut(duration: 0.3), value: progress)
    }
}

#Preview {
    VStack(spacing: 20) {
        RadialProgressView(progress: 1.0, lineWidth: 4, color: .green)
            .frame(width: 100, height: 100)

        RadialProgressView(progress: 0.5, lineWidth: 4, color: .green)
            .frame(width: 100, height: 100)

        RadialProgressView(progress: 0.25, lineWidth: 4, color: .green)
            .frame(width: 100, height: 100)
    }
}
