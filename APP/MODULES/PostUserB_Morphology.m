%% Import and elaboration of data
tic
cd(fold_var)
load('StudyAreaVariables.mat');
load('UserA_Answers.mat','SpecificWindow');
cd(fold_raw_dtm)

% Import tif and tfw file names
switch DTMType
    case 0
    NameFile1=FileName_DTM(contains(FileName_DTM,'tif'));
    NameFile2=FileName_DTM(contains(FileName_DTM,'tfw'));
    case 1
    NameFile1=FileName_DTM;
    case 2
    NameFile1=FileName_DTM;
end

% Initializing of cells in for loop to increase speed
[xLongAll, yLatAll, ElevationAll, RAll, AspectAngleAll, SlopeAll,...
            GradNAll,GradEAll]=deal(cell(1,length(NameFile1)));

for i1=1:length(NameFile1)
    switch DTMType
        case 0
            A=imread(NameFile1(i1));
            R=worldfileread(NameFile2(i1),'planar',size(A));  
        case 1
            [A,R]=readgeoraster(NameFile1(i1),'OutputType','double');
        case 2
            [A,R]=readgeoraster(NameFile1(i1),'OutputType','double');
    end

    if isempty(R.ProjectedCRS) && i1==1
        choice2=inputdlg({'Set DTM EPSG (default value is for Sicily):'},'',1,{'32633'});
        R.ProjectedCRS=projcrs(str2double(choice2));
    elseif isempty(R.ProjectedCRS) && i1>1
        R.ProjectedCRS=projcrs(str2double(choice2));
    end
        
    [x_lim,y_lim] = mapoutline(R, size(A));
    RasterExtentInWorldX=max(x_lim)-min(x_lim);
    RasterExtentInWorldY=max(y_lim)-min(y_lim);
    dX=RasterExtentInWorldX/(size(A,2)-1);
    dY=RasterExtentInWorldY/(size(A,1)-1);
    [XTBS,YTBS]=worldGrid(R);

    if AnswerChangeDTMResolution==1
        ScaleFactorX=int64(NewDx/dX);
        ScaleFactorY=int64(NewDy/dY);
    else
        ScaleFactorX=1;
        ScaleFactorY=1;
    end

    X=XTBS(1:ScaleFactorX:end,1:ScaleFactorY:end);
    Y=YTBS(1:ScaleFactorX:end,1:ScaleFactorY:end);

    Elevation=A(1:ScaleFactorX:end,1:ScaleFactorY:end);
    
    if string(R.CoordinateSystemType)=="planar"
        [yLat,xLong]=projinv(R.ProjectedCRS,X,Y);
        LatMin=min(yLat,[],"all");
        LatMax=max(yLat,[],"all");
        LongMin=min(xLong,[],"all");
        LongMax=max(xLong,[],"all");
        RGeo=georefcells([LatMin,LatMax],[LongMin,LongMax],size(Elevation));
        RGeo.GeographicCRS=R.ProjectedCRS.GeographicCRS;
    else
        RGeo=R;
    end

    xLongAll{i1}=xLong;
    yLatAll{i1}=yLat;
    [AspectDTM,SlopeDTM,GradNDTM,GradEDTM]=gradientm(Elevation,RGeo);
    ElevationAll{i1}=Elevation;
    RAll{i1}=RGeo;
    AspectAngleAll{i1}=AspectDTM;
    SlopeAll{i1}=SlopeDTM;
    GradNAll{i1}=GradNDTM;
    GradEAll{i1}=GradEDTM;
end

IndexDTMPointsInsideStudyArea=cell(1,length(xLongAll));

for i2=1:length(xLongAll)
    [pp,ee]=getnan2([StudyAreaPolygonClean.Vertices; nan nan]);
    IndexDTMPointsInsideStudyArea{i2}=find(inpoly([xLongAll{i2}(:),yLatAll{i2}(:)],pp,ee)==1);
end

EmptyIndexDTMPointsInsideStudyArea=cellfun(@isempty,IndexDTMPointsInsideStudyArea);
IndexDTMPointsInsideStudyArea(EmptyIndexDTMPointsInsideStudyArea)=[];
xLongAll(EmptyIndexDTMPointsInsideStudyArea)=[];
yLatAll(EmptyIndexDTMPointsInsideStudyArea)=[];
ElevationAll(EmptyIndexDTMPointsInsideStudyArea)=[];
RAll(EmptyIndexDTMPointsInsideStudyArea)=[];
AspectAngleAll(EmptyIndexDTMPointsInsideStudyArea)=[];
SlopeAll(EmptyIndexDTMPointsInsideStudyArea)=[];
GradNAll(EmptyIndexDTMPointsInsideStudyArea)=[];
GradEAll(EmptyIndexDTMPointsInsideStudyArea)=[];

%% Orthophoto
if OrthophotoAnswer
    cd(fold_raw_sat)
    FileID=fopen('UrlMap.txt','r');
    UrlMap=fscanf(FileID,'%s');
    fclose(FileID);

    if isempty(UrlMap)
        choice1=inputdlg({'Enter WMS Url:'},'',1,{''});
        UrlMap=string(choice1{1});
    end

    ServerMap=WebMapServer(UrlMap);
    info = wmsinfo(UrlMap);
    orthoLayer = info.Layer(1);
    
    LimMap=cellfun(@(x) [x.LongitudeLimits; x.LatitudeLimits] ,RAll,'UniformOutput',false);
    LimLatMap=cellfun(@(x) x(2,:),LimMap,'UniformOutput',false);
    LimLonMap=cellfun(@(x) x(1,:),LimMap,'UniformOutput',false);
    
    samplesPerInterval=[km2deg(0.005) km2deg(0.005)] ;

    [ZOrtho,ROrtho]=cellfun(@(x,y) wmsread(orthoLayer,'LatLim',x,'LonLim',y,'CellSize',samplesPerInterval),...
                            LimLatMap,LimLonMap,'UniformOutput',false);

    filename1='fig1';
    f1=figure(1);
    set(f1 , ...
        'Color',[1 1 1],...
        'PaperType','a4',...
        'PaperSize',[29.68 20.98 ],...    
        'PaperUnits', 'centimeters',...
        'PaperPositionMode','manual',...
        'PaperPosition', [0 1 12 6],...
        'InvertHardcopy','off');
    set( gcf ,'Name' , filename1);

    axes1 = axes('Parent',f1); 
    hold(axes1,'on');

    % cellfun(@(x,y) geoshow(x,y),ZOrtho,ROrtho);

    LatGridOrtho = cellfun(@(x) x.LatitudeLimits(2)-x.CellExtentInLatitude/2 : ...
                           -x.CellExtentInLatitude : ...
                           x.LatitudeLimits(1)+x.CellExtentInLatitude/2, ...
                           ROrtho, 'UniformOutput',false);
    LongGridOrtho = cellfun(@(x) x.LongitudeLimits(1)+x.CellExtentInLongitude/2 : ...
                            x.CellExtentInLongitude : ...
                            x.LongitudeLimits(2)-x.CellExtentInLongitude/2, ...
                            ROrtho, 'UniformOutput',false);
    [xLongOrtho, yLatOrtho] = cellfun(@(x,y) meshgrid(x,y), ...
                                      LongGridOrtho, LatGridOrtho, ...
                                      'UniformOutput',false);

    OrthoRGB = cellfun(@(x) reshape(x(:), [size(x,1)*size(x,2), 3]), ...
                       ZOrtho, 'UniformOutput',false);

    IndexOrthoPointsInsideStudyArea = cell(1,length(xLongOrtho));
    for i2 = 1:length(xLongOrtho)
        [pp,ee] = getnan2([StudyAreaPolygon.Vertices; nan nan]);
        IndexOrthoPointsInsideStudyArea{i2} = find(inpoly([xLongOrtho{i2}(:),yLatOrtho{i2}(:)],pp,ee)==1);
    end

    for i = 1:length(xLongOrtho)
        scatter(xLongOrtho{i}(IndexOrthoPointsInsideStudyArea{i}), ...
                yLatOrtho{i}(IndexOrthoPointsInsideStudyArea{i}), ...
                2, double(OrthoRGB{i}(IndexOrthoPointsInsideStudyArea{i},:))./255, ... % Note that it is important to convert OrthoRGB in double!
                's', 'filled', 'MarkerEdgeColor','none') % , 'MarkerFaceAlpha',0.5)
        hold on
    end
    daspect([1, 1, 1])
end

%% Plot to check the Study Area
f1 = figure(1);
for i3=1:length(xLongAll)
    fastscatter(xLongAll{i3}(IndexDTMPointsInsideStudyArea{i3}), ...
                yLatAll{i3}(IndexDTMPointsInsideStudyArea{i3}), ...
                ElevationAll{i3}(IndexDTMPointsInsideStudyArea{i3}))
    hold on
    title('Study Area Polygon Check')
    xlim([MinExtremes(1) MaxExtremes(1)])
    ylim([MinExtremes(2) MaxExtremes(2)])
    daspect([1 1 1])
end

    hold on
    plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1);
    hold on
    plot(StudyAreaPolygonClean,'FaceColor','none','LineWidth',0.5);

%% Creation of empty parameter matrices
SizeGridInCell =    cellfun(@size, xLongAll, 'UniformOutput',false);
CohesionAll =       cellfun(@(x) NaN(x), SizeGridInCell, 'UniformOutput',false);
PhiAll =            cellfun(@(x) NaN(x), SizeGridInCell, 'UniformOutput',false);
KtAll =             cellfun(@(x) NaN(x), SizeGridInCell, 'UniformOutput',false);
AAll =              cellfun(@(x) NaN(x), SizeGridInCell, 'UniformOutput',false);
nAll =              cellfun(@(x) NaN(x), SizeGridInCell, 'UniformOutput',false);
BetaStarAll =       cellfun(@cosd, SlopeAll, 'UniformOutput',false); % If Vegetation is not associated, betastar will depends on slope
RootCohesionAll =   cellfun(@zeros, SizeGridInCell, 'UniformOutput',false); % If Vegetation is not associated, root cohesion will be zero
toc

% Creatings string names of variables in cell arrays to save at the end
VariablesMorph={'ElevationAll','RAll','AspectAngleAll','SlopeAll','GradNAll','GradEAll'};
VariablesGridCoord={'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea'};
VariablesSoilPar={'CohesionAll','PhiAll','KtAll','AAll','nAll'};
VariablesVegPar={'RootCohesionAll','BetaStarAll'};
VariablesAnswer={'AnswerChangeDTMResolution','DTMType','FileName_DTM','AnswerChangeDTMResolution','OrthophotoAnswer'};
if AnswerChangeDTMResolution==1; VariablesAnswer=[VariablesAnswer,{'NewDx','NewDy'}]; end

%% Saving...
cd(fold_var)
if OrthophotoAnswer; save('Orthophoto.mat','ZOrtho','ROrtho'); end
save('UserB_Answers.mat',VariablesAnswer{:});
save('MorphologyParameters.mat',VariablesMorph{:});
save('GridCoordinates',VariablesGridCoord{:});
save('SoilParameters.mat',VariablesSoilPar{:});
save('VegetationParameters.mat',VariablesVegPar{:});
cd(fold0)