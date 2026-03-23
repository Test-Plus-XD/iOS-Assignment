//
//  BookingCardView.swift
//  Pour Rice
//
//  Card component for displaying a single booking
//  Shows restaurant name, date/time, guest count, and status badge
//

import SwiftUI

/// A card displaying booking details with contextual actions
struct BookingCardView: View {

    let booking: Booking
    var onCancel: (() -> Void)?

    @State private var showCancelConfirmation = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: restaurant name + status badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.restaurantName)
                        .font(.headline)
                        .lineLimit(2)
                }

                Spacer()

                StatusBadgeView(status: booking.status)
            }

            // Date, time, and guest count
            HStack(spacing: 16) {
                Label(booking.formattedDate, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(booking.formattedTime, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label("\(booking.numberOfGuests)", systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let requests = booking.specialRequests, !requests.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("booking_special_requests")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(requests)
                                .font(.subheadline)
                        }
                    }

                    if booking.status == .declined, let reason = booking.declineMessage, !reason.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("booking_decline_reason")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                            Text(reason)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Cancel button for pending bookings
            if booking.canCancel {
                Button(role: .destructive) {
                    showCancelConfirmation = true
                } label: {
                    Label("booking_cancel", systemImage: "xmark.circle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            withAnimation(.spring(duration: 0.3)) {
                isExpanded.toggle()
            }
        }
        .confirmationDialog(
            "booking_cancel_title",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("booking_cancel_confirm", role: .destructive) {
                onCancel?()
            }
        } message: {
            Text("booking_cancel_message")
        }
    }
}
