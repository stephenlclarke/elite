import AVFoundation
import EliteCore
import Foundation

@MainActor
final class AudioPresenter {
  private var players: [AVAudioPlayer] = []
  private let speech = AVSpeechSynthesizer()
  private var previous = Game()
  private var feed = SpeechFeed()
  func update(_ game: Game) {
    players.removeAll { !$0.isPlaying }
    if game.ecmControl.epoch != previous.ecmControl.epoch {
      for player in players { player.stop() }
    } else {
      if game.laserFlash > 0 && previous.laserFlash == 0 { play(.laser) }
      if previous.docked && !game.docked { play(.launch) }
      if !previous.docked && game.docked { play(.dock) }
      if game.commander.kills > previous.commander.kills { play(.explosion) }
      if game.message != previous.message && game.messageTime > 0 {
        play(game.message == "E.C.M." ? .ecm : .ping)
      }
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
