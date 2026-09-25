import SwiftUI

struct CompanionProductTile<Artwork: View>: View {
    let name: String
    let status: String
    let symbol: String
    let selected: Bool
    let accent: Color
    let surface: Color
    @ViewBuilder let artwork: () -> Artwork

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            artwork().frame(width: 44, height: 44)
                .frame(maxWidth: .infinity).padding(.vertical, 4)
            // Both lines reserve two rows, so a status that wraps ("250 hours of
            // work") no longer pushes its tile out of line with its row.
            Text(name).font(.caption.weight(.semibold))
                .lineLimit(2, reservesSpace: true)
            Label(status, systemImage: symbol)
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        .background(selected ? accent.opacity(0.15) : surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? accent.opacity(0.4) : .clear, lineWidth: 1))
    }
}
