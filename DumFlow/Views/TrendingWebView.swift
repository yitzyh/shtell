import Foundation
import SwiftData
import SwiftUI
import UIKit
import WebKit
import SafariServices
//import CoreData

struct TrendingWebView: UIViewRepresentable {
    
    
    let trendingWebView = WKWebView()
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: TrendingWebView

        init(_ parent: TrendingWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        }
    }
    
    
    func makeCoordinator() -> Coordinator {
        print("makeCoordinator")
        return Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        trendingWebView.allowsBackForwardNavigationGestures = true
        trendingWebView.navigationDelegate = context.coordinator

        print("trending: makeUIView")
        return trendingWebView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("trending: updateUIView")
    }
     
    func loadURL(urlString: String) {
        if let url = URL(string: urlString){
            print("if let url = URL(string: \(urlString))")
            trendingWebView.load(URLRequest(url: url))
        }
    }
    
    func getCurrentURL() -> String{
        String(describing: trendingWebView.url ?? URL(string: "about:blank")!)
    }
    
    func isReaderMode(_ enabled: Bool) {
        
        let readerModeScript: String
        
        if enabled{
            readerModeScript = """
                // Function to extract and display text content only
                function extractTextContent() {
                    // Remove unwanted elements
                    document.querySelectorAll('header, nav, aside, footer, .ad-banner, .widget, .sidebar, .related, .social-buttons, .popup, .modal, .overlay, .newsletter-signup, .subscribe').forEach(el => el.remove());


                    // Extract headline and paragraphs
                    let headline = '';
                    let headlineElement = document.querySelector('h1') || document.querySelector('h2') || document.querySelector('h3');
                    if (headlineElement) {
                        headline = '<h1 style="font-size: 24px; font-weight: bold; margin-bottom: 20px;">' + headlineElement.innerText + '</h1>';
                    }
                    
                    let paragraphs = document.querySelectorAll('p');
                    let bodyContent = headline;
                    paragraphs.forEach(p => {
                        bodyContent += '<p style="margin-bottom: 20px;">' + p.innerText + '</p>';
                    });

                    // Replace body content with formatted headline and paragraphs
                    document.body.innerHTML = bodyContent;
                    
                    // Apply basic styles to main content
                    document.body.style.margin = "0";
                    document.body.style.padding = "20px";
                    document.body.style.fontSize = "18px";
                    document.body.style.lineHeight = "1.6";
                    document.body.style.backgroundColor = "#000000";
                    document.body.style.color = "#ffffff";
                    document.body.style.fontFamily = 'Arial, sans-serif';
                }
                extractTextContent();
            """
        } else {
            readerModeScript = """
                location.reload();
            """
        }
        trendingWebView.evaluateJavaScript(readerModeScript, completionHandler: nil)
    }
}
