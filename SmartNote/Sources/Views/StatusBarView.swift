import SwiftUI
import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "book.fill", accessibilityDescription: "智学笔记")
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: StatusBarPopoverView())
        
        statusItem?.button?.action = #selector(togglePopover)
        statusItem?.button?.target = self
    }
    
    @objc private func togglePopover() {
        guard let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

struct StatusBarPopoverView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var pomodoro = PomodoroTimer.shared
    @State private var todayExamCount: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("智学笔记")
                    .font(.headline)
                Spacer()
                Text("菜单栏")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            if pomodoro.isRunning {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.red)
                    VStack(alignment: .leading) {
                        Text("专注中")
                            .font(.subheadline)
                        Text(pomodoro.currentPhase.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(timerString)
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            } else {
                Button {
                    pomodoro.start()
                } label: {
                    Label("开始番茄钟", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("今日任务")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                let todayPlans = appState.reviewPlans.flatMap { $0.dailyPlans }
                    .filter { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
                
                if todayPlans.isEmpty {
                    Text("暂无今日任务")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    let totalTasks = todayPlans.flatMap { $0.tasks }.count
                    let completedTasks = todayPlans.flatMap { $0.tasks }.filter { $0.isCompleted }.count
                    
                    ProgressView(value: Double(completedTasks), total: Double(totalTasks))
                    Text("\(completedTasks)/\(totalTasks) 任务完成")
                        .font(.caption)
                }
            }
            
            Divider()
            
            let upcomingExams = appState.examCountdowns
                .filter { !$0.isArchived && !$0.isExpired }
                .sorted { $0.examDate < $1.examDate }
                .prefix(2)
            
            if !upcomingExams.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(" upcomingExams")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(upcomingExams)) { exam in
                        HStack {
                            Image(systemName: "calendar")
                            Text(exam.name)
                            Spacer()
                            Text("\(exam.daysRemaining) 天")
                                .foregroundColor(exam.isUrgent ? .red : .secondary)
                        }
                        .font(.caption)
                    }
                }
            }
            
            Spacer()
            
            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Label("打开主程序", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 280, height: 380)
    }
    
    private var timerString: String {
        let minutes = pomodoro.remainingSeconds / 60
        let seconds = pomodoro.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
