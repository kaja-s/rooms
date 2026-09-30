import AppKit
import Combine
import SwiftUI

/// Window showing the setup steps; presented by `GettingStartedModel.isPresented`.
final class GettingStartedWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private unowned let controller: AppController
    private var cancellables: Set<AnyCancellable> = []

    init(controller: AppController) {
        self.controller = controller
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = controller.gettingStarted.title
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating
        window.contentView = NSHostingView(rootView: GettingStartedView(model: controller.gettingStarted))

        controller.gettingStarted.$isPresented
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] presented in presented ? self?.show() : self?.window.orderOut(nil) }
            .store(in: &cancellables)
    }

    private func show() {
        let area = controller.gettingStarted.screenArea
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        controller.gettingStarted.done()
        return false
    }
}

struct GettingStartedView: View {
    @ObservedObject var model: GettingStartedModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.title).font(.system(size: 22, weight: .semibold))
            ForEach(Array(model.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 24, height: 24).background(Circle().fill(Color.accentColor))
                    Text(step).font(.system(size: 14))
                }
            }
            Text(model.footerText).font(.system(size: 13)).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(model.doneButtonTitle) { model.done() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
