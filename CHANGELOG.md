# Changelog

## [1.0.0] - 2026-10-29
### Added
- Modular pipeline (`Run_VesiclePipeline`, `modules/`) with batch mode and JSON settings.
- Optimal assignment linking (`matchpairs`, with Hungarian fallback) and optional Kalman prediction.
- Local ring background, bleach correction, sustained-rise event detection (dF/F0, MAD noise gate).
- MSD alpha motion classes, edge flags, and track filters.
- Synthetic ground-truth validation (`Run_VesiclePipeline('synthetic')`).
- `darkOffset` and `bleachModel` settings; metadata JSON for every run.
- Interactive GUI (`gui/vesicleTrackingGUI_TIFF.m`).

### Fixed
- Detection: contrast-to-noise gate (`minContrastToNoise`) removes background-noise objects
  picked up by the adaptive threshold (synthetic precision was 0.03).
- GUI: `grid` variable shadowing that crashed startup; stale axes when loading a new stack;
  centroid-based ROI assignment; memory estimate; key handling in edit fields.
- Pipeline: ROI polygons from JSON; parallel TIFF reads; event baseline exclusion;
  unused `eventBaselineFrames`; duplicate files in Windows batch mode.
