import SwiftUI

struct StartupSearchField: View {
    @Binding var query: String
    var onSearch: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.black.opacity(0.55))
                .accessibilityHidden(true)

            TextField("", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 22))
                .foregroundStyle(.black)
                .focused($isFocused)
                .accessibilityLabel("What are you shopping for?")
                .onSubmit(finishEditing)

            Button("Start search", systemImage: "chevron.right", action: finishEditing)
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black.opacity(0.55))
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint("Open the product view")
        }
        .padding(.leading, 26)
        .padding(.trailing, 26)
        .frame(height: 84)
        .background(.white, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.black.opacity(isFocused ? 0.22 : 0), lineWidth: 1.5)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: 600)
    }

    private func finishEditing() {
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isFocused = false
        onSearch()
    }
}
