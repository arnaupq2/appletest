import ExpoModulesCore
import Foundation
import AVFoundation
import FluidAudio

/// Local voice cloning and speech synthesis. Model files are downloaded by FluidAudio
/// on first use; synthesis itself runs on-device once the language pack is available.
public class VoiceDubEngineModule: Module {
  private var managers: [String: PocketTtsManager] = [:]
  private var player: AVAudioPlayer?
  private var recorder: AVAudioRecorder?
  private var activeRecordingURL: URL?
  private let workDirectory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("VoiceDubAI/VoiceEngine", isDirectory: true)

  public func definition() -> ModuleDefinition {
    Name("VoiceDubEngine")

    AsyncFunction("getStatus") { () async -> [String: Any] in
      return [
        "available": true,
        "engine": "FluidAudio PocketTTS",
        "supportedLanguages": ["Spanish", "German", "English", "French", "Italian", "Portuguese"],
        "note": "Voice cloning requires a clean 1–30 second audio sample."
      ]
    }

    AsyncFunction("startVoiceSampleRecording") { () async throws -> [String: Any] in
      let granted: Bool = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in continuation.resume(returning: allowed) }
      }
      guard granted else { throw self.error(20, "Permite el micrófono en Ajustes para grabar una muestra de voz.") }
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
      try session.setActive(true)
      let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("VoiceDubAI/VoiceSamples", isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let url = folder.appendingPathComponent(UUID().uuidString + ".m4a")
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
      ]
      let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
      guard audioRecorder.prepareToRecord(), audioRecorder.record() else {
        throw self.error(21, "No se pudo iniciar la grabación de la muestra.")
      }
      self.recorder = audioRecorder
      self.activeRecordingURL = url
      return ["recording": true, "uri": url.absoluteString]
    }

    AsyncFunction("stopVoiceSampleRecording") { () async throws -> String in
      guard let audioRecorder = self.recorder, let url = self.activeRecordingURL else {
        throw self.error(22, "No hay ninguna muestra de voz grabándose.")
      }
      let duration = audioRecorder.currentTime
      audioRecorder.stop()
      self.recorder = nil
      self.activeRecordingURL = nil
      guard duration >= 1 else {
        try? FileManager.default.removeItem(at: url)
        throw self.error(23, "Graba al menos 1 segundo; lo recomendable son entre 5 y 15 segundos de una sola persona.")
      }
      return url.absoluteString
    }

    AsyncFunction("cloneVoiceFromFile") { (audioUri: String) async throws -> [String: Any] in
      let sourceURL = self.fileURL(from: audioUri)
      let isAppRecordedSample = sourceURL.path.contains("/VoiceDubAI/VoiceSamples/")
      defer {
        if isAppRecordedSample { try? FileManager.default.removeItem(at: sourceURL) }
      }
      guard FileManager.default.fileExists(atPath: sourceURL.path) else {
        throw self.error(10, "No se encuentra el archivo de audio seleccionado.")
      }
      try FileManager.default.createDirectory(at: self.workDirectory, withIntermediateDirectories: true)
      let manager = try await self.manager(for: "Spanish")
      let voiceData = try await manager.cloneVoice(from: sourceURL)
      let profileURL = self.workDirectory.appendingPathComponent(UUID().uuidString + ".voice")
      defer { try? FileManager.default.removeItem(at: profileURL) }
      try manager.saveClonedVoice(voiceData, to: profileURL)
      let data = try Data(contentsOf: profileURL)
      guard !data.isEmpty else { throw self.error(11, "El motor devolvió un perfil de voz vacío.") }
      return [
        "profileBase64": data.base64EncodedString(),
        "profileBytes": data.count,
        "engine": "PocketTTS",
        "source": sourceURL.lastPathComponent
      ]
    }

    AsyncFunction("synthesizeWithVoice") { (text: String, profileBase64: String, language: String) async throws -> [String: Any] in
      let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cleanText.isEmpty else { throw self.error(12, "No hay texto para sintetizar.") }
      guard let profileData = Data(base64Encoded: profileBase64), !profileData.isEmpty else {
        throw self.error(13, "El perfil de voz de la caché no es válido.")
      }
      try FileManager.default.createDirectory(at: self.workDirectory, withIntermediateDirectories: true)
      let profileURL = self.workDirectory.appendingPathComponent(UUID().uuidString + ".voice")
      let outputURL = self.workDirectory.appendingPathComponent(UUID().uuidString + ".wav")
      defer {
        try? FileManager.default.removeItem(at: profileURL)
        // Keep the current output until the player finishes; the next call cleans old outputs.
        self.removeOldOutputs(except: outputURL)
      }
      try profileData.write(to: profileURL, options: .atomic)
      let manager = try await self.manager(for: language)
      let voiceData = try manager.loadClonedVoice(from: profileURL)
      let audioData = try await manager.synthesize(text: cleanText, voiceData: voiceData)
      try audioData.write(to: outputURL, options: .atomic)

      let audioPlayer = try AVAudioPlayer(contentsOf: outputURL)
      audioPlayer.prepareToPlay()
      self.player = audioPlayer
      guard audioPlayer.play() else { throw self.error(14, "iOS no pudo iniciar la reproducción del audio generado.") }
      return [
        "played": true,
        "engine": "PocketTTS",
        "language": self.normalizedLanguage(language),
        "durationSeconds": audioPlayer.duration
      ]
    }

    Function("stopPlayback") {
      self.player?.stop()
      self.player = nil
    }
  }

  private func manager(for language: String) async throws -> PocketTtsManager {
    let key = normalizedLanguage(language)
    if let existing = managers[key] { return existing }
    let manager: PocketTtsManager
    switch key {
    case "German": manager = PocketTtsManager(language: .german)
    case "French": manager = PocketTtsManager(language: .french24L)
    case "Italian": manager = PocketTtsManager(language: .italian)
    case "Portuguese": manager = PocketTtsManager(language: .portuguese)
    case "English": manager = PocketTtsManager(language: .english)
    default: manager = PocketTtsManager(language: .spanish)
    }
    try await manager.initialize()
    managers[key] = manager
    return manager
  }

  private func normalizedLanguage(_ value: String) -> String {
    let lower = value.lowercased()
    if lower.contains("german") || lower == "de" || lower.hasPrefix("de-") { return "German" }
    if lower.contains("french") || lower == "fr" || lower.hasPrefix("fr-") { return "French" }
    if lower.contains("italian") || lower == "it" || lower.hasPrefix("it-") { return "Italian" }
    if lower.contains("portuguese") || lower == "pt" || lower.hasPrefix("pt-") { return "Portuguese" }
    if lower.contains("english") || lower == "en" || lower.hasPrefix("en-") { return "English" }
    return "Spanish"
  }

  private func fileURL(from value: String) -> URL {
    if let url = URL(string: value), url.isFileURL { return url }
    return URL(fileURLWithPath: value)
  }

  private func removeOldOutputs(except current: URL) {
    let files = (try? FileManager.default.contentsOfDirectory(at: workDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    for file in files where file != current && file.pathExtension == "wav" {
      try? FileManager.default.removeItem(at: file)
    }
  }

  private func error(_ code: Int, _ message: String) -> NSError {
    NSError(domain: "VoiceDubEngine", code: code, userInfo: [NSLocalizedDescriptionKey: message])
  }
}
