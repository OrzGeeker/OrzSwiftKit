# OrzSwiftKit

The Basic Utils for OrzGeeker
# ConsoleCore / ConsoleUI

`ConsoleCore` contains the reusable `ConsoleFollowState` state machine for a log
viewer. `ConsoleUI` provides `ConsoleRows`, a lazy row container with an empty
state; the application owns its data source, scrolling policy, row style, and
command handling. Both products are independent of Minecraft and networking.

The package declares macOS 13 and iOS 16 as minimum Apple platform versions;
`ConsoleUI` is available where SwiftUI can be imported. The manifest requires
Swift tools 6.0; the resolved dependency graph may require a newer toolchain.
These APIs are currently pre-1.0: pin a tested revision or release, review API
changes when updating, and do not assume that following `main` is reproducible.

Add the `ConsoleUI` product to a target and supply stable IDs for retained rows:

```swift
import ConsoleUI
import Foundation
import SwiftUI

struct LogLine: Identifiable {
    let id: UUID
    let text: String
}

struct LogView: View {
    let lines: [LogLine]

    var body: some View {
        ScrollView {
            ConsoleRows(lines, id: \.id) { line in
                Text(line.text).font(.body.monospaced())
            } empty: {
                Text("No output")
            }
        }
    }
}
```

For follow/pause behavior, add the `ConsoleCore` product and keep a
`ConsoleFollowState` in the view's state. Call `appended(_:)` when lines arrive,
`userLeftBottom()` / `userReachedBottom()` for user scrolling, and
`requestFollow()` for an explicit return to the latest line. The hosting view
must perform scrolling itself when `shouldScrollToLatest` is true. Format
parsers, buffering limits, server connections and command execution belong to the
consumer; `ConsoleRows` does not implement them.
