import SwiftUI

struct P2PSocialView: View {
    @StateObject private var p2pService = P2PService.shared
    @State private var selectedFriend: P2PFriend?
    @State private var showAddFriend = false
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            if let identity = p2pService.currentIdentity {
                identityHeader(identity)
                
                Divider()
                
                if p2pService.friends.isEmpty {
                    emptyFriendsView
                } else {
                    friendsListView
                }
            } else {
                noIdentityView
            }
        }
        .sheet(isPresented: $showAddFriend) {
            P2PAddFriendView()
        }
        .sheet(isPresented: $showSettings) {
            P2PSettingsView()
        }
    }
    
    private func identityHeader(_ identity: P2PUserIdentity) -> some View {
        HStack {
            if let avatarData = identity.avatarData,
               let nsImage = NSImage(data: avatarData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(identity.nickname)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(for: identity))
                        .frame(width: 8, height: 8)
                    Text("在线")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.bordered)
                
                Button {
                    showAddFriend = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func statusColor(for identity: P2PUserIdentity) -> Color {
        .green
    }
    
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "person.2.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("暂无好友")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击上方按钮添加好友")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var friendsListView: some View {
        List(p2pService.friends) { friend in
            P2PFriendRow(friend: friend, status: p2pService.connectionStatus[friend.id])
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedFriend = friend
                }
        }
        .sheet(item: $selectedFriend) { friend in
            P2PChatView(friend: friend)
        }
    }
    
    private var noIdentityView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("创建 P2P 社交身份")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("创建后可与好友进行端到端加密聊天、文件传输")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            P2PCreateIdentityView()
            
            Spacer()
        }
        .padding()
    }
}

struct P2PFriendRow: View {
    let friend: P2PFriend
    let status: P2PFriend.FriendStatus?
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let avatarData = friend.avatarData,
                   let nsImage = NSImage(data: avatarData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 44, height: 44)
                        .foregroundColor(.accentColor)
                }
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .offset(x: 2, y: 2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.nickname)
                    .font(.headline)
                
                if let preview = friend.lastMessagePreview {
                    Text(preview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let lastMessageAt = friend.lastMessageAt {
                Text(formatTime(lastMessageAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch status {
        case .online: return .green
        case .focusing: return .orange
        case .offline, .none: return .gray
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
