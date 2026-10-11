import ExpoModulesCore
import Foundation

/// Bounded, inactivity-based cache for voice profiles/assets.
/// Each file is an independent cache entry. Reads update its modification date,
/// so the size limit evicts least-recently-used entries instead of wiping everything.
public class VoiceCacheModule: Module {
  private let maxAge: TimeInterval = 50 * 60
  private let maxBytes: Int64 = 20 * 1024 * 1024
  private let fileExtension = "voicecache"
  private let lock = NSRecursiveLock()

  private var cacheDirectory: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("VoiceDubAI/VoiceProfiles", isDirectory: true)
  }

  public func definition() -> ModuleDefinition {
    Name("VoiceCache")

    AsyncFunction("cleanup") { () async -> [String: Any] in
      self.lock.lock(); defer { self.lock.unlock() }
      self.cleanCache()
      return self.status()
    }

    AsyncFunction("getStatus") { () async -> [String: Any] in
      self.lock.lock(); defer { self.lock.unlock() }
      self.cleanCache()
      return self.status()
    }

    AsyncFunction("clear") { () async -> [String: Any] in
      self.lock.lock(); defer { self.lock.unlock() }
      try? FileManager.default.removeItem(at: self.cacheDirectory)
      return self.status()
    }

    /// Store a profile/audio asset under a stable key. Oldest entries are evicted
    /// until the cache fits. A single asset larger than the entire budget is rejected.
    AsyncFunction("storeVoiceAsset") {
      (assetName: String, base64: String) async throws -> [String: Any] in
      self.lock.lock(); defer { self.lock.unlock() }
      self.cleanCache()

      guard let data = Data(base64Encoded: base64) else {
        throw NSError(domain: "VoiceDubAI", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Base64 inválido."])
      }
      guard Int64(data.count) <= self.maxBytes else {
        throw NSError(domain: "VoiceDubAI", code: 2,
          userInfo: [NSLocalizedDescriptionKey: "El recurso supera el límite de caché de 20 MB."])
      }

      try FileManager.default.createDirectory(
        at: self.cacheDirectory, withIntermediateDirectories: true
      )
      let file = self.fileURL(for: assetName)
      try data.write(to: file, options: .atomic)
      try self.touch(file)
      self.evictOldestUntilWithinLimit()
      return self.status()
    }

    /// Return a cached profile as Base64 and refresh its inactivity timer.
    AsyncFunction("getVoiceAsset") { (assetName: String) async throws -> String? in
      self.lock.lock(); defer { self.lock.unlock() }
      self.cleanCache()
      let file = self.fileURL(for: assetName)
      guard FileManager.default.fileExists(atPath: file.path) else { return nil }
      do {
        let data = try Data(contentsOf: file)
        try self.touch(file)
        return data.base64EncodedString()
      } catch {
        throw NSError(domain: "VoiceDubAI", code: 3,
          userInfo: [NSLocalizedDescriptionKey: "No se pudo leer el perfil de voz: \\(error.localizedDescription)"])
      }
    }

    AsyncFunction("deleteVoiceAsset") { (assetName: String) async -> [String: Any] in
      self.lock.lock(); defer { self.lock.unlock() }
      try? FileManager.default.removeItem(at: self.fileURL(for: assetName))
      return self.status()
    }
  }

  private func fileURL(for name: String) -> URL {
    let safeName = name.replacingOccurrences(
      of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression
    )
    let filename = safeName.isEmpty ? "unnamed" : String(safeName.prefix(120))
    return cacheDirectory.appendingPathComponent("\\(filename).\\(fileExtension)")
  }

  private func touch(_ url: URL) throws {
    try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
  }

  private func cacheFiles() -> [URL] {
    (try? FileManager.default.contentsOfDirectory(
      at: cacheDirectory,
      includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
      options: [.skipsHiddenFiles]
    ))?.filter { $0.pathExtension == fileExtension } ?? []
  }

  private func cleanCache() {
    let now = Date()
    for file in cacheFiles() {
      let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      if now.timeIntervalSince(date) > maxAge {
        try? FileManager.default.removeItem(at: file)
      }
    }
    evictOldestUntilWithinLimit()
  }

  private func evictOldestUntilWithinLimit() {
    var files = cacheFiles().map { file -> (url: URL, date: Date, size: Int64) in
      let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
      return (file, values?.contentModificationDate ?? .distantPast, Int64(values?.fileSize ?? 0))
    }
    var total = files.reduce(Int64(0)) { $0 + $1.size }
    files.sort { $0.date < $1.date }
    while total > maxBytes, let oldest = files.first {
      try? FileManager.default.removeItem(at: oldest.url)
      total -= oldest.size
      files.removeFirst()
    }
  }

  private func totalBytes() -> Int64 {
    cacheFiles().reduce(Int64(0)) { total, file in
      total + Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
  }

  private func status() -> [String: Any] {
    return [
      "files": cacheFiles().count,
      "bytes": totalBytes(),
      "maxBytes": maxBytes,
      "maxAgeSeconds": maxAge,
      "evictionPolicy": "least-recently-used"
    ]
  }
}
