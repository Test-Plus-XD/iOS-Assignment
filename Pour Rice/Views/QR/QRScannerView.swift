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

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel: QRScannerViewModel?
    @State private var selectedQRImageItem: PhotosPickerItem?
    @State private var manualPayload = ""
    @State private var isProcessingImage = false

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                scannerBody(vm: vm)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = QRScannerViewModel(services: services)
            }
        }
    }

    // MARK: - Scanner Body

    @ViewBuilder
    private func scannerBody(vm: QRScannerViewModel) -> some View {
        scannerContent(vm: vm)
            .navigationTitle("qr_scanner_title")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(
                get: {
                    if case .success = vm.scannerState { return true }
                    return false
                },
                set: { presented in
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
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            iosCameraScannerView(vm: vm)
        } else {
            fallbackScannerView(vm: vm)
        }
        #else
        fallbackScannerView(vm: vm)
        #endif
    }

    // MARK: - iOS Camera Scanner

    #if canImport(VisionKit) && canImport(UIKit) && !os(macOS)
    private func iosCameraScannerView(vm: QRScannerViewModel) -> some View {
        ZStack {
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
    private func fallbackScannerView(vm: QRScannerViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.UI.spacingLarge) {
                VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {
                    Text("Camera scanner unavailable on this device.")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Use a QR image or paste a payload to test the exact same QR logic flow on macOS or simulator.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {
                    Text("1) Import QR image")
                        .font(.headline)

                    PhotosPicker(selection: $selectedQRImageItem, matching: .images) {
                        Label("Choose QR image", systemImage: "photo")
                    }
                    .buttonStyle(.borderedProminent)
                    .onChange(of: selectedQRImageItem) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            await processImportedImage(item: newItem, vm: vm)
                        }
                    }

                    if isProcessingImage {
                        ProgressView("Analysing QR image…")
                    }
                }

                VStack(alignment: .leading, spacing: Constants.UI.spacingSmall) {
                    Text("2) Paste QR payload")
                        .font(.headline)

                    TextField("pourrice://menu/{restaurantId}", text: $manualPayload, axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            await vm.handleScannedString(manualPayload.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    } label: {
                        Label("Validate payload", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .disabled(manualPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if case .loading = vm.scannerState {
                    ProgressView("Loading restaurant…")
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
            vm.showToast = false
            vm.toastMessage = "Unable to read the selected image."
            vm.toastStyle = .error
            vm.showToast = true
            return
        }

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
}

#if canImport(VisionKit) && canImport(UIKit) && !os(macOS)
// MARK: - DataScanner Representable

private struct DataScannerRepresentable: UIViewControllerRepresentable {

    let viewModel: QRScannerViewModel

    func makeUIViewController(context: Context) -> DataScannerViewController {
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
        try? scanner.startScanning()

        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
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
            guard let item = addedItems.first,
                  case .barcode(let barcode) = item,
                  let payload = barcode.payloadStringValue
            else { return }

            Task { @MainActor in
                await viewModel.handleScannedString(payload)
            }
        }
    }
}
#endif
