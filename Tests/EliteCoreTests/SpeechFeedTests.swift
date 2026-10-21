import Testing

@testable import EliteCore

@Test func speechNamespaceHistoryStaysBoundedAndDropsOnlyTheDepartedQueue() {
  var live = Game(executive: false)
  live.screen = .status
  live.commander.speech = true
  live.notify("LIVE")
  var feed = SpeechFeed()
  #expect(feed.update(live, busy: false) == "LIVE")
  for index in 0..<80 {
    var trial = Game(executive: false)
    trial.screen = .status
    trial.commander.speech = true
    trial.notify("QUEUED TRIAL \(index)")
    #expect(feed.update(trial, busy: true) == nil)
    #expect(feed.update(live, busy: false) == nil)
    #expect(feed.retainedNamespaceCount <= SpeechFeed.namespaceLimit)
  }
  #expect(feed.retainedNamespaceCount == SpeechFeed.namespaceLimit)
  live.notify("NEW LIVE")
  #expect(feed.update(live, busy: false) == "NEW LIVE")
  #expect(feed.update(live, busy: false) == nil)
}

@Test func mutedAndBusySpeechEventsRemainConsumedAcrossNamespaceReturns() {
  var live = Game(executive: false)
  live.screen = .status
  live.notify("MUTED")
  var trial = Game(executive: false)
  trial.screen = .status
  trial.commander.speech = true
  var feed = SpeechFeed()
  #expect(feed.update(live, busy: false) == nil)
  #expect(feed.update(trial, busy: false) == nil)
  live.commander.speech = true
  #expect(feed.update(live, busy: false) == nil)
  live.notify("SAME NAMESPACE QUEUE")
  #expect(feed.update(live, busy: true) == nil)
  #expect(feed.update(live, busy: false) == "SAME NAMESPACE QUEUE")
  live.notify("DEPARTED QUEUE")
  #expect(feed.update(live, busy: true) == nil)
  trial.notify("TRIAL")
  #expect(feed.update(trial, busy: false) == "TRIAL")
  #expect(feed.update(live, busy: false) == nil)
  live.notify("NEW AFTER RETURN")
  #expect(feed.update(live, busy: false) == "NEW AFTER RETURN")
  #expect(feed.update(live, busy: false) == nil)
}

@Test func titleSpeechTracksEachNamespaceAndOnlyActualScreenTransitions() {
  var live = Game(executive: false)
  live.screen = .title
  live.commander.speech = true
  var trial = Game(executive: false)
  trial.screen = .title
  trial.commander.speech = true
  var feed = SpeechFeed()
  #expect(feed.update(live, busy: false) == "Elite")
  #expect(feed.update(trial, busy: false) == "Elite")
  trial.screen = .status
  #expect(feed.update(trial, busy: false) == nil)
  #expect(feed.update(live, busy: false) == nil)
  live.screen = .status
  #expect(feed.update(live, busy: false) == nil)
  live.screen = .title
  #expect(feed.update(live, busy: false) == "Elite")
  #expect(feed.update(live, busy: false) == nil)
  trial.ecmControl = ECMControl()
  trial.screen = .title
  trial.commander.speech = false
  #expect(feed.update(trial, busy: false) == nil)
  trial.commander.speech = true
  #expect(feed.update(trial, busy: false) == nil)
}

@Test func olderSpeechSnapshotsCannotRewindAnObservedNamespaceCursor() {
  var live = Game(executive: false)
  live.screen = .status
  live.commander.speech = true
  live.notify("FIRST")
  let older = live
  var feed = SpeechFeed()
  #expect(feed.update(live, busy: false) == "FIRST")
  live.notify("SECOND")
  #expect(feed.update(live, busy: false) == "SECOND")
  #expect(feed.update(older, busy: false) == nil)
  #expect(feed.update(live, busy: false) == nil)
  live.notify("THIRD")
  #expect(feed.update(live, busy: false) == "THIRD")
  #expect(feed.update(live, busy: false) == nil)
}
