function T=vt_link(D,p)
% One-to-one global assignment, optional constant velocity Kalman predictor.
T=D;T.TrackID=zeros(height(D),1);
if isempty(D),return;end
frameMax=max(D.Frame); nextID=0;
active=struct('id',{},'roi',{},'lastFrame',{},'state',{},'P',{});
F=eye(4); H=[1 0 0 0;0 1 0 0]; R=p.kalmanMeasurementVariance*eye(2);
for f=1:frameMax
    active=active(arrayfun(@(a) f-a.lastFrame<=p.maxGapFrames+1,active));
    idx=find(D.Frame==f);M=numel(idx);N=numel(active);
    predicted=zeros(N,2); predStates=cell(N,1);predCovs=cell(N,1);
    for a=1:N
        dt=f-active(a).lastFrame;
        F(1,3)=dt;F(2,4)=dt;
        Q=p.kalmanProcessVariance*diag([dt^2 dt^2 max(dt,1) max(dt,1)]);
        if p.useKalman
            predStates{a}=F*active(a).state;
            predCovs{a}=F*active(a).P*F'+Q;
        else
            predStates{a}=active(a).state;
            predCovs{a}=active(a).P;
        end
        tmp=predStates{a};predicted(a,:)=tmp(1:2)';
    end
    cost=inf(N,M);
    for a=1:N
        if M==0,continue;end
        dd=hypot(D.X(idx)-predicted(a,1),D.Y(idx)-predicted(a,2));
        good=D.ROI(idx)==active(a).roi & dd<=p.maxLinkDistancePx*(f-active(a).lastFrame);
        cost(a,good)=dd(good);
    end
    assigned=false(M,1);
    if N>0 && M>0
        pairs=vt_assignment(cost,p.maxLinkDistancePx*(p.maxGapFrames+2),p.assignmentMethod);
        for kk=1:size(pairs,1)
            a=pairs(kk,1);b=pairs(kk,2); j=idx(b);
            T.TrackID(j)=active(a).id; assigned(b)=true;
            z=[D.X(j);D.Y(j)]; x=predStates{a};P=predCovs{a};
            if p.useKalman
                K=P*H'/(H*P*H'+R);
                x=x+K*(z-H*x);P=(eye(4)-K*H)*P;
            else
                x(3:4)=(z-x(1:2))/max(1,f-active(a).lastFrame);
                x(1:2)=z;
            end
            active(a).state=x;active(a).P=P;active(a).lastFrame=f;
        end
    end
    for b=find(~assigned)'
        j=idx(b);nextID=nextID+1;T.TrackID(j)=nextID;
        aa=struct('id',nextID,'roi',D.ROI(j),'lastFrame',f, ...
            'state',[D.X(j);D.Y(j);0;0],'P',diag([4 4 16 16]));
        active(end+1)=aa; %#ok<AGROW>
    end
end
end
