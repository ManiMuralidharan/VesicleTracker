function p=vt_defaults()
% All parameters can be serialized with jsonencode(p).
p=struct();
p.fps=1; p.pixelSizeUm=0.1;
p.thresholdMethod='adaptive'; p.sensitivity=0.55;
p.gaussianSigma=1; p.minAreaPx=3; p.maxAreaPx=200;
p.minContrastToNoise=3; % (object mean - ring median)/ring MAD-sigma; 0 disables
p.maxLinkDistancePx=8; p.maxGapFrames=1;
p.assignmentMethod='auto'; % matchpairs if available, else local Hungarian algorithm
p.useKalman=true; p.kalmanProcessVariance=2; p.kalmanMeasurementVariance=1;
p.localRingInnerPx=2; p.localRingOuterPx=6;
p.bleachCorrection=true;
p.darkOffset=0;          % camera dark level (raw units) subtracted before bleach fitting
p.bleachModel='offset';  % 'offset': factor=(f-offset)/(f1-offset); 'ratio': legacy f/f1
p.bleachMinFitR2=0.50; p.bleachFitFloorFraction=0.05;
p.eventMADMultiplier=3; p.eventMinConsecutiveFrames=3;
p.eventBaselineFrames=5; p.eventMinDeltaFOverF0=0.2;
p.minTrackDetections=5; p.edgeMarginPx=4;
p.msdMaxLag=10; p.msdMinPairs=3;
p.useParallel=false; p.roiPolygons={}; % optional cell array of Nx2 [x y] vertices
p.softwareVersion='1.0.0-modular';
end
