//
//  ImageUploadService.swift
//  Pour Rice
//
//  Handles chat image uploads with live progress reporting and cleanup
//  Uses multipart/form-data via URLSession — same pattern as StoreService.uploadRestaurantImage
//
//  ============================================================================
//  FOR FLUTTER/ANDROID DEVELOPERS:
//  FLUTTER EQUIVALENT: dio package with onSendProgress callback
//
//  KEY IOS DIFFERENCES:
//  - URLSession.uploadTask = Dio.post with onSendProgress
//  - KVO observe(\.fractionCompleted) = StreamController progress callback
//  - withCheckedThrowingContinuation = Completer<T>
//  ============================================================================
//

import Foundation

/// Service responsible for uploading and deleting chat images via the backend.
/// Upload progress is reported via a callback on the main actor.
@MainActor
final class ImageUploadService {

    // MARK: - Upload

    /// Uploads image data as multipart/form-data to the Chat folder on the backend.
    /// - Parameters:
    ///   - data: JPEG-compressed image bytes
    ///   - mimeType: e.g. "image/jpeg"
    ///   - filename: e.g. "photo.jpg"
    ///   - onProgress: Called on the main actor with 0.0–1.0 as upload progresses
    /// - Returns: Tuple of the public imageUrl and the server-side filePath (for deletion)
    func uploadChatImage(
        _ data: Data,
        mimeType: String,
        filename: String,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> (imageUrl: String, filePath: String) {

        let urlString = "\(Constants.API.baseURL)/API/Images/upload?folder=Chat"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: Constants.API.Headers.contentType
        )
        request.setValue(Constants.API.passcode, forHTTPHeaderField: Constants.API.Headers.apiPasscode)

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        // Use uploadTask so we can observe progress via KVO
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.uploadTask(with: request, from: body) { responseData, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 500
                    continuation.resume(throwing: APIError.serverError(code))
                    return
                }

                guard let responseData = responseData else {
                    continuation.resume(throwing: APIError.decodingError)
                    return
                }

                struct UploadResponse: Decodable {
                    let imageUrl: String
                    let fileName: String?
                }

                do {
                    let decoded = try JSONDecoder().decode(UploadResponse.self, from: responseData)
                    // filePath is the fileName returned by the server, used for deletion
                    let filePath = decoded.fileName ?? decoded.imageUrl
                    continuation.resume(returning: (imageUrl: decoded.imageUrl, filePath: filePath))
                } catch {
                    continuation.resume(throwing: APIError.decodingError)
                }
            }

            // Observe upload progress via KVO and forward to the caller on the main actor
            let observation = task.progress.observe(\.fractionCompleted, options: [.new]) { progress, _ in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    onProgress(fraction)
                }
            }

            // Keep the observation alive for the task duration
            // Swift's KVO observation is automatically invalidated when the observer is deallocated.
            // We store it as an associated object on the task to tie its lifetime to the upload.
            objc_setAssociatedObject(task, &AssociatedKeys.progressObservation, observation, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            task.resume()
            print("📸 ImageUploadService: Uploading \(filename) (\(data.count) bytes)")
        }
    }

    // MARK: - Delete

    /// Deletes a previously uploaded image by its server-side file path.
    /// Errors are silently logged — deletion failure must never block UX.
    func deleteImage(filePath: String) async {
        let urlString = "\(Constants.API.baseURL)/API/Images/delete"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: Constants.API.Headers.contentType)
        request.setValue(Constants.API.passcode, forHTTPHeaderField: Constants.API.Headers.apiPasscode)

        struct DeleteBody: Encodable {
            let filePath: String
        }

        do {
            request.httpBody = try JSONEncoder().encode(DeleteBody(filePath: filePath))
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("⚠️ ImageUploadService: Delete returned \(http.statusCode) for \(filePath)")
            } else {
                print("🗑️ ImageUploadService: Deleted \(filePath)")
            }
        } catch {
            print("⚠️ ImageUploadService: Delete failed for \(filePath): \(error.localizedDescription)")
        }
    }
}

// MARK: - Private

/// Key used to store KVO observation as an associated object on the URLSessionTask
private enum AssociatedKeys {
    static var progressObservation: UInt8 = 0
}
