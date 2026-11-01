#if canImport(SwiftUI)
import SwiftUI

/// A lazily constructed collection of console rows. The caller owns scrolling,
/// selection, styling and the meaning of each row.
public struct ConsoleRows<Data: RandomAccessCollection, ID: Hashable, Row: View, Empty: View>: View {
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let spacing: CGFloat
    private let row: (Data.Element) -> Row
    private let empty: () -> Empty

    public init(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        spacing: CGFloat = 0,
        @ViewBuilder row: @escaping (Data.Element) -> Row,
        @ViewBuilder empty: @escaping () -> Empty
    ) {
        self.data = data
        self.id = id
        self.spacing = spacing
        self.row = row
        self.empty = empty
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: spacing) {
            if data.isEmpty {
                empty()
            } else {
                ForEach(data, id: id, content: row)
            }
        }
    }
}
#endif
