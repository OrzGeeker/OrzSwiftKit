//
//  SwiftUIView.swift
//  OrzSwiftKit
//
//  Created by joker on 9/6/24.
//

import SwiftUI

struct BuyMeCoffeeButton<PopoverContent>: View where PopoverContent: View {
    
    let content: PopoverContent
    
    @State private var isPresented: Bool = false
    
    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Sponsor", systemImage: "heart")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.pink)
                .fontWeight(.semibold)
                .padding([.top, .bottom], 2)
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $isPresented, attachmentAnchor: .point(.init(x: 0.5, y: -0.5))) {
            content
        }
    }
}

#Preview {
    BuyMeCoffeeButton(content: Rectangle().frame(width: 240, height: 240).backgroundStyle(.white))
        .padding()
}
