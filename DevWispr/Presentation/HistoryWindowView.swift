//
//  HistoryWindowView.swift
//  DevWispr
//

import AppKit
import SwiftUI

struct HistoryWindowView: View {
    @ObservedObject var viewModel: HistoryWindowViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Rectangle()
                .fill(WisprTheme.divider)
                .frame(height: 1)

            if let error = viewModel.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(WisprTheme.statusError)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(WisprTheme.statusError)
                }
                .padding()
            }

            if viewModel.items.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                itemList
            }

            Rectangle()
                .fill(WisprTheme.divider)
                .frame(height: 1)

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(minWidth: 400, minHeight: 400)
        .background(WisprTheme.background)
        .preferredColorScheme(.dark)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(WisprTheme.textTertiary)

            TextField("Search transcriptions…", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(WisprTheme.textPrimary)
                .onSubmit { viewModel.performSearch() }

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(WisprTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(WisprTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(WisprTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Item List

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.items) { item in
                    historyRow(item)
                }
                if viewModel.hasMorePages {
                    Button("Load More") {
                        viewModel.loadNextPage()
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.plain)
                    .foregroundStyle(WisprTheme.statusRecording)
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func historyRow(_ item: TranscriptItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.text)
                    .font(.system(size: 13))
                    .foregroundStyle(WisprTheme.textPrimary)
                    .lineLimit(3)

                HStack(spacing: 10) {
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(WisprTheme.textTertiary)

                    if let appName = item.appName {
                        HStack(spacing: 3) {
                            Image(systemName: "app.badge")
                                .font(.system(size: 9))
                            Text(appName)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(WisprTheme.textTertiary)
                    }

                    HStack(spacing: 3) {
                        Text(item.inputLanguage.displayName)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                        Text(item.outputLanguage.displayName)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(WisprTheme.textTertiary)
                }
            }

            Spacer()

            CopyButton(text: item.text)
        }
        .wisprCard()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(WisprTheme.textTertiary)

            if viewModel.searchQuery.isEmpty {
                Text("No history yet")
                    .font(.headline)
                    .foregroundStyle(WisprTheme.textSecondary)
                Text("Transcriptions will appear here after recording.")
                    .font(.caption)
                    .foregroundStyle(WisprTheme.textTertiary)
            } else {
                Text("No results found")
                    .font(.headline)
                    .foregroundStyle(WisprTheme.textSecondary)
                Text("Try a different search term.")
                    .font(.caption)
                    .foregroundStyle(WisprTheme.textTertiary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("^[\(viewModel.totalCount) item](inflect: true)")
                .font(.system(size: 11))
                .foregroundStyle(WisprTheme.textTertiary)

            Spacer()

            Button("Clear All History") {
                viewModel.showClearConfirmation = true
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(viewModel.items.isEmpty ? WisprTheme.textTertiary : WisprTheme.statusError.opacity(0.8))
            .disabled(viewModel.items.isEmpty)
            .alert("Clear All History?", isPresented: $viewModel.showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    viewModel.clearAll()
                }
            } message: {
                Text("This will permanently delete all transcription history.")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
private final class PreviewHistoryStore: HistoryStore {
    private var items: [TranscriptItem]
    init(items: [TranscriptItem]) { self.items = items }
    func add(_ item: TranscriptItem) throws { items.insert(item, at: 0) }
    func list(page: Int, pageSize: Int) throws -> [TranscriptItem] { paginate(items, page: page, pageSize: pageSize) }
    func search(query: String, page: Int, pageSize: Int) throws -> [TranscriptItem] {
        let filtered = items.filter { $0.text.localizedCaseInsensitiveContains(query) }
        return paginate(filtered, page: page, pageSize: pageSize)
    }
    func count(query: String) throws -> Int {
        query.trimmingCharacters(in: .whitespaces).isEmpty
            ? items.count
            : items.filter { $0.text.localizedCaseInsensitiveContains(query) }.count
    }
    func clearAll() throws { items.removeAll() }
}

#Preview("With Items") {
    let vm = HistoryWindowViewModel(historyStore: PreviewHistoryStore(items: [
        TranscriptItem(text: "Hey everyone, let's kick off the meeting.", inputLanguage: .english, outputLanguage: .english, appName: "Zoom"),
        TranscriptItem(text: "Bitte schicken Sie mir den Bericht bis Freitag.", inputLanguage: .german, outputLanguage: .english, appName: "Mail"),
        TranscriptItem(text: "The deployment is scheduled for tomorrow morning.", inputLanguage: .english, outputLanguage: .english, appName: "Slack"),
    ]))
    return HistoryWindowView(viewModel: vm)
}

#Preview("Empty") {
    HistoryWindowView(viewModel: HistoryWindowViewModel(historyStore: PreviewHistoryStore(items: [])))
}
#endif

// MARK: - Copy Button

private struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { copied = false }
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 12))
                .foregroundStyle(copied ? WisprTheme.statusOK : WisprTheme.textTertiary)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
    }
}
