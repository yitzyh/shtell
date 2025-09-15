import SwiftUI

struct TopToolbarTestView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var sortOrder: TrendPageView.SortOrder = .dateCreated
    
    var body: some View {
        VStack {
            // Mock toolbar buttons in main view
            HStack {
                Text("Total: 25")
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Spacer()
                
                // Sort menu button
                Menu {
                    Picker("Sort Order", selection: $sortOrder) {
                        ForEach(TrendPageView.SortOrder.allCases, id: \.self) { order in
                            Label(order.title, systemImage: order.iconName)
                                .tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    ZStack {
                        Circle()
                            .fill(.thinMaterial)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                .foregroundColor(colorScheme == .dark ? .white : .black)
                
                // TrendingView button
                Button {
                    // Mock action
                } label: {
                    ZStack {
                        Circle()
                            .fill(.thinMaterial)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "newspaper")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                .foregroundColor(colorScheme == .dark ? .white : .black)
                
                // Refresh button
                Button {
                    // Mock action
                } label: {
                    ZStack {
                        Circle()
                            .fill(.thinMaterial)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
                .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .padding()
            .background(colorScheme == .dark ? Color(white: 0.07) : .white)
            
            Spacer()
            
            Text("This is a test view to play with toolbar overlays")
                .padding()
            
            Spacer()
        }
    }
}

#Preview {
    TopToolbarTestView()
}