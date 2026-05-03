import SwiftUI

struct FocusModeView: View {
    @StateObject private var focusService = FocusModeService.shared
    @State private var showTimerPicker = false
    @State private var focusDuration: Int = 25
    @State private var timer: Timer?
    @State private var remainingSeconds: Int = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(focusService.isActive ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                Image(systemName: focusService.isActive ? "moon.fill" : "moon")
                    .font(.system(size: 80))
                    .foregroundColor(focusService.isActive ? .red : .gray)
            }
            
            VStack(spacing: 8) {
                Text(focusService.isActive ? "专注模式已开启" : "专注模式")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(focusService.isActive ? remainingTimeString : "点击下方按钮开始专注")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                if focusService.isActive {
                    Button {
                        exitFocusMode()
                    } label: {
                        Label("退出专注", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                } else {
                    Button {
                        showTimerPicker = true
                    } label: {
                        Label("\(focusDuration) 分钟", systemImage: "clock")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button {
                        enterFocusMode()
                    } label: {
                        Label("开始专注", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            
            Spacer()
            
            focusModeDescription
        }
        .padding()
        .sheet(isPresented: $showTimerPicker) {
            timerPickerSheet
        }
    }
    
    private var remainingTimeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var focusModeDescription: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("专注模式功能")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                FocusFeatureRow(icon: "bell.slash.fill", text: "开启勿扰模式，屏蔽所有通知")
                FocusFeatureRow(icon: "desktopcomputer", text: "隐藏桌面图标，减少干扰")
                FocusFeatureRow(icon: "rectangle.on.rectangle.slash", text: "专注当前应用，提高效率")
                FocusFeatureRow(icon: "lock.fill", text: "专注结束后自动恢复系统设置")
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var timerPickerSheet: some View {
        VStack(spacing: 20) {
            Text("选择专注时长")
                .font(.headline)
            
            Picker("时长", selection: $focusDuration) {
                Text("15 分钟").tag(15)
                Text("25 分钟").tag(25)
                Text("30 分钟").tag(30)
                Text("45 分钟").tag(45)
                Text("60 分钟").tag(60)
                Text("90 分钟").tag(90)
            }
            .pickerStyle(.radioGroup)
            
            Button("确认") {
                showTimerPicker = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 250, height: 250)
    }
    
    private func enterFocusMode() {
        focusService.enable()
        
        remainingSeconds = focusDuration * 60
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                exitFocusMode()
            }
        }
    }
    
    private func exitFocusMode() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = 0
        
        focusService.disable()
    }
}

struct FocusFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
        }
    }
}
