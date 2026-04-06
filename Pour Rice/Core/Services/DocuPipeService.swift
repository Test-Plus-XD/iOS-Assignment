//
//  DocuPipeService.swift
//  Pour Rice
//
//  Service for extracting restaurant menu data from documents using DocuPipe AI.
//  Handles the multipart file upload to POST /API/DocuPipe/extract-menu and
//  returns structured menu items ready for bulk import.
//
//  FLUTTER/ANDROID EQUIVALENT:
//  lib/services/docupipe_service.dart — same multipart upload pattern using
//  http.MultipartRequest with the 'file' field.
//

import Foundation

// MARK: - Extracted Menu Item

/// A single menu item extracted by DocuPipe from an uploaded document.
/// The `id` field is a local UUID generated for SwiftUI list identification;
/// it is NOT sent to the API when items are saved.
struct ExtractedMenuItem: Identifiable {
    let id: UUID = UUID()
    var nameEN: String
    var nameTC: String?
    var descriptionEN: String?
    var descriptionTC: String?
    var price: Double?
    /// Whether this item is selected for import (user can deselect unwanted items)
    var isSelected: Bool = true
}

// MARK: - DocuPipe Service

/// Service for AI-powered menu extraction from PDF and image documents.
/// Calls POST /API/DocuPipe/extract-menu (no auth required).
@MainActor
final class DocuPipeService {

    // MARK: - Properties

    private let session: URLSession

    // MARK: - Initialisation

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Extract Menu

    /// Uploads a document to DocuPipe and returns extracted menu items.
    /// The endpoint handles polling internally and returns all items in one response.
    ///
    /// Processing typically takes 5–60 seconds depending on document complexity.
    ///
    /// - Parameters:
    ///   - fileData: Raw bytes of the document (PDF, JPG, PNG, etc.)
    ///   - mimeType: MIME type string (e.g. "application/pdf" or "image/jpeg")
    ///   - fileName: File name hint for DocuPipe (e.g. "menu.pdf")
    /// - Returns: Array of extracted menu items with bilingual names, descriptions and price.
    func extractMenu(fileData: Data, mimeType: String, fileName: String) async throws -> [ExtractedMenuItem] {
        print("📄 DocuPipeService: Uploading \(fileName) (\(fileData.count / 1024) KB) for menu extraction")

        // Build URL manually — this is a multipart request, not JSON,
        // so we bypass APIClient's JSON-centric buildRequest(for:) helper.
        guard let url = URL(string: Constants.API.baseURL + "/API/DocuPipe/extract-menu") else {
            throw APIError.invalidURL
        }

        let boundary = "PourRiceBoundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // DocuPipe processing can take up to 60 seconds on large documents.
        request.timeoutInterval = 120
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(
            Constants.API.passcode,
            forHTTPHeaderField: Constants.API.Headers.apiPasscode
        )

        // Build multipart body with the single required 'file' field.
        var body = Data()
        let crlf = "\r\n"
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(fileData)
        body.append("\(crlf)--\(boundary)--\(crlf)".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(DocuPipeExtractMenuResponse.self, from: data)

        print("✅ DocuPipeService: Extracted \(result.menuItems.count) menu items from \(fileName)")
        return result.menuItems.map { item in
            ExtractedMenuItem(
                nameEN: item.nameEN ?? "",
                nameTC: item.nameTC,
                descriptionEN: item.descriptionEN,
                descriptionTC: item.descriptionTC,
                price: item.price
            )
        }
    }
}

// MARK: - Private Response Types

/// Top-level wrapper for the extract-menu response.
private struct DocuPipeExtractMenuResponse: Decodable {
    let menuItems: [DocuPipeMenuItem]

    private enum CodingKeys: String, CodingKey {
        case menuItems = "menu_items"
    }
}

/// Raw API shape for a single extracted menu item.
private struct DocuPipeMenuItem: Decodable {
    let nameEN: String?
    let nameTC: String?
    let descriptionEN: String?
    let descriptionTC: String?
    let price: Double?

    private enum CodingKeys: String, CodingKey {
        case nameEN         = "Name_EN"
        case nameTC         = "Name_TC"
        case descriptionEN  = "Description_EN"
        case descriptionTC  = "Description_TC"
        case price
    }
}
