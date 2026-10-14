import Foundation

extension Game {
  public var blackjackGalleryMission: GalleryMission {
    packGallery(missionPacks.entries.first { $0.pack.mission.binding == "blackjack" }!)
  }
}
