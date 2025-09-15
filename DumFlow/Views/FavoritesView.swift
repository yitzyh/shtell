////
////  FavoritesView.swift
////  DumFlow
////
////  Created by Isaac Herskowitz on 7/18/24.
////
//
//import SwiftUI
//
//struct FavoritesGridView: View {
//    
//    @EnvironmentObject private var webBroswer: WebBrowser
//    
//    let webPages: [WebPage] = [
//        WebPage(urlString: "https://chatgpt.com"),
//        WebPage(urlString: "https://google.com"),
//        WebPage(urlString: "https://apple.com"),
//        WebPage(urlString: "https://microsoft.com"),
//        WebPage(urlString: "https://apnews.com"),
//        WebPage(urlString: "https://npr.org"),
//        WebPage(urlString: "https://app.com"),
//        WebPage(urlString: "https://nyt.com"),
//        WebPage(urlString: "https://whitehouse.gov"),
//        WebPage(urlString: "https://chatgpt.com"),
//        WebPage(urlString: "https://google.com"),
//        WebPage(urlString: "https://apple.com"),
//        WebPage(urlString: "https://microsoft.com"),
//        WebPage(urlString: "https://apnews.com"),
//        WebPage(urlString: "https://npr.org"),
//        WebPage(urlString: "https://app.com"),
//        WebPage(urlString: "https://nyt.com"),
//        WebPage(urlString: "https://whitehouse.gov"),
//        WebPage(urlString: "https://chatgpt.com"),
//        WebPage(urlString: "https://google.com"),
//        WebPage(urlString: "https://apple.com"),
//        WebPage(urlString: "https://microsoft.com"),
//        WebPage(urlString: "https://apnews.com"),
//        WebPage(urlString: "https://npr.org"),
//        WebPage(urlString: "https://app.com"),
//        WebPage(urlString: "https://nyt.com"),
//        WebPage(urlString: "https://whitehouse.gov"),
//        WebPage(urlString: "https://chatgpt.com"),
//        WebPage(urlString: "https://google.com"),
//        WebPage(urlString: "https://apple.com"),
//        WebPage(urlString: "https://microsoft.com"),
//        WebPage(urlString: "https://apnews.com"),
//        WebPage(urlString: "https://npr.org"),
//        WebPage(urlString: "https://app.com"),
//        WebPage(urlString: "https://nyt.com"),
//        WebPage(urlString: "https://whitehouse.gov")
//    ]
//    
//    // Define the grid layout with three columns
//    private let columns = [
//        GridItem(.flexible(), spacing: 10),
//        GridItem(.flexible(), spacing: 10),
//        GridItem(.flexible(), spacing: 10)
//    ]
//    
//    var body: some View {
//        ScrollView {
//            LazyVGrid(columns: columns, spacing: 10) {
//                ForEach(webPages, id: \.id) { webPage in
//                    VStack{
//                        webPageThumbnail(webPage: webPage)
//                        Text(webPage.urlString.shortURL())
//                            .font(.caption)
//                    }
//                    .onTapGesture {
//                        webBroswer.urlString = webPage.urlString
//                        webBroswer.isUserInitiatedNavigation = true
//                    }
//                }
//            }
//            .padding(.horizontal, 10)
//            .padding(.vertical, 10)
//        }
//        .background(.regularMaterial)
//    }
//}
//
//#Preview{
//    FavoritesGridView()
//}
