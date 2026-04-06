//
//  StoreAdsView.swift
//  Pour Rice
//
//  Advertisement management view for restaurant owners.
//  Lists active/inactive ads, supports toggle and swipe-to-delete.
//  "+" toolbar button opens a two-step creation flow:
//    Step 1 — Stripe payment (HK$10) via SFSafariViewController
//    Step 2 — Ad content form with optional Gemini AI generation
//

import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class StoreAdsViewModel {

    // MARK: - State

    var ads: [Advertisement] = []
    var isLoading = false
    var error: Error?

    var toastMessage = ""
    var toastStyle: ToastStyle = .success
    var showToast = false

    // MARK: - Private

    private var advertisementService: AdvertisementService?
    private(set) var restaurantId: String = ""

    // MARK: - Load

    func load(restaurantId: String, advertisementService: AdvertisementService) async {
        guard !isLoading else { return }
        self.advertisementService = advertisementService
        self.restaurantId = restaurantId
        isLoading = true
        error = nil
        do {
            ads = try await advertisementService.fetchAdvertisements(restaurantId: restaurantId)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func refresh() async {
        guard let service = advertisementService, !restaurantId.isEmpty else { return }
        await load(restaurantId: restaurantId, advertisementService: service)
    }

    // MARK: - Toggle Active/Inactive

    func toggleStatus(ad: Advertisement) async {
        guard let service = advertisementService else { return }
        let newStatus = ad.isActive ? "inactive" : "active"
        do {
            try await service.updateAdvertisement(
                id: ad.id,
                request: UpdateAdvertisementRequest(status: newStatus)
            )
            await refresh()
            showToastMsg("ad_toggled", .success)
        } catch {
            showToastMsg("ad_update_failed", .error)
        }
    }

    // MARK: - Delete

    func delete(id: String) async {
        guard let service = advertisementService else { return }
        do {
            try await service.deleteAdvertisement(id: id)
            ads.removeAll { $0.id == id }
            showToastMsg("ad_deleted", .success)
        } catch {
            showToastMsg("ad_delete_failed", .error)
        }
    }

    // MARK: - Helpers

    private func showToastMsg(_ key: String, _ style: ToastStyle) {
        toastMessage = String(localized: LocalizedStringResource(stringLiteral: key))
        toastStyle = style
        showToast = true
    }
}

// MARK: - StoreAdsView

/// Restaurant owner's advertisement management interface.
struct StoreAdsView: View {

    let restaurantId: String

    // MARK: - Environment & State

    @Environment(\.services) private var services
    @State private var viewModel = StoreAdsViewModel()
    @State private var showCreateSheet = false

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.ads.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.ads.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                adList
            }
        }
        .navigationTitle("store_ads")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await viewModel.load(
                restaurantId: restaurantId,
                advertisementService: services.advertisementService
            )
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: {
            Task { await viewModel.refresh() }
        }) {
            StoreAdCreationSheet(restaurantId: restaurantId)
        }
        .errorAlert(error: $viewModel.error)
        .toast(
            message: viewModel.toastMessage,
            style: viewModel.toastStyle,
            isPresented: Binding(
                get: { viewModel.showToast },
                set: { viewModel.showToast = $0 }
            )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "megaphone")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("store_ads_empty")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("store_ads_empty_subtitle")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                showCreateSheet = true
            } label: {
                Label("store_ads_create", systemImage: "plus")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
        }
        .padding()
    }

    // MARK: - Ad List

    private var adList: some View {
        List {
            ForEach(viewModel.ads) { ad in
                AdRowView(ad: ad) {
                    Task { await viewModel.toggleStatus(ad: ad) }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(id: ad.id) }
                    } label: {
                        Label("delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Ad Row View

private struct AdRowView: View {

    let ad: Advertisement
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let url = ad.localizedImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        placeholderThumb
                    }
                }
            } else {
                placeholderThumb
            }

            // Title + status
            VStack(alignment: .leading, spacing: 6) {
                let title = ad.localizedTitle
                Text(title.isEmpty ? String(localized: "store_ad_untitled") : title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(ad.isActive ? "ad_status_active" : "ad_status_inactive")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        (ad.isActive ? Color.green : Color.gray).opacity(0.15),
                        in: Capsule()
                    )
                    .foregroundStyle(ad.isActive ? .green : .secondary)
            }

            Spacer()

            // Pause / play toggle
            Button {
                onToggle()
            } label: {
                Image(systemName: ad.isActive ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(ad.isActive ? .orange : .green)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var placeholderThumb: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(width: 60, height: 60)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Ad Creation Sheet (Step 1: Payment → Step 2: Form)

private struct StoreAdCreationSheet: View {

    let restaurantId: String

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    private enum Step { case payment, form }

    @State private var step: Step = .payment
    @State private var stripeURL: URL?
    @State private var showSafari = false
    @State private var isCreatingSession = false
    @State private var sessionErrorMessage: String?

    var body: some View {
        NavigationStack {
            switch step {
            case .payment:
                paymentStep
            case .form:
                StoreAdFormView(restaurantId: restaurantId) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Payment Step

    private var paymentStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.pink)
                }

                // Copy
                VStack(spacing: 10) {
                    Text("store_ad_payment_title")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("store_ad_payment_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Price tag
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("HK$")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text("10")
                            .font(.system(size: 64, weight: .bold))
                    }
                    Text("store_ad_per_listing")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                // Feature bullets
                VStack(alignment: .leading, spacing: 10) {
                    FeatureBullet(icon: "globe", text: "store_ad_feature_bilingual")
                    FeatureBullet(icon: "brain", text: "store_ad_feature_ai")
                    FeatureBullet(icon: "photo.on.rectangle", text: "store_ad_feature_image")
                    FeatureBullet(icon: "arrow.triangle.2.circlepath", text: "store_ad_feature_toggle")
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                // Error
                if let msg = sessionErrorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer(minLength: 16)
            }
            .padding(.bottom)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                // Pay with Stripe
                Button {
                    Task { await startPayment() }
                } label: {
                    HStack(spacing: 8) {
                        if isCreatingSession {
                            ProgressView().tint(.white)
                        }
                        Text("store_ad_pay_stripe")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isCreatingSession)

                // Shortcut for users who already paid
                Button {
                    step = .form
                } label: {
                    Text("store_ad_already_paid")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .padding(.top, 8)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("store_ad_new")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showSafari, onDismiss: {
            // Advance to form once Safari is dismissed — covers both
            // success redirect and manual dismissal (belt-and-suspenders).
            step = .form
        }) {
            if let url = stripeURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Stripe Session

    private func startPayment() async {
        isCreatingSession = true
        sessionErrorMessage = nil

        do {
            // Use Vercel-hosted URLs as Stripe redirect targets.
            // The iOS app advances to the form regardless of which URL Stripe lands on;
            // the session_id is embedded for potential server-side verification.
            let successURL = "https://vercel-express-api-alpha.vercel.app/stripe-success?session_id={CHECKOUT_SESSION_ID}"
            let cancelURL  = "https://vercel-express-api-alpha.vercel.app/stripe-cancel"

            let session = try await services.advertisementService.createStripeCheckoutSession(
                restaurantId: restaurantId,
                successURL: successURL,
                cancelURL: cancelURL
            )

            stripeURL = session.url
            showSafari = true
        } catch {
            sessionErrorMessage = error.localizedDescription
        }

        isCreatingSession = false
    }
}

// MARK: - Feature Bullet (reusable inside payment step)

private struct FeatureBullet: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.pink)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Ad Form View

/// Bilingual ad content form with optional Gemini AI generation.
/// Called from `StoreAdCreationSheet` after payment, and could be reused for editing.
struct StoreAdFormView: View {

    let restaurantId: String
    /// Called after a successful save so the parent can dismiss.
    let onSave: () -> Void

    // MARK: - Environment & State

    @Environment(\.services) private var services
    @Environment(\.authService) private var authService

    @State private var titleEN = ""
    @State private var titleTC = ""
    @State private var contentEN = ""
    @State private var contentTC = ""

    @State private var isSaving = false
    @State private var isGenerating = false
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                TextField("store_ad_title_en", text: $titleEN)
                TextField("store_ad_title_tc", text: $titleTC)
            } header: {
                Text("store_ad_section_title")
            }

            Section {
                TextField("store_ad_content_en", text: $contentEN, axis: .vertical)
                    .lineLimit(4...8)
                TextField("store_ad_content_tc", text: $contentTC, axis: .vertical)
                    .lineLimit(4...8)
            } header: {
                Text("store_ad_section_content")
            }

            Section {
                Button {
                    Task { await generateWithAI() }
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Image(systemName: "brain")
                        }
                        Text("store_ad_generate_ai")
                    }
                }
                .disabled(isGenerating)
            } footer: {
                Text("store_ad_generate_ai_hint")
            }

            if let errMsg = errorMessage {
                Section {
                    Text(errMsg)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("store_ad_form_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await saveAd() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSaving || (titleEN.isEmpty && titleTC.isEmpty))
            }
        }
    }

    // MARK: - Actions

    private func generateWithAI() async {
        isGenerating = true
        errorMessage = nil

        // Use the restaurant name from the auth service if available,
        // otherwise fall back to restaurantId as the name hint.
        let restaurantName = authService.currentUser?.displayName ?? restaurantId

        do {
            let result = try await services.geminiService.generateAdvertisement(
                restaurantId: restaurantId,
                name: restaurantName
            )
            titleEN   = result.titleEN
            titleTC   = result.titleTC
            contentEN = result.contentEN
            contentTC = result.contentTC
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    private func saveAd() async {
        isSaving = true
        errorMessage = nil

        let request = CreateAdvertisementRequest(
            titleEN:      titleEN.isEmpty   ? nil : titleEN,
            titleTC:      titleTC.isEmpty   ? nil : titleTC,
            contentEN:    contentEN.isEmpty  ? nil : contentEN,
            contentTC:    contentTC.isEmpty  ? nil : contentTC,
            imageEN:      nil,
            imageTC:      nil,
            restaurantId: restaurantId
        )

        do {
            _ = try await services.advertisementService.createAdvertisement(request)
            onSave()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
