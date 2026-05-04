import SwiftUI
import AVFoundation

struct RelaxGameView: View {
    @State private var gameEngine = DinoGameEngine()
    @State private var audioPlayer: AVQueuePlayer?
    @State private var audioFiles: [URL] = []
    @State private var isGameStarted = false
    @State private var score = 0
    @State private var gameOver = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerText
            
            gameArea
            
            controlButtons
        }
        .onAppear {
            loadAudioFiles()
            setupKeyboardMonitor()
        }
    }
    
    private var headerText: some View {
        Text("Ciallo～(∠・ω< )⌒★")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [.pink, .purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.top, 20)
            .padding(.bottom, 10)
    }
    
    private var gameArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                )
            
            if isGameStarted && !gameOver {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        GroundView()
                        
                        DinoView(y: gameEngine.dinoY, isJumping: gameEngine.isJumping)
                        
                        ForEach(gameEngine.obstacles) { obstacle in
                            ObstacleView(obstacle: obstacle)
                        }
                        
                        if gameEngine.showCactus {
                            CactusView()
                        }
                        
                        VStack {
                            HStack {
                                Text("得分: \(score)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("HI: \(gameEngine.highScore)")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            
                            Spacer()
                        }
                    }
                }
            } else if gameOver {
                VStack(spacing: 16) {
                    Text("游戏结束!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("得分: \(score)")
                        .font(.title)
                    
                    Text("最高分: \(gameEngine.highScore)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button {
                        resetGame()
                    } label: {
                        Label("再来一次", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 10)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("点击开始游戏")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("使用空格键或方向键控制")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        startGame()
                    } label: {
                        Label("开始", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .padding()
    }
    
    private var controlButtons: some View {
        HStack(spacing: 40) {
            Button {
                jump()
            } label: {
                VStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 50))
                    Text("跳跃")
                        .font(.caption)
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(!isGameStarted || gameOver)
            
            Button {
                duck()
            } label: {
                VStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 50))
                    Text("下蹲")
                        .font(.caption)
                }
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(!isGameStarted || gameOver)
        }
        .padding(.vertical, 20)
    }
    
    private func loadAudioFiles() {
        let audioDir = Bundle.main.resourceURL?.appendingPathComponent("CialloAudio") ?? URL(fileURLWithPath: "")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil)
            audioFiles = files.filter { $0.pathExtension == "mp3" }
        } catch {
            print("Failed to load audio files: \(error)")
        }
    }
    
    private func playRandomAudio() {
        guard !audioFiles.isEmpty else { return }
        
        let randomFile = audioFiles.randomElement()!
        
        if audioPlayer == nil {
            audioPlayer = AVQueuePlayer()
        }
        
        let playerItem = AVPlayerItem(url: randomFile)
        audioPlayer?.removeAllItems()
        audioPlayer?.insert(playerItem, after: nil)
        audioPlayer?.play()
    }
    
    private func setupKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isGameStarted && !gameOver else { return event }
            
            switch event.keyCode {
            case 49, 126:
                jump()
                return nil
            case 125:
                duck()
                return nil
            default:
                return event
            }
        }
    }
    
    private func startGame() {
        isGameStarted = true
        gameOver = false
        score = 0
        
        gameEngine.start()
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if !isGameStarted || gameOver {
                timer.invalidate()
                return
            }
            
            gameEngine.update()
            score = gameEngine.score
            
            if gameEngine.isGameOver {
                gameOver = true
                timer.invalidate()
            }
        }
    }
    
    private func resetGame() {
        gameEngine.reset()
        gameOver = false
        score = 0
        startGame()
    }
    
    private func jump() {
        gameEngine.jump()
        playRandomAudio()
    }
    
    private func duck() {
        gameEngine.duck()
        playRandomAudio()
    }
}

class DinoGameEngine: ObservableObject {
    @Published var dinoY: CGFloat = 0
    @Published var isJumping = false
    @Published var isDucking = false
    @Published var obstacles: [Obstacle] = []
    @Published var showCactus = false
    @Published var score = 0
    @Published var highScore = 0
    @Published var isGameOver = false
    
    private var dinoVelocity: CGFloat = 0
    private let gravity: CGFloat = 0.8
    private let jumpStrength: CGFloat = -15
    private let groundY: CGFloat = 0
    
    private var obstacleTimer: Timer?
    private var gameSpeed: Double = 5
    
    func start() {
        isGameOver = false
        score = 0
        obstacles = []
        dinoY = groundY
        dinoVelocity = 0
        
        obstacleTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.spawnObstacle()
        }
    }
    
    func reset() {
        obstacleTimer?.invalidate()
        obstacleTimer = nil
    }
    
    func update() {
        updateDino()
        updateObstacles()
        updateScore()
        checkCollisions()
    }
    
    func jump() {
        guard !isJumping && !isDucking else { return }
        isJumping = true
        dinoVelocity = jumpStrength
    }
    
    func duck() {
        guard !isJumping else { return }
        isDucking = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isDucking = false
        }
    }
    
    private func updateDino() {
        if isJumping {
            dinoY += dinoVelocity
            dinoVelocity += gravity
            
            if dinoY >= groundY {
                dinoY = groundY
                isJumping = false
                dinoVelocity = 0
            }
        }
    }
    
    private func updateObstacles() {
        for i in obstacles.indices {
            obstacles[i].x -= gameSpeed
        }
        
        obstacles.removeAll { $0.x < -50 }
    }
    
    private func spawnObstacle() {
        let type: ObstacleType = Bool.random() ? .cactus : .bird
        let obstacle = Obstacle(type: type, x: 400)
        obstacles.append(obstacle)
    }
    
    private func updateScore() {
        score += 1
        
        if score % 500 == 0 {
            gameSpeed += 0.5
        }
    }
    
    private func checkCollisions() {
        let dinoRect = CGRect(x: 50, y: dinoY, width: isDucking ? 50 : 40, height: isDucking ? 25 : 50)
        
        for obstacle in obstacles {
            let obstacleRect = CGRect(x: obstacle.x, y: obstacle.y, width: obstacle.width, height: obstacle.height)
            
            if dinoRect.intersects(obstacleRect) {
                isGameOver = true
                if score > highScore {
                    highScore = score
                }
                reset()
                break
            }
        }
    }
}

struct Obstacle: Identifiable {
    let id = UUID()
    let type: ObstacleType
    var x: CGFloat
    
    var width: CGFloat {
        switch type {
        case .cactus: return 30
        case .bird: return 40
        }
    }
    
    var height: CGFloat {
        switch type {
        case .cactus: return 50
        case .bird: return 30
        }
    }
    
    var y: CGFloat {
        switch type {
        case .cactus: return 0
        case .bird: return 50
        }
    }
}

enum ObstacleType {
    case cactus
    case bird
}

struct DinoView: View {
    let y: CGFloat
    let isJumping: Bool
    
    var body: some View {
        Image(systemName: "hare.fill")
            .resizable()
            .frame(width: 40, height: 50)
            .foregroundColor(.orange)
            .offset(y: -y)
            .scaleEffect(y: isJumping ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isJumping)
            .position(x: 70, y: 200 - y)
    }
}

struct CactusView: View {
    var body: some View {
        Image(systemName: "leaf.fill")
            .resizable()
            .frame(width: 30, height: 50)
            .foregroundColor(.green)
            .position(x: 350, y: 200)
    }
}

struct ObstacleView: View {
    let obstacle: Obstacle
    
    var body: some View {
        Image(systemName: obstacle.type == .cactus ? "leaf.fill" : "bird.fill")
            .resizable()
            .frame(width: obstacle.width, height: obstacle.height)
            .foregroundColor(obstacle.type == .cactus ? .green : .brown)
            .position(x: obstacle.x, y: 200 - obstacle.y)
    }
}

struct GroundView: View {
    var body: some View {
        Rectangle()
            .fill(Color.brown.opacity(0.3))
            .frame(height: 2)
            .position(y: 225)
    }
}
