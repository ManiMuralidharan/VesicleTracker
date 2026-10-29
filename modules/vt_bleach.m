function [factor,info]=vt_bleach(roiSignal,p)
% Robust global ROI exponential model y(t)=offset + amplitude*exp(-rate*t).
% No Optimization Toolbox required. Always normalize at first frame.
y=roiSignal(:);n=numel(y); t=(0:n-1)'/p.fps;factor=ones(n,1);
info=struct('applied',false,'r2',NaN,'ratePerSecond',NaN,'offset',NaN, ...
    'amplitude',NaN,'reason','Disabled or insufficient signal');
if ~p.bleachCorrection || n<8 || any(~isfinite(y)) || median(y)<=0,return;end
% Empirical floor at or below lower tail, preventing a spurious elevated offset.
floorMax=min(y)*max(0,min(1,p.bleachFitFloorFraction));
fitfun=@(v) v(1)+exp(v(2))*exp(-exp(v(3))*t);
loss=@(v) sum((fitfun(v)-y).^2);
v0=[floorMax log(max(eps,y(1)-floorMax)) log(max(1e-9,0.1/max(t(end),eps)))];
opts=optimset('Display','off','MaxIter',1200,'MaxFunEvals',2500);
try
    v=fminsearch(loss,v0,opts); f=fitfun(v);
    sst=sum((y-mean(y)).^2);
    if sst<=eps,info.reason='No measurable ROI trend';return;end
    r2=1-sum((y-f).^2)/sst;
    rate=exp(v(3));
    if r2<p.bleachMinFitR2 || rate<=0 || f(1)<=0 || any(f<=0) || f(end)>f(1)
        info.reason='Exponential did not pass quality control';info.r2=r2;return
    end
    if strcmpi(p.bleachModel,'offset')
        % Background-subtracted signals bleach with the exponential term only.
        bleaching=exp(v(2))*exp(-rate*t);factor=bleaching/bleaching(1);
    else
        factor=f/f(1);
    end
    factor=max(factor,0.05); % guard against division blow-up late in the movie
    info=struct('applied',true,'r2',r2, ...
        'ratePerSecond',rate,'offset',v(1),'amplitude',exp(v(2)),'model',p.bleachModel,'reason','OK');
catch ME
    info.reason=ME.message;
end
end
