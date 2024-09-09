//
//  SwiftUIView.swift
//  OrzSwiftKit
//
//  Created by joker on 9/6/24.
//

import SwiftUI

public struct BuyMeCoffeeButton<PopoverContent>: View where PopoverContent: View {
    
    public let content: PopoverContent
    
    public let attachmentAnchor: PopoverAttachmentAnchor
    
    public init(
        content: PopoverContent,
        attachmentAnchor: PopoverAttachmentAnchor = .point(.init(x: 0.5, y: -0.5))
    ) {
        self.content = content
        self.attachmentAnchor = attachmentAnchor
    }
    
    @State private var isPresented: Bool = false
    
    public var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            
            ViewThatFits(in: .horizontal) {
                Label("Sponsor", systemImage: isPresented ? "heart.fill" : "heart")
                    .labelStyle(.titleAndIcon)
                
                Text("Sponsor")
                
                Image(systemName: isPresented ? "heart.fill" : "heart")
            }
            .foregroundStyle(.pink)
            .fontWeight(.semibold)
            .padding(4)
            
        }
        .disabled(isPresented)
        .popover(isPresented: $isPresented, attachmentAnchor: attachmentAnchor) {
            content
        }
    }
}

#Preview("Full Mode") {
    BuyMeCoffeeButton(
        content: Rectangle().frame(width: 240, height: 240)
            .foregroundStyle(.clear)
    )
    .padding()
}

#Preview("Text Only") {
    BuyMeCoffeeButton(
        content: Rectangle().frame(width: 240, height: 240)
            .foregroundStyle(.clear),
        attachmentAnchor: .point(.init(x: 1, y: -0.5))
    )
    .frame(width: 100)
    .padding()
}

#Preview("Image Only") {
    BuyMeCoffeeButton(
        content: Rectangle().frame(width: 240, height: 240)
            .foregroundStyle(.clear),
        attachmentAnchor: .point(.init(x: 0, y: -0.5))
    )
    .frame(width: 50)
    .padding()
}
