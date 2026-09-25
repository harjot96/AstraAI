import SwiftUI

/// Renders model output: paragraphs with inline markdown (**bold**, *italic*) and "- " bullets.
struct ReadingText: View {
    let text: String
    var size: CGFloat = 17

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, para in
                if para.hasPrefix("- ") || para.hasPrefix("• ") {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("✦").font(Theme.mono(10)).foregroundStyle(Theme.gold)
                        inline(String(para.dropFirst(2)))
                    }
                } else {
                    inline(para)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var paragraphs: [String] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.hasPrefix("#") ? "**" + $0.trimmingCharacters(in: CharacterSet(charactersIn: "# ")) + "**" : $0 }
            .filter { !$0.isEmpty }
    }

    private func inline(_ s: String) -> some View {
        let attributed = (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
        return Text(attributed)
            .font(Theme.serif(size))
            .lineSpacing(4)
            .foregroundStyle(Theme.text)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Loading / error / content wrapper for streamed readings.
struct ReadingBlock: View {
    let loader: ReadingLoader
    var retry: () -> Void

    var body: some View {
        if let error = loader.errorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Text(error).font(Theme.serif(15)).foregroundStyle(Theme.tense)
                Button("Try again", action: retry).font(Theme.mono(12))
            }
        } else if loader.text.isEmpty && loader.isLoading {
            HStack(spacing: 10) {
                ProgressView()
                Text("Reading the sky…").font(Theme.mono(12)).foregroundStyle(Theme.secondary)
            }
        } else {
            ReadingText(text: loader.text)
        }
    }
}
