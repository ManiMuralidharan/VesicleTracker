function [T,E]=vt_events(T,p)
% Compare each post-baseline point against baseline; require persistence.
% Events flagged only once, at first sample of a sustained rise.
T.DeltaFOverF0=nan(height(T),1);T.Event=false(height(T),1);
E=table('Size',[0 5],'VariableTypes',{'double','double','double','double','double'}, ...
    'VariableNames',{'TrackID','Frame','TimeS','DeltaFOverF0','NoiseMAD'});
ids=unique(T.TrackID)';
for id=ids
    ind=find(T.TrackID==id);[~,ord]=sort(T.Frame(ind));ind=ind(ord);
    f=T.Frame(ind);raw=T.BleachCorrectedNetMean(ind);
    valid=find(isfinite(raw));
    nb=p.eventBaselineFrames;
    if numel(valid)<nb+1,continue;end
    B=raw(valid(1:nb));base=median(B);
    if base<=0,continue;end
    z=(raw-base)/base;
    T.DeltaFOverF0(ind)=z;
    % Robust noise estimate from baseline or all negative/rest observations.
    noise=1.4826*median(abs(B-median(B)))/base;
    if noise<=eps
        rest=z(isfinite(z) & z<=median(z));
        if ~isempty(rest),noise=1.4826*median(abs(rest-median(rest)));end
    end
    threshold=max(p.eventMinDeltaFOverF0,p.eventMADMultiplier*noise);
    high=isfinite(z) & z>=threshold;
    % Never bridge missing observations or detect baseline calibration frames.
    high(1:valid(nb))=false; % exclude every row up to the last baseline sample
    starts=find(high & ~[false;high(1:end-1)]);
    for st=starts'
        en=st;
        while en<numel(f) && high(en+1) && f(en+1)==f(en)+1
            en=en+1;
        end
        if en-st+1>=p.eventMinConsecutiveFrames
            T.Event(ind(st))=true;
            E=[E;{id,f(st),(f(st)-1)/p.fps,z(st),noise}]; %#ok<AGROW>
        end
    end
end
end
