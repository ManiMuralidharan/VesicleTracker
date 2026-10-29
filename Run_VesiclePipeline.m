function result = Run_VesiclePipeline(inputPath, outputDir, settingsFile)
% RUN_VESICLEPIPELINE  Modular companion to vesicleTrackingGUI_TIFF.
% Examples:
%   Run_VesiclePipeline()                  % select TIFF with dialog
%   Run_VesiclePipeline('movie.tif')
%   Run_VesiclePipeline('folder', 'results') % batch all TIFFs in folder
%   Run_VesiclePipeline('movie.tif','results','settings.json')
%   Run_VesiclePipeline('synthetic')       % validation on ground-truth data
% The original GUI is not modified. Requires Image Processing Toolbox.
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'modules'));
if nargin<1 || isempty(inputPath)
    [f,p]=uigetfile({'*.tif;*.tiff','TIFF stacks'},'Select a TIFF');
    if isequal(f,0), result=[]; return; end
    inputPath=fullfile(p,f);
end
if nargin<2 || isempty(outputDir), outputDir=fullfile(root,'results');end
if nargin<3,settingsFile='';end
p=vt_defaults();
if ~isempty(settingsFile)
    userP=jsondecode(fileread(settingsFile));
    p=vt_merge_params(p,userP);
end
if ~exist(outputDir,'dir'),mkdir(outputDir);end
if strcmpi(inputPath,'synthetic')
    result=vt_validate(outputDir,p);return
end
if isfolder(inputPath)
    a=[dir(fullfile(inputPath,'*.tif'));dir(fullfile(inputPath,'*.tiff'))];
    % Windows dir('*.tif') also matches .tiff: de-duplicate by full path.
    [~,u]=unique(lower(fullfile({a.folder},{a.name})),'stable');a=a(u);
    [~,stems]=cellfun(@fileparts,{a.name},'UniformOutput',false);
    if numel(unique(lower(stems)))<numel(stems)
        warning('VesicleTracker:NameClash', ...
            'Files differing only by extension share a results folder; rename them.');
    end
    result=cell(numel(a),1);
    for k=1:numel(a)
        fprintf('Batch %d/%d: %s\n',k,numel(a),a(k).name);
        try
            result{k}=vt_analyze(fullfile(a(k).folder,a(k).name),outputDir,p);
        catch ME
            warning('VesicleTracker:BatchFailure','%s: %s',a(k).name,ME.message);
            result{k}=struct('source',a(k).name,'error',ME.message);
        end
    end
else
    result=vt_analyze(inputPath,outputDir,p);
end
end
