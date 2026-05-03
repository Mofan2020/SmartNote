import SwiftUI
import Charts

struct PomodoroView: View {
    @StateObject private var timer = PomodoroTimer.shared
    @StateObject private var stats = StudyStatisticsService.shared
    @State private var selectedSubject: String = "通用"
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 24) {
            timerDisplay
            
            timerControls
            
            Divider()
            
            statisticsView
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showSettings) {
            pomodoroSettings
        }
    }
    
    private var timerDisplay: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                
                VStack(spacing: 4) {
                    Text(timer.currentPhase.displayName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(timeString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    if timer.isRunning {
                        Text("\(timer.sessionsCompleted) 个番茄完成")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 20)
    }
    
    private var timerControls: some View {
        HStack(spacing: 20) {
            if timer.isRunning {
                Button {
                    timer.pause()
                } label: {
                    Label("暂停", systemImage: timer.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button {
                    timer.stop()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
            } else {
                Picker("科目", selection: $selectedSubject) {
                    Text("通用").tag("通用")
                    ForEach(Array(Set(stats.subjectStats.keys)), id: \.self) { subject in
                        Text(subject).tag(subject)
                    }
                }
                .frame(width: 120)
                
                Button {
                    timer.start(subject: selectedSubject)
                } label: {
                    Label("开始专注", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var statisticsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习统计")
                .font(.headline)
            
            HStack(spacing: 20) {
                statCard(title: "今日", value: formatDuration(stats.todayDuration), icon: "sun.max.fill")
                statCard(title: "本周", value: formatDuration(stats.weekDuration), icon: "calendar")
                statCard(title: "完成率", value: String(format: "%.0f%%", stats.completionRate), icon: "checkmark.circle.fill")
            }
            
            if !stats.subjectStats.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("科目分布")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Chart(Array(stats.subjectStats.keys.sorted().prefix(5)), id: \.self) { subject in
                        BarMark(
                            x: .value("时长", stats.subjectStats[subject] ?? 0),
                            y: .value("科目", subject)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                    }
                    .frame(height: 150)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }
    
    private var pomodoroSettings: some View {
        VStack(spacing: 20) {
            Text("番茄钟设置")
                .font(.headline)
            
            Form {
                Stepper("专注时长: \(timer.workDuration) 分钟", value: $timer.workDuration, in: 5...60, step: 5)
                
                Stepper("短休息: \(timer.shortBreakDuration) 分钟", value: $timer.shortBreakDuration, in: 1...15, step: 1)
                
                Stepper("长休息: \(timer.longBreakDuration) 分钟", value: $timer.longBreakDuration, in: 5...30, step: 5)
                
                Toggle("专注模式", isOn: $timer.isFocusModeEnabled)
            }
            .formStyle(.grouped)
            
            Button("保存") {
                timer.setDurations(work: timer.workDuration, shortBreak: timer.shortBreakDuration, longBreak: timer.longBreakDuration)
                showSettings = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 350, height: 300)
    }
    
    private var progress: Double {
        guard timer.totalSeconds > 0 else { return 0 }
        return Double(timer.totalSeconds - timer.remainingSeconds) / Double(timer.totalSeconds)
    }
    
    private var timerColor: Color {
        switch timer.currentPhase {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
    
    private var timeString: String {
        let minutes = timer.remainingSeconds / 60
        let seconds = timer.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
