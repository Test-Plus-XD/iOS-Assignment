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
#endif

// MARK: - QR Scanner View

struct QRScannerView: View {
    /// Explains why live camera scanning is not being shown.
    private enum FallbackReason {
        /// Camera scanner cannot run on this platform/hardware (e.g. macOS, simulator).
        case unsupportedPlatform
        /// Camera scanner is supported, but currently unavailable (usually permissions).
        case cameraUnavailable
    }

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel: QRScannerViewModel?
    @State private var selectedQRImageItem: PhotosPickerItem?
    @State private var manualPayload = ""
    /// Tracks asynchronous image decoding/extraction so fallback UI can show progress.
    @State private var isProcessingImage = false

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
                get: {
                    // Present destination whenever scanner state transitions to success.
                    if case .success = vm.scannerState { return true }
                    return false
                },
                set: { presented in
                    // When destination is dismissed, reset scanner so users can run another test.
                    if !presented { vm.reset() }
                }
            )) {
                if case .success(let restaurant) = vm.scannerState {
                    MenuView(
                        restaurantId: restaurant.id,
                        restaurantName: restaurant.name.localised
                    )
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
    }

    @ViewBuilder
    private func scannerContent(vm: QRScannerViewModel) -> some View {
        #if canImport(VisionKit) && canImport(UIKit) && !os(macOS)
        if DataScannerViewController.isSupported {
            if DataScannerViewController.isAvailable {
                // Primary path for physical iPhone/iPad devices with camera access.
                iosCameraScannerView(vm: vm)
            } else {
                // Supported device, but camera access/session is currently unavailable.
                fallbackScannerView(vm: vm, reason: .cameraUnavailable)
            }
        } else {
            // Unsupported runtime (commonly simulator).
            fallbackScannerView(vm: vm, reason: .unsupportedPlatform)
        }
        #else
        // Native macOS build path always uses fallback scanner.
        fallbackScannerView(vm: vm, reason: .unsupportedPlatform)
        #endif
    }

    // MARK: - iOS Camera Scanner

    #if canImport(VisionKit) && canImport(UIKit) && !os(macOS)
    private func iosCameraScannerView(vm: QRScannerViewModel) -> some View {
        ZStack {
            // Live camera feed + QR detection bridge.
            DataScannerRepresentable(viewModel: vm)
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

    // MARK: - Fallback Scanner (macOS / Simulator)

    /// Desktop/simulator QR test harness.
    ///
    /// This allows full feature validation without a physical iPhone by:
    /// 1) importing a QR image file, or
    /// 2) pasting a deep-link payload directly.
    private func fallbackScannerView(vm: QRScannerViewModel, reason: FallbackReason) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.UI.spacingLarge) {
                VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {
                    Text(fallbackTitle(for: reason))
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(fallbackMessage(for: reason))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {
                    Text("qr_scanner_fallback_import_step")
                        .font(.headline)

                    PhotosPicker(selection: $selectedQRImageItem, matching: .images) {
                        Label("qr_scanner_fallback_choose_image", systemImage: "photo")
                    }
                    .buttonStyle(.borderedProminent)
                    .onChange(of: selectedQRImageItem) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            await processImportedImage(item: newItem, vm: vm)
                        }
                    }

                    if isProcessingImage {
                        // British English wording kept intentionally per project request.
                        ProgressView("qr_scanner_fallback_analysing")
                    }
                }

                VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {
                    Text("qr_scanner_fallback_paste_step")
                        .font(.headline)

                    TextField("qr_scanner_fallback_payload_placeholder", text: $manualPayload, axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            // Manual payload testing still runs through ViewModel validation/fetch flow.
                            await vm.handleScannedString(manualPayload.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    } label: {
                        Label("qr_scanner_fallback_validate_payload", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .disabled(manualPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if case .loading = vm.scannerState {
                    // Shared loading indicator while RestaurantService fetches matched restaurant.
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

    /// Loads selected image data and forwards it into shared frame processing logic.
    private func processImportedImage(item: PhotosPickerItem, vm: QRScannerViewModel) async {
        isProcessingImage = true
        defer { isProcessingImage = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            // Defer toast state mutation to the ViewModel so presentation state
            // remains centralised in one layer.
            vm.presentImageLoadError()
            return
        }

        // Forward raw bytes into reusable frame-processing/data-handling pipeline.
        await vm.handleScannedImageData(data)
    }

    /// Platform-specific semantic background colour.
    private var backgroundColour: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }

    /// Reason-specific heading so users understand why live camera scanning is absent.
    private func fallbackTitle(for reason: FallbackReason) -> String {
        switch reason {
        case .unsupportedPlatform:
            return String(localized: "qr_scanner_fallback_unsupported_title")
        case .cameraUnavailable:
            return String(localized: "qr_scanner_fallback_permission_title")
        }
    }

    /// Reason-specific guidance for unsupported platform vs permission issues.
    private func fallbackMessage(for reason: FallbackReason) -> String {
        switch reason {
        case .unsupportedPlatform:
            return String(localized: "qr_scanner_fallback_unsupported_message")
        case .cameraUnavailable:
            return String(localized: "qr_scanner_fallback_permission_message")
        }
    }
}

#if canImport(VisionKit) && canImport(UIKit) && !os(macOS)
// MARK: - DataScanner Representable

private struct DataScannerRepresentable: UIViewControllerRepresentable {

    let viewModel: QRScannerViewModel

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
        Coordinator(viewModel: viewModel)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let viewModel: QRScannerViewModel

        init(viewModel: QRScannerViewModel) {
            self.viewModel = viewModel
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
                await viewModel.handleScannedString(payload)
            }
        }
    }
}
#endif
