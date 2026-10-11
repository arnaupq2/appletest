const { withPodfile } = require('@expo/config-plugins');

module.exports = function withFluidAudio(config) {
  return withPodfile(config, (mod) => {
    let contents = mod.modResults.contents;
    // AppleFoundationTranslator imports FoundationModels and therefore needs iOS 26.
    // Expo's generated Podfile can otherwise retain its default 15.1 platform even
    // when app.json declares a newer deployment target, causing CocoaPods to skip it.
    contents = contents.replace(/^platform :ios,.*$/m, "platform :ios, '26.0'");
    if (contents.includes("pod 'FluidAudio'")) {
      mod.modResults.contents = contents;
      return mod;
    }

    const targetLine = contents.match(/^target ['"][^'"]+['"] do\s*$/m);
    if (!targetLine || targetLine.index == null) {
      throw new Error('with-fluid-audio: no se encontró el target principal en el Podfile generado.');
    }

    const insertAt = targetLine.index + targetLine[0].length;
    const podLine = "\n  # PocketTTS + voice cloning / speaker audio engine\n  pod 'FluidAudio', :git => 'https://github.com/FluidInference/FluidAudio.git', :tag => 'v0.17.1'\n";
    mod.modResults.contents = contents.slice(0, insertAt) + podLine + contents.slice(insertAt);
    return mod;
  });
};
