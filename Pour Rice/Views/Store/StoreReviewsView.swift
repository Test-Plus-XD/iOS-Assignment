//
//  StoreReviewsView.swift
//  Pour Rice
//
//  Review list for restaurant owners
//  Shows all customer reviews for the owner's restaurant
//

import SwiftUI

/// Restaurant owner's review list.
struct StoreReviewsView: View {

    // MARK: - Environment

    @Environment(\.services) private var services

    // MARK: - Input

    let restaurantId: String

    // MARK: - State

    @State private var reviews: [Review] = []
    @State private var isLoading = false
    @State private var error: Error?

    // MARK: - Body

    var body: some View {
        Group {
            if reviews.isEmpty && !isLoading {
                emptyState
            } else {
                reviewList
            }
        }
        .navigationTitle("store_view_reviews")
        .task(id: restaurantId) {
            await loadReviews()
        }
        .refreshable {
            await loadReviews()
        }
        .overlay {
            if isLoading && reviews.isEmpty {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
        .errorAlert(error: $error)
    }

    // MARK: - Content

    private var emptyState: some View {
        ScrollView {
            EmptyStateView.noReviews()
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                .padding()
        }
    }

    private var reviewList: some View {
        List {
            Section {
                summaryHeader
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(reviews) { review in
                    ReviewRowView(review: review)
                }
            }
        }
        .listStyle(.plain)
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(averageRatingDisplay)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("/5")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(reviews.count) \(Text("restaurant_reviews_count"))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: starSymbol(for: index))
                        .foregroundStyle(.orange)
                        .font(.headline)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Loading

    private func loadReviews() async {
        isLoading = true
        error = nil

        do {
            reviews = try await services.reviewService.fetchReviews(restaurantId: restaurantId)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Helpers

    private var averageRating: Double {
        services.reviewService.calculateAverageRating(from: reviews)
    }

    private var averageRatingDisplay: String {
        String(format: "%.1f", averageRating)
    }

    private func starSymbol(for index: Int) -> String {
        let rounded = (averageRating * 2).rounded() / 2
        let full = Int(rounded)
        let hasHalf = rounded - Double(full) > 0

        if index < full { return "star.fill" }
        if index == full && hasHalf { return "star.leadinghalf.filled" }
        return "star"
    }
}
