import SwiftUI
import WebKit
import Combine

/// Browser-based compatibility edition for iOS 16. This is NOT a native port
/// of the iOS 17 download, SwiftData or YouTubeKit implementations.
struct SavedPage: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var url: String
}

final class FreeTubeBrowser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    static let homeURL = URL(string: "https://m.youtube.com/")!
    static let bookmarksKey = "FreeTube16.bookmarks.v1"

    let webView: WKWebView
    @Published private(set) var title = "YouTube"
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var currentURL: URL?
    @Published private(set) var bookmarks: [SavedPage] = []
    @Published private(set) var navigationError: String?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        if let data = UserDefaults.standard.data(forKey: Self.bookmarksKey),
           let stored = try? JSONDecoder().decode([SavedPage].self, from: data) {
            bookmarks = stored
        }
        open(homeURL)
    }

    func open(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return
        }
        navigationError = nil
        webView.load(URLRequest(url: url))
    }

    func openHome() { open(Self.homeURL) }

    func openSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let direct = URL(string: trimmed),
           let scheme = direct.scheme?.lowercased(), ["https", "http"].contains(scheme) {
            open(direct)
            return
        }
        var components = URLComponents(string: "https://m.youtube.com/results")
        components?.queryItems = [URLQueryItem(name: "search_query", value: trimmed)]
        if let url = components?.url { open(url) }
    }

    func back() { if webView.canGoBack { webView.goBack() } }
    func forward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }

    var isBookmarked: Bool {
        guard let url = currentURL?.absoluteString else { return false }
        return bookmarks.contains { $0.url == url }
    }

    func toggleBookmark() {
        guard let url = currentURL?.absoluteString else { return }
        if let index = bookmarks.firstIndex(where: { $0.url == url }) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.insert(SavedPage(id: UUID(), title: title, url: url), at: 0)
        }
        persistBookmarks()
    }

    func deleteBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        persistBookmarks()
    }

    private func persistBookmarks() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        UserDefaults.standard.set(data, forKey: Self.bookmarksKey)
    }

    private func refresh() {
        title = webView.title?.isEmpty == false ? webView.title! : "YouTube"
        currentURL = webView.url
        isLoading = webView.isLoading
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        navigationError = nil
        refresh()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        refresh()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refresh()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        refresh()
        if (error as NSError).code != NSURLErrorCancelled {
            navigationError = error.localizedDescription
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refresh()
        if (error as NSError).code != NSURLErrorCancelled {
            navigationError = error.localizedDescription
        }
    }

    // Handle target=_blank links in the same tab (e.g. Google sign-in windows).
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil,
           let url = navigationAction.request.url {
            open(url)
        }
        return nil
    }
}

private struct BrowserWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct BrowserScreen: View {
    @StateObject private var browser = FreeTubeBrowser()
    @State private var showingSearch = false
    @State private var showingBookmarks = false
    @State private var showingInfo = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                BrowserWebView(webView: browser.webView)
                    .ignoresSafeArea(edges: .bottom)
                if browser.isLoading {
                    ProgressView().progressViewStyle(.linear)
                }
                if let error = browser.navigationError {
                    VStack(spacing: 10) {
                        Text("Page couldn't load").font(.headline)
                        Text(error).font(.footnote).multilineTextAlignment(.center)
                        Button("Try again") { browser.reload() }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
            }
            .navigationTitle("FreeTube 16")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        browser.toggleBookmark()
                    } label: {
                        Image(systemName: browser.isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(browser.isBookmarked ? "Remove bookmark" : "Add bookmark")

                    if let url = browser.currentURL {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }

                    Button { showingInfo = true } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack {
                    navButton("chevron.left", "Back", disabled: !browser.canGoBack) { browser.back() }
                    navButton("chevron.right", "Forward", disabled: !browser.canGoForward) { browser.forward() }
                    navButton("house.fill", "Home") { browser.openHome() }
                    navButton("magnifyingglass", "Search") { showingSearch = true }
                    navButton("bookmark.fill", "Saved") { showingBookmarks = true }
                    navButton("arrow.clockwise", "Reload") { browser.reload() }
                }
                .padding(.vertical, 11)
                .background(.regularMaterial)
            }
            .sheet(isPresented: $showingSearch) {
                SearchPanel { query in browser.openSearch(query) }
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingBookmarks) {
                BookmarksPanel(browser: browser)
            }
            .sheet(isPresented: $showingInfo) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("FreeTube 16 — Compatibility Edition")
                                .font(.title3.bold())
                            Text("This iOS 16 version is a YouTube WebKit browser with search, bookmarks, browsing history, sharing and playback provided by the website.")
                            Text("It does not include the iOS 17 native app's yt-dlp downloads, FFmpeg conversion, SwiftData library or native AVPlayer playback.")
                            Text("Google may refuse sign-in within embedded browsers. Background playback, PiP and particular videos depend on YouTube's website and iOS WebKit restrictions.")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .navigationTitle("About")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingInfo = false } } }
                }
            }
        }
    }

    private func navButton(_ symbol: String, _ title: String, disabled: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .contentShape(Rectangle())
        }
        .disabled(disabled)
        .accessibilityLabel(title)
    }
}

private struct SearchPanel: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let onSearch: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Search YouTube or paste a URL", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { submit() }
                Button("Search") { submit() }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Search")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func submit() {
        onSearch(query)
        dismiss()
    }
}

private struct BookmarksPanel: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var browser: FreeTubeBrowser

    var body: some View {
        NavigationStack {
            List {
                if browser.bookmarks.isEmpty {
                    Text("No saved pages yet. Tap the bookmark icon while browsing.")
                        .foregroundStyle(.secondary)
                }
                ForEach(browser.bookmarks) { saved in
                    Button {
                        if let url = URL(string: saved.url) {
                            browser.open(url)
                            dismiss()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(saved.title).lineLimit(2)
                            Text(saved.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .onDelete(perform: browser.deleteBookmarks)
            }
            .navigationTitle("Saved pages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
