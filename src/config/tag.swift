func getTag(currentDebug: Bool, targetDebug: Bool, latestAvailable: Bool, targetTag: String?)
  -> String?
{
  if targetDebug && latestAvailable {
    return "latest"
  }
  if targetTag != nil {
    return targetTag
  }
  if currentDebug && !targetDebug && latestAvailable {
    return "latest"
  }
  return nil
}
