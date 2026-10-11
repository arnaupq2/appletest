const { withPodfile } = require('@expo/config-plugins');

module.exports = function withFluidAudio(config) {
  return withPodfile(config, (mod) => {
    const contents = mod.modResults.contents;
    if (contents.includes("pod 'FluidAudio'")) return mod;

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
