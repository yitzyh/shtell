import Foundation
import SwiftUI

extension UIScreen{
   @available(*, deprecated, message: "Use GeometryReader or view-based screen access instead")
   static var screenWidth: CGFloat {
       UIScreen.main.bounds.size.width
   }
   @available(*, deprecated, message: "Use GeometryReader or view-based screen access instead") 
   static var screenHeight: CGFloat {
       UIScreen.main.bounds.size.height
   }
   @available(*, deprecated, message: "Use GeometryReader or view-based screen access instead")
   static var screenSize: CGSize {
       UIScreen.main.bounds.size
   }
}
