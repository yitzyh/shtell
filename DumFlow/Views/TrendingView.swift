import SwiftData
import SwiftUI
import UIKit
import WebKit
import SafariServices


struct TrendingView: View {
        
    @Environment(\.presentationMode) var presentationMode
//    @Environment(\.modelContext) var modelContext
    @Environment(\.openURL) var openLink

    @State private var trendingWebView = TrendingWebView()
    
    @State private var isReaderMode = false
    
    @State var isShowingComments = false
        
    @State private var index = 0
        
    @State private var webPages: [WebPage]
    
    @State private var currentWebPage: WebPage?
    
    @State private var urlStrings: [String]
    
    @State var isSaved = false
    
    @State private var isShowingSafariView = false
    
    @State private var urlToOpen: URL? = nil
    
    init(webPages: [WebPage]) {
        self.webPages = webPages
        urlStrings = webPages.map {$0.urlString}
    }
    
    @State private var commentCount = 0
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        
        NavigationStack{
            trendingWebView
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            dragOffset = gesture.translation
                        }
                        .onEnded { gesture in
                            if gesture.translation.width < -100 {
                                print("Swiped left")
                                leftTap()
                            } else if gesture.translation.width > 100 {
                                print("Swiped right")
                                rightTap()
                            }
                            dragOffset = .zero
                        }
                )
            
            .onAppear(){
                fetchCommentsCount()
                if !urlStrings.isEmpty {
                    trendingWebView.loadURL(urlString: urlStrings[0])
                }
                if !webPages.isEmpty {
                    currentWebPage = webPages[0]
                }
            }
            .safeAreaInset(edge: .bottom) {
                ZStack{
                                
                    Button{
                        isShowingComments.toggle()
                    } label:{
                        Text(commentCount > 0 ? "\(commentCount ) Comments" : "Comments")
                            .font(.headline.bold())
                            .foregroundColor(.orange)
                            .contentTransition(.numericText(value: Double(commentCount)))
                    }
    //                .sheet(isPresented: $isShowingComments){
    //                    CommentView(/*urlString: trendingWebView.getCurrentURL(), modelContext: modelContext*/urlString: currentWebPage?.urlString)
    //                        .presentationDetents([.fraction(0.75), .large])
    //                        .presentationContentInteraction(.scrolls)
    //                }
                                    
                    HStack{
                        Spacer()
                        Button{
//                            currentWebPage?.isSaved.toggle()
    //                        isSaved.toggle()
                        } label: {
                            Image(systemName: /*(currentWebPage?.isSaved ?? false) ? "star.fill" :*/ "star")
                                .resizable()
                                .frame(width: 17, height: 20)
                                .foregroundColor(.orange)
                            
                        }
                        .padding(.trailing, 30)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isReaderMode ?  "Hide Reader \(Image(systemName: "newspaper.fill"))" : "Show Reader \(Image(systemName: "newspaper"))"){
                        isReaderMode.toggle()
                        if isReaderMode {
                            trendingWebView.isReaderMode(true)
                        } else {
                            trendingWebView.isReaderMode(false)
                        }
                    }
                }
                ToolbarItem{
                    Button{
                        urlToOpen = URL(string: currentWebPage?.urlString ?? "https://www.apple.com")
                        isShowingSafariView = true
                    } label: {
                        Image(systemName: "safari")
                    }
                    .sheet(isPresented: $isShowingSafariView) {
                        if let url = urlToOpen {
                            SafariView(url: url)
                        }
                    }
                }
            }
        }
            
//        .navigationBarItems(leading: Button("Back"){self.presentationMode.wrappedValue.dismiss()})
    
    }
    
    func updateCurrentPage(index: Int) {
        self.index = index
        fetchCommentsCount()
        currentWebPage = webPages[index]
        trendingWebView.loadURL(urlString: urlStrings[index])
        applyReaderModeIfNeeded()
    }

    func applyReaderModeIfNeeded() {
        if isReaderMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                trendingWebView.isReaderMode(true)
            }
        }
    }
    
    func leftTap() {
        let newIndex = (index + 1) % urlStrings.count
        updateCurrentPage(index: newIndex)
    }

    func rightTap() {
        let newIndex = (index - 1 + urlStrings.count) % urlStrings.count
        updateCurrentPage(index: newIndex)
    }
    
    func fetchCommentsCount(){

//        let descriptor = FetchDescriptor<WebPage>(predicate: #Predicate<WebPage> { webPage in webPage.urlString == urlStrings[index] })
//                
//        if let webPage = try? modelContext.fetch(descriptor).first {
//            withAnimation{
//                commentCount = webPage.comments?.count ?? 0
//            }
//        } else {
//            withAnimation{
//                commentCount = 0
//            }
//        }
        print("fetchCommentsCount()")
    }
}

struct TapOverlayView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap))
        view.addGestureRecognizer(tapGesture)
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        @objc func handleTap(gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            if location.x < gesture.view!.bounds.width / 2 {
                print("Tapped left")
            } else {
                print("Tapped right")
            }
        }
    }
}


//#Preview {
//    
//    let webPages: [WebPage] = [
//        WebPage(urlString: "https://apnews.com/article/hunter-biden-gun-trial-federal-charges-delaware-5dd8a9380235c6360a1ddb691ef24a06"),
//        WebPage(urlString: "https://app.com")
//    ]
//    TrendingView(webPages: webPages)
//}
