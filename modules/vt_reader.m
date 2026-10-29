function R=vt_reader(path)
% Single-page buffered TIFF reader; frames never all loaded into RAM.
info=imfinfo(path);
if isempty(info),error('TIFF contains no frames');end
R.path=path; R.n=numel(info);R.height=info(1).Height;R.width=info(1).Width;
R.info=info;
if any([info.Height]~=R.height) || any([info.Width]~=R.width)
    error('TIFF pages must have identical spatial dimensions');
end
sample=imread(path,1,'Info',info);
if ndims(sample)~=2,error('Only grayscale TIFF stacks are supported');end
R.frame=@(k)imread(path,k,'Info',info);
end
