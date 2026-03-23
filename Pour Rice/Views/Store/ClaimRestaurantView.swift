//
//  ClaimRestaurantView.swift
//  Pour Rice
//
//  Flow for restaurant owners to claim ownership of a restaurant
//  Searches for restaurants and submits a claim request
//

import SwiftUI

/// View for claiming restaurant ownership
struct ClaimRestaurantView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    // MARK: - State

    @State private var searchQuery = ""
    @State private var searchResults: [Restaurant] = []
    @State private var isSearching = false
    @State private var isClaiming = false
    @State private var claimError: Error?
    @State private var claimSuccess = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "storefront")
                    .font(.system(size: 48))
                    .foregroundStyle(.accent)

                Text("store_claim_title")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("store_claim_description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("store_claim_search", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await search() } }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            // Results
            if searchResults.isEmpty && !searchQuery.isEmpty && !isSearching {
                ContentUnavailableView.search(text: searchQuery)
            } else {
                List(searchResults) { restaurant in
                    Button {
                        Task { await claimRestaurant(restaurant) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(restaurant.name.localised)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(restaurant.description.localised)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if isClaiming {
                                ProgressView()
                            } else {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                    .disabled(isClaiming)
                }
                .listStyle(.plain)
            }

            Spacer()
        }
        .overlay {
            if claimSuccess {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("store_claim_success")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("store_claim_success_description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .errorAlert(error: $claimError)
    }

    // MARK: - Search

    private func search() async {
        guard searchQuery.count >= 2 else { return }
        isSearching = true

        do {
            let page = try await services.restaurantService.search(
                query: searchQuery,
                filters: SearchFilters(districts: [], keywords: [])
            )
            searchResults = page.restaurants
        } catch {
            claimError = error
        }

        isSearching = false
    }

    // MARK: - Claim

    private func claimRestaurant(_ restaurant: Restaurant) async {
        isClaiming = true

        do {
            _ = try await services.storeService.claimRestaurant(id: restaurant.id)

            withAnimation(.spring) {
                claimSuccess = true
            }
        } catch {
            claimError = error
        }

        isClaiming = false
    }
}
