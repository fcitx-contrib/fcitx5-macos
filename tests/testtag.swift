import Foundation

@_cdecl("main")
func main() -> Int {
// targetTag can be nil, version or latest. When latestAvailable is false, targetTag can't be latest.
// So it's a combination of 2*2*5 = 20 cases.

// Release to Release
  // latest >> stable = current
  assert(getTag(currentDebug: false, targetDebug: false, latestAvailable: false, targetTag: nil) == nil)
  // latest >> stable > current
  assert(getTag(currentDebug: false, targetDebug: false, latestAvailable: false, targetTag: "1") == "1")
  // latest = current
  assert(getTag(currentDebug: false, targetDebug: false, latestAvailable: true, targetTag: nil) == nil)
  // stable > current
  assert(getTag(currentDebug: false, targetDebug: false, latestAvailable: true, targetTag: "1") == "1")
  // latest > current >= stable
  assert(getTag(currentDebug: false, targetDebug: false, latestAvailable: true, targetTag: "latest") == "latest")

// Release to Debug
  // latest >> stable = current
  let _ = getTag(currentDebug: false, targetDebug: true, latestAvailable: false, targetTag: nil) // Switch button not clickable.
  // latest >> stable > current
  let _ = getTag(currentDebug: false, targetDebug: true, latestAvailable: false, targetTag: "1") // Switch button not clickable.
  // latest = current
  assert(getTag(currentDebug: false, targetDebug: true, latestAvailable: true, targetTag: nil) == "latest")
  // stable > current
  assert(getTag(currentDebug: false, targetDebug: true, latestAvailable: true, targetTag: "1") == "latest")
  // latest > current >= stable
  assert(getTag(currentDebug: false, targetDebug: true, latestAvailable: true, targetTag: "latest") == "latest")

// Debug to Release
  // latest >> stable = current
  let _ = getTag(currentDebug: true, targetDebug: false, latestAvailable: false, targetTag: nil) // We don't provide debug stable.
  // latest >> stable > current
  assert(getTag(currentDebug: true, targetDebug: false, latestAvailable: false, targetTag: "1") == "1")
  // latest = current
  assert(getTag(currentDebug: true, targetDebug: false, latestAvailable: true, targetTag: nil) == "latest")
  // stable > current
  assert(getTag(currentDebug: true, targetDebug: false, latestAvailable: true, targetTag: "1") == "1")
  // latest > current >= stable
  assert(getTag(currentDebug: true, targetDebug: false, latestAvailable: true, targetTag: "latest") == "latest")

// Debug to Debug
  // latest >> stable = current
  let _ = getTag(currentDebug: true, targetDebug: true, latestAvailable: false, targetTag: nil) // We don't provide debug stable.
  // latest >> stable > current
  let _ = getTag(currentDebug: true, targetDebug: true, latestAvailable: false, targetTag: "1") // Update button not clickable.
  // latest = current
  let _ = getTag(currentDebug: true, targetDebug: true, latestAvailable: true, targetTag: nil) // Update button not clickable.
  // stable > current
  assert(getTag(currentDebug: true, targetDebug: true, latestAvailable: true, targetTag: "1") == "latest")
  // latest > current >= stable
  assert(getTag(currentDebug: true, targetDebug: true, latestAvailable: true, targetTag: "latest") == "latest")

  return 0
}
