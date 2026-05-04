import Foundation
import Network
import Combine
import Darwin

class P2PNetworkService: ObservableObject {
    static let shared = P2PNetworkService()
    
    @Published var isListening = false
    @Published var localIPv6Address: String = ""
    @Published var localPort: Int = 0
    @Published var connections: [UUID: P2PConnection] = [:]
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.smartnote.p2p", qos: .userInitiated)
    
    var onMessageReceived: ((UUID, Data) -> Void)?
    var onConnectionStatusChanged: ((UUID, NWConnection.State) -> Void)?
    var onIncomingConnection: ((String, Int) -> Void)?
    
    private init() {}
    
    func startListening(port: UInt16 = 0) -> Bool {
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("Failed to create listener: \(error)")
            return false
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.isListening = (state == .ready)
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleIncomingConnection(connection)
        }
        
        listener?.start(queue: queue)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateLocalAddress()
        }
        
        return true
    }
    
    func stopListening() {
        listener?.cancel()
        listener = nil
        isListening = false
    }
    
    private func updateLocalAddress() {
        let params = NWParameters()
        let browser = NWBrowser(for: .bonjour(type: "_tcp", domain: nil), using: params)
        
        browser.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.getIPv6Address()
            }
            browser.cancel()
        }
        
        browser.start(queue: queue)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.getIPv6Address()
        }
    }
    
    private func getIPv6Address() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return
        }
        
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET6) {
                let name = String(cString: interface.ifa_name)
                if name.hasPrefix("en") || name.hasPrefix("utun") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    
                    let ipv6 = String(cString: hostname)
                    if !ipv6.contains("fe80") && !ipv6.contains("%") {
                        localIPv6Address = ipv6
                        break
                    }
                }
            }
        }
        
        if let port = listener?.port?.rawValue {
            localPort = Int(port)
        }
    }
    
    func connectToPeer(ipv6Address: String, port: UInt16, friendID: UUID) -> Bool {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(ipv6Address),
            port: NWEndpoint.Port(rawValue: port)!
        )
        
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        let p2pConnection = P2PConnection(
            id: friendID,
            connection: connection,
            isOutgoing: true
        )
        
        connections[friendID] = p2pConnection
        
        setupConnectionHandlers(p2pConnection)
        
        connection.start(queue: queue)
        
        return true
    }
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        let tempID = UUID()
        let p2pConnection = P2PConnection(
            id: tempID,
            connection: connection,
            isOutgoing: false
        )
        
        connections[tempID] = p2pConnection
        
        setupConnectionHandlers(p2pConnection)
        
        connection.start(queue: queue)
        
        if let endpoint = connection.currentPath?.remoteEndpoint,
           case .hostPort(let host, let port) = endpoint {
            DispatchQueue.main.async {
                self.onIncomingConnection?(host.debugDescription, Int(port.rawValue))
            }
        }
    }
    
    private func setupConnectionHandlers(_ p2pConnection: P2PConnection) {
        p2pConnection.connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.onConnectionStatusChanged?(p2pConnection.id, state)
            }
        }
        
        p2pConnection.connection.start(queue: queue)
        receiveData(on: p2pConnection)
    }
    
    private func receiveData(on p2pConnection: P2PConnection) {
        p2pConnection.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                DispatchQueue.main.async {
                    self?.onMessageReceived?(p2pConnection.id, data)
                }
            }
            
            if let error = error {
                print("Receive error: \(error)")
                return
            }
            
            if isComplete {
                return
            }
            
            self?.receiveData(on: p2pConnection)
        }
    }
    
    func send(_ data: Data, to friendID: UUID) -> Bool {
        guard let p2pConnection = connections[friendID] else {
            return false
        }
        
        var lengthPrefix = UInt32(data.count).bigEndian
        var messageData = Data(bytes: &lengthPrefix, count: 4)
        messageData.append(data)
        
        p2pConnection.connection.send(content: messageData, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
        
        return true
    }
    
    func disconnect(friendID: UUID) {
        connections[friendID]?.connection.cancel()
        connections.removeValue(forKey: friendID)
    }
    
    func disconnectAll() {
        for (_, connection) in connections {
            connection.connection.cancel()
        }
        connections.removeAll()
    }
}

class P2PConnection: Identifiable {
    let id: UUID
    let connection: NWConnection
    let isOutgoing: Bool
    var aesKey: Data?
    var handshakeCompleted = false
    
    init(id: UUID, connection: NWConnection, isOutgoing: Bool) {
        self.id = id
        self.connection = connection
        self.isOutgoing = isOutgoing
    }
}
