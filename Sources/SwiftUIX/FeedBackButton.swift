//
//  FeedBackButton.swift
//  APNs Helper
//
//  Created by joker on 2024/4/29.
//

import SwiftUI
import Utils

public struct FeedBackButton: View {
    
    public let email: String
    
    public let subject: String?
    
    public let content: String?
    
    public let larkChatLink: String?
    
    @State private var isPresented: Bool = false
    
    
    public init(
        email: String,
        subject: String? = bugReportSubject,
        content: String? = bugReportContentTemplate,
        larkChatLink: String? = defaultLarkFeedbackGroupLink
    ) {
        self.email = email
        self.subject = subject
        self.content = content
        self.larkChatLink = larkChatLink
    }
    
    var mailToURL: URL? {
        var mailTo = "mailto:\(email)"
        if let subject {
            mailTo.append("?subject=\(subject)")
        }
        if let content {
            mailTo.append("&body=\(content)")
        }
        guard let ret = mailTo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: ret)
    }
    
    var larkChatLinkURL: URL? {
        guard let larkChatLink
        else {
            return nil
        }
        return URL(string: larkChatLink)
    }
    
    public var body: some View {
        
        Button {
            isPresented.toggle()
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("FeedBack To Author")
                        .font(.body)
                        .bold()
                }
                
                Text("FeedBack To Author")
                    .font(.body)
                    .bold()
                
                Image(systemName: "paperplane.fill")
                
            }
            .padding(4)
        }
        .disabled(isPresented)
        .popover(isPresented: $isPresented, attachmentAnchor: .point(.init(x: 0.5, y: -0.5))) {
            VStack(alignment: .leading, spacing: 15) {
                if let larkChatLinkURL {
                    Link(destination: larkChatLinkURL, label: {
                        Label("Lark Chat", systemImage: "message")
                    })
                }
                if let mailToURL {
                    Link(destination: mailToURL, label: {
                        Label("Send Email", systemImage: "envelope")
                    })
                }
            }
            .padding()
        }
        
    }
}

extension FeedBackButton {
    
    public static let defaultLarkFeedbackGroupLink = "https://applink.feishu.cn/client/chat/chatter/add_by_link?link_token=322i0419-57cf-4ab3-bcff-966c31f71d2e"
    
    public static let bugReportSubject: String = {
        
        var subject = "Bug Report"
        
        if let bundleName = Bundle.main.infoDictionary?["CFBundleName"] {
            subject.append(" - \(bundleName)")
        }
        
        if let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] {
            subject.append(" \(shortVersion)")
        }
        
        if let version = Bundle.main.infoDictionary?["CFBundleVersion"] {
            subject.append("(\(version))")
        }
        
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        subject.append(" - \(Platform.os) \(osVersion)")
        
        return subject
    }()
    
    public static let bugReportContentTemplate = """
    🙏 Please provide the following information as much as possible:
    
        🐛 Bug Description:
    
                    [Detailed description of the issue encountered]
    
        🧵 Steps to Reproduce:
    
                    [List the specific steps to trigger the bug]
    
        😁 Expected Behavior:
    
                    [Describe the expected normal behavior]
    
        🤬 Actual Behavior:
    
                    [Describe the actual incorrect behavior]
    
        🏞️ Screenshots/Video if applicable:
    
                    [Include relevant screenshots or video if needed]
    
        🤩 Additional Information:
    
                    [Any other relevant details]]
    
    
    💖 Thank for your feedback! 👍🏻
    
    👨🏻‍💻 I will fix this problem as soon as possible.
    
    """
}

#Preview("Full Mode") {
    FeedBackButton(email: "824219521@qq.com")
        .buttonStyle(.borderedProminent)
        .padding()
}

#Preview("Text Only") {
    FeedBackButton(email: "824219521@qq.com")
        .frame(width: 154)
        .buttonStyle(.borderedProminent)
        .padding()
}

#Preview("Image Only") {
    FeedBackButton(email: "824219521@qq.com")
        .frame(width: 50)
        .buttonStyle(.borderedProminent)
        .padding()
}
