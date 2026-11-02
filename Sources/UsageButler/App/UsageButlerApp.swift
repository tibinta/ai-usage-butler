import SwiftUI
import AppKit
import CoreText
import UsageCore

@main struct UsageButlerApp: App {
    @StateObject private var store: UsageStore
    private static var previewWindow: NSWindow?
    init() {
        let store = UsageStore()
        _store = StateObject(wrappedValue: store)
        if CommandLine.arguments.contains("--preview") {
            DispatchQueue.main.async {
                let view = ScrollView { ContentView(store: store) }.frame(width: 680)
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 470), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                window.title = "Usage Butler Preview"
                window.contentView = NSHostingView(rootView: view)
                window.center()
                Self.previewWindow = window
                NSApp.setActivationPolicy(.regular)
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        if let url = Bundle.main.url(forResource: "LibreBaskerville", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            Image(nsImage: MenuBarPill.image(title: menuTitle, color: menuColor))
                .renderingMode(.original)
                .accessibilityLabel(menuAccessibilityTitle)
        }.menuBarExtraStyle(.window)
    }
    private var menuTitle: String {
        let now = Date()
        if let provider = DecisionPolicy.activeProvider(store.providers, now: now) {
            let guidance = DecisionPolicy.guidance(provider, now: now)
            return "\(provider.name): \(Banter.menuPhrase(color: guidance.color, pause: guidance.text == "Pause until 7 am"))"
        }
        return DecisionPolicy.allSpent(store.providers, now: now) ? "Quota: \(Banter.menuPhrase(color: "red"))" : DecisionPolicy.menuTitle(store.providers, now: now)
    }
    private var menuAccessibilityTitle: String {
        let now = Date()
        if let provider = DecisionPolicy.activeProvider(store.providers, now: now) {
            return "\(provider.name): \(DecisionPolicy.guidance(provider, now: now).text)"
        }
        return DecisionPolicy.menuTitle(store.providers, now: now)
    }
    private var menuColor: Color {
        switch DecisionPolicy.color(store.providers, now: Date()) {
        case "green": return Color(red: 0.10, green: 0.38, blue: 0.25)
        case "red": return Color(red: 0.66, green: 0.16, blue: 0.15)
        default: return Color(red: 0.55, green: 0.35, blue: 0.04)
        }
    }
}
