import SwiftUI

struct ConfigureView: View {
    @ObservedObject var viewModel: ConfigureViewModel
    @ObservedObject var wordStore: WordStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(AppTheme.line)

            GeometryReader { geo in
                if geo.size.width > 700 {
                    HStack(alignment: .top, spacing: 0) {
                        wordList
                            .frame(width: min(260, geo.size.width * 0.38))
                        Divider().overlay(AppTheme.line)
                        editorPane
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        wordList
                            .frame(height: geo.size.height * 0.42)
                        Divider().overlay(AppTheme.line)
                        editorPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(Color.clear)
        .onAppear {
            viewModel.attach(wordStore: wordStore)
            viewModel.loadFromStore()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Words")
                .font(AppTheme.brandFont)
                .foregroundStyle(AppTheme.ink)

            Text("Add or edit nouns and their articles. Saved words are used in the game on this device.")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.muted)

            HStack(spacing: 8) {
                Button("Add word") { viewModel.addWord() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Save") { viewModel.save() }
                    .buttonStyle(PrimaryButtonStyle(disabled: !viewModel.hasUnsavedChanges))
                    .disabled(!viewModel.hasUnsavedChanges)
            }

            Button("Reload defaults") { viewModel.resetToDefaults() }
                .buttonStyle(GhostButtonStyle())

            if let status = viewModel.statusMessage {
                Text(status)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(viewModel.hasUnsavedChanges ? AppTheme.das : AppTheme.accent)
            }
        }
        .padding(20)
    }

    private var wordList: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search", text: $viewModel.filter)
                .textFieldStyle(RoundedFieldStyle())
                .font(AppTheme.bodyFont)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.filteredWords) { item in
                        Button {
                            viewModel.selectedID = item.id
                        } label: {
                            HStack(spacing: 8) {
                                Text(item.emoji)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.word.isEmpty ? "New word" : item.word)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.ink)
                                        .lineLimit(1)
                                    Text(item.article.label)
                                        .font(AppTheme.captionFont)
                                        .foregroundStyle(AppTheme.articleColor(item.article))
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(viewModel.selectedID == item.id ? AppTheme.gold.opacity(0.22) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
        }
        .background(AppTheme.surface.opacity(0.55))
    }

    @ViewBuilder
    private var editorPane: some View {
        if let selectedID = viewModel.selectedID, let binding = viewModel.binding(for: selectedID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Edit word")
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.ink)

                    TextField("Noun", text: binding.word)
                        .textFieldStyle(RoundedFieldStyle())
                        .font(AppTheme.titleFont)

                    Text("Article")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.muted)

                    Picker("Article", selection: binding.article) {
                        ForEach(Article.allCases) { article in
                            Text(article.label).tag(article)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Emoji", text: binding.emoji)
                        .textFieldStyle(RoundedFieldStyle())
                        .font(AppTheme.bodyFont)

                    Button("Delete word", role: .destructive) {
                        viewModel.deleteSelected()
                    }
                    .buttonStyle(GhostButtonStyle())
                    .padding(.top, 8)
                }
                .padding(20)
            }
        } else {
            ContentUnavailableView(
                "No word selected",
                systemImage: "text.book.closed",
                description: Text("Pick a word from the list or add a new one.")
            )
            .padding()
        }
    }
}
