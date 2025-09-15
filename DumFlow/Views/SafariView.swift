//
//  SafariView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 12/2/24.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let readerMode: Bool
    
    init(url: URL, readerMode: Bool = false) {
        self.url = url
        self.readerMode = readerMode
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = readerMode
        let safariViewController = SFSafariViewController(url: url, configuration: config)
        safariViewController.modalPresentationStyle = .pageSheet
        return safariViewController
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

//struct SafariView: UIViewControllerRepresentable {
//    let urlString: String
//
//    init(urlString: String) {
//        self.urlString = urlString
//    }
//
//    func makeUIViewController(context: Context) -> SFSafariViewController {
//        guard let url = URL(string: urlString) else {
//            return SFSafariViewController(url: URL(string: "about:blank")!)
//        }
//        let config = SFSafariViewController.Configuration()
//        // no reader-mode toggling here
//        let safariViewController = SFSafariViewController(url: url, configuration: config)
//        safariViewController.modalPresentationStyle = .pageSheet
//        return safariViewController
//    }
//
//    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
//}

