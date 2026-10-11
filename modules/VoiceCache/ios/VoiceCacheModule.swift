import ExpoModulesCore
import Foundation

public class VoiceCacheModule: Module {
  private let maxAge: TimeInterval = 50 * 60
  private let maxBytes: Int64 = 20 * 1024 * 1024

  private var cacheDirectory: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("VoiceDubAI/VoiceProfiles", isDirectory: true)
  }

  public func definition() -> ModuleDefinition {
    Name("VoiceCache")

    AsyncFunction("cleanup") { () async -> [String: Any] in
      self.cleanCache()
      return self.status()
    }

    AsyncFunction("getStatus") { () async -> [String: Any] in
      self.cleanCache()
      return self.status()
    }

    AsyncFunction("clear") { () async -> [String: Any] in
      try? FileManager.default.removeItem(at: self.cacheDirectory)
      return self.status()
    }

    AsyncFunction("storeVoiceAsset") {
      (assetName: String, base64: String) async throws -> [String: Any] in

      self.cleanCache()

      guard let data = Data(base64Encoded: base64) else {
        throw NSError(domain: "VoiceDubAI", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Base64 inválido."])
      }

      try FileManager.default.createDirectory(
        at: self.cacheDirectory,
        withIntermediateDirectories: true
      )

      let safeName = assetName.replacingOccurrences(
        of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression
      )
      let filename = safeName.isEmpty ? UUID().uuidString : safeName
      let file = self.cacheDirectory
        .appendingPathComponent("\(filename).voicecache")

      try data.write(to: file, options: .atomic)

      if self.totalBytes() > self.maxBytes {
        try? FileManager.default.removeItem(at: self.cacheDirectory)
        return ["files": 0, "bytes": 0, "clearedForLimit": true]
      }

      return self.status()
    }
  }

  private func cleanCache() {
    let fm = FileManager.default

    guard let files = try? fm.contentsOfDirectory(
      at: cacheDirectory,
      includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
      options: [.skipsHiddenFiles]
    ) else { return }

    for file in files {
      let values = try? file.resourceValues(
        forKeys: [.contentModificationDateKey, .fileSizeKey]
      )
      let date = values?.contentModificationDate ?? .distantPast

      if Date().timeIntervalSince(date) > maxAge {
        try? fm.removeItem(at: file)
      }
    }

    if totalBytes() > maxBytes {
      try? fm.removeItem(at: cacheDirectory)
    }
  }

  private func totalBytes() -> Int64 {
    let files = (try? FileManager.default.contentsOfDirectory(
      at: cacheDirectory,
      includingPropertiesForKeys: [.fileSizeKey],
      options: [.skipsHiddenFiles]
    )) ?? []

    return files.reduce(Int64(0)) { total, file in
      total + Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
  }

  private func status() -> [String: Any] {
    let files = (try? FileManager.default.contentsOfDirectory(
      at: cacheDirectory,
      includingPropertiesForKeys: [.fileSizeKey],
      options: [.skipsHiddenFiles]
    )) ?? []

    return [
      "files": files.count,
      "bytes": totalBytes(),
      "maxBytes": maxBytes,
      "maxAgeSeconds": maxAge
    ]
  }
}
