//
//  StatusBadgeView.swift
//  Pour Rice
//
//  Reusable colour-coded status badge capsule
//  Used in booking cards and store booking management
//

import SwiftUI

/// A small capsule badge displaying a status label with a matching colour
struct StatusBadgeView: View {

    let text: String
    let colour: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(colour, in: Capsule())
    }
}

// MARK: - Convenience Init

extension StatusBadgeView {
    /// Creates a badge from a BookingStatus enum value.
    init(status: Booking.BookingStatus) {
        self.text = status.label
        self.colour = status.colour
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusBadgeView(status: .pending)
        StatusBadgeView(status: .accepted)
        StatusBadgeView(status: .declined)
        StatusBadgeView(status: .completed)
        StatusBadgeView(status: .cancelled)
    }
    .padding()
}
