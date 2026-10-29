function Q=vt_motion(T,p,mask,nFrames)
% Time-lag MSD from observed pairs (not interpolated). Log-log alpha.
Q=table('Size',[0 13], ...
    'VariableTypes',[repmat({'double'},1,10),{'logical','logical','string'}], ...
    'VariableNames',{'TrackID','ROI','FirstFrame','LastFrame','Detections', ...
    'DurationS','PathLengthUm','NetDisplacementUm','MeanSpeedUmPerS', ...
    'MSDAlpha','StartsNearEdge','EndsNearEdge','MotionClass'});
ids=unique(T.TrackID)';
for id=ids
    d=T(T.TrackID==id,:);d=sortrows(d,'Frame');n=height(d);
    if n<p.minTrackDetections,continue;end
    frames=d.Frame;xy=[d.X d.Y]*p.pixelSizeUm;
    steps=hypot(diff(xy(:,1)),diff(xy(:,2)));
    duration=(frames(end)-frames(1))/p.fps;
    speed=NaN;if duration>0,speed=sum(steps)/duration;end
    maxlag=min(p.msdMaxLag,frames(end)-frames(1));tau=[];msd=[];
    for lag=1:maxlag
        [~,ia,ib]=intersect(frames+lag,frames);
        if numel(ia)<p.msdMinPairs,continue;end
        diffXY=xy(ib,:)-xy(ia,:);
        tau(end+1,1)=lag/p.fps; %#ok<AGROW>
        msd(end+1,1)=mean(sum(diffXY.^2,2)); %#ok<AGROW>
    end
    alpha=NaN;label='Unclassified';
    good=isfinite(msd)&msd>0;
    if nnz(good)>=3
        coeff=polyfit(log(tau(good)),log(msd(good)),1);alpha=coeff(1);
        if alpha<0.8,label='Confined/subdiffusive';
        elseif alpha<=1.2,label='Diffusive';else,label='Superdiffusive/directed';end
    end
    row=table(id,d.ROI(1),frames(1),frames(end),n,duration,sum(steps), ...
        hypot(xy(end,1)-xy(1,1),xy(end,2)-xy(1,2)),speed,alpha, ...
        logical(d.NearROIEdge(1)),logical(d.NearROIEdge(end)),string(label), ...
        'VariableNames',{'TrackID','ROI','FirstFrame','LastFrame','Detections', ...
        'DurationS','PathLengthUm','NetDisplacementUm','MeanSpeedUmPerS', ...
        'MSDAlpha','StartsNearEdge','EndsNearEdge','MotionClass'});
    Q=[Q;row]; %#ok<AGROW>
end
end
