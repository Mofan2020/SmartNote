import Foundation
import Combine
import Network

class P2PService: ObservableObject {
    static let shared = P2PService()
    
    @Published var currentIdentity: P2PUserIdentity?
    @Published var friends: [P2PFriend] = []
    @Published var blackList: [P2PBlackIP] = []
    @Published var isBackgroundEnabled = false
    @Published var connectionStatus: [UUID: P2PFriend.FriendStatus] = [:]
    
    private let cryptoService = P2PCryptoService.shared
    private let networkService = P2PNetworkService.shared
    private let storageService = StorageService()
    
    private var pendingConnections: [(ipv6: String, port: Int)] = []
    
    private init() {
        loadData()
        setupNetworkHandlers()
    }
    
    private func loadData() {
        currentIdentity = storageService.loadP2PIdentity()
        friends = storageService.loadP2PFriends()
        blackList = storageService.loadP2PBlackList()
        isBackgroundEnabled = storageService.loadSettings().p2pBackgroundEnabled
        
        if let identity = currentIdentity {
            networkService.startListening(port: UInt16(identity.port > 0 ? identity.port : 0))
        }
    }
    
    private func setupNetworkHandlers() {
        networkService.onMessageReceived = { [weak self] friendID, data in
            self?.handleReceivedData(friendID, data: data)
        }
        
        networkService.onConnectionStatusChanged = { [weak self] friendID, state in
            self?.handleConnectionStatusChanged(friendID, state: state)
        }
        
        networkService.onIncomingConnection = { [weak self] ipv6, port in
            self?.handleIncomingConnection(ipv6: ipv6, port: port)
        }
    }
    
    func createIdentity(nickname: String, signature: String = "", avatarData: Data? = nil) -> Bool {
        guard let keyData = cryptoService.generateRSAKeyPair() else {
            return false
        }
        
        let identity = P2PUserIdentity(
            nickname: nickname,
            avatarData: avatarData,
            signature: signature,
            publicKey: keyData.publicKey,
            privateKeyRef: keyData.privateKeyRef,
            keyFingerprint: keyData.fingerprint,
            ipv6Address: networkService.localIPv6Address,
            port: networkService.localPort
        )
        
        currentIdentity = identity
        storageService.saveP2PIdentity(identity)
        
        networkService.startListening(port: 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            var updatedIdentity = identity
            updatedIdentity.ipv6Address = self?.networkService.localIPv6Address ?? ""
            updatedIdentity.port = self?.networkService.localPort ?? 0
            self?.currentIdentity = updatedIdentity
            self?.storageService.saveP2PIdentity(updatedIdentity)
        }
        
        return true
    }
    
    func updateIdentity(nickname: String? = nil, signature: String? = nil, avatarData: Data? = nil) {
        guard var identity = currentIdentity else { return }
        
        if let nickname = nickname {
            identity.nickname = nickname
        }
        if let signature = signature {
            identity.signature = signature
        }
        if let avatarData = avatarData {
            identity.avatarData = avatarData
        }
        identity.updatedAt = Date()
        
        currentIdentity = identity
        storageService.saveP2PIdentity(identity)
    }
    
    func resetIdentity() {
        if let identity = currentIdentity {
            cryptoService.deletePrivateKey(identifier: identity.privateKeyRef)
        }
        
        networkService.disconnectAll()
        networkService.stopListening()
        
        currentIdentity = nil
        friends = []
        blackList = []
        
        storageService.deleteP2PIdentity()
        storageService.deleteAllP2PFriends()
        storageService.deleteP2PBlackList()
    }
    
    func connectToFriend(ipv6Address: String, port: Int) -> UUID? {
        for ip in blackList {
            if ipv6Address.hasPrefix(ip.ipv6Address) {
                return nil
            }
        }
        
        let friendID = UUID()
        
        if networkService.connectToPeer(ipv6Address: ipv6Address, port: UInt16(port), friendID: friendID) {
            return friendID
        }
        
        return nil
    }
    
    func acceptConnection(friendID: UUID, nickname: String, publicKey: String) {
        let friend = P2PFriend(
            nickname: nickname,
            ipv6Address: "",
            port: 0,
            publicKey: publicKey
        )
        
        friends.append(friend)
        storageService.saveP2PFriends(friends)
    }
    
    func rejectConnection(friendID: UUID) {
        networkService.disconnect(friendID: friendID)
    }
    
    func addToBlackList(ipv6Address: String, reason: String = "") {
        let blackIP = P2PBlackIP(ipv6Address: ipv6Address, reason: reason)
        blackList.append(blackIP)
        storageService.saveP2PBlackList(blackList)
    }
    
    func removeFromBlackList(ipv6Address: String) {
        blackList.removeAll { $0.ipv6Address == ipv6Address }
        storageService.saveP2PBlackList(blackList)
    }
    
    func sendMessage(_ content: String, to friendID: UUID, type: P2PChatMessage.MessageType = .text) -> P2PChatMessage? {
        guard let friend = friends.first(where: { $0.id == friendID }),
              let connection = networkService.connections[friendID],
              let aesKey = connection.aesKey else {
            return nil
        }
        
        let message = P2PChatMessage(
            friendID: friendID,
            content: content,
            isSent: true,
            status: .sending,
            type: type
        )
        
        let messageData = content.data(using: .utf8) ?? Data()
        
        guard let encryptedData = cryptoService.aesEncrypt(messageData, key: aesKey) else {
            return nil
        }
        
        var packet = Data([0x01])
        var typeByte: UInt8 = 0x01
        switch type {
        case .text: typeByte = 0x01
        case .file: typeByte = 0x02
        case .status: typeByte = 0x03
        case .system: typeByte = 0x04
        }
        packet.append(typeByte)
        packet.append(encryptedData)
        
        if networkService.send(packet, to: friendID) {
            return message
        }
        
        return nil
    }
    
    func sendStatus(_ status: UserStatus, to friendID: UUID) {
        guard let connection = networkService.connections[friendID],
              let aesKey = connection.aesKey else {
            return
        }
        
        let statusString = status.rawValue
        guard let statusData = statusString.data(using: .utf8),
              let encryptedData = cryptoService.aesEncrypt(statusData, key: aesKey) else {
            return
        }
        
        var packet = Data([0x02, 0x03])
        packet.append(encryptedData)
        
        networkService.send(packet, to: friendID)
    }
    
    func setBackgroundEnabled(_ enabled: Bool) {
        isBackgroundEnabled = enabled
        
        var settings = storageService.loadSettings()
        settings.p2pBackgroundEnabled = enabled
        storageService.saveSettings(settings)
        
        if !enabled {
            networkService.disconnectAll()
        }
    }
    
    private func handleReceivedData(_ friendID: UUID, data: Data) {
        guard data.count > 2 else { return }
        
        let packetType = data[0]
        let messageType = data[1]
        
        switch packetType {
        case 0x01:
            handleChatMessage(friendID, type: messageType, data: data.suffix(from: 2))
        case 0x02:
            handleStatusMessage(friendID, data: data.suffix(from: 2))
        case 0x10:
            handleHandshake(friendID, data: data.suffix(from: 1))
        default:
            break
        }
    }
    
    private func handleChatMessage(_ friendID: UUID, type: UInt8, data: Data.SubSequence) {
        print("Received chat message from \(friendID)")
    }
    
    private func handleStatusMessage(_ friendID: UUID, data: Data.SubSequence) {
        print("Received status message from \(friendID)")
    }
    
    private func handleHandshake(_ friendID: UUID, data: Data.SubSequence) {
        print("Received handshake from \(friendID)")
    }
    
    private func handleConnectionStatusChanged(_ friendID: UUID, state: NWConnection.State) {
        switch state {
        case .ready:
            connectionStatus[friendID] = .online
        case .failed, .cancelled:
            connectionStatus[friendID] = .offline
        default:
            break
        }
    }
    
    private func handleIncomingConnection(ipv6: String, port: Int) {
        for ip in blackList {
            if ipv6.hasPrefix(ip.ipv6Address) {
                return
            }
        }
        
        pendingConnections.append((ipv6, port))
    }
    
    func getIPv6Address() -> String {
        return networkService.localIPv6Address
    }
    
    func getPort() -> Int {
        return networkService.localPort
    }
}
