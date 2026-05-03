import SwiftUI

struct FocusModeView: View {
    @State private var isFocusModeActive = false
    @State private var showTimerPicker = false
    @State private var focusDuration: Int = 25
    @State private var timer: Timer?
    @State private var remainingSeconds: Int = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(isFocusModeActive ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                Image(systemName: isFocusModeActive ? "moon.fill" : "moon")
                    .font(.system(size: 80))
                    .foregroundColor(isFocusModeActive ? .red : .gray)
            }
            
            VStack(spacing: 8) {
                Text(isFocusModeActive ? "专注模式已开启" : "专注模式")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(isFocusModeActive ? remainingTimeString : "点击下方按钮开始专注")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                if isFocusModeActive {
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
                FocusFeatureRow(icon: "bell.slash", text: "自动开启勿扰模式")
                FocusFeatureRow(icon: "desktopcomputer", text: "隐藏桌面图标")
                FocusFeatureRow(icon: "rectangle.on.rectangle.slash", text: "屏蔽无关应用通知")
                FocusFeatureRow(icon: "lock.fill", text: "锁定软件全屏")
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
        isFocusModeActive = true
        remainingSeconds = focusDuration * 60
        
        enableSystemFocusMode()
        
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
        isFocusModeActive = false
        remainingSeconds = 0
        
        disableSystemFocusMode()
    }
    
    private func enableSystemFocusMode() {
        print("macOS Focus Mode enabled")
    }
    
    private func disableSystemFocusMode() {
        print("macOS Focus Mode disabled")
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
