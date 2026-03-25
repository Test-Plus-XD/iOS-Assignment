//
//  QRScannerView.swift
//  Pour Rice
//
//  Full-screen QR code scanner presented from the Search tab toolbar.
//  Validates pourrice://menu/{restaurantId} codes and navigates to MenuView on success.
//
//  ============= FOR FLUTTER/ANDROID DEVELOPERS: =============
//  Android equivalent: lib/pages/qr_scanner_page.dart using the mobile_scanner package.
//
//  iOS uses VisionKit's DataScannerViewController (built-in, no package needed):
//    - UIViewControllerRepresentable bridges it into SwiftUI (= PlatformViewFactory in Flutter)
//    - DataScannerViewControllerDelegate = callback listener (= BarcodeCapture callback)
//    - Coordinator pattern = the Listener/Observer class in Android
//
//  iOS advantage: DataScannerViewController provides built-in:
//    - Scanning guidance text ("Point camera at a QR code")
//    - Highlight rectangles around detected codes
//    - Pinch-to-zoom
//  The Android app implements these manually via custom painter + MobileScannerController.
//  =============================================================
//

import SwiftUI
import VisionKit       // DataScannerViewController — Apple's high-level barcode scanner (iOS 16+)
import AVFoundation    // AVCaptureDevice — needed to control the torch separately
internal import Vision

// MARK: - QR Scanner View

/// Full-screen QR scanner presented as a .fullScreenCover from SearchView.
///
/// This view MUST be wrapped in a NavigationStack at the call site:
///   .fullScreenCover { NavigationStack { QRScannerView() } }
/// The NavigationStack is required so .navigationDestination works for post-scan navigation.
struct QRScannerView: View {

    // MARK: - Environment

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// ViewModel is created lazily inside .task so services are available at init time.
    /// (ViewModels that need @Environment values cannot be created in the struct initialiser.)
    @State private var viewModel: QRScannerViewModel?

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                // ViewModel ready — render the scanner or unsupported fallback
                scannerBody(vm: vm)
            } else {
                // Brief black flash while the .task initialises the ViewModel
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            // Initialise ViewModel once, injecting services from the environment.
            // Using .task (not .onAppear) ensures the async context is available
            // and the task is cancelled automatically when the view disappears.
            if viewModel == nil {
                viewModel = QRScannerViewModel(services: services)
            }
        }
    }

    // MARK: - Scanner Body

    /// Main scanner UI — guards DataScannerViewController availability first.
    @ViewBuilder
    private func scannerBody(vm: QRScannerViewModel) -> some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            // ---------------------------------------------------------------
            // SUPPORTED PATH — physical device with a camera
            // DataScannerViewController.isSupported  = hardware + OS check (iOS 16+)
            // DataScannerViewController.isAvailable  = camera permission granted
            //   (will prompt the user if not yet granted, then become true)
            // ---------------------------------------------------------------
            ZStack {
                // ── Camera layer ──────────────────────────────────────────
                // DataScannerRepresentable fills the full screen behind all overlays.
                // Its Coordinator notifies the ViewModel when a QR code is detected.
                DataScannerRepresentable(viewModel: vm)
                    .ignoresSafeArea()

                // ── Overlay UI ────────────────────────────────────────────
                // Floats over the camera feed:
                //   • Top:    dismiss button (left) + torch toggle (right)
                //   • Middle: loading spinner while fetching restaurant
                //   • Bottom: instruction label (glass capsule)
                VStack {

                    // Top controls bar
                    HStack {
                        // Dismiss button — exits the full-screen scanner
                        Button {
                            dismiss()
                        } label: {
                            // xmark.circle.fill provides a clear tap target over any background
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 4)
                        }
                        .accessibilityLabel(Text("qr_scanner_dismiss"))

                        Spacer()

                        // Torch toggle — illuminates low-light menus on physical tables
                        // The actual torch state is applied in DataScannerRepresentable.updateUIViewController
                        Button {
                            vm.isTorchOn.toggle()
                        } label: {
                            Image(systemName: vm.isTorchOn
                                  ? "flashlight.on.fill"   // Filled = torch is on
                                  : "flashlight.off.fill") // Outlined = torch is off
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 4)
                        }
                        .accessibilityLabel(Text("qr_scanner_torch"))
                    }
                    .padding(.horizontal, Constants.UI.spacingMedium)
                    .padding(.top, Constants.UI.spacingMedium)

                    Spacer()

                    // Loading spinner — shown while the API call is in flight
                    // Displayed over the camera feed so the user knows a scan was detected
                    if case .loading = vm.scannerState {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                            .padding(Constants.UI.spacingLarge)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium))
                            .padding(.bottom, Constants.UI.spacingMedium)
                    }

                    // Bottom instruction label (Liquid Glass–style capsule)
                    Text("qr_scanner_instruction")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Constants.UI.spacingLarge)
                        .padding(.vertical, Constants.UI.spacingSmall + 2)
                        // ultraThinMaterial gives the frosted-glass look consistent with iOS 26 design
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, Constants.UI.spacingExtraLarge)
                }
            }
            // ── Post-scan navigation ─────────────────────────────────────
            // When scannerState becomes .success(restaurant), push MenuView
            // onto the NavigationStack that wraps this view (created in SearchView's fullScreenCover).
            //
            // ANDROID EQUIVALENT:
            //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RestaurantMenuPage(...)))
            .navigationDestination(isPresented: Binding(
                // isPresented == true when state is .success (regardless of associated value)
                get: {
                    if case .success = vm.scannerState { return true }
                    return false
                },
                // When the user pops back from MenuView (isPresented set to false),
                // reset the ViewModel so they can scan another code
                set: { presented in
                    if !presented { vm.reset() }
                }
            )) {
                // Destination: only rendered when state is actually .success
                // Extract the associated Restaurant value safely
                if case .success(let restaurant) = vm.scannerState {
                    MenuView(
                        restaurantId: restaurant.id,
                        restaurantName: restaurant.name.localised
                    )
                }
            }
            // Toast for invalid QR or restaurant-not-found errors
            .toast(
                message: vm.toastMessage,
                style: vm.toastStyle,
                isPresented: Binding(
                    get: { vm.showToast },
                    set: { vm.showToast = $0 }
                )
            )

        } else {
            // ---------------------------------------------------------------
            // UNSUPPORTED PATH — simulator or device without camera
            // DataScannerViewController.isSupported is false on simulators.
            // Presenting a meaningful fallback prevents a blank/crashed screen.
            // ---------------------------------------------------------------
            unsupportedView
        }
    }

    // MARK: - Unsupported Device View

    /// Shown on the iOS Simulator (no camera) or when camera permission is permanently denied.
    private var unsupportedView: some View {
        VStack(spacing: Constants.UI.spacingMedium) {
            // Large camera icon to make the state visually clear
            Image(systemName: "camera.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("qr_scanner_unavailable")
                .font(.title2)
                .fontWeight(.semibold)

            Text("qr_scanner_unavailable_message")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("qr_scanner_dismiss_button") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, Constants.UI.spacingSmall)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("qr_scanner_title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - DataScanner Representable

/// Bridges VisionKit's UIKit-based DataScannerViewController into SwiftUI.
///
/// ============= FOR FLUTTER/ANDROID DEVELOPERS: =============
/// UIViewControllerRepresentable = Flutter's PlatformViewFactory / AndroidView widget.
///
/// Three required methods mirror the platform view lifecycle:
///   makeUIViewController   = createPlatformView() — create and configure
///   updateUIViewController = update in response to parent state changes
///   makeCoordinator        = create the delegate/listener object
///
/// The Coordinator holds delegate callbacks (= Listener in Android).
/// =============================================================
private struct DataScannerRepresentable: UIViewControllerRepresentable {

    // The ViewModel that receives scan results — passed in from QRScannerView
    let viewModel: QRScannerViewModel

    // MARK: - UIViewControllerRepresentable

    /// Creates and starts the DataScannerViewController.
    /// Called once when the SwiftUI view first appears.
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            // Only recognise QR codes — ignore barcodes, Data Matrix, etc.
            // Matches Android: formats: [BarcodeFormat.qrCode]
            recognizedDataTypes: [.barcode(symbologies: [.qr])],

            // .balanced is the default; provides a good mix of accuracy and performance.
            // Use .accurate only if missing scans becomes an issue.
            qualityLevel: .balanced,

            // Stop after detecting the first QR code.
            // Multiple-item recognition would require extra deduplication logic.
            recognizesMultipleItems: false,

            // Disable 120fps tracking — unnecessary for static QR codes on tables
            isHighFrameRateTrackingEnabled: false,

            // Pinch-to-zoom lets users focus on small or distant QR codes
            isPinchToZoomEnabled: true,

            // Apple's built-in scanning instruction text shown when no code is in frame
            isGuidanceEnabled: true,

            // Blue highlight rectangle drawn over a detected QR code before it is processed
            isHighlightingEnabled: true
        )

        // Wire up the delegate — Coordinator receives barcode events
        scanner.delegate = context.coordinator

        // Begin capturing immediately.
        // try? suppresses the AVFoundation error if the session is already running
        // (can happen on fast device orientation changes)
        try? scanner.startScanning()

        return scanner
    }

    /// Called whenever SwiftUI re-renders this representable due to state changes.
    /// Used here to sync the ViewModel's torch toggle with the camera hardware.
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Torch control via AVCaptureDevice.
        //
        // DataScannerViewController does NOT expose a torch API directly,
        // so we access the back camera device and set torchMode manually.
        //
        // try? silences errors on devices without a torch (rare) or when
        // another app holds the camera session.
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = viewModel.isTorchOn ? .on : .off
            device.unlockForConfiguration()
        }
    }

    /// Creates the Coordinator (delegate) object.
    /// Called once by SwiftUI before makeUIViewController.
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    // MARK: - Coordinator

    /// Receives DataScannerViewController delegate callbacks and forwards them to the ViewModel.
    ///
    /// The Coordinator inherits from NSObject because UIKit delegates require Objective-C
    /// compatibility. This is boilerplate in UIViewControllerRepresentable.
    ///
    /// FLUTTER EQUIVALENT:
    /// The anonymous BarcodeCapture callback in MobileScannerController(onDetect: ...)
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {

        // Weak reference not needed — DataScannerViewController does not retain its delegate
        // (delegates in UIKit are unowned/weak by convention, checked in practice here
        // because QRScannerViewModel is @MainActor and stays alive as long as the view does)
        let viewModel: QRScannerViewModel

        init(viewModel: QRScannerViewModel) {
            self.viewModel = viewModel
        }

        /// Called by DataScannerViewController when new barcodes enter the camera frame.
        ///
        /// - Parameters:
        ///   - dataScanner: The controller that detected the items
        ///   - addedItems: Newly detected items (we only care about the first one)
        ///   - allItems: All currently tracked items in frame
        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            // We configured recognizesMultipleItems: false, so addedItems has at most 1 element.
            // Guard against an empty array just in case.
            guard let item = addedItems.first,
                  case .barcode(let barcode) = item,           // Ensure it is a barcode (not text)
                  let payload = barcode.payloadStringValue      // Extract the raw string payload
            else { return }

            // Bridge the UIKit delegate callback to the @MainActor ViewModel.
            //
            // WHY Task { @MainActor in }:
            // DataScannerViewControllerDelegate methods are called on the main thread by VisionKit,
            // but Swift 6 strict concurrency still requires an explicit actor hop when calling
            // @MainActor methods from a non-isolated context (the Coordinator class).
            // The Task is cheap — it resolves synchronously on the main run loop.
            //
            // FLUTTER EQUIVALENT:
            // setState(() { ... }) or ChangeNotifier.notifyListeners() from BarcodeCapture callback
            Task { @MainActor in
                await viewModel.handleScannedString(payload)
            }
        }
    }
}
