enum OcrEngineMode { hybrid, lowCost, vision }

enum OcrVisionQuality { low, high }

OcrVisionQuality effectiveVisionQuality(OcrEngineMode engineMode, OcrVisionQuality selected) {
  if (engineMode == OcrEngineMode.lowCost) return OcrVisionQuality.low;
  return selected;
}

int ocrMaxSideFor(OcrEngineMode engineMode, OcrVisionQuality quality) {
  if (engineMode == OcrEngineMode.lowCost) return 448;
  return quality == OcrVisionQuality.high ? 896 : 640;
}

int cameraPickMaxSideFor(OcrEngineMode engineMode, OcrVisionQuality quality) {
  if (engineMode == OcrEngineMode.lowCost) return 960;
  return quality == OcrVisionQuality.high ? 1280 : 1024;
}
