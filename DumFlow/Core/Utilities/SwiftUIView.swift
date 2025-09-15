//
//  SwiftUIView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/6/25.
//

import SwiftUI

struct SwiftUIView: View {
    @State private var dotOffset: [CGFloat] = [0, 0, 0]
    @State private var isAnimationEnabled: Bool = true
    
    var body: some View {
        ZStack{
            VStack {
                HStack {
                    Spacer()
                    Toggle("", isOn: $isAnimationEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .scaleEffect(0.8)
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                }
                Spacer()
            }
            
            VStack{
                // The S in the middle
                Text("S")
                    .font(.system(size: 500, design: .rounded))
                    .foregroundColor(.orange)
            }

            VStack(spacing: 150) {
                // Top three dots
                HStack(spacing: 30) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                            .offset(y: dotOffset[index])
                            .animation(
                                isAnimationEnabled ? 
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2) : 
                                Animation.easeInOut(duration: 0.3),
                                value: dotOffset[index]
                            )
                            .scaleEffect(2.8)
                    }
                }
//                .offset(x: 10)
                // Bottom three dots
                HStack(spacing: 30) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                            .offset(y: dotOffset[index])
                            .animation(
                                isAnimationEnabled ? 
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2) : 
                                Animation.easeInOut(duration: 0.3),
                                value: dotOffset[index]
                            )
                            .scaleEffect(2.8)
                    }
                }
//                .offset(x: -10)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if isAnimationEnabled {
                    for index in 0..<3 {
                        dotOffset[index] = -10
                    }
                }
            }
        }
        .onChange(of: isAnimationEnabled) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                if newValue {
                    for index in 0..<3 {
                        dotOffset[index] = -15
                    }
                } else {
                    for index in 0..<3 {
                        dotOffset[index] = 0
                    }
                }
            }
        }
    }
}

#Preview {
    SwiftUIView()
}
