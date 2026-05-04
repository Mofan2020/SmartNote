import SwiftUI

struct P2PAddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var p2pService = P2PService.shared
    
    @State private var ipv6Address = ""
    @State private var port = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var showPendingConnection = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("添加好友")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("对方 IPv6 地址")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("例如: 2001:0db8:85a3:0000:0000:8a2e:0370:7334", text: $ipv6Address)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("端口")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("例如: 8080", text: $port)
                    .textFieldStyle(.roundedBorder)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                Text("你的连接信息")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("IPv6: \(p2pService.getIPv6Address())")
                        .font(.caption)
                        .textSelection(.enabled)
                    
                    Spacer()
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("\(p2pService.getIPv6Address()):\(p2pService.getPort())", forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .help("复制地址")
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                
                Text("将以上地址发送给好友，等待对方连接")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                connectToFriend()
            } label: {
                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("连接")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(ipv6Address.isEmpty || port.isEmpty || isConnecting)
        }
        .padding()
        .frame(width: 400, height: 450)
    }
    
    private func connectToFriend() {
        guard let portInt = Int(port) else {
            errorMessage = "端口必须是数字"
            return
        }
        
        isConnecting = true
        errorMessage = nil
        
        DispatchQueue.global().async {
            _ = p2pService.connectToFriend(ipv6Address: ipv6Address, port: portInt)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isConnecting = false
                dismiss()
            }
        }
    }
}
