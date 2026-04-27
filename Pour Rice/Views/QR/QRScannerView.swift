//
//  QRScannerView.swift
//  Pour Rice
//
//  Cross-platform QR scanner entry view.
//  - iOS: live camera scanning via VisionKit DataScannerViewController
//  - macOS/simulator fallback: image import + manual payload testing
//
//  ============= FOR FLUTTER/ANDROID DEVELOPERS: =============
//  Think of this as one screen with two scanner providers:
//    1) camera provider (mobile native API)
//    2) file/manual provider (desktop + simulator fallback)
//  Both providers call the same ViewModel methods, so business logic stays shared.
//  =============================================================
//

import SwiftUI
import PhotosUI

#if canImport(VisionKit) && canImport(UIKit) && !os(macOS)
import VisionKit
import AVFoundation
internal import Vision
#endif

// MARK: - QR Scanner View

struct QRScannerView: View {
    // MARK: - Routing

    /// Optional parent-owned route handler.
    ///
    /// When provided, the scanner reports a fetched restaurant to its parent
    /// instead of pushing locally. SearchView uses this to dismiss the
    /// full-screen scanner first, then push MenuView on the Search tab's
    /// NavigationStack.
    private let onRestaurantScanned: ((Restaurant) -> Void)?

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel: QRScannerViewModel?
    @State private var selectedQRImageItem: PhotosPickerItem?
    @State private var manualPayload = ""
    /// Tracks asynchronous image decoding/extraction only.
    @State private var isProcessingImage = false
    /// Tracks restaurant lookup after payload extraction succeeds.
    @State private var isFetchingRestaurant = false
    /// Drives `.photosPicker(isPresented:)` — the view-style `PhotosPicker` fails to
    /// surface its sheet from inside a `.fullScreenCover`, so a Button + modifier
    /// pattern is used instead. Shared across all three scanner UI variants.
    @State private var showingPhotoPicker = false
    /// Prevents duplicate routing when camera callbacks report the same QR frame repeatedly.
    @State private var deliveredRestaurantId: String?
    /// Local fallback destination for standalone scanner usage without a parent route handler.
    @State private var fallbackMenuRestaurant: Restaurant?
    @State private var showingFallbackMenu = false

    // MARK: - Init

    init(onRestaurantScanned: ((Restaurant) -> Void)? = nil) {
        self.onRestaurantScanned = onRestaurantScanned
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                // ViewModel is ready, render platform-appropriate scanner UI.
                scannerBody(vm: vm)
            } else {
                // Temporary placeholder while dependencies are injected from environment.
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            if viewModel == nil {
                // Delay creation until .task so @Environment values are guaranteed available.
                viewModel = QRScannerViewModel(services: services)
            }
        }
    }

    // MARK: - Scanner Body

    @ViewBuilder
    private func scannerBody(vm: QRScannerViewModel) -> some View {
        // Shared wrapper applies navigation + toast behaviour regardless of scanner source
        // (camera, imported image, or manual payload text field).
        scannerContent(vm: vm)
            .navigationTitle("qr_scanner_title")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(
                get: { onRestaurantScanned == nil && showingFallbackMenu && fallbackMenuRestaurant != nil },
                set: { presented in
                    showingFallbackMenu = presented
                    if !presented {
                        fallbackMenuRestaurant = nil
                        deliveredRestaurantId = nil
                        vm.reset()
                    }
                }
            )) {
                if let restaurant = fallbackMenuRestaurant {
                    RestaurantView(restaurant: restaurant, opensMenuOnAppear: true)
                }
            }
            .toast(
                message: vm.toastMessage,
                style: vm.toastStyle,
                isPresented: Binding(
                    get: { vm.showToast },
                    set: { vm.showToast = $0 }
                )
            )
            .onChange(of: isLoadingState(of: vm)) { _, isLoading in
                // QRScannerViewModel uses @Observable (not ObservableObject), so there is no
                // Combine publisher on $scannerState. Instead we derive a plain Bool from the
                // state enum — SwiftUI's @Observable tracking will re-evaluate this expression
                // whenever `vm.scannerState` changes, triggering onChange as expected.
                if isLoading {
                    // Once lookup starts, stop image-analysis indicator.
                    isProcessingImage = false
                    isFetchingRestaurant = true
                } else {
                    isFetchingRestaurant = false
                }
            }
            // No SwiftUI photo-picker modifier here: every SwiftUI presentation API
            // (`.photosPicker(isPresented:)`, `.sheet`, `.fullScreenCover`) is unstable
            // for this view because it is itself hosted inside a `.fullScreenCover` from
            // SearchView. The QR-only buttons present `PHPickerViewController` directly
            // through UIKit (see `presentPhotoPicker(vm:)`), which is independent of the
            // SwiftUI modal stack and therefore unaffected by the nesting.
            #if !canImport(UIKit) || os(macOS)
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $selectedQRImageItem,
                matching: .images
            )
            .onChange(of: selectedQRImageItem) { _, newItem in
                guard let newItem else { return }
                guard !vm.isPaused else { return }
                selectedQRImageItem = nil
                Task {
                    await processImportedImage(item: newItem, vm: vm)
                }
            }
            #endif
    }

    @ViewBuilder
    private func scannerContent(vm: QRScannerViewModel) -> some View {
        #if canImport(VisionKit) && canImport(UIKit) && !os(macOS)
        if DataScannerViewController.isSupported {
            if DataScannerViewController.isAvailable {
                // Primary path for physical iPhone/iPad devices with camera access.
                iosCameraScannerView(vm: vm)
            } else {
                // Supported device, but camera access/session is currently unavailable —
                // typically Camera permission is denied. Show a user-facing screen that
                // guides them into Settings and offers a photo-library scan as an
                // immediate alternative.
                cameraUnavailableView(vm: vm)
            }
        } else {
            // Unsupported runtime (commonly simulator) — keep the dev test harness.
            unsupportedPlatformView(vm: vm)
        }
        #else
        // Native macOS build path always uses the dev test harness.
        unsupportedPlatformView(vm: vm)
        #endif
    }

    // MARK: - iOS Camera Scanner

    #if canImport(VisionKit) && canImport(UIKit) && !os(macOS)
    private func iosCameraScannerView(vm: QRScannerViewModel) -> some View {
        ZStack {
            // Live camera feed + QR detection bridge.
            DataScannerRepresentable(viewModel: vm, onRestaurantScanned: routeScannedRestaurant)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 4)
                    }
                    .accessibilityLabel(Text("qr_scanner_dismiss"))

                    Spacer()

                    HStack(spacing: Constants.UI.spacingMedium) {
                        // Gallery import mirrors the fallback path: users can decode a QR
                        // screenshot or a saved QR image without leaving the scanner.
                        Button {
                            presentPhotoPicker(vm: vm)
                        } label: {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 4)
                        }
                        .accessibilityLabel(Text("qr_scanner_pick_image"))
                        .disabled(vm.isPaused)

                        Button {
                            // Toggle is reflected in updateUIViewController where torch hardware is set.
                            vm.isTorchOn.toggle()
                        } label: {
                            Image(systemName: vm.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 4)
                        }
                        .accessibilityLabel(Text("qr_scanner_torch"))
                    }
                }
                .padding(.horizontal, Constants.UI.spacingMedium)
                .padding(.top, Constants.UI.spacingMedium)

                Spacer()

                if case .loading = vm.scannerState {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                        .padding(Constants.UI.spacingLarge)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium))
                        .padding(.bottom, Constants.UI.spacingMedium)
                } else if isProcessingImage {
                    // Image decoding runs off the main actor and completes before the
                    // viewmodel transitions to .loading; show an interim spinner so the
                    // tap on the gallery icon has immediate visual feedback.
                    ProgressView("qr_scanner_fallback_analysing")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding(Constants.UI.spacingLarge)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium))
                        .padding(.bottom, Constants.UI.spacingMedium)
                }

                Text("qr_scanner_instruction")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Constants.UI.spacingLarge)
                    .padding(.vertical, Constants.UI.spacingSmall + 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, Constants.UI.spacingExtraLarge)
            }
        }
    }
    #endif

    // MARK: - Camera Unavailable (User-Facing)

    /// Shown to end users when the device supports DataScanner but the camera
    /// session is unavailable — almost always because Camera permission was
    /// denied. The screen mirrors Apple's permission-prompt style and offers
    /// two recovery paths: open Settings to grant access, or scan a saved QR
    /// image from the photo library.
    @ViewBuilder
    private func cameraUnavailableView(vm: QRScannerViewModel) -> some View {
        VStack(spacing: Constants.UI.spacingLarge) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(.secondary)

            VStack(spacing: Constants.UI.spacingSmall) {
                Text("qr_scanner_fallback_permission_title")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("qr_scanner_fallback_permission_message")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Constants.UI.spacingLarge)

            VStack(spacing: Constants.UI.spacingMedium) {
                #if canImport(UIKit) && !os(macOS)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("qr_scanner_open_settings", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                #endif

                Button {
                    presentPhotoPicker(vm: vm)
                } label: {
                    Label("qr_scanner_pick_image", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(vm.isPaused)

                if isProcessingImage {
                    ProgressView("qr_scanner_fallback_analysing")
                } else if isFetchingRestaurant {
                    ProgressView("qr_scanner_fallback_loading_restaurant")
                }
            }
            .padding(.horizontal, Constants.UI.spacingLarge)

            Spacer()

            Button("qr_scanner_dismiss_button") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, Constants.UI.spacingLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColour)
    }

    // MARK: - Unsupported Platform (Dev Test Harness)

    /// Desktop/simulator QR test harness.
    ///
    /// Used only when DataScanner is not supported by the runtime (macOS or
    /// older simulator builds). Allows full feature validation without a
    /// physical iPhone by:
    /// 1) importing a QR image file, or
    /// 2) pasting a deep-link payload directly.
    private func unsupportedPlatformView(vm: QRScannerViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.UI.spacingLarge) {
                VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {
                    Text("qr_scanner_fallback_unsupported_title")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("qr_scanner_fallback_unsupported_message")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {
                    Text("qr_scanner_fallback_import_step")
                        .font(.headline)

                    Button {
                        presentPhotoPicker(vm: vm)
                    } label: {
                        Label("qr_scanner_fallback_choose_image", systemImage: "photo")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isPaused)

                    if isProcessingImage {
                        ProgressView("qr_scanner_fallback_analysing")
                    }
                }

                VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {
                    Text("qr_scanner_fallback_paste_step")
                        .font(.headline)

                    TextField("qr_scanner_fallback_payload_placeholder", text: $manualPayload, axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        guard !vm.isPaused else { return }
                        Task {
                            // Manual payload testing still runs through ViewModel validation/fetch flow.
                            if let restaurant = await vm.handleScannedString(manualPayload.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                routeScannedRestaurant(restaurant)
                            }
                        }
                    } label: {
                        Label("qr_scanner_fallback_validate_payload", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .disabled(manualPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isPaused)
                }

                if isFetchingRestaurant {
                    // Shown after extraction completes and restaurant fetch is in-flight.
                    ProgressView("qr_scanner_fallback_loading_restaurant")
                }

                Button("qr_scanner_dismiss_button") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(Constants.UI.spacingLarge)
        }
        .background(backgroundColour)
    }

    // MARK: - Private Helpers

    /// Triggers the photo picker via the platform-appropriate path.
    ///
    /// On iOS, the picker is presented through UIKit (`PHPickerHost.present`) directly
    /// against the topmost view controller, which avoids the SwiftUI modal-stack bug
    /// that fires when `.photosPicker` / `.sheet` are nested inside the host
    /// `.fullScreenCover`. On macOS, a regular SwiftUI `.photosPicker(isPresented:)`
    /// modifier handles presentation since macOS does not exhibit the bug.
    private func presentPhotoPicker(vm: QRScannerViewModel) {
        guard !vm.isPaused else { return }

        #if canImport(UIKit) && !os(macOS)
        PHPickerHost.present { data in
            handlePickedImageData(data, vm: vm)
        }
        #else
        showingPhotoPicker = true
        #endif
    }

    /// Forwards image bytes returned from the iOS PHPicker into the shared QR pipeline.
    private func handlePickedImageData(_ data: Data?, vm: QRScannerViewModel) {
        guard !vm.isPaused else { return }
        guard let data else {
            vm.presentImageLoadError()
            return
        }
        Task {
            isProcessingImage = true
            let restaurant = await vm.handleScannedImageData(data)
            isProcessingImage = false
            if let restaurant {
                routeScannedRestaurant(restaurant)
            }
        }
    }

    /// Loads selected image data and forwards it into shared frame processing logic.
    /// Used by the macOS path where `PhotosPicker` returns a `PhotosPickerItem`.
    private func processImportedImage(item: PhotosPickerItem, vm: QRScannerViewModel) async {
        guard !vm.isPaused else { return }
        isProcessingImage = true

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            isProcessingImage = false
            // Defer toast state mutation to the ViewModel so presentation state
            // remains centralised in one layer.
            vm.presentImageLoadError()
            return
        }

        // Forward raw bytes into reusable frame-processing/data-handling pipeline.
        let restaurant = await vm.handleScannedImageData(data)
        isProcessingImage = false
        if let restaurant {
            routeScannedRestaurant(restaurant)
        }
    }

    /// Completes the successful scan flow exactly once.
    ///
    /// This is called by the same async task that received the fetched
    /// `Restaurant`, instead of waiting for a separate SwiftUI `.onChange`.
    /// For SearchView, the parent stores the restaurant, then this scanner
    /// dismisses its own full-screen cover. For standalone use, it falls back to
    /// local navigation.
    private func routeScannedRestaurant(_ restaurant: Restaurant) {
        guard deliveredRestaurantId != restaurant.id else { return }
        deliveredRestaurantId = restaurant.id

        if let onRestaurantScanned {
            onRestaurantScanned(restaurant)
            dismiss()
        } else {
            fallbackMenuRestaurant = restaurant
            showingFallbackMenu = true
        }
    }

    /// Derives a simple Bool from `ScannerState` for use with `.onChange(of:)`.
    ///
    /// `ScannerState` carries an associated `Restaurant` value and is not `Equatable`,
    /// so it cannot be observed directly by `.onChange`. Reducing it to a Bool keeps
    /// the observation cheap while still letting SwiftUI's `@Observable` dependency
    /// tracking pick up the underlying state change.
    private func isLoadingState(of vm: QRScannerViewModel) -> Bool {
        if case .loading = vm.scannerState { return true }
        return false
    }

    /// Platform-specific semantic background colour.
    private var backgroundColour: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }

}

#if canImport(VisionKit) && canImport(UIKit) && !os(macOS)
// MARK: - DataScanner Representable

private struct DataScannerRepresentable: UIViewControllerRepresentable {

    let viewModel: QRScannerViewModel
    let onRestaurantScanned: (Restaurant) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        // DataScanner configured strictly for QR symbols to minimise false positives
        // and keep parity with Android scanner expectations.
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )

        scanner.delegate = context.coordinator
        // Start capture immediately so the scanner is interactive on presentation.
        try? scanner.startScanning()

        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            // DataScanner itself has no direct torch API, so we sync against AVCaptureDevice.
            try? device.lockForConfiguration()
            device.torchMode = viewModel.isTorchOn ? .on : .off
            device.unlockForConfiguration()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onRestaurantScanned: onRestaurantScanned)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let viewModel: QRScannerViewModel
        let onRestaurantScanned: (Restaurant) -> Void

        init(viewModel: QRScannerViewModel, onRestaurantScanned: @escaping (Restaurant) -> Void) {
            self.viewModel = viewModel
            self.onRestaurantScanned = onRestaurantScanned
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            // We only care about the first newly detected QR payload for this flow.
            guard let item = addedItems.first,
                  case .barcode(let barcode) = item,
                  let payload = barcode.payloadStringValue
            else { return }

            Task { @MainActor in
                // Actor hop keeps Swift 6 strict-concurrency rules satisfied.
                if let restaurant = await viewModel.handleScannedString(payload) {
                    onRestaurantScanned(restaurant)
                }
            }
        }
    }
}
#endif

#if canImport(UIKit) && !os(macOS)
import UniformTypeIdentifiers

// MARK: - PHPicker Host (Direct UIKit Presentation)

/// Presents `PHPickerViewController` through UIKit's modal stack instead of any
/// SwiftUI presentation modifier (`.sheet`, `.fullScreenCover`, `.photosPicker`).
///
/// Why direct UIKit presentation:
/// - QRScannerView is hosted inside a `.fullScreenCover` from SearchView.
/// - Every SwiftUI presentation API observed dismisses itself when nested inside
///   that cover on iOS 26 — both the view-style `PhotosPicker` and the modifier
///   `.photosPicker(isPresented:)` exhibit the bug, and routing the picker
///   through a `.sheet` simply moves the same bug down one level.
/// - UIKit's `present(_:animated:)` is independent of SwiftUI's modal-state
///   tracking, so the picker remains open until the user selects or cancels.
@MainActor
private enum PHPickerHost {
    /// The active coordinator is retained statically for the picker's lifetime.
    /// PHPickerViewController only holds its delegate weakly — without an
    /// independent strong reference the coordinator deallocates the moment the
    /// stack frame returns and the delegate callback is never delivered.
    private static var activeCoordinator: PHPickerCoordinator?

    static func present(onPicked: @escaping (Data?) -> Void) {
        guard let topVC = topMostViewController() else {
            onPicked(nil)
            return
        }

        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)

        let coordinator = PHPickerCoordinator { data in
            // Drop the strong reference once the picker has reported its result so
            // the coordinator (and its captured closure) can be released.
            PHPickerHost.activeCoordinator = nil
            onPicked(data)
        }
        picker.delegate = coordinator
        activeCoordinator = coordinator

        topVC.present(picker, animated: true)
    }

    /// Walks the scene/window hierarchy to find the view controller that should
    /// host the picker. The picker has to be presented from a controller that is
    /// itself fully visible — typically the deepest `presentedViewController`.
    private static func topMostViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.first as? UIWindowScene

        let window = scene?.windows.first(where: \.isKeyWindow)
            ?? scene?.windows.first

        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

private final class PHPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
    private let onPicked: (Data?) -> Void

    init(onPicked: @escaping (Data?) -> Void) {
        self.onPicked = onPicked
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // Dismiss before invoking the callback so the picker animation does not
        // race with downstream state updates triggered by `onPicked`.
        picker.dismiss(animated: true)

        // Capture the closure up-front so it can be hopped onto the main actor
        // without retaining the coordinator across the Task boundary — Swift 6
        // strict concurrency rejects implicit `self` captures here.
        let onPicked = onPicked

        guard let provider = results.first?.itemProvider else {
            // User cancelled — propagate nil so the caller can short-circuit.
            Task { @MainActor in
                onPicked(nil)
            }
            return
        }

        // `public.image` covers HEIC, PNG, JPEG, WebP, etc. PHPicker resolves it
        // to the concrete representation transparently.
        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            Task { @MainActor in
                onPicked(data)
            }
        }
    }
}
#endif
