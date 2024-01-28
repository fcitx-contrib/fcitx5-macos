import Foundation

// In fcitx, a "config" can be either an option or a container for
// options.
public struct Config: Identifiable {
  public let path: String
  public let description: String
  public let kind: ConfigKind
  public let id = UUID()
}

public enum ConfigKind {
  case group([Config])
  case option(any Option)
}
