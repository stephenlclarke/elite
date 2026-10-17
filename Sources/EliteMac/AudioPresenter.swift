import AVFoundation
import EliteCore
import Foundation

@MainActor
final class AudioPresenter {
  private var players: [AVAudioPlayer] = []
  private let speech = AVSpeechSynthesizer()
  private var previous = Game()
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
    if previous.docked && !game.docked { play(.launch) }
    if !previous.docked && game.docked { play(.dock) }
    if game.commander.kills > previous.commander.kills { play(.explosion) }
    if game.message != previous.message && game.messageTime > 0 {
      play(game.message == "E.C.M." ? .ecm : .ping)
    }
    if (!game.commander.speech && previous.commander.speech)
      || game.ecmControl.epoch != previous.ecmControl.epoch
    {
      speech.stopSpeaking(at: .immediate)
    }
    if let text = feed.update(game, busy: speech.isSpeaking) {
      speech.speak(AVSpeechUtterance(string: text))
    }
    previous = game
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
