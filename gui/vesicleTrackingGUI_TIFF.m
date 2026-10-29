function vesicleTrackingGUI_TIFF()
% VESICLETRACKINGGUI_TIFF  Multi-page grayscale TIFF vesicle detector/tracker.
% Author: Muralidharan Mani | License: MIT
% Requires MATLAB R2021b+ with Image Processing Toolbox.
% Tracking uses nearest-neighbor one-to-one assignment (no split/merge handling).
%
% The CSVs contain raw per-object intensities; preprocessing affects only detection.

S = struct('stack',[],'path','','rois',{{}},'detections',table(), ...
    'tracks',table(),'summary',table(),'current',1,'playing',false, ...
    'busy',false,'lastDir',pwd,'overlay',gobjects(0));
fig = uifigure('Name','Vesicle Tracker | Multi-frame TIFF', ...
    'Position',[80 60 1260 800],'Color',[.97 .98 .99]);
fig.CloseRequestFcn = @closeApp;
mainGrid = uigridlayout(fig,[3 2]);
mainGrid.RowHeight = {46,'1x',50};
mainGrid.ColumnWidth = {268,'1x'};
mainGrid.Padding = [10 10 10 10]; mainGrid.RowSpacing=8; mainGrid.ColumnSpacing=10;

topBar = uigridlayout(mainGrid,[1 6]); topBar.Layout.Row=1; topBar.Layout.Column=[1 2];
topBar.ColumnWidth={'1x','1x','1x','1x','1x','1x'}; topBar.Padding=[0 0 0 0];
uibutton(topBar,'Text','Load TIFF','ButtonPushedFcn',@loadTiff);
uibutton(topBar,'Text','Load session','ButtonPushedFcn',@loadSession);
uibutton(topBar,'Text','Save session','ButtonPushedFcn',@saveSession);
uibutton(topBar,'Text','Export CSV','ButtonPushedFcn',@exportCSV);
uibutton(topBar,'Text','Export plot','ButtonPushedFcn',@exportPlot);
uibutton(topBar,'Text','Reset','ButtonPushedFcn',@resetApp);

left = uipanel(mainGrid,'Title','Detection / tracking controls');
left.Layout.Row=2; left.Layout.Column=1;
l = uigridlayout(left,[19 2]); l.ColumnWidth={'1x','1x'};
l.RowHeight = {28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,'1x'};
l.Padding=[8 8 8 8]; l.RowSpacing=3;
addROI = uibutton(l,'Text','Add ROI','ButtonPushedFcn',@addROIcb); addROI.Layout.Row=1;
delROI = uibutton(l,'Text','Delete ROI','ButtonPushedFcn',@deleteROIcb); delROI.Layout.Row=1;
roiList = uilistbox(l,'Items',{'(no ROI)'},'Value','(no ROI)');
roiList.Layout.Row=[2 4]; roiList.Layout.Column=[1 2];

uilabel(l,'Text','Threshold');
thresh = uidropdown(l,'Items',{'Adaptive','Global Otsu'},'Value','Adaptive');
uilabel(l,'Text','Sensitivity');
sens = uieditfield(l,'numeric','Limits',[0.01 .99],'Value',.55);
uilabel(l,'Text','Min area (px²)');
minArea = uieditfield(l,'numeric','Limits',[1 Inf],'Value',3);
uilabel(l,'Text','Max area (px²)');
maxArea = uieditfield(l,'numeric','Limits',[1 Inf],'Value',200);
uilabel(l,'Text','Gaussian σ (px)');
sigma = uieditfield(l,'numeric','Limits',[0 20],'Value',1);
uilabel(l,'Text','Link radius (px)');
maxDist = uieditfield(l,'numeric','Limits',[.1 Inf],'Value',8);
uilabel(l,'Text','Max missing frames');
maxGap = uieditfield(l,'numeric','Limits',[0 100],'RoundFractionalValues','on','Value',1);
uilabel(l,'Text','Frame rate (Hz)');
fps = uieditfield(l,'numeric','Limits',[.01 Inf],'Value',1);
uilabel(l,'Text','Pixel size (µm/px)');
pxSize = uieditfield(l,'numeric','Limits',[.0001 Inf],'Value',.1);
uilabel(l,'Text','Event rise (raw units)');
eventDelta = uieditfield(l,'numeric','Limits',[0 Inf],'Value',4);
uilabel(l,'Text','Trace metric');
metric = uidropdown(l,'Items',{'MeanIntensity','MaxIntensity','IntegratedIntensity'}, ...
    'Value','MeanIntensity','ValueChangedFcn',@refreshPlot);
overlayCheck = uicheckbox(l,'Text','Show detections','Value',true,'ValueChangedFcn',@refreshFrame);
overlayCheck.Layout.Row=16; overlayCheck.Layout.Column=[1 2];
processButton = uibutton(l,'Text','PROCESS ALL FRAMES','FontWeight','bold', ...
    'ButtonPushedFcn',@processAll);
processButton.Layout.Row=17; processButton.Layout.Column=[1 2];
uilabel(l,'Text','Track ID (0 = all)');
trackSelect = uieditfield(l,'numeric','Limits',[0 Inf], ...
    'RoundFractionalValues','on','Value',0,'ValueChangedFcn',@refreshPlot);
helpLabel = uilabel(l,'Text','Left/right arrows: frame step','FontColor',[.3 .3 .3]);
helpLabel.Layout.Row=19; helpLabel.Layout.Column=[1 2];

right = uigridlayout(mainGrid,[2 1]); right.Layout.Row=2; right.Layout.Column=2;
right.RowHeight={'1.35x','1x'}; right.Padding=[0 0 0 0];
axImage = uiaxes(right); axImage.Layout.Row=1;
axImage.XTick=[]; axImage.YTick=[]; title(axImage,'Load a multi-page TIFF');
axPlot = uiaxes(right); axPlot.Layout.Row=2;
xlabel(axPlot,'Time (s)'); ylabel(axPlot,'Mean intensity (raw AU)');
title(axPlot,'Vesicle intensity traces'); grid(axPlot,'on');

bottom = uigridlayout(mainGrid,[1 6]); bottom.Layout.Row=3; bottom.Layout.Column=[1 2];
bottom.ColumnWidth={40,'1x',40,88,105,'2x'};
bottom.Padding=[0 0 0 0];
uibutton(bottom,'Text','◀','ButtonPushedFcn',@(~,~)stepFrame(-1));
frameSlider = uislider(bottom,'Limits',[1 2],'Value',1,'MajorTicks',[], ...
    'ValueChangedFcn',@sliderChange); frameSlider.Layout.Column=2;
uibutton(bottom,'Text','▶','ButtonPushedFcn',@(~,~)stepFrame(1));
playButton = uibutton(bottom,'Text','Play','ButtonPushedFcn',@togglePlay);
frameLabel = uilabel(bottom,'Text','Frame —');
status = uilabel(bottom,'Text','Ready','FontColor',[.2 .35 .45]);
fig.WindowKeyPressFcn=@keyPress;

    function setStatus(msg)
        if isvalid(status), status.Text=msg; drawnow limitrate; end
    end
    function assertStack()
        if isempty(S.stack), error('Load a TIFF first.'); end
    end
    function loadTiff(~,~)
        [fn,folder]=uigetfile({'*.tif;*.tiff','TIFF image stacks'}, ...
            'Select a multi-page grayscale TIFF',S.lastDir);
        if isequal(fn,0), return; end
        full=fullfile(folder,fn);
        try
            info=imfinfo(full);
            if isempty(info), error('TIFF has no frames.'); end
            H=info(1).Height; W=info(1).Width; N=numel(info);
            sample=imread(full,1,'Info',info);
            if ndims(sample)~=2, error('Only grayscale TIFF pages are supported.'); end
            bytes=double(H)*double(W)*double(N)*max(1,info(1).BitDepth/8);
            if bytes>4e9
                choice=uiconfirm(fig,sprintf('Stack may require up to %.1f GB of memory. Continue?',bytes/1e9), ...
                    'Large TIFF','Options',{'Continue','Cancel'},'DefaultOption',2);
                if strcmp(choice,'Cancel'),return;end
            end
            st=zeros(H,W,N,'like',sample);
            for k=1:N
                a=imread(full,k,'Info',info);
                if ~isequal(size(a),[H W]) || ~strcmp(class(a),class(sample))
                    error('All TIFF pages must share size and pixel type.');
                end
                st(:,:,k)=a;
            end
            S.playing=false; playButton.Text='Play';
            S.stack=st; S.path=full; S.lastDir=folder;
            S.rois={}; S.detections=table(); S.tracks=table(); S.summary=table();
            S.current=1; cla(axImage); S.overlay=gobjects(0);
            refreshROIList(); configureSlider(); refreshFrame(); refreshPlot();
            setStatus(sprintf('Loaded %s (%d × %d × %d)',fn,W,H,N));
        catch ME
            uialert(fig,ME.message,'TIFF load error');
        end
    end
    function configureSlider()
        n=max(1,size(S.stack,3)); frameSlider.Limits=[1 max(2,n)];
        frameSlider.Value=1; frameSlider.MajorTicks=[];
        frameLabel.Text=sprintf('Frame 1/%d',n);
    end
    function refreshROIList()
        if isempty(S.rois)
            roiList.Items={'(no ROI)'}; roiList.Value='(no ROI)';
        else
            roiList.Items=arrayfun(@(i)sprintf('ROI %d',i),1:numel(S.rois), ...
                'UniformOutput',false);
            roiList.Value=roiList.Items{end};
        end
    end
    function addROIcb(~,~)
        try
            assertStack();
            S.playing=false; playButton.Text='Play'; refreshFrame();
            setStatus('Draw polygon; double-click to finish.');
            p=drawpolygon(axImage,'Color',[1 .8 .05]);
            if isempty(p) || ~isvalid(p),return;end
            pos=p.Position;
            delete(p);
            if size(pos,1)<3, return; end
            S.rois{end+1}=pos;
            invalidateResults(); refreshROIList();refreshFrame();
            setStatus(sprintf('%d ROI(s) selected',numel(S.rois)));
        catch ME, uialert(fig,ME.message,'ROI error');end
    end
    function deleteROIcb(~,~)
        if isempty(S.rois),return;end
        idx=sscanf(roiList.Value,'ROI %d');
        if isempty(idx),return;end
        S.rois(idx)=[]; invalidateResults(); refreshROIList(); refreshFrame();
    end
    function invalidateResults()
        S.detections=table(); S.tracks=table(); S.summary=table();
        refreshPlot();
    end
    function showFrame(k)
        if isempty(S.stack),return;end
        S.current=max(1,min(size(S.stack,3),round(k)));
        frameSlider.Value=S.current;
        frameLabel.Text=sprintf('Frame %d/%d',S.current,size(S.stack,3));
        refreshFrame();
    end
    function stepFrame(delta), showFrame(S.current+delta);end
    function sliderChange(~,~), showFrame(frameSlider.Value);end
    function refreshFrame(~,~)
        if isempty(S.stack),cla(axImage);return;end
        % Reuse image object: faster than calling imshow on every frame.
        pic=findobj(axImage,'Type','image');
        if isempty(pic)
            imagesc(axImage,S.stack(:,:,S.current)); axis(axImage,'image');
            colormap(axImage,gray); axImage.YDir='reverse';
        else
            pic(1).CData=S.stack(:,:,S.current);
        end
        if ~isempty(S.overlay)
            delete(S.overlay(isgraphics(S.overlay)));
        end
        S.overlay=gobjects(0);
        hold(axImage,'on');
        for r=1:numel(S.rois)
            p=S.rois{r}; p=[p;p(1,:)];
            S.overlay(end+1)=plot(axImage,p(:,1),p(:,2),'-', ...
                'Color',[1 .8 .05],'LineWidth',1.3);
        end
        if overlayCheck.Value && ~isempty(S.detections)
            d=S.detections(S.detections.Frame==S.current,:);
            if ~isempty(d)
                S.overlay(end+1)=scatter(axImage,d.X,d.Y,35,'r','o');
            end
        end
        hold(axImage,'off');
        title(axImage,sprintf('Frame %d | %s',S.current,shortName(S.path)),'Interpreter','none');
        drawnow limitrate;
    end
    function out=shortName(path)
        [~,n,e]=fileparts(path);out=[n e];
    end
    function togglePlay(~,~)
        if isempty(S.stack) || S.busy,return;end
        S.playing=~S.playing;
        if ~S.playing,playButton.Text='Play';return;end
        playButton.Text='Pause';
        while S.playing && isvalid(fig) && ~S.busy
            t=tic;
            if S.current>=size(S.stack,3),showFrame(1);else,stepFrame(1);end
            drawnow;
            pause(max(0,1/fps.Value-toc(t)));
        end
        if isvalid(playButton),playButton.Text='Play';end
    end
    function keyPress(~,evt)
        if S.busy,return;end
        fo=fig.CurrentObject;
        if ~isempty(fo) && isa(fo,'matlab.ui.control.NumericEditField'),return;end
        switch evt.Key
            case 'rightarrow',stepFrame(1);
            case 'leftarrow',stepFrame(-1);
            case 'space',togglePlay();
        end
    end
    function [det,mask]=detectAt(k,roiMask,roiMasks)
        raw=S.stack(:,:,k);
        img=im2double(raw);
        if sigma.Value>0,img=imgaussfilt(img,sigma.Value);end
        if strcmp(thresh.Value,'Adaptive')
            bw=imbinarize(img,'adaptive','ForegroundPolarity','bright', ...
                'Sensitivity',sens.Value);
        else
            values=img(roiMask);
            if isempty(values) || max(values)==min(values),bw=false(size(img));
            else,bw=img>graythresh(values);end
        end
        bw=bw & roiMask;
        bw=bwareaopen(bw,max(1,ceil(minArea.Value)));
        % Objects crossing an ROI boundary are clipped at the ROI boundary.
        cc=bwconncomp(bw,8);
        stats=regionprops(cc,raw,'Area','Centroid','MeanIntensity', ...
            'MaxIntensity','PixelIdxList');
        keep=find([stats.Area]<=maxArea.Value);
        mask=false(size(bw));
        rows=zeros(numel(keep),8);
        for j=1:numel(keep)
            s=stats(keep(j));mask(s.PixelIdxList)=true;
            % ROI = the ROI containing most of the object's pixels (robust for concave ROIs).
            ri=0;best=0;
            for rr=1:numel(roiMasks)
                c=nnz(roiMasks{rr}(s.PixelIdxList));
                if c>best,best=c;ri=rr;end
            end
            rows(j,:)=[k s.Centroid s.Area double(s.MeanIntensity) ...
                double(s.MaxIntensity) double(s.MeanIntensity)*double(s.Area) ri];
        end
        det=array2table(rows,'VariableNames', ...
            {'Frame','X','Y','AreaPx','MeanIntensity','MaxIntensity','IntegratedIntensity','ROI'});
        % ROI attribution is based on centroid; overlapping ROIs are combined.
    end
    function processAll(~,~)
        if S.busy,return;end
        try
            assertStack();
            if isempty(S.rois),error('Add at least one ROI before processing.');end
            if minArea.Value>maxArea.Value,error('Minimum area exceeds maximum area.');end
            S.playing=false; playButton.Text='Play'; S.busy=true;
            processButton.Enable='off';
            [h,w,n]=size(S.stack);
            mask=false(h,w); roiMasks=cell(numel(S.rois),1);
            for j=1:numel(S.rois)
                p=S.rois{j};roiMasks{j}=poly2mask(p(:,1),p(:,2),h,w);
                mask=mask|roiMasks{j};
            end
            D=cell(n,1);
            dlg=uiprogressdlg(fig,'Title','Processing vesicles', ...
                'Message','Detecting objects','Cancelable','on');
            t=tic;
            for k=1:n
                if dlg.CancelRequested
                    close(dlg);setStatus('Processing cancelled; prior results retained.');
                    S.busy=false; processButton.Enable='on';
                    return;
                end
                D{k}=detectAt(k,mask,roiMasks);
                dlg.Value=k/n;
                if mod(k,10)==0 || k==n
                    dlg.Message=sprintf('Detecting frame %d/%d',k,n);
                    drawnow limitrate;
                end
            end
            det=vertcat(D{:});
            dlg.Message='Linking vesicle trajectories'; drawnow;
            [tracks,summary]=linkObjects(det);
            close(dlg);
            S.detections=det; S.tracks=tracks; S.summary=summary;
            refreshFrame(); refreshPlot();
            setStatus(sprintf('%d detections, %d tracks, %.1f s',height(det),height(summary),toc(t)));
        catch ME
            if exist('dlg','var') && isvalid(dlg),close(dlg);end
            uialert(fig,ME.message,'Processing error');
        end
        S.busy=false; processButton.Enable='on';
    end
    function [T,Q]=linkObjects(D)
        % Greedy global nearest-distance pairs, restricted within ROI.
        % Allows gaps up to maxGap frames; IDs persist, no split/merge logic.
        % Search radius scales with frames elapsed (maxDist per frame of gap).
        if isempty(D)
            T=D;T.TrackID=zeros(0,1);
            Q=table('Size',[0 8],'VariableTypes',repmat({'double'},1,8), ...
                'VariableNames',{'TrackID','FirstFrame','LastFrame','Detections','DurationS', ...
                'PathLengthUm','NetDisplacementUm','MeanSpeedUmPerS'});
            return;
        end
        ids=zeros(height(D),1);
        activeID=[]; activeXY=zeros(0,2); activeFrame=[]; activeROI=[];
        nextID=0;
        for f=1:max(D.Frame)
            ix=find(D.Frame==f); n=numel(ix);
            % Evict tracks with too many missing observations.
            ok=(f-activeFrame)<=maxGap.Value+1;
            activeID=activeID(ok);activeXY=activeXY(ok,:);
            activeFrame=activeFrame(ok);activeROI=activeROI(ok);
            assignedTrack=false(numel(activeID),1);
            assignedDet=false(n,1);
            if n>0 && ~isempty(activeID)
                aa=[];bb=[];dist=[];
                for a=1:numel(activeID)
                    valid=find(D.ROI(ix)==activeROI(a));
                    if isempty(valid),continue;end
                    dx=D.X(ix(valid))-activeXY(a,1);
                    dy=D.Y(ix(valid))-activeXY(a,2);
                    dd=hypot(dx,dy);
                    good=dd<=maxDist.Value*(f-activeFrame(a));
                    aa=[aa;repmat(a,nnz(good),1)]; %#ok<AGROW>
                    bb=[bb;valid(good)]; %#ok<AGROW>
                    dist=[dist;dd(good)]; %#ok<AGROW>
                end
                [~,order]=sort(dist);
                for z=order'
                    a=aa(z);b=bb(z);
                    if assignedTrack(a) || assignedDet(b),continue;end
                    ids(ix(b))=activeID(a);
                    activeXY(a,:)=[D.X(ix(b)) D.Y(ix(b))];
                    activeFrame(a)=f;
                    assignedTrack(a)=true;assignedDet(b)=true;
                end
            end
            for b=find(~assignedDet)'
                nextID=nextID+1;ids(ix(b))=nextID;
                activeID(end+1,1)=nextID;
                activeXY(end+1,:)=[D.X(ix(b)) D.Y(ix(b))];
                activeFrame(end+1,1)=f;activeROI(end+1,1)=D.ROI(ix(b));
            end
        end
        T=D;T.TrackID=ids;
        % Spatial metrics in µm use the pixel size field.
        rows=zeros(nextID,8); px=pxSize.Value;
        for id=1:nextID
            sel=ids==id; [frames,o]=sort(T.Frame(sel));
            x=T.X(sel);y=T.Y(sel);x=x(o);y=y(o);
            dur=(max(frames)-min(frames))/fps.Value;
            pathUm=sum(hypot(diff(x),diff(y)))*px;
            netUm=hypot(x(end)-x(1),y(end)-y(1))*px;
            spd=NaN; if dur>0,spd=pathUm/dur;end
            rows(id,:)=[id frames(1) frames(end) numel(frames) dur pathUm netUm spd];
        end
        Q=array2table(rows,'VariableNames', ...
            {'TrackID','FirstFrame','LastFrame','Detections','DurationS', ...
            'PathLengthUm','NetDisplacementUm','MeanSpeedUmPerS'});
    end
    function refreshPlot(~,~)
        cla(axPlot);
        if isempty(S.tracks)
            xlabel(axPlot,'Time (s)'); ylabel(axPlot,'Intensity (raw AU)');
            title(axPlot,'Process a TIFF to view traces');grid(axPlot,'on');return;
        end
        T=S.tracks; field=metric.Value;
        if trackSelect.Value>0,T=T(T.TrackID==trackSelect.Value,:);end
        if isempty(T),title(axPlot,'No matching track');return;end
        ids=unique(T.TrackID);
        hold(axPlot,'on');
        cm=lines(max(numel(ids),1));
        for j=1:numel(ids)
            d=T(T.TrackID==ids(j),:);
            [fr,ord]=sort(d.Frame);v=d.(field);v=v(ord);
            % Missing frames plotted as gaps instead of fabricated intensity.
            ft=(min(fr):max(fr))'; y=nan(size(ft));y(fr-min(fr)+1)=v;
            plot(axPlot,(ft-1)/fps.Value,y,'-','LineWidth',1.2,'Color',cm(j,:));
            if eventDelta.Value>0 && numel(fr)>1
                rise=[false;diff(v)>=eventDelta.Value & diff(fr)==1];
                scatter(axPlot,(fr(rise)-1)/fps.Value,v(rise),22,cm(j,:),'filled');
            end
        end
        hold(axPlot,'off');xlabel(axPlot,'Time (s)');
        ylabel(axPlot,[field ' (raw AU)']);
        title(axPlot,sprintf('%d tracked trajectories | events = consecutive increases ≥ %.3g', ...
            numel(ids),eventDelta.Value));grid(axPlot,'on');
    end
    function exportCSV(~,~)
        if isempty(S.tracks),uialert(fig,'Process frames first.','No results');return;end
        [file,folder]=uiputfile('*.csv','Save detection/tracking CSV', ...
            fullfile(S.lastDir,'vesicle_tracks.csv'));
        if isequal(file,0),return;end
        [~,base,~]=fileparts(file);
        writetable(S.tracks,fullfile(folder,[base '.csv']));
        writetable(S.summary,fullfile(folder,[base '_summary.csv']));
        setStatus('Exported object-level and track-summary CSVs');
    end
    function saveSession(~,~)
        if isempty(S.stack),uialert(fig,'Load a TIFF first.','No data');return;end
        [file,folder]=uiputfile('*.mat','Save session',fullfile(S.lastDir,'vesicle_session.mat'));
        if isequal(file,0),return;end
        session=struct('version',1,'stack',S.stack,'sourcePath',S.path, ...
            'roiPositions',{S.rois},'detections',S.detections,'tracks',S.tracks, ...
            'summary',S.summary,'params',captureParams(),'frame',S.current);
        save(fullfile(folder,file),'session','-v7.3');
        setStatus('Saved self-contained MAT session (includes image stack)');
    end
    function p=captureParams()
        p=struct('threshold',thresh.Value,'sensitivity',sens.Value, ...
            'minArea',minArea.Value,'maxArea',maxArea.Value,'sigma',sigma.Value, ...
            'maxDist',maxDist.Value,'maxGap',maxGap.Value,'fps',fps.Value, ...
            'pxSize',pxSize.Value,'eventDelta',eventDelta.Value,'metric',metric.Value);
    end
    function loadSession(~,~)
        [file,folder]=uigetfile('*.mat','Load vesicle session',S.lastDir);
        if isequal(file,0),return;end
        try
            a=load(fullfile(folder,file),'session');x=a.session;
            if ~isfield(x,'version') || x.version~=1,error('Unsupported session version.');end
            S.playing=false;playButton.Text='Play';S.stack=x.stack;S.path=x.sourcePath;
            S.rois=x.roiPositions;S.detections=x.detections;
            S.tracks=x.tracks;S.summary=x.summary;S.lastDir=folder;
            p=x.params;
            thresh.Value=p.threshold;sens.Value=p.sensitivity;
            minArea.Value=p.minArea;maxArea.Value=p.maxArea;sigma.Value=p.sigma;
            maxDist.Value=p.maxDist;maxGap.Value=p.maxGap;fps.Value=p.fps;
            pxSize.Value=p.pxSize;eventDelta.Value=p.eventDelta;metric.Value=p.metric;
            cla(axImage);S.overlay=gobjects(0);
            refreshROIList();configureSlider();showFrame(x.frame);refreshPlot();
            setStatus('Session restored');
        catch ME,uialert(fig,ME.message,'Session error');end
    end
    function exportPlot(~,~)
        if isempty(S.tracks),uialert(fig,'Process frames first.','No plot');return;end
        [file,folder]=uiputfile({'*.png','PNG image';'*.pdf','Vector PDF'}, ...
            'Export intensity plot',fullfile(S.lastDir,'vesicle_traces.png'));
        if isequal(file,0),return;end
        try
            exportgraphics(axPlot,fullfile(folder,file),'Resolution',300);
            setStatus('Plot exported');
        catch ME,uialert(fig,ME.message,'Export error');end
    end
    function resetApp(~,~)
        S.playing=false; S.stack=[];S.path='';S.rois={};
        S.detections=table();S.tracks=table();S.summary=table();
        S.current=1;S.overlay=gobjects(0);refreshROIList();cla(axImage);
        title(axImage,'Load a multi-page TIFF');configureSlider();refreshPlot();
        frameLabel.Text='Frame —';playButton.Text='Play';setStatus('Ready');
    end
    function closeApp(~,~)
        S.playing=false;delete(fig);
    end
end
