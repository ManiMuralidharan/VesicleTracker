function report=vt_validate(outputDir,p)
% Quantitative point-detection precision/recall, track identity consistency,
% and event timing accuracy. Thresholds are explicit in exported report.
path=fullfile(outputDir,'synthetic_ground_truth.tif');
truth=vt_synthetic(path,p);
result=vt_analyze(path,outputDir,p);D=result.tracks;
N=truth.frameCount;K=truth.trackCount;gate=3; TP=0; FP=0; FN=0;
matched=zeros(height(D),1);
for f=1:N
    ix=find(D.Frame==f);pos=squeeze(truth.positionsPx(f,:,:));
    if size(pos,1)~=K,pos=pos';end
    C=hypot(pos(:,1)-D.X(ix)',pos(:,2)-D.Y(ix)');
    pairs=vt_assignment(C,gate,'hungarian');
    if ~isempty(pairs)
        dist=C(sub2ind(size(C),pairs(:,1),pairs(:,2)));
        pairs=pairs(dist<=gate,:);
        matched(ix(pairs(:,2)))=pairs(:,1);
    end
    TP=TP+size(pairs,1);FP=FP+numel(ix)-size(pairs,1);FN=FN+K-size(pairs,1);
end
identityCorrect=0;identityTotal=0;
for id=unique(D.TrackID)'
    idx=find(D.TrackID==id & matched>0);
    if isempty(idx),continue;end
    truthIds=matched(idx);identityCorrect=identityCorrect+max(histcounts(truthIds,0.5:1:K+0.5));
    identityTotal=identityTotal+numel(idx);
end
precision=TP/max(1,TP+FP);recall=TP/max(1,TP+FN);
% Event matching: event detection reports onset after sustained rise,
% tolerance accounts for persistence and frame-based sampling.
evt=result.events; hits=0;
for k=1:K
    goodTrack=[];
    for id=unique(D.TrackID)'
        ids=matched(D.TrackID==id);ids=ids(ids>0);
        if nnz(ids==k)>=5 && nnz(ids==k)>=numel(ids)/2,goodTrack(end+1)=id;end %#ok<AGROW>
    end
    evtFrames=evt.Frame(ismember(evt.TrackID,goodTrack));
    hits=hits+any(abs(evtFrames-truth.eventFrames(k))<=p.eventMinConsecutiveFrames+2);
end
report=struct('trueObjects',N*K,'trueTracks',K,'trueEvents',K, ...
    'detectionsTP',TP,'detectionsFP',FP,'detectionsFN',FN, ...
    'detectionPrecision',precision,'detectionRecall',recall, ...
    'trackIdentityConsistency',identityCorrect/max(1,identityTotal), ...
    'eventRecall',hits/K,'eventTimingToleranceFrames',p.eventMinConsecutiveFrames+2, ...
    'localizationTolerancePx',gate,'settings',p);
fid=fopen(fullfile(outputDir,'validation_report.json'),'w');
fprintf(fid,'%s',jsonencode(report));fclose(fid);
fprintf('Validation: precision %.3f, recall %.3f, identity consistency %.3f, event recall %.3f\n', ...
    precision,recall,report.trackIdentityConsistency,report.eventRecall);
end
