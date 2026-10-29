function [mask,roiMasks]=vt_roi_mask(H,W,polys)
if isempty(polys)
    mask=true(H,W);roiMasks={mask};return
end
if ~iscell(polys),error('roiPolygons must be a cell array of polygons');end
mask=false(H,W);roiMasks=cell(numel(polys),1);
for j=1:numel(polys)
    xy=polys{j};
    if size(xy,2)~=2 || size(xy,1)<3,error('Invalid ROI polygon %d',j);end
    roiMasks{j}=poly2mask(xy(:,1),xy(:,2),H,W);
    mask=mask | roiMasks{j};
end
end
