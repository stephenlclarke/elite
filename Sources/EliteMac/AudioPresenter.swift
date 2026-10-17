import AVFoundation
import EliteCore
import Foundation

@MainActor
final class AudioPresenter {
  private var players: [AVAudioPlayer] = []
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
  func update(_ game: Game) {
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
