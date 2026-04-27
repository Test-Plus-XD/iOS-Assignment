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

import Combine
import PhotosUI
import SwiftUI

private enum StoreAdCreationStartMode: Equatable {
    case payment
    case resume(sessionId: String)
}

private enum StoreAdPaymentConstants {
    static let pendingSessionKey = "pendingAdSession"
    static let graceInterval: TimeInterval = 2 * 60 * 60
}

private struct PendingAdPaymentSession: Codable, Equatable {
    let sessionId: String
    let timestamp: Date
}

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
    @State private var creationStartMode: StoreAdCreationStartMode = .payment
    @State private var pendingAdPaymentSession: PendingAdPaymentSession?
    private let pendingSessionTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if let pendingAdPaymentSession {
                pendingAdSessionBanner(pendingAdPaymentSession)
            }

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
        }
        .navigationTitle("store_ads")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openPaymentSheet()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            refreshPendingAdPaymentSession()
            await viewModel.load(
                restaurantId: restaurantId,
                advertisementService: services.advertisementService
            )
        }
        .onReceive(pendingSessionTimer) { _ in
            refreshPendingAdPaymentSession()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showCreateSheet, onDismiss: {
            refreshPendingAdPaymentSession()
            Task { await viewModel.refresh() }
        }) {
            StoreAdCreationSheet(
                restaurantId: restaurantId,
                startMode: creationStartMode,
                onVerifiedPayment: { sessionId in
                    savePendingAdPaymentSession(sessionId: sessionId)
                },
                onAdCreated: {
                    clearPendingAdPaymentSession()
                }
            )
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
                openPaymentSheet()
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

    // MARK: - Pending Payment Banner

    private func pendingAdSessionBanner(_ session: PendingAdPaymentSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hourglass.circle.fill")
                    .foregroundStyle(.orange)
                Text("ad_pending_title")
                    .font(.headline)
            }

            Text("ad_pending_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label(
                    "ad_pending_time_remaining \(pendingAdSessionRemainingText(for: session))",
                    systemImage: "clock"
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    openResumeSheet(sessionId: session.sessionId)
                } label: {
                    Label("ad_pending_complete", systemImage: "arrow.forward.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.12))
    }

    // MARK: - Pending Payment Helpers

    private func openPaymentSheet() {
        creationStartMode = .payment
        showCreateSheet = true
    }

    private func openResumeSheet(sessionId: String) {
        creationStartMode = .resume(sessionId: sessionId)
        showCreateSheet = true
    }

    @discardableResult
    private func refreshPendingAdPaymentSession() -> PendingAdPaymentSession? {
        guard let data = UserDefaults.standard.data(forKey: StoreAdPaymentConstants.pendingSessionKey),
              let session = try? JSONDecoder().decode(PendingAdPaymentSession.self, from: data),
              isValidStripeCheckoutSessionId(session.sessionId),
              Date().timeIntervalSince(session.timestamp) <= StoreAdPaymentConstants.graceInterval else {
            clearPendingAdPaymentSession()
            return nil
        }

        pendingAdPaymentSession = session
        return session
    }

    private func savePendingAdPaymentSession(sessionId: String) {
        let session = PendingAdPaymentSession(sessionId: sessionId, timestamp: Date())
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: StoreAdPaymentConstants.pendingSessionKey)
        }
        pendingAdPaymentSession = session
    }

    private func clearPendingAdPaymentSession() {
        UserDefaults.standard.removeObject(forKey: StoreAdPaymentConstants.pendingSessionKey)
        pendingAdPaymentSession = nil
    }

    private func isValidStripeCheckoutSessionId(_ sessionId: String) -> Bool {
        sessionId.range(of: #"^cs_[A-Za-z0-9_]+$"#, options: .regularExpression) != nil
    }

    private func pendingAdSessionRemainingText(for session: PendingAdPaymentSession) -> String {
        let elapsed = Date().timeIntervalSince(session.timestamp)
        let remaining = max(0, StoreAdPaymentConstants.graceInterval - elapsed)
        let totalMinutes = max(1, Int((remaining / 60).rounded(.up)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours <= 0 { return "\(minutes)m" }
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
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
    let startMode: StoreAdCreationStartMode
    let onVerifiedPayment: (String) -> Void
    let onAdCreated: () -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    private enum Step { case payment, verifying, form }

    @State private var step: Step
    @State private var stripeURL: URL?
    @State private var showSafari = false
    @State private var isCreatingSession = false
    @State private var isVerifyingPayment = false
    @State private var isHandlingCheckoutReturn = false
    @State private var didVerifyInitialSession = false
    @State private var verifiedSessionId: String?
    @State private var sessionErrorMessage: String?
    @State private var toastMessage = ""
    @State private var toastStyle: ToastStyle = .info
    @State private var showToast = false

    init(
        restaurantId: String,
        startMode: StoreAdCreationStartMode,
        onVerifiedPayment: @escaping (String) -> Void,
        onAdCreated: @escaping () -> Void
    ) {
        self.restaurantId = restaurantId
        self.startMode = startMode
        self.onVerifiedPayment = onVerifiedPayment
        self.onAdCreated = onAdCreated

        switch startMode {
        case .payment:
            _step = State(initialValue: .payment)
        case .resume:
            _step = State(initialValue: .verifying)
        }
    }

    var body: some View {
        NavigationStack {
            switch step {
            case .payment:
                paymentStep
            case .verifying:
                verifyingStep
            case .form:
                StoreAdFormView(restaurantId: restaurantId) {
                    onAdCreated()
                    dismiss()
                }
            }
        }
        .task {
            await verifyInitialResumeSessionIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .storeStripeReturnURL)) { notification in
            guard let url = notification.object as? URL else { return }
            Task { await handleStripeReturnURL(url) }
        }
        .sheet(isPresented: $showSafari, onDismiss: handleSafariDismissed) {
            if let url = stripeURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .toast(
            message: toastMessage,
            style: toastStyle,
            isPresented: Binding(
                get: { showToast },
                set: { showToast = $0 }
            )
        )
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
                        if isCreatingSession || isVerifyingPayment {
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
                .disabled(isCreatingSession || isVerifyingPayment)
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
    }

    // MARK: - Verifying Step

    private var verifyingStep: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.25)
            Text("ad_payment_verifying_title")
                .font(.headline)
            Text("ad_payment_verifying_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("store_ad_new")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Stripe Session

    private func startPayment() async {
        isCreatingSession = true
        sessionErrorMessage = nil

        do {
            // Stripe redirects back through the app's registered URL scheme.
            let successURL = "pourrice://store?payment_success=true&session_id={CHECKOUT_SESSION_ID}"
            let cancelURL  = "pourrice://store?payment_cancelled=true"

            let session = try await services.advertisementService.createStripeCheckoutSession(
                restaurantId: restaurantId,
                successURL: successURL,
                cancelURL: cancelURL
            )

            stripeURL = session.url
            showSafari = true
        } catch {
            sessionErrorMessage = error.localizedDescription
            showPaymentToast(error.localizedDescription, .error)
        }

        isCreatingSession = false
    }

    private func verifyInitialResumeSessionIfNeeded() async {
        guard !didVerifyInitialSession else { return }
        guard case .resume(let sessionId) = startMode else { return }
        didVerifyInitialSession = true
        await verifyPayment(sessionId: sessionId, persistSession: false)
    }

    private func handleStripeReturnURL(_ url: URL) async {
        guard url.scheme == Constants.DeepLink.scheme,
              url.host == Constants.DeepLink.storeHost else {
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let paymentSuccess = queryItems.first(where: { $0.name == "payment_success" })?.value == "true"
        let paymentCancelled = queryItems.first(where: { $0.name == "payment_cancelled" })?.value == "true"
        let sessionId = queryItems.first(where: { $0.name == "session_id" })?.value

        let wasShowingSafari = showSafari
        isHandlingCheckoutReturn = wasShowingSafari
        showSafari = false

        if paymentCancelled {
            step = .payment
            showPaymentToast(localised("ad_payment_cancelled"), .error)
            if !wasShowingSafari { isHandlingCheckoutReturn = false }
            return
        }

        guard paymentSuccess,
              let sessionId,
              isValidStripeCheckoutSessionId(sessionId) else {
            step = .payment
            showPaymentToast(localised("ad_payment_incomplete"), .error)
            if !wasShowingSafari { isHandlingCheckoutReturn = false }
            return
        }

        await verifyPayment(sessionId: sessionId, persistSession: true)
        if !wasShowingSafari { isHandlingCheckoutReturn = false }
    }

    private func verifyPayment(sessionId: String, persistSession: Bool) async {
        isVerifyingPayment = true
        sessionErrorMessage = nil
        step = .verifying

        do {
            _ = try await services.advertisementService.verifyPaidAdvertisementSession(
                sessionId: sessionId,
                restaurantId: restaurantId
            )
            verifiedSessionId = sessionId
            if persistSession {
                onVerifiedPayment(sessionId)
            }
            step = .form
            showPaymentToast(localised("ad_payment_confirmed"), .success)
        } catch {
            verifiedSessionId = nil
            step = .payment
            showPaymentToast(error.localizedDescription, .error)
        }

        isVerifyingPayment = false
    }

    private func handleSafariDismissed() {
        if isHandlingCheckoutReturn {
            isHandlingCheckoutReturn = false
            return
        }

        guard verifiedSessionId == nil, step != .form else { return }
        showPaymentToast(localised("ad_payment_incomplete"), .error)
    }

    private func localised(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: L10n.bundle)
    }

    private func isValidStripeCheckoutSessionId(_ sessionId: String) -> Bool {
        sessionId.range(of: #"^cs_[A-Za-z0-9_]+$"#, options: .regularExpression) != nil
    }

    private func showPaymentToast(_ message: String, _ style: ToastStyle) {
        sessionErrorMessage = message
        toastMessage = message
        toastStyle = style
        showToast = true
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

    @State private var titleEN = ""
    @State private var titleTC = ""
    @State private var contentEN = ""
    @State private var contentTC = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoImage: Image?
    @State private var selectedPhotoData: Data?

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
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    if let image = selectedPhotoImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Label("store_ad_image_add", systemImage: "photo.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .disabled(isSaving)
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task { await loadSelectedPhoto(newItem) }
                }

                if selectedPhotoImage != nil {
                    Button(role: .destructive) {
                        selectedPhotoItem = nil
                        selectedPhotoImage = nil
                        selectedPhotoData = nil
                    } label: {
                        Label("store_ad_image_remove", systemImage: "trash")
                    }
                    .disabled(isSaving)
                }
            } header: {
                Text("store_ad_section_image")
            } footer: {
                Text("store_ad_image_optional_hint")
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

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
                errorMessage = String(localized: "store_ad_image_load_failed", bundle: L10n.bundle)
                return
            }

            selectedPhotoData = jpegData
            selectedPhotoImage = Image(uiImage: uiImage)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateWithAI() async {
        isGenerating = true
        errorMessage = nil

        do {
            let result = try await services.geminiService.generateAdvertisement(
                restaurantId: restaurantId
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

        var uploadedImageURL: String?

        do {
            if let photoData = selectedPhotoData {
                let token = try await services.authService.getIDToken()
                uploadedImageURL = try await services.imageUploadService.uploadImage(
                    photoData,
                    mimeType: "image/jpeg",
                    filename: "advertisement_\(UUID().uuidString).jpg",
                    folder: "Advertisements/\(restaurantId)",
                    authToken: token
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return
        }

        let request = CreateAdvertisementRequest(
            titleEN:      titleEN.isEmpty   ? nil : titleEN,
            titleTC:      titleTC.isEmpty   ? nil : titleTC,
            contentEN:    contentEN.isEmpty  ? nil : contentEN,
            contentTC:    contentTC.isEmpty  ? nil : contentTC,
            imageEN:      uploadedImageURL,
            imageTC:      uploadedImageURL,
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
