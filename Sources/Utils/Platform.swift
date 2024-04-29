//
//  Platform.swift
//
//
//  Created by joker on 2022/1/4.
//

/// [Swift条件编译参考](https://docs.swift.org/swift-book/ReferenceManual/Statements.html#//apple_ref/doc/uid/TP40014097-CH33-ID538)

public enum Platform {
    case macOS
    case iOS
    case tvOS
    case watchOS
    case visionOS
    case linux
    case windows
    case unsupportedOS

    public static let os: Platform = {
#if os(macOS)
        return .macOS
#elseif os(iOS)
        return .iOS
#elseif os(tvOS)
        return .tvOS
#elseif os(watchOS)
        return .watchOS
#elseif os(visionOS)
        return .visionOS
#elseif os(Linux)
        return .linux
#elseif os(Windows)
        return .windows
#else
        return .unsupportedOS
#endif
    }()

    public enum Arch {
        case unknowned
        case i386
        case x86_64
        case arm
        case arm64
    }

    public static let arch: Arch = {
#if arch(x86_64)
        return .x86_64
#elseif arch(arm)
        return .arm
#elseif arch(arm64)
        return .arm64
#elseif arch(i386)
        return .i386
#else
        return .unknowned
#endif
    }()
}


