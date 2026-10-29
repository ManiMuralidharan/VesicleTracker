function pairs=vt_assignment(cost,missCost,method)
% Optimal finite-cost rectangular assignment. Prohibitive edges are Inf.
% matchpairs is built into MATLAB R2019a+; the local
% Hungarian-style augmenting paths implementation is fallback.
[n,m]=size(cost);pairs=zeros(0,2);
if n==0 || m==0,return;end
if nargin<3,method='auto';end
if ~strcmpi(method,'hungarian') && exist('matchpairs','file')==2
    try
        pairs=matchpairs(cost,missCost);
        pairs=pairs(isfinite(cost(sub2ind([n m],pairs(:,1),pairs(:,2)))),:);
        return
    catch
        % Local solver below.
    end
end
% Min-cost max-flow formulation with explicit unmatched track/detection,
% converted to perfect assignment. O((n+m)^3) Hungarian algorithm.
N=n+m; bad=max(1,missCost)*1e7;
A=bad*ones(N,N);
C=cost;C(~isfinite(C))=bad;
A(1:n,1:m)=C;
A(1:n,m+1:end)=missCost;
A(n+1:end,1:m)=missCost;
A(n+1:end,m+1:end)=0;
% Hungarian shortest augmenting path, based on 1-based sentinel column.
u=zeros(N+1,1);v=zeros(N+1,1);p=zeros(N+1,1);way=zeros(N+1,1);
for i=1:N
    p(1)=i; j0=1; minv=inf(N+1,1);used=false(N+1,1);
    while true
        used(j0)=true;i0=p(j0);delta=inf;j1=0;
        for j=2:N+1
            if used(j),continue;end
            cur=A(i0,j-1)-u(i0+1)-v(j);
            if cur<minv(j),minv(j)=cur;way(j)=j0;end
            if minv(j)<delta,delta=minv(j);j1=j;end
        end
        for j=1:N+1
            if used(j)
                if p(j)>0,u(p(j)+1)=u(p(j)+1)+delta;end
                v(j)=v(j)-delta;
            else
                minv(j)=minv(j)-delta;
            end
        end
        j0=j1;
        if p(j0)==0,break;end
    end
    while true
        j1=way(j0);p(j0)=p(j1);j0=j1;
        if j0==1,break;end
    end
end
for j=2:N+1
    i=p(j);
    if i>=1 && i<=n && j-1<=m && isfinite(cost(i,j-1)) && cost(i,j-1)<2*missCost
        pairs(end+1,:)=[i,j-1]; %#ok<AGROW>
    end
end
end
