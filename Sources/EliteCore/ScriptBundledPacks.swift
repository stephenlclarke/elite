import Foundation

extension ScriptPackLibrary {
  public static var userDirectory: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      ".xyzzy/elite/script-packs")
  }

  static var bundledCourierDirectory: URL {
    let resources =
      Bundle.main.resourceURL.flatMap {
        Bundle(url: $0.appendingPathComponent("Elite_EliteCore.bundle"))
      } ?? Bundle.module
    return resources.resourceURL!.appendingPathComponent("ScriptPacks/generated-couriers")
  }

  static var bundledBondedFreightDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-bonded-freight")
  }

  static func defaultLibrary(directory: URL = userDirectory) -> (
    packs: [ScriptPack], errors: [String]
  ) {
    // Keep installed versions and their original ordering. Only identical content deduplicates.
    var library = installed(directory: directory)
    do {
      let courier = try read(bundledCourierDirectory)
      if !library.packs.contains(where: { $0.digest == courier.digest }) {
        library.packs.append(courier)
      }
    } catch {
      library.errors.append("Bundled courier pack: " + error.localizedDescription)
    }
    do {
      let bonded = try read(bundledBondedFreightDirectory)
      if !library.packs.contains(where: { $0.digest == bonded.digest }) {
        library.packs.append(bonded)
      }
    } catch {
      library.errors.append("Bundled bonded freight pack: " + error.localizedDescription)
    }
    return library
  }
}
