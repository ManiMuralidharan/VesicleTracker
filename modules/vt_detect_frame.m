function [D,wholeROI]=vt_detect_frame(raw,k,mask,roiMasks,p)
% Detection-only smoothing; quantification always uses original raw pixels.
I=im2double(raw);
if p.gaussianSigma>0,I=imgaussfilt(I,p.gaussianSigma);end
if strcmpi(p.thresholdMethod,'adaptive')
    BW=imbinarize(I,'adaptive','ForegroundPolarity','bright', ...
        'Sensitivity',p.sensitivity);
elseif strcmpi(p.thresholdMethod,'otsu')
    vals=I(mask);
    if isempty(vals) || max(vals)==min(vals),BW=false(size(I));
    else,BW=I>graythresh(vals);end
else
    error('Unknown thresholdMethod: %s',p.thresholdMethod);
end
BW=BW & mask;
CC=bwconncomp(BW,8);
st=regionprops(CC,'PixelIdxList','Area','Centroid');
keep=find([st.Area]>=p.minAreaPx & [st.Area]<=p.maxAreaPx);
% IMPORTANT: Exclude all detectable foreground objects from background rings.
foreground=BW;
seOuter=strel('disk',max(1,round(p.localRingOuterPx)),0);
if p.localRingInnerPx>0
    seInner=strel('disk',round(p.localRingInnerPx),0);
else
    seInner=[];
end
N=numel(keep);rows=nan(N,12);
boundary=~mask;boundary([1 end],:)=true;boundary(:,[1 end])=true;
edgeDist=bwdist(boundary);
for j=1:N
    s=st(keep(j));obj=false(size(BW));obj(s.PixelIdxList)=true;
    if isempty(seInner),inner=obj;else,inner=imdilate(obj,seInner);end
    outer=imdilate(obj,seOuter);
    ring=outer & ~inner & mask & ~foreground;
    bg=double(raw(ring));
    if isempty(bg),background=NaN;bgNoise=NaN;
    else,background=median(bg);bgNoise=1.4826*median(abs(bg-background));end
    % Contrast-to-noise gate: reject objects not clearly brighter than local background.
    if p.minContrastToNoise>0 && numel(bg)>=10 && bgNoise>0
        if (mean(double(raw(s.PixelIdxList)))-background)/bgNoise<p.minContrastToNoise
            continue
        end
    end
    intensity=double(raw(s.PixelIdxList));
    ri=1;best=0;
    for r=1:numel(roiMasks)
        count=nnz(roiMasks{r}(s.PixelIdxList));
        if count>best,best=count;ri=r;end
    end
    touchesEdge=any(edgeDist(s.PixelIdxList)<=p.edgeMarginPx);
    meanI=mean(intensity);
    rows(j,:)=[k,s.Centroid,s.Area,meanI,max(intensity), ...
        sum(intensity),background,meanI-background, ...
        (meanI-background)*s.Area,ri,double(touchesEdge)];
end
rows=rows(~isnan(rows(:,1)),:); % drop rejected objects
D=array2table(rows,'VariableNames',{'Frame','X','Y','AreaPx','MeanIntensity', ...
    'MaxIntensity','IntegratedIntensity','LocalBackground','NetMeanIntensity', ...
    'NetIntegratedIntensity','ROI','NearROIEdge'});
wholeROI=median(double(raw(mask))); % robust ROI reference for bleach fitting
end
