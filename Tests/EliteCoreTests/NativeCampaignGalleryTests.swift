import AppKit
import Testing

@testable import EliteCore
@testable import EliteMac

@Suite(.serialized)
struct NativeCampaignGalleryTests {
  @MainActor @Test func nativeCampaignGalleryRendersRelationshipsAndTrialReviewAtBothSizes() throws
  {
    let fixture = try CampaignGalleryFixture()
    defer { fixture.clean() }
    var game = fixture.game()
    let (parent, child) = try fixture.start(&game)
    let before = game.commander
    for (width, height, scale) in [(512, 518, 1), (1512, 982, 2)] {
      game.viewportWidth = Double(width)
      game.viewportHeight = Double(height)
      for (name, id) in [("parent", parent), ("child", child)] {
        try fixture.select(id, game: &game)
        game.gallery.campaignLinks = false
        try capture(game, name: name, width: width, height: height, scale: scale)
        game.key("pagedown")
        #expect(game.gallery.scroll > 0 || width == 1512)
        game.key("return")
        try capture(game, name: name + "-links", width: width, height: height, scale: scale)
      }
      game.openCampaignTrialReview()
      #expect(game.gallery.campaignReview?.root == parent)
      #expect(!game.gallery.campaignStartSelected)
      try capture(game, name: "root-review", width: width, height: height, scale: scale)
      game.key("escape")
    }
    #expect(game.commander == before)
  }

  @MainActor private func capture(
    _ game: Game, name: String, width: Int, height: Int, scale: Int
  ) throws {
    let frame = Display.gallery(game, width: Double(width), height: Double(height))
    #expect(
      frame.labels.allSatisfy {
        $0.bounds.x >= 0 && $0.bounds.maxX <= Double(width)
          && $0.bounds.y >= 0 && $0.bounds.maxY <= Double(height)
      })
    let image = try #require(imageForGame(game, width: width, height: height, scale: scale))
    #expect(image.width == width * scale && image.height == height * scale)
    if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let directory = URL(fileURLWithPath: path, isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let bytes = try #require(
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try bytes.write(to: directory.appendingPathComponent("campaign-gallery-\(name)-\(width).png"))
    }
  }
}
