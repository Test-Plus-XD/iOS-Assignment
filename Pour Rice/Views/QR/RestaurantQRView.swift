//
//  RestaurantQRView.swift
//  Pour Rice
//
//  Generates and displays a QR code for a restaurant's menu deep link.
//  Presented as a sheet from the StoreView Quick Actions grid (restaurant owners only).
//
//  ============= FOR FLUTTER/ANDROID DEVELOPERS: =============
//  Android equivalent: lib/widgets/qr/menu_qr_generator.dart using qr_flutter package.
//
//  iOS uses CoreImage's built-in CIQRCodeGenerator filter — no package needed:
//    - CIFilter.qrCodeGenerator() = QrImageView in qr_flutter
//    - correctionLevel "H" = QrErrorCorrectLevel.H (both = ~30% damage tolerance)
//    - CIContext.createCGImage() = the render step (Flutter does this internally)
//    - ShareLink = Share.shareXFiles() via share_plus
//
//  Key iOS-specific detail:
//    .interpolation(.none) on the SwiftUI Image is REQUIRED.
//    Without it, SwiftUI applies bilinear filtering when scaling the 1pt-per-module
//    CoreImage output up to the display size, making the QR code blurry and potentially
//    unreadable. interpolation(.none) keeps hard pixel edges — same as qr_flutter's
//    default nearest-neighbour rendering.
//  =============================================================
//

import SwiftUI
internal import CoreImage                   // CIFilter, CIContext, CIImage
import CoreImage.CIFilterBuiltins  // Typed CIFilter.qrCodeGenerator() API (iOS 15+)
import UniformTypeIdentifiers      // UTType.png — required for DataRepresentation in the Transferable extension

// MARK: - Restaurant QR View

/// Sheet displaying a scannable QR code for this restaurant's menu deep link.
///
/// The QR encodes: pourrice://menu/{restaurantId}
/// Any device running the Pour Rice app (iOS or Android) can scan it
/// to jump directly to the restaurant's menu.
struct RestaurantQRView: View {

    // MARK: - Properties

    /// The restaurant whose QR code is being displayed
    let restaurant: Restaurant

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - Private

    /// CIContext is moderately expensive to create (allocates a Metal/GPU pipeline).
    /// Declaring it as a stored property means it is created once per view instance,
    /// not on every body re-evaluation.
    ///
    /// IMPORTANT: CIContext is not @State because RestaurantQRView is a struct
    /// (value type). SwiftUI recreates structs frequently — @State ensures a
    /// single object survives across those recreations.
    @State private var ciContext = CIContext()

    // MARK: - Computed

    /// The deep link URL encoded inside this QR code.
    /// Format: pourrice://menu/{restaurantId}  (identical to Android)
    private var deepLinkURL: String {
        "\(Constants.DeepLink.scheme)://\(Constants.DeepLink.menuHost)/\(restaurant.id)"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.UI.spacingLarge) {

                Spacer()

                // ── QR Code Image ──────────────────────────────────────────
                // generateQRImage() returns a UIImage from the CoreImage pipeline.
                // Image(uiImage:) wraps it into a SwiftUI Image.
                if let qrUIImage = generateQRImage() {
                    Image(uiImage: qrUIImage)
                        // interpolation(.none) = nearest-neighbour scaling
                        // CRITICAL: prevents bilinear blur when SwiftUI scales up
                        // the small CoreImage output (typically ~33x33 pt) to 240x240 pt
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        // White padding is part of the QR code's quiet zone specification.
                        // Scanners require at least 4 modules of white space around the code.
                        .padding(Constants.UI.spacingMedium)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium))
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                } else {
                    // Fallback if CoreImage fails (should not happen on real hardware)
                    Image(systemName: "qrcode")
                        .font(.system(size: 120))
                        .foregroundStyle(.secondary)
                }

                // ── Restaurant Info ────────────────────────────────────────
                VStack(spacing: 6) {
                    // Restaurant name (bilingual — respects current language setting)
                    Text(restaurant.name.localised)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    // Instruction text below the name
                    Text("qr_code_scan_instruction")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Constants.UI.spacingLarge)

                Spacer()

                // ── Share Button ───────────────────────────────────────────
                // ShareLink lets the restaurant owner export the QR code as an image
                // to WhatsApp, AirDrop, email, or save to Photos.
                //
                // ShareLink requires Item: Transferable. UIImage does NOT conform to
                // Transferable natively — the extension below adds this conformance.
                //
                // ANDROID EQUIVALENT: Share.shareXFiles([XFile(path)]) via share_plus
                if let qrUIImage = generateQRImage() {
                    ShareLink(
                        item: qrUIImage,
                        // preview: provides the image thumbnail shown in the share sheet
                        preview: SharePreview(
                            restaurant.name.localised,  // Title in the share sheet
                            image: Image(uiImage: qrUIImage)
                        )
                    ) {
                        Label("qr_code_share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: Constants.UI.cornerRadiusMedium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, Constants.UI.spacingMedium)
                    .padding(.bottom, Constants.UI.spacingLarge)
                }
            }
            .navigationTitle("qr_code_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Done button dismisses the sheet
                ToolbarItem(placement: .topBarTrailing) {
                    Button("qr_code_done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - QR Code Generation

    /// Generates a high-resolution QR code UIImage using CoreImage's built-in filter.
    ///
    /// Pipeline:
    ///   String → Data(UTF-8) → CIFilter → CIImage → scale 3× → CGImage → UIImage
    ///
    /// Error correction level "H" (High):
    ///   Allows up to ~30% of the code to be damaged or obscured and still scan correctly.
    ///   This matches Android's QrErrorCorrectLevel.H in qr_flutter.
    ///   Restaurant QR codes printed on menus or table tents benefit from high correction
    ///   because they may be partially covered, worn, or photographed at an angle.
    ///
    /// Scale factor 3×:
    ///   CIQRCodeGenerator outputs 1 pixel per QR module (typically 33–49 px total).
    ///   Scaling 3× before converting to CGImage produces a ~100-150 px image that
    ///   is sharp at all screen densities and suitable for printing.
    ///   Matches Android's pixelRatio: 3.0 in RepaintBoundary.toImage().
    ///
    /// - Returns: A UIImage with the QR code, or nil if CoreImage fails.
    private func generateQRImage() -> UIImage? {
        // Step 1: Create the typed filter (iOS 15+ API — cleaner than string-based CIFilter(name:))
        let filter = CIFilter.qrCodeGenerator()

        // Step 2: Set the data to encode — must be UTF-8 Data, not a String directly
        guard let messageData = deepLinkURL.data(using: .utf8) else { return nil }
        filter.message = messageData

        // Step 3: Set error correction level.
        // Valid values: "L" (7%), "M" (15%), "Q" (25%), "H" (30%)
        // "H" matches Android's QrErrorCorrectLevel.H
        filter.correctionLevel = "H"

        // Step 4: Get the output CIImage (1 pixel per module, black on transparent background)
        guard let outputImage = filter.outputImage else { return nil }

        // Step 5: Scale up 3× using a CGAffineTransform.
        // CIImage.transformed(by:) applies the transform lazily (no pixel allocation yet).
        let scale = CGAffineTransform(scaleX: 3, y: 3)
        let scaledImage = outputImage.transformed(by: scale)

        // Step 6: Render the CIImage into a CGImage via the shared CIContext.
        // extent is the bounding rect of the transformed image.
        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        // Step 7: Wrap in UIImage — UIImage is the currency for ShareLink and UIKit interop
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - UIImage Transferable Conformance

// UIImage (UIKit) does NOT conform to Transferable out of the box — Apple added
// Transferable conformances to SwiftUI types and URL, but left UIImage out.
// ShareLink<Item> requires Item: Transferable, so we add the conformance here.
//
// @retroactive tells the compiler this is an intentional cross-module conformance
// (UIImage is from UIKit; Transferable is from SwiftUI), suppressing the
// "extension declares conformance of imported type" warning introduced in Swift 5.7.
//
// DataRepresentation exports the image as PNG, which is what the system share sheet
// and share_plus on Android both expect for lossless QR code sharing.
//
// ANDROID EQUIVALENT: no manual conformance needed — share_plus accepts XFile directly.
extension UIImage: @retroactive Transferable {
    // Declares how the system should serialise a UIImage when it is passed to ShareLink.
    public static var transferRepresentation: some TransferRepresentation {
        // DataRepresentation exports the UIImage as PNG bytes under the public.png UTType.
        // The system share sheet receives these bytes and writes them as a .png file.
        DataRepresentation(exportedContentType: .png) { uiImage in
            // pngData() returns nil only if the image has no valid CGImage backing —
            // practically impossible here since we construct the image from a CGImage above.
            guard let pngData = uiImage.pngData() else { throw CocoaError(.fileWriteUnknown) }
            return pngData
        }
    }
}
