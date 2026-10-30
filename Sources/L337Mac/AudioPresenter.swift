import AVFoundation
import Foundation
import L337Core

@MainActor
final class AudioPresenter {
  private(set) var players: [AVAudioPlayer] = []
  private let speech = AVSpeechSynthesizer()
  // Keep transition facts without retaining a second world and its copy-on-write storage.
  private var previousDocked = true
  private var previousKills = 0
  private var previousMessage = ""
  private var previousSpeech = false
  private var previousSpeechEpoch: UUID?
  private var feed = SpeechFeed()
  private var dischargeFeed = DischargeAudioFeed()
  private var dischargeEpoch: UUID?
  private var cutterPlayer: AVAudioPlayer?
  private(set) var isShutdown = false

  /// Closing a view is terminal, including for a frame already suspended in an actor call.
  func shutdown() {
    guard !isShutdown else { return }
    isShutdown = true
    cutterPlayer?.stop()
    cutterPlayer = nil
    for player in players { player.stop() }
    players.removeAll()
    speech.stopSpeaking(at: .immediate)
  }

  func update(_ game: Game) {
    guard !isShutdown else { return }
    players.removeAll { !$0.isPlaying }
    if dischargeEpoch != game.dischargeAudio.epoch {
      dischargeEpoch = game.dischargeAudio.epoch
      cutterPlayer?.stop()
      cutterPlayer = nil
    }
    for tool in dischargeFeed.update(game.dischargeAudio) {
      if tool == .salvageCutter {
        // Continuous section work produces events each tick; keep one cutter sound active.
        if cutterPlayer?.isPlaying != true { cutterPlayer = play(.laser) }
      } else {
        play(.laser)
      }
    }
    if previousDocked && !game.docked { play(.launch) }
    if !previousDocked && game.docked { play(.dock) }
    if game.commander.kills > previousKills { play(.explosion) }
    if game.message != previousMessage && game.messageTime > 0 {
      play(game.message == "E.C.M." ? .ecm : .ping)
    }
    if (!game.commander.speech && previousSpeech)
      || game.ecmControl.epoch != previousSpeechEpoch
    {
      speech.stopSpeaking(at: .immediate)
    }
    if let text = feed.update(game, busy: speech.isSpeaking) {
      speech.speak(AVSpeechUtterance(string: text))
    }
    previousDocked = game.docked
    previousKills = game.commander.kills
    previousMessage = game.message
    previousSpeech = game.commander.speech
    previousSpeechEpoch = game.ecmControl.epoch
  }
  @discardableResult
  private func play(_ effect: SoundEffect) -> AVAudioPlayer? {
    guard !isShutdown else { return nil }
    do {
      let player = try AVAudioPlayer(data: effect.wav())
      player.volume = 0.4
      if player.play() {
        players.append(player)
        return player
      }
    } catch {
      // A missing audio output must not interrupt the simulation.
    }
    return nil
  }
}
