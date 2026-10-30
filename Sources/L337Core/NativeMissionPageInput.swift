import Foundation

extension GameRuntime {
  /// Preserve Gallery's detail/list wheel semantics while binding them to the painted page.
  public func scriptPageGalleryScroll(_ amount: Int, expected: ScriptPagePresentation) {
    guard amount == -1 || amount == 1, expected.valid, case .gallery? = expected.page,
      expected == game.scriptPagePresentation
    else {
      game.notify("CONTACT CHANGED - REVIEW THE CURRENT PAGE")
      return
    }
    key("gallery-scroll:\(amount)")
  }
}
