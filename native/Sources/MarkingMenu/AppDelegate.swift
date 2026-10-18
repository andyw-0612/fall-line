import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular); NSApp.activate()
    }
    func applicationDidResignActive(_ notification: Notification) { AppModel.shared.cancel() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { await AppModel.shared.camera.shutdown(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
