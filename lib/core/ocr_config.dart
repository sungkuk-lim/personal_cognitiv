enum OcrEngineMode { hybrid, lowCost, vision }

enum OcrVisionQuality { low, high }

OcrVisionQuality effectiveVisionQuality(OcrEngineMode engineMode, OcrVisionQuality selected) {
  if (engineMode == OcrEngineMode.lowCost) return OcrVisionQuality.low;
  return selected;
}

int ocrMaxSideFor(OcrEngineMode engineMode, OcrVisionQuality quality) {
  if (engineMode == OcrEngineMode.lowCost) return 512;
  return quality == OcrVisionQuality.high ? 1024 : 768;
}

int cameraPickMaxSideFor(OcrEngineMode engineMode, OcrVisionQuality quality) {
  if (engineMode == OcrEngineMode.lowCost) return 1024;
  return quality == OcrVisionQuality.high ? 1600 : 1280;
}
