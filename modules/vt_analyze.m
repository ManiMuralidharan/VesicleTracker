function result=vt_analyze(path,outputDir,p)
% Orchestrator: I/O -> detect -> bleach -> link -> events -> MSD -> exports.
R=vt_reader(path);
[mask,roiMasks]=vt_roi_mask(R.height,R.width,p.roiPolygons);
if ~any(mask(:)),error('Selected ROI contains no image pixels');end
D=cell(R.n,1);whole=nan(R.n,1);
% A Parallel Computing Toolbox license is needed only if useParallel=true.
if p.useParallel
    if license('test','Distrib_Computing_Toolbox')==0
        error('Parallel Computing Toolbox required for useParallel=true');
    end
    pool=gcp();
    modDir=fileparts(mfilename('fullpath'));
    if ~any(strcmp(pool.AttachedFiles,modDir)),addAttachedFiles(pool,{modDir});end
    info=R.info; % broadcast once: avoids re-parsing the TIFF header per frame
    parfor k=1:R.n
        frame=imread(path,k,'Info',info);[D{k},whole(k)]=vt_detect_frame(frame,k,mask,roiMasks,p);
    end
else
    for k=1:R.n
        frame=R.frame(k);[D{k},whole(k)]=vt_detect_frame(frame,k,mask,roiMasks,p);
        if mod(k,50)==0,fprintf('Detected %d/%d frames\n',k,R.n);end
    end
end
D=vertcat(D{:});
[factor,bleachInfo]=vt_bleach(whole-p.darkOffset,p); % dark level removed before fitting
D.BleachFactor=factor(D.Frame);
D.BleachCorrectedNetMean=D.NetMeanIntensity./D.BleachFactor;
T=vt_link(D,p);
[T,E]=vt_events(T,p);
Q=vt_motion(T,p,mask,R.n);
% Object rows are unfiltered; filtered table includes only long enough tracks.
if isempty(Q),filtered=T([],:);
else,filtered=T(ismember(T.TrackID,Q.TrackID),:);end
[~,name]=fileparts(path);
folder=fullfile(outputDir,name);if ~exist(folder,'dir'),mkdir(folder);end
writetable(T,fullfile(folder,'detections_tracks.csv'));
writetable(filtered,fullfile(folder,'tracks_filtered.csv'));
writetable(Q,fullfile(folder,'track_summary.csv'));
writetable(E,fullfile(folder,'events.csv'));
writetable(table((1:R.n)',whole,factor, ...
    'VariableNames',{'Frame','ROIMedianRaw','BleachFactor'}),fullfile(folder,'roi_bleaching.csv'));
metadata=struct('software','VesicleTracker modular','version',p.softwareVersion, ...
    'matlabVersion',version,'sourcePath',path,'height',R.height,'width',R.width, ...
    'frames',R.n,'settings',p,'bleaching',bleachInfo, ...
    'created',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
fid=fopen(fullfile(folder,'metadata.json'),'w');
if fid<0,error('Cannot create metadata file');end
fprintf(fid,'%s',jsonencode(metadata));fclose(fid);
result=struct('tracks',T,'filteredTracks',filtered,'summary',Q,'events',E, ...
    'metadata',metadata,'folder',folder);
save(fullfile(folder,'results.mat'),'result','-v7.3');
fprintf('Exported %d detections, %d eligible tracks, %d events -> %s\n', ...
    height(T),height(Q),height(E),folder);
end
