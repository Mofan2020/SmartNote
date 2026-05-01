import Foundation
import AVFoundation
import AppKit

class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()
    
    @Published var isSpeaking = false
    @Published var isPaused = false
    @Published var availableVoices: [NSSpeechSynthesizer.VoiceName] = []
    @Published var currentVoice: String = "Ting-Ting"
    @Published var speechRate: Double = 0.5
    @Published var volume: Double = 1.0
    
    private var synthesizer: NSSpeechSynthesizer?
    private var currentText: String = ""
    private var currentTextIndex: String.Index?
    
    private override init() {
        super.init()
        loadAvailableVoices()
        setupSynthesizer()
    }
    
    private func setupSynthesizer() {
        let voiceName = NSSpeechSynthesizer.VoiceName(rawValue: currentVoice)
        synthesizer = NSSpeechSynthesizer(voice: voiceName)
        synthesizer?.rate = Float(speechRate * 200 + 100)
        synthesizer?.volume = Float(volume)
        synthesizer?.delegate = self
    }
    
    func loadAvailableVoices() {
        availableVoices = NSSpeechSynthesizer.availableVoices
    }
    
    func setVoice(_ voiceName: String) {
        currentVoice = voiceName
        let voice = NSSpeechSynthesizer.VoiceName(rawValue: voiceName)
        synthesizer?.setVoice(voice)
    }
    
    func setRate(_ rate: Double) {
        speechRate = rate
        synthesizer?.rate = Float(rate * 200 + 100)
    }
    
    func setVolume(_ vol: Double) {
        volume = vol
        synthesizer?.volume = Float(vol)
    }
    
    func speak(_ text: String) {
        stop()
        currentText = text
        
        if let synthesizer = synthesizer {
            isSpeaking = true
            isPaused = false
            synthesizer.startSpeaking(text)
        }
    }
    
    func pause() {
        if isSpeaking && !isPaused {
            synthesizer?.pauseSpeaking(at: .wordBoundary)
            isPaused = true
        }
    }
    
    func resume() {
        if isPaused {
            synthesizer?.continueSpeaking()
            isPaused = false
        }
    }
    
    func stop() {
        synthesizer?.stopSpeaking()
        isSpeaking = false
        isPaused = false
        currentText = ""
    }
    
    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }
    
    func getVoiceDisplayName(_ voiceName: String) -> String {
        let voice = NSSpeechSynthesizer.VoiceName(rawValue: voiceName)
        let attributes = NSSpeechSynthesizer.attributes(forVoice: voice)
        return attributes[NSSpeechSynthesizer.VoiceAttributeKey.name] as? String ?? voiceName
    }
    
    func isChineseVoice(_ voiceName: String) -> Bool {
        let chineseVoices = ["Ting-Ting", "Mei-Jia", "Yu-Shu", "Sin-Ji", "Han-Yu", "Zhong"]
        return chineseVoices.contains { voiceName.contains($0) }
    }
    
    func getChineseVoices() -> [String] {
        return availableVoices.map { $0.rawValue }.filter { isChineseVoice($0) }
    }
    
    func getDefaultChineseVoice() -> String {
        let chineseVoices = getChineseVoices()
        if chineseVoices.isEmpty {
            return currentVoice
        }
        if chineseVoices.contains(where: { $0 == "Ting-Ting" }) {
            return "Ting-Ting"
        }
        return chineseVoices.first ?? currentVoice
    }
}

extension SpeechService: NSSpeechSynthesizerDelegate {
    func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
            self.currentText = ""
        }
    }
}
