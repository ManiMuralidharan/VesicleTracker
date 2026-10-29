# VesicleTracker

[![MATLAB tests](https://github.com/ManiMuralidharan/VesicleTracker/actions/workflows/matlab-tests.yml/badge.svg)](https://github.com/ManiMuralidharan/VesicleTracker/actions/workflows/matlab-tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

MATLAB tools to detect, track and quantify fluorescent vesicles in multi-page grayscale TIFF stacks (for example TIRF movies of dense-core vesicle exocytosis), and to flag fluorescence event candidates along each track.

Two ways to use it:

- **GUI** (`gui/vesicleTrackingGUI_TIFF.m`): interactive ROI drawing, detection, tracking, trace plots and CSV export.
- **Pipeline** (`Run_VesiclePipeline.m` + `modules/`): scripted and batch analysis with background subtraction, bleach correction, optimal-assignment tracking, event detection, motion analysis and synthetic validation.

Author: Muralidharan Mani ([ORCID](https://orcid.org/0000-0002-1194-3616)), University of Wisconsin-Madison.

## Requirements

- MATLAB R2021b or newer
- Image Processing Toolbox (required)
- Parallel Computing Toolbox (optional, only for `useParallel: true`)

## Installation

```bash
git clone https://github.com/ManiMuralidharan/VesicleTracker.git
```

In MATLAB, set the Current Folder to `VesicleTracker`.

## Quick start

**GUI**

```matlab
addpath('gui'); vesicleTrackingGUI_TIFF
```

Load TIFF, add one or more ROIs, set parameters, press PROCESS ALL FRAMES, then export CSV or the plot.

**Pipeline**

```matlab
Run_VesiclePipeline()                                         % choose a TIFF
Run_VesiclePipeline('movie.tif','results','example_settings.json')
Run_VesiclePipeline('tiff_folder','batch_results','example_settings.json')
Run_VesiclePipeline('synthetic','validation_results')         % ground-truth check
```

Each movie gets its own results folder:

| File | Contents |
|---|---|
| `detections_tracks.csv` | Every detection with track ID, raw and background-subtracted intensities, dF/F0, event flag |
| `tracks_filtered.csv` | Detections from tracks passing `minTrackDetections` |
| `track_summary.csv` | Per track: duration, path length, net displacement, speed (um), MSD alpha, motion class, edge flags |
| `events.csv` | Event candidates: track, frame, time, dF/F0, noise |
| `roi_bleaching.csv` | ROI median intensity and bleach correction factor per frame |
| `metadata.json` | Software version, MATLAB version, all settings, bleach fit quality |
| `results.mat` | All tables and metadata |

## Settings

Pass a JSON file with any subset of the settings; unknown names raise an error. All defaults and descriptions are in `modules/vt_defaults.m`. Key settings:

| Setting | Default | Meaning |
|---|---|---|
| `fps`, `pixelSizeUm` | 1, 0.1 | Frame rate (Hz) and pixel size (um/px) |
| `thresholdMethod`, `sensitivity` | adaptive, 0.55 | Segmentation (`adaptive` or `otsu`) |
| `minAreaPx`, `maxAreaPx` | 3, 200 | Object size limits |
| `minContrastToNoise` | 3 | Reject objects less than this many noise SDs above the local ring background (0 disables) |
| `maxLinkDistancePx`, `maxGapFrames` | 8, 1 | Linking radius per frame and allowed missing frames |
| `useKalman` | true | Constant-velocity motion prediction |
| `darkOffset` | 0 | Camera dark level subtracted before bleach fitting |
| `bleachModel` | offset | `offset` (recommended for background-subtracted signal) or `ratio` |
| `eventBaselineFrames` | 5 | Detections used for each track's F0 |
| `eventMADMultiplier`, `eventMinDeltaFOverF0`, `eventMinConsecutiveFrames` | 3, 0.2, 3 | Event thresholds and persistence |
| `roiPolygons` | whole image | List of polygons, each a list of `[x, y]` vertices |

## How it works

1. **Detection:** Gaussian smoothing (detection only), adaptive or Otsu threshold within the ROI, size filtering. Intensities are always measured on raw pixels.
2. **Background:** median of a ring around each object, excluding other objects; gives net intensity.
3. **Bleach correction:** exponential fit to the ROI median over time, with a quality gate (`bleachMinFitR2`). If the fit fails, no correction is applied.
4. **Linking:** one-to-one optimal assignment within each ROI (`matchpairs`, with a built-in Hungarian fallback), optional Kalman prediction, gap closing.
5. **Events:** dF/F0 against each track's baseline; an event requires a sustained rise above both a MAD-based noise threshold and a minimum dF/F0.
6. **Motion:** path length, displacement, speed and mean squared displacement exponent (alpha < 0.8 confined, 0.8 to 1.2 diffusive, > 1.2 directed).

## Validation and tests

`Run_VesiclePipeline('synthetic')` generates a TIFF with moving Gaussian spots, known intensity rises and bleaching, then reports detection precision and recall, track identity consistency and event recall in `validation_report.json`.

Unit tests: `runtests('tests')`. They also run on GitHub Actions for each push.

## Limitations

- An intensity rise is an **event candidate**, not proof of fusion. Confirm with morphology, a membrane marker or a second channel.
- Grayscale single-channel TIFF only; no OME metadata or multichannel support.
- No split/merge handling; crossings of nearby vesicles can still swap IDs.
- Drift is not corrected; register stacks first.
- MSD alpha is a heuristic and is biased low by localization error on short tracks.
- The whole-ROI median is a proxy for bleaching; large biological intensity changes can bias it. Check `roi_bleaching.csv`.

## Citation

If you use VesicleTracker, please cite it using `CITATION.cff` (GitHub shows a "Cite this repository" button).

## License

MIT. See [LICENSE](LICENSE).
