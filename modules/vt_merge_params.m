function p=vt_merge_params(p,q)
if ~isstruct(q),error('Expected a JSON object of settings');end
names=fieldnames(q);
for k=1:numel(names)
    if ~isfield(p,names{k}),error('Unknown setting: %s',names{k});end
    v=q.(names{k});
    if strcmp(names{k},'roiPolygons'),v=normalizeROIs(v);end
    p.(names{k})=v;
end
end

function c=normalizeROIs(v)
% jsondecode returns Nx2 (one ROI), KxNx2 (equal-sized ROIs) or a cell array.
if isempty(v),c={};
elseif iscell(v),c=cellfun(@(x)double(reshape(x,[],2)),v(:)','UniformOutput',false);
elseif isnumeric(v) && ismatrix(v),c={double(v)};
elseif isnumeric(v) && ndims(v)==3
    c=cell(1,size(v,1));
    for i=1:size(v,1),c{i}=double(reshape(v(i,:,:),[],2));end
else,error('roiPolygons must be a list of [x,y] vertex lists');end
end
