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

    public init(
        email: String,
        subject: String = FeedBackButton.bugReportSubject,
        content: String = FeedBackButton.bugReportContentTemplate
    ) {
        self.email = email
        self.subject = subject
        self.content = content
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

    public var body: some View {
        Link(destination: mailToURL!, label: {
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
        })
    }
}

extension FeedBackButton {

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
        .frame(width: 150)
        .buttonStyle(.borderedProminent)
        .padding()
}

#Preview("Image Only") {
    FeedBackButton(email: "824219521@qq.com")
        .frame(width: 50)
        .buttonStyle(.borderedProminent)
        .padding()
}
