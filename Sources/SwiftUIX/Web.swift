//
//  Web.swift
//  OrzMC
//
//  Created by joker on 5/3/24.
//

import SwiftUI
import WebView

public struct Web: View {
    
    public let url: URL
    
    @StateObject var webViewStore = WebViewStore()
    
    @Environment(\.openURL) private var openURL
    
    public var body: some View {
        WebView(webView: webViewStore.webView)
            .navigationTitle(webViewStore.title ?? "")
            .toolbar {
                ToolbarItem {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .imageScale(.large)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!webViewStore.canGoBack)
                }
                ToolbarItem {
                    Button(action: goForward) {
                        Image(systemName: "chevron.right")
                            .imageScale(.large)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    }
                    .disabled(!webViewStore.canGoForward)
                }
                ToolbarItem {
                    Button(action: openWithBrowser, label: {
                        Image(systemName: "safari")
                            .imageScale(.large)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    })
                }
            }
            .onAppear {
                self.webViewStore.webView.load(URLRequest(url: url))
            }
    }
    
    func goBack() {
        webViewStore.webView.goBack()
    }
    
    func goForward() {
        webViewStore.webView.goForward()
    }
    
    func openWithBrowser() {
        openURL(url)
    }
}

#Preview {
    Web(url: URL(string: "https://www.baidu.com")!)
}
