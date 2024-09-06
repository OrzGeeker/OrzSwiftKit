//
//  SwiftUIView.swift
//  OrzSwiftKit
//
//  Created by joker on 9/6/24.
//

import SwiftUI

public struct BuyMeCoffeeButton<PopoverContent>: View where PopoverContent: View {
    
    public let content: PopoverContent
    
    public init(content: PopoverContent) {
        self.content = content
    }
    
    @State private var isPresented: Bool = false
    
    public var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Sponsor", systemImage: isPresented ? "heart.fill" : "heart")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.pink)
                .fontWeight(.semibold)
                .padding(6)
        }
        .disabled(isPresented)
        .buttonStyle(.borderedProminent)
        .tint(.gray)
        .popover(isPresented: $isPresented, attachmentAnchor: .point(.init(x: 0.5, y: -0.5))) {
            content
        }
    }
}

#Preview {
    BuyMeCoffeeButton(content: Rectangle().frame(width: 240, height: 240).backgroundStyle(.white))
        .padding()
}
