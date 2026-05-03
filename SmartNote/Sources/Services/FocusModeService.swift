import Foundation
import AppKit
import UserNotifications

class FocusModeService: ObservableObject {
    static let shared = FocusModeService()
    
    @Published var isActive = false
    
    private init() {}
    
    func enable() {
        isActive = true
        
        hideDesktopIcons()
        enableDoNotDisturb()
        
        postNotification(title: "专注模式已开启", body: "所有通知已屏蔽，桌面图标已隐藏")
    }
    
    func disable() {
        isActive = false
        
        showDesktopIcons()
        disableDoNotDisturb()
        
        postNotification(title: "专注模式已关闭", body: "桌面图标已恢复，通知已开启")
    }
    
    private func hideDesktopIcons() {
        let script = """
        tell application "Finder"
            set visible of every desktop item to false
        end tell
        """
        runAppleScript(script)
    }
    
    private func showDesktopIcons() {
        let script = """
        tell application "Finder"
            set visible of every desktop item to true
        end tell
        """
        runAppleScript(script)
    }
    
    private func enableDoNotDisturb() {
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                -- Click on Control Center in menu bar
                click menu bar item "Control Center" of menu bar 1
                -- Wait for popup
                delay 0.5
                -- Click on Focus
                click checkbox "专注模式" of group 1 of window "Control Center"
                -- Close Control Center
                key code 53
            end tell
        end tell
        """
        runAppleScript(script)
        
        NotificationCenter.default.post(name: .focusModeChanged, object: true)
    }
    
    private func disableDoNotDisturb() {
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                click menu bar item "Control Center" of menu bar 1
                delay 0.5
                try
                    click checkbox "专注模式" of group 1 of window "Control Center"
                end try
                key code 53
            end tell
        end tell
        """
        runAppleScript(script)
        
        NotificationCenter.default.post(name: .focusModeChanged, object: false)
    }
    
    private func runAppleScript(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("AppleScript error: \(error)")
                }
            }
        }
    }
    
    private func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

extension Notification.Name {
    static let focusModeChanged = Notification.Name("focusModeChanged")
}
