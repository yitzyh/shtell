//
//  CommpressedParentCommentRowView.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 7/22/24.
//

import SwiftUI

struct CommpressedParentCommentRowView: View {
    
    @State private var foregroundColor: Color = .primary
    
    var body: some View {
        HStack{
            ZStack{
                Rectangle()
                    .frame(width: 1, height: .infinity)
                ZStack{
                    Image(systemName: "circle.fill")
                        .font(.body)
                        .foregroundColor(.green)
                        .foregroundColor(.red)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 19, height: 19)
                        )
                    Image(systemName: "circle.fill")
                        .font(.body)
                        .foregroundColor(.red)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 19, height: 19)
                        )
                        .offset(y: 5)
                    Image(systemName: "s.circle.fill")
                        .font(.body)
                        .foregroundColor(.blue)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 19, height: 19)
                        )
                        .offset(y: 10)
                }
            }
            .frame(width: 25)
            .border(.red)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .border(.red)
    }
}

#Preview {
    CommpressedParentCommentRowView()
}
