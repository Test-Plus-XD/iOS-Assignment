//
//  SafariView.swift
//  Pour Rice
//
//  Wraps SFSafariViewController as a SwiftUI-compatible view.
//  Used for Stripe Checkout flows and other external web content that
//  needs the full Safari experience (cookies, autofill, Apple Pay).
//
//  USAGE:
//    .sheet(isPresented: $showSafari) {
//        SafariView(url: stripeCheckoutURL)
//            .ignoresSafeArea()
//    }
//

import SwiftUI
import SafariServices

/// UIViewControllerRepresentable wrapper for SFSafariViewController.
/// Presents a full Safari browsing experience inside the app.
struct SafariView: UIViewControllerRepresentable {

    /// The URL to open in Safari.
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed — SFSafariViewController manages its own lifecycle.
    }
}
