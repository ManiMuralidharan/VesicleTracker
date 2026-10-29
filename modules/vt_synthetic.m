function truth=vt_synthetic(path,p)
% Reproducible synthetic moving Gaussian spots with deliberately timed rises.
rng(1042,'twister');H=128;W=128;N=60;[X,Y]=meshgrid(1:W,1:H);
starts=[22 24;98 28;26 100;97 95;60 60];v=[.60 .35;-.52 .32;.30 -.48;-.45 -.30;0.12 0.2];
K=size(starts,1);eventFrame=[20;30;40;25;35];
xy=zeros(N,K,2);intensities=zeros(N,K);tObj=Tiff(path,'w');
for f=1:N
    im=double(180+25*randn(H,W));
    for k=1:K
        xy(f,k,:)=starts(k,:)+(f-1)*v(k,:);
        xx=xy(f,k,1);yy=xy(f,k,2);
        amp=1000;
        if f>=eventFrame(k) && f<eventFrame(k)+8,amp=1700;end
        intensities(f,k)=amp;
        im=im+amp*exp(-((X-xx).^2+(Y-yy).^2)/(2*1.5^2));
    end
    im=im*exp(-.004*(f-1));frame=uint16(max(0,min(65535,round(im))));
    tags.ImageLength=H;tags.ImageWidth=W;tags.Photometric=Tiff.Photometric.MinIsBlack;
    tags.BitsPerSample=16;tags.SamplesPerPixel=1;tags.SampleFormat=Tiff.SampleFormat.UInt;
    tags.PlanarConfiguration=Tiff.PlanarConfiguration.Chunky;
    tags.Compression=Tiff.Compression.None;tags.RowsPerStrip=H;
    tObj.setTag(tags);tObj.write(frame);
    if f<N,tObj.writeDirectory();end
end
tObj.close();
truth=struct('positionsPx',xy,'eventFrames',eventFrame,'intensities',intensities, ...
    'frameCount',N,'trackCount',K);
save([path '.truth.mat'],'truth');
end
