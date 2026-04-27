//
//  BulkMenuImportView.swift
//  Pour Rice
//
//  Bulk menu import from menu images using DocuPipe AI extraction.
//  Flow: Pick image → AI extracts items → Review list → Import selected items.
//
//  FLUTTER/ANDROID EQUIVALENT:
//  lib/pages/store_page.dart BulkMenuImportModal — same three-step flow with
//  file picker, review table, and batch createMenuItem calls.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - BulkMenuImportView

/// Three-step bulk menu importer for restaurant owners.
///
/// Step 1 (Pick): Image picker (JPG, PNG, GIF, or WebP)
/// Step 2 (Review): AI-extracted items shown in an editable list — user can
///   deselect items they don't want and correct names/prices inline
/// Step 3 (Done): Success summary with item count
struct BulkMenuImportView: View {

    let restaurantId: String
    /// Called after items are successfully imported so the parent can refresh.
    let onImported: () -> Void

    // MARK: - Environment & State

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    private enum Step { case pick, review, done }

    @State private var step: Step = .pick
    @State private var extractedItems: [ExtractedMenuItem] = []
    @State private var isExtracting = false
    @State private var extractionError: String?
    @State private var isImporting = false
    @State private var importedCount = 0
    @State private var showFilePicker = false
    @State private var showManualEntry = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            switch step {
            case .pick:
                pickStep
            case .review:
                reviewStep
            case .done:
                doneStep
            }
        }
    }

    // MARK: - Step 1: Pick

    private var pickStep: some View {
        VStack(spacing: 28) {
            Spacer()

            // Illustration
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 56))
                    .foregroundStyle(.purple)
            }

            VStack(spacing: 10) {
                Text("bulk_import_title")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("bulk_import_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Supported image formats
            HStack(spacing: 20) {
                FormatChip(icon: "photo.fill", label: "JPG")
                FormatChip(icon: "photo", label: "PNG")
                FormatChip(icon: "photo.on.rectangle", label: "WEBP")
            }

            Text("bulk_import_image_only_note")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let errMsg = extractionError {
                Text(errMsg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    showFilePicker = true
                } label: {
                    HStack(spacing: 8) {
                        if isExtracting {
                            ProgressView().tint(.white)
                            Text("bulk_import_extracting")
                                .fontWeight(.semibold)
                        } else {
                            Image(systemName: "photo.badge.plus")
                            Text("bulk_import_pick_file")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isExtracting)

                Button {
                    showManualEntry = true
                } label: {
                    Label("bulk_import_add_manually", systemImage: "square.and.pencil")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isExtracting)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .padding(.top, 8)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("bulk_import_nav_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") { dismiss() }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: allowedImageTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFilePick(result)
        }
        .sheet(isPresented: $showManualEntry) {
            ManualMenuItemSheet(restaurantId: restaurantId) {
                onImported()
            }
        }
    }

    // MARK: - Step 2: Review

    private var reviewStep: some View {
        Group {
            if extractedItems.isEmpty {
                // Edge case: extraction returned no items
                ContentUnavailableView {
                    Label("bulk_import_no_items", systemImage: "questionmark.circle")
                } description: {
                    Text("bulk_import_no_items_description")
                } actions: {
                    Button("bulk_import_try_again") {
                        step = .pick
                        extractionError = nil
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                List {
                    Section {
                        ForEach($extractedItems) { $item in
                            ExtractedItemRow(item: $item)
                        }
                    } header: {
                        Text("bulk_import_review_header \(selectedCount)")
                    } footer: {
                        Text("bulk_import_review_footer")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("bulk_import_review_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await importSelected() }
                } label: {
                    if isImporting {
                        ProgressView()
                    } else {
                        Text("bulk_import_import_count \(selectedCount)")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(selectedCount == 0 || isImporting)
            }
        }
    }

    // MARK: - Step 3: Done

    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 10) {
                Text("bulk_import_done_title")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("bulk_import_done_subtitle \(importedCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                onImported()
                dismiss()
            } label: {
                Text("done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .padding()
        .navigationTitle("bulk_import_nav_title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed

    private var selectedCount: Int {
        extractedItems.filter(\.isSelected).count
    }

    private var allowedImageTypes: [UTType] {
        var types: [UTType] = [.jpeg, .png, .gif]
        if let webPType = UTType(filenameExtension: "webp") {
            types.append(webPType)
        }
        return types
    }

    // MARK: - Actions

    private func handleFilePick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            extractionError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            guard isSupportedImage(url) else {
                extractionError = String(localized: "bulk_import_images_only_error", bundle: L10n.bundle)
                return
            }
            Task { await extractFromURL(url) }
        }
    }

    private func extractFromURL(_ url: URL) async {
        isExtracting = true
        extractionError = nil

        // Access security-scoped resource for files picked from Files app.
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        do {
            let fileData = try Data(contentsOf: url)
            guard let mimeType = mimeType(for: url) else {
                extractionError = String(localized: "bulk_import_images_only_error", bundle: L10n.bundle)
                isExtracting = false
                return
            }
            let fileName = url.lastPathComponent

            extractedItems = try await services.docuPipeService.extractMenu(
                fileData: fileData,
                mimeType: mimeType,
                fileName: fileName
            )
            step = .review
        } catch {
            extractionError = error.localizedDescription
        }

        isExtracting = false
    }

    private func importSelected() async {
        isImporting = true
        let selected = extractedItems.filter(\.isSelected)
        var count = 0

        for item in selected {
            guard !item.nameEN.isEmpty else { continue }
            let request = CreateMenuItemRequest(
                restaurantId: restaurantId,
                nameEN: item.nameEN,
                nameTC: item.nameTC ?? item.nameEN,
                descriptionEN: item.descriptionEN,
                descriptionTC: item.descriptionTC,
                price: item.price,
                image: nil
            )
            do {
                try await services.storeService.createMenuItem(request)
                count += 1
            } catch {
                print("⚠️ BulkMenuImportView: Failed to import '\(item.nameEN)': \(error)")
            }
        }

        importedCount = count
        isImporting = false
        step = .done
    }

    // MARK: - Helpers

    private func isSupportedImage(_ url: URL) -> Bool {
        mimeType(for: url) != nil
    }

    private func mimeType(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png":  return "image/png"
        case "gif":  return "image/gif"
        case "webp": return "image/webp"
        default:     return nil
        }
    }
}

// MARK: - Manual Menu Item Sheet

private struct ManualMenuItemSheet: View {
    let restaurantId: String
    let onSaved: () -> Void

    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var nameEN = ""
    @State private var nameTC = ""
    @State private var descEN = ""
    @State private var descTC = ""
    @State private var price = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("store_menu_name") {
                    TextField("English", text: $nameEN)
                    TextField("繁體中文", text: $nameTC)
                }

                Section("store_menu_description") {
                    TextField("English", text: $descEN, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("繁體中文", text: $descTC, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("store_menu_price") {
                    TextField("HK$", text: $price)
                        .keyboardType(.decimalPad)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("store_menu_add")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(nameEN.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("bulk_import_manual_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil

        let request = CreateMenuItemRequest(
            restaurantId: restaurantId,
            nameEN: nameEN,
            nameTC: nameTC.isEmpty ? nameEN : nameTC,
            descriptionEN: descEN.isEmpty ? nil : descEN,
            descriptionTC: descTC.isEmpty ? nil : descTC,
            price: Double(price),
            image: nil
        )

        do {
            try await services.storeService.createMenuItem(request)
            onSaved()
            dismiss()
        } catch {
            errorMessage = String(localized: "bulk_import_manual_save_failed", bundle: L10n.bundle)
        }

        isSubmitting = false
    }
}

// MARK: - Extracted Item Row

/// An editable row for a single extracted menu item.
/// Shows a checkbox for selection and inline name display.
private struct ExtractedItemRow: View {
    @Binding var item: ExtractedMenuItem

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isSelected ? Color.accentColor : .secondary)
                .font(.title3)
                .onTapGesture {
                    item.isSelected.toggle()
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.nameEN.isEmpty ? String(localized: "bulk_import_unnamed") : item.nameEN)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let nameTC = item.nameTC, !nameTC.isEmpty {
                    Text(nameTC)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let price = item.price, price > 0 {
                Text("HK$\(Int(price))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.accent)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            item.isSelected.toggle()
        }
        .opacity(item.isSelected ? 1 : 0.45)
    }
}

// MARK: - Format Chip

private struct FormatChip: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(width: 60, height: 60)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
