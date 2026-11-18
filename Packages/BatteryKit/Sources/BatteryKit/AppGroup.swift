import Foundation

public enum AppGroup {
  // A Team ID prefix lets macOS accept the group without a provisioning profile.
  public static var identifier: String {
    Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String ?? "group.unknown"
  }
}
