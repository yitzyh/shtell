////
////  DumFlowTests.swift
////  DumFlowTests
////
////  Created by Isaac Herskowitz on 4/24/25.
////
//
//import XCTest
//@testable import DumFlow
//
//final class DumFlowTests: XCTestCase {
//    
//    func testWebPageViewModelCanBeCreated() {
//        // This test just checks: "Can I create a WebPageViewModel without the app crashing?"
//        let authViewModel = AuthViewModel()
//        let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
//        
//        // If we get here without crashing, the test passes ✅
//        XCTAssertNotNil(webPageViewModel)
//    }
//    
//    func testStateStructsStartEmpty() {
//        // This test checks: "Are the new state structs empty when created?"
//        let authViewModel = AuthViewModel()
//        let webPageViewModel = WebPageViewModel(authViewModel: authViewModel)
//        
//        // Check if arrays start empty
//        XCTAssertTrue(webPageViewModel.contentState.webPages.isEmpty)
//        XCTAssertTrue(webPageViewModel.contentState.comments.isEmpty)
//        XCTAssertTrue(webPageViewModel.uiState.likedWebPages.isEmpty)
//    }
//}
