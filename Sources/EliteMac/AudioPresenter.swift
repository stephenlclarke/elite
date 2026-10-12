import AVFoundation
import EliteCore

@MainActor
final class AudioPresenter {
  private var players: [AVAudioPlayer] = []
  private let speech = AVSpeechSynthesizer()
  private var previous = Game()
  private var lastSpoken = ""
  func update(_ game: Game) {
    players.removeAll { !$0.isPlaying }
    if game.laserFlash > 0 && previous.laserFlash == 0 { play(.laser) }
    if previous.docked && !game.docked { play(.launch) }
    if !previous.docked && game.docked { play(.dock) }
    if game.commander.kills > previous.commander.kills { play(.explosion) }
    if game.message != previous.message && game.messageTime > 0 {
      play(game.message == "E.C.M." ? .ecm : .ping)
    }
    if game.commander.speech {
      let text = game.screen == .title ? "Elite" : spokenMessage(game)
      if !text.isEmpty && text != lastSpoken {
        speech.speak(AVSpeechUtterance(string: text))
        lastSpoken = text
      }
    } else {
      lastSpoken = ""
      speech.stopSpeaking(at: .immediate)
    }
    previous = game
  }
  private func spokenMessage(_ game: Game) -> String {
    if game.messageTime <= 0 { return "" }
    if game.message.hasPrefix("ENERGY LOW") { return "Energy low" }
    if game.message.hasPrefix("INCOMING MISSILE") { return "Incoming missile" }
    return ""
  }
  private func play(_ effect: SoundEffect) {
    do {
      let player = try AVAudioPlayer(data: effect.wav())
      player.volume = 0.4
      if player.play() { players.append(player) }
    } catch {
      // A missing audio output must not interrupt the simulation.
    }
  }
}
