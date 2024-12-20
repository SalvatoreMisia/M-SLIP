function [varargout] = datasetstudy_creation(fold0, varargin)

% CREATE A DATASET TO USE FOR ML
%   
% Outputs:
%   [DatasetFeaturesStudy]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, ...
%                                                           TimeSensitivePart]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, ...
%                                     TimeSensitivePart, DatasetNotNormalized]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, ...
%                       TimeSensitivePart, DatasetNotNormalized, FeaturesType]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, ...
%           TimeSensitivePart, DatasetNotNormalized, FeaturesType, ClassPolys]
%   
% Required arguments:
%   - fold0 : is to identify the folder in which you have the analysis.
%   
%   - 'Features', cellStringArray : a list of the feature you want to use 
%   (example: 'Features', {'Elevation', 'Slope', 'Rainfall'}).
%   Possible feature are 'Elevation', 'Slope', 'Aspect Angle', 'Mean Curvature', 
%   'Profile Curvature', 'Planform Curvature', 'Contributing Area (log)', 'TWI', 
%   'Clay Content', 'Sand Content', 'NDVI', 'Sub Soil', 'Top Soil', 'Land Use', 
%   'Vegetation', 'Distance To Roads', 'Rainfall', 'Temperature', 'Random'.
%   If you use ('Features', 'AllFeats') or you don't specify anything, then you 
%   will take all of these.
%   
%   - 'Categorical', logical : to choose if you want to consider
%   categorical part (i.e. Sub Soil, Top Soil, Land Use, and Vegetation) as
%   a categorical variable or numerical. If you set ('Categorical', true)
%   then you will consider these variables as categorical, otherwise not.
%   If you don't specify anything, then ('Categorical', true) will be
%   assumed.
%   
% Optional arguments:
%   - 'Normalize', logical : to have or not ranges for normalization. Default 
%   is true, so it will ask you to specify these ranges during the script. 
%   If you write false, then no Normalization will be performed and outfput
%   for Ranges will be a matrix of NaNs.
%   
%   - 'Ranges', table : is the table that will be used to normalize data
%   in dataset. It must be a nx2 table (n is the number of features you
%   have), containing in the first column min values and in the second the
%   max values.
%   
%   - 'TargetFig', uiFigObject : to specify in which figure you want to
%   prompt questions or extra inputs. If you don't specify anything, a new
%   uifigure will be created.
%   
%   - 'TimeSensMode', string : to set the type of approach you want to use
%   for time sensitive part. Possible string values are 'CondensedDays', 
%   'SeparateDays', or 'TriggerCausePeak'. If no value is specified, then
%   the default value will be 'CondensedDays'.
%   
%   - 'DaysForTS', num : to set how many days to consider for time sensitive 
%   part (cumulate or average). If you don't specify anything the value will 
%   be set to 1 by default (1 day of cumulate or average value). This entry 
%   means the number of days you want to use to cumulate or average values 
%   when 'TimeSensMode' is set to value 'CondensedDays'. If 'TimeSensMode' is
%   set to 'SeparateDays', this value will be the number of separate 
%   days to consider as separate features of your neural network.
%   
%   - 'DayOfEvent', datetime : to set the datetime of the event you want to 
%   consider. If you don't specify anything, then it will be prompted a dialog 
%   where to choose.
%   
%   - 'CauseMode', string : to set the way you want to consider rainfalls 
%   before the Trigger event. It will have effect only when 'TimeSensMode'
%   is set to 'TriggerCausePeak'. Possible string values are 'DailyCumulate' 
%   or'EventsCumulate'. If no value is specified, then 'EventsCumulate' is 
%   taken as default.
%   
%   - 'FileAssName', string : is to define the name of the excel that
%   contains the association between the content of shapefiles and classes.
%   If you don't specify anything, then 'ClassesML.xlsx' file will be take 
%   as default.

%% Settings initialization
FeatsToUse = {"allfeats"};      % Default
CategVars  = true;              % Default
NormData   = true;              % Default
ModeForTS  = "condenseddays";   % Default
DaysForTS  = 1;                 % Default
FileAssoc  = 'ClassesML.xlsx';  % Default
CreateRngs = true;              % Default
CauseMode  = "eventscumulate";  % Default
Prmpt4Fts  = [];                % Inizialized
FeatsType  = [];                % Initialized
SuggRanges = [];                % Initialized

ClassPolys = table;             % Initialized
DatasetFeaturesStudy = table;   % Initialized

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart), 'Uniform',false);

    vararginCopy = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCopy(StringPart) = varargin(StringPart);

    InputFeatures    = find(cellfun(@(x) strcmpi(x, "features"),     vararginCopy));
    InputCategorical = find(cellfun(@(x) strcmpi(x, "categorical"),  vararginCopy));
    InputNormalize   = find(cellfun(@(x) strcmpi(x, "normalize"),    vararginCopy));
    InputModeForTS   = find(cellfun(@(x) strcmpi(x, "timesensmode"), vararginCopy));
    InputDaysForTS   = find(cellfun(@(x) strcmpi(x, "daysforts"),    vararginCopy));
    InputEventDay    = find(cellfun(@(x) strcmpi(x, "dayofevent"),   vararginCopy));
    InputTargetFig   = find(cellfun(@(x) strcmpi(x, "targetfig"),    vararginCopy));
    InputFileAssoc   = find(cellfun(@(x) strcmpi(x, "fileassname"),  vararginCopy));
    InputRanges      = find(cellfun(@(x) strcmpi(x, "ranges"),       vararginCopy));
    InputCauseMode   = find(cellfun(@(x) strcmpi(x, "causemode"),    vararginCopy));

    if InputFeatures;    FeatsToUse = varargin{InputFeatures+1};    end
    if InputCategorical; CategVars  = varargin{InputCategorical+1}; end
    if InputNormalize;   NormData   = varargin{InputNormalize+1};   end
    if InputModeForTS;   ModeForTS  = varargin{InputModeForTS+1};   end
    if InputDaysForTS;   DaysForTS  = varargin{InputDaysForTS+1};   end
    if InputEventDay;    EventDay   = varargin{InputEventDay+1};    end
    if InputTargetFig;   Fig        = varargin{InputTargetFig+1};   end
    if InputFileAssoc;   FileAssoc  = varargin{InputFileAssoc+1};   end
    if InputRanges;      Ranges     = varargin{InputRanges+1};      end
    if InputCauseMode;   CauseMode  = varargin{InputCauseMode+1};   end

    if InputFeatures
        FeatsToUse = cellfun(@(x) lower(string(x)), FeatsToUse, 'Uniform',false); % To have consistency in terms of data type and case type
    end

    if InputRanges
        CreateRngs = false;
        if not(istable(Ranges))
            error('You have specified Ranges as input but not as a table!')
        elseif isempty(Ranges) || all(isnan(Ranges{:,:}), 'all')
            CreateRngs = true;
            warning('You have put as input Ranges but it is empty or filled with nans. Ranges will be ignored and re-created!')
        end
    end
end

if not(exist('Fig', 'var')); Fig = uifigure; end

%% Loading of main variables
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Dataset: reading files for dataset creation...', ...
                                 'Indeterminate','on');

sl = filesep;

% Main files
load([fold0,sl,'os_folders.mat'],         'fold_var','fold_user')
load([fold_var,sl,'GridCoordinates.mat'], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')

xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy  = cellfun(@(x,y) x(y), yLatAll , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

xLongStudyCat = cat(1, xLongStudy{:});
yLatStudyCat  = cat(1, yLatStudy{:});

DatasetCoordinatesStudy = table(xLongStudyCat, yLatStudyCat, 'VariableNames',{'Longitude','Latitude'});

%% Loading of features (numerical part)
ProgressBar.Message = 'Dataset: reading numerical part...';

% Elevation
if any(contains([FeatsToUse{:}], ["elevation", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll')

    ElevationStudy = cellfun(@(x,y) x(y), ElevationAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.Elevation = cat(1,ElevationStudy{:});
    clear('ElevationAll')

    Prmpt4Fts = [Prmpt4Fts, "Elevation [m]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [0, 2000];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Slope
if any(contains([FeatsToUse{:}], ["slope", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'SlopeAll')

    SlopeStudy = cellfun(@(x,y) x(y), SlopeAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.Slope = cat(1,SlopeStudy{:});
    clear('SlopeAll')

    Prmpt4Fts = [Prmpt4Fts, "Slope [°]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [0, 80];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Aspect angle
if any(contains([FeatsToUse{:}], ["aspect", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'AspectAngleAll')

    AspectAngleStudy = cellfun(@(x,y) x(y), AspectAngleAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.AspectAngle = cat(1,AspectAngleStudy{:});
    clear('AspectAngleAll')

    Prmpt4Fts = [Prmpt4Fts, "Aspect Angle [°]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [0, 360];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Mean curvature
if any(contains([FeatsToUse{:}], ["mean", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'MeanCurvatureAll')

    MeanCurvStudy = cellfun(@(x,y) x(y), MeanCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.MeanCurvature = cat(1,MeanCurvStudy{:});
    clear('MeanCurvatureAll')

    Prmpt4Fts = [Prmpt4Fts, "Mean Curvature [1/m]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = quantile(DatasetFeaturesStudy.MeanCurvature, [0.25, 0.75]);
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Profile curvature
if any(contains([FeatsToUse{:}], ["profile", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'ProfileCurvatureAll')

    ProfileCurvStudy = cellfun(@(x,y) x(y), ProfileCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.ProfileCurvature = cat(1,ProfileCurvStudy{:});
    clear('ProfileCurvatureAll')

    Prmpt4Fts = [Prmpt4Fts, "Profile Curvature [1/m]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = quantile(DatasetFeaturesStudy.ProfileCurvature, [0.25, 0.75]);
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Planform curvature
if any(contains([FeatsToUse{:}], ["planform", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'PlanformCurvatureAll')

    PlanformCurvStudy = cellfun(@(x,y) x(y), PlanformCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.PlanformCurvature = cat(1,PlanformCurvStudy{:});
    clear('PlanformCurvatureAll')

    Prmpt4Fts = [Prmpt4Fts, "Planform Curvature [1/m]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = quantile(DatasetFeaturesStudy.PlanformCurvature, [0.25, 0.75]);
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Contributing area
if any(contains([FeatsToUse{:}], ["contributing", "allfeats"]))
    load([fold_var,sl,'FlowRouting.mat'], 'ContributingAreaAll')

    ContrAreaLogStudy = cellfun(@(x,y) log(x(y)), ContributingAreaAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.ContributingAreaLog = cat(1,ContrAreaLogStudy{:});
    clear('ContributingAreaAll')

    Prmpt4Fts = [Prmpt4Fts, "Contributing Area [log(m2)]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.ContributingAreaLog), max(DatasetFeaturesStudy.ContributingAreaLog)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% TWI
if any(contains([FeatsToUse{:}], ["twi", "allfeats"]))
    load([fold_var,sl,'FlowRouting.mat'], 'TwiAll')

    TwiStudy = cellfun(@(x,y) x(y), TwiAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.TWI = cat(1,TwiStudy{:});
    clear('TwiAll')

    Prmpt4Fts = [Prmpt4Fts, "TWI [log(m2)]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.TWI), max(DatasetFeaturesStudy.TWI)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Clay content
if any(contains([FeatsToUse{:}], ["clay", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'ClayContentAll')

    ClayContentStudy = cellfun(@(x,y) x(y), ClayContentAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.ClayContent = cat(1,ClayContentStudy{:});
    clear('ClayContentAll')

    Prmpt4Fts = [Prmpt4Fts, "Clay Content [-]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.ClayContent), max(DatasetFeaturesStudy.ClayContent)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Sand content
if any(contains([FeatsToUse{:}], ["sand", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'SandContentAll')

    SandContentStudy = cellfun(@(x,y) x(y), SandContentAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.SandContent = cat(1,SandContentStudy{:});
    clear('SandContentAll')

    Prmpt4Fts = [Prmpt4Fts, "Sand Content [-]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.SandContent), max(DatasetFeaturesStudy.SandContent)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% NDVI
if any(contains([FeatsToUse{:}], ["ndvi", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'NdviAll')

    NdviStudy = cellfun(@(x,y) x(y), NdviAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.NDVI = cat(1,NdviStudy{:});
    clear('NdviAll')

    Prmpt4Fts = [Prmpt4Fts, "NDVI [-]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.NDVI), max(DatasetFeaturesStudy.NDVI)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Distance
if any(contains([FeatsToUse{:}], ["distance", "allfeats"]))
    load([fold_var,sl,'Distances.mat'], 'MinDistToRoadAll')

    MinDistToRoadStudy = cellfun(@(x,y) x(y), MinDistToRoadAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.MinDistanceToRoads = cat(1,MinDistToRoadStudy{:});
    clear('MinDistToRoadAll')

    Prmpt4Fts = [Prmpt4Fts, "Distance To Roads [m]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.MinDistanceToRoads), max(DatasetFeaturesStudy.MinDistanceToRoads)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Vegetation Probabilities
if any(contains([FeatsToUse{:}], ["veg"+wildcardPattern+"prob"+lettersPattern, "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'VgPrAll')

    VegVarNames = VgPrAll.Properties.RowNames;
    for i1 = 1:numel(VegVarNames)
        VegPrTmp = cellfun(@(x,y) x(y), VgPrAll{i1,:}, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
        DatasetFeaturesStudy.(VegVarNames{i1}) = cat(1,VegPrTmp{:});
        clear('VegPrTmp')
    end

    Prmpt4Fts = [Prmpt4Fts, string(VegVarNames')];
    FeatsType = [FeatsType, repmat("Numerical", 1, numel(VegVarNames))];
    RngsToAdd = [min(DatasetFeaturesStudy{:,VegVarNames}, [], 'all'), ...
                 max(DatasetFeaturesStudy{:,VegVarNames}, [], 'all')];
    if NormData; SuggRanges = [SuggRanges; repmat(RngsToAdd, numel(VegVarNames), 1)]; end
end

% Random
if any(contains([FeatsToUse{:}], ["random", "allfeats"]))
    RandomStudy = cellfun(@(x,y) rand(size(x)), IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.Random = cat(1,RandomStudy{:});

    Prmpt4Fts = [Prmpt4Fts, "Random [-]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [0, 1];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

%% Loading of features (categorical part) -- please work on it to make it a single operation for each class (just from line 409 to 486 in a cycle)
ProgressBar.Message = 'Dataset: reading categorical part...';

% Reading of excel sheets
if any(contains([FeatsToUse{:}], ["sub", "top", "land", "vegetation", "allfeats"]))
    Sheet_InfoClasses    = readcell([fold_user,sl,FileAssoc], 'Sheet','Main');
    Sheet_SubSoilClasses = readcell([fold_user,sl,FileAssoc], 'Sheet','Sub soil');
    Sheet_TopSoilClasses = readcell([fold_user,sl,FileAssoc], 'Sheet','Top soil');
    Sheet_LandUseClasses = readcell([fold_user,sl,FileAssoc], 'Sheet','Land use');
    Sheet_VegetClasses   = readcell([fold_user,sl,FileAssoc], 'Sheet','Vegetation');

    [ColWithTitles, ColWithClassNum, ColWithDescript] = deal(false(1, size(Sheet_InfoClasses, 2)));
    for i1 = 1:length(ColWithTitles)
        ColWithTitles(i1)   = any(cellfun(@(x) strcmp(string(x), 'Title'      ), Sheet_InfoClasses(:,i1)));
        ColWithClassNum(i1) = any(cellfun(@(x) strcmp(string(x), 'Number'     ), Sheet_InfoClasses(:,i1)));
        ColWithDescript(i1) = any(cellfun(@(x) strcmp(string(x), 'Description'), Sheet_InfoClasses(:,i1)));
    end
    ColWithSubject = find(ColWithTitles)-1;

    if sum(ColWithTitles) > 1 || sum(ColWithClassNum) > 1 || sum(ColWithDescript) > 1
        error('Please, align columns in excel! Sheet: Main')
    end

    IndsBlankRowsTot = all(cellfun(@(x) all(ismissing(x)), Sheet_InfoClasses), 2);
    IndsBlnkInColNum = cellfun(@(x) all(ismissing(x)), Sheet_InfoClasses(:,ColWithClassNum));

    if not(isequal(IndsBlankRowsTot, IndsBlnkInColNum))
        error('Please fill with data only tables with association, no more else outside!')
    end

    Sheet_Info_Splits = mat2cell(Sheet_InfoClasses, diff(find([true; diff(~IndsBlankRowsTot); true]))); % Line suggested by ChatGPT that works, but check it better!

    InfoCont  = {'Sub soil', 'Top soil', 'Land use', 'Vegetation'};
    IndSplits = zeros(size(InfoCont));
    for i1 = 1:length(IndSplits)
        IndSplits(i1) = find(cellfun(@(x) any(strcmp(InfoCont{i1}, string([x(:,ColWithSubject)]))), Sheet_Info_Splits));
    end

    Sheet_Info_Div = cell2table(Sheet_Info_Splits(IndSplits)', 'VariableNames',InfoCont);
end

% Sub Soil
if any(contains([FeatsToUse{:}], ["sub", "allfeats"]))
    ProgressBar.Message = "Dataset: associating subsoil classes...";

    SubFeatName = 'SubSoilClass';

    GlbSubSlClss = string(Sheet_Info_Div.('Sub soil'){:}(2:end, ColWithTitles));
    if numel(unique(GlbSubSlClss)) ~= numel(GlbSubSlClss)
        error(['Sub Soil classes in Main sheet of association excel ' ...
               'must be unique! There are repetitions, check it!'])
    end

    if CategVars
        SubSoilStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    else
        SubSoilStudy = cellfun(@(x) zeros(size(x)),   xLongStudy, 'UniformOutput',false);
    end

    if exist([fold_var,sl,'LithoPolygonsStudyArea.mat'], 'file')
        load([fold_var,sl,'LithoPolygonsStudyArea.mat'], 'LithoAllUnique','LithoPolygonsStudyArea')
    
        [ColWithRawClasses, ColWithAss] = deal(false(1, size(Sheet_SubSoilClasses, 2)));
        for i1 = 1:length(ColWithRawClasses)
            ColWithRawClasses(i1) = any(cellfun(@(x) strcmp(string(x), 'Raw data name'), Sheet_SubSoilClasses(:,i1)));
            ColWithAss(i1)        = any(cellfun(@(x) strcmp(string(x), 'Ass. class'),    Sheet_SubSoilClasses(:,i1)));
        end
    
        [AssSubSoilClass, AssSubSoilNum, AssSubSoilDescr] = deal(cell(size(LithoAllUnique)));
        for i1 = 1:length(LithoAllUnique)
            RowToTakeLoc = strcmp(LithoAllUnique{i1}, string(Sheet_SubSoilClasses(:,ColWithRawClasses)));
            if not(any(RowToTakeLoc))
                warning(['Raw sub soil class "',LithoAllUnique{i1},'" will be skipped (no row found in excel)'])
                continue
            end
    
            NumOfSubSoilClass = Sheet_SubSoilClasses{RowToTakeLoc, ColWithAss};
            if isempty(NumOfSubSoilClass) || ismissing(NumOfSubSoilClass)
                warning(['Raw sub soil class "',LithoAllUnique{i1},'" will be skipped (no association)'])
                continue
            end
    
            RowToTakeGlb = find(NumOfSubSoilClass == [Sheet_Info_Div.('Sub soil'){:}{2:end,ColWithClassNum}])+1; % +1 because the first row is char and was excluded in finding equal number, but anyway must be considered in taking the correct row!
            if isempty(RowToTakeGlb)
                error(['Raw sub soil class "',LithoAllUnique{i1},'" has an associated number that is not present in main sheet! Check your excel.'])
            end
    
            AssSubSoilClass(i1) = Sheet_Info_Div.('Sub soil'){:}(RowToTakeGlb, ColWithTitles);
            AssSubSoilNum(i1)   = Sheet_Info_Div.('Sub soil'){:}(RowToTakeGlb, ColWithClassNum);
            AssSubSoilDescr(i1) = Sheet_Info_Div.('Sub soil'){:}(RowToTakeGlb, ColWithDescript);
        end
    
        IndNumPart = cellfun(@(x) isnumeric(x) && not(isempty(x)), AssSubSoilClass);
        AssSubSoilClass(IndNumPart) = cellfun(@(x) num2str(x), AssSubSoilClass(IndNumPart), 'UniformOutput',false); % To convert all numerical values to char

        IndStrPart = cellfun(@(x) ischar(x)||isstring(x), AssSubSoilClass);
    
        [AssSubSoilClassUnq, IndUniqueSubSoil] = unique(AssSubSoilClass(IndStrPart));
        if numel(AssSubSoilClassUnq) ~= numel(GlbSubSlClss)
            warning(['The associated classes of sub soil are less than the ' ...
                     'possible classes in the Main sheet of the association file.'])
        end
    
        AssSubSoilNumUnq = AssSubSoilNum(IndStrPart);
        AssSubSoilNumUnq = AssSubSoilNumUnq(IndUniqueSubSoil);

        AssSubSoilDescrUnq = AssSubSoilDescr(IndStrPart);
        AssSubSoilDescrUnq = AssSubSoilDescrUnq(IndUniqueSubSoil);
    
        SubSoilPolygons = repmat(polyshape, 1, length(AssSubSoilClassUnq));
        for i1 = 1:length(AssSubSoilClassUnq)
            ProgressBar.Message = ['Dataset: union of subsoil poly n. ',num2str(i1),' of ',num2str(length(AssSubSoilClassUnq))];
            IndToUnify = strcmp(AssSubSoilClassUnq{i1}, AssSubSoilClass);
            SubSoilPolygons(i1) = union(LithoPolygonsStudyArea(IndToUnify));
        end
    
        ProgressBar.Message = "Dataset: indexing of subsoil classes...";
        for i1 = 1:length(SubSoilPolygons)
            [pp1,ee1] = getnan2([SubSoilPolygons(i1).Vertices; nan, nan]);
            IndsInsideSubSoilPolygon = cellfun(@(x,y) inpoly([x,y],pp1,ee1), xLongStudy, yLatStudy, 'Uniform',false);
            for i2 = 1:size(xLongAll,2)
                if not(any(IndsInsideSubSoilPolygon{i2})); continue; end
                if CategVars
                    SubSoilStudy{i2}(IndsInsideSubSoilPolygon{i2}) = string(AssSubSoilClassUnq{i1});
                else
                    SubSoilStudy{i2}(IndsInsideSubSoilPolygon{i2}) = AssSubSoilNumUnq{i1};
                end
            end
        end
    
        ClassPolys(SubFeatName,{'Polys','ClassNames', ...
                                'ClassNum','ClassDescr'}) = {SubSoilPolygons', AssSubSoilClassUnq', ...
                                                             AssSubSoilNumUnq', AssSubSoilDescrUnq'};

    else
        warning(['You have selected Sub Soil as a feature but there is no file containing ' ...
                 'polygons. Zero values or empty string will be generated for this feature!' ...
                 'It is highly suggested to use this dataset only with pre-trained models.'])
    end

    Prmpt4Fts = [Prmpt4Fts, "Sub Soil Class [-]"];
    if CategVars
        DatasetFeaturesStudy.(SubFeatName) = categorical(cat(1,SubSoilStudy{:}), ...
                                                         unique(GlbSubSlClss), 'Ordinal',true); % unique is to order the classes!
        FeatsType = [FeatsType, "Categorical"];
        RngsToAdd = [nan, nan];
    else
        DatasetFeaturesStudy.(SubFeatName) = cat(1,SubSoilStudy{:});
        FeatsType = [FeatsType, "Numerical"];
        RngsToAdd = [0, max([Sheet_Info_Div.('Sub soil'){:}{2:end,ColWithClassNum}])];
    end

    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Top Soil
if any(contains([FeatsToUse{:}], ["top", "allfeats"]))
    ProgressBar.Message = "Dataset: associating topsoil classes...";

    TopFeatName = 'TopSoilClass';

    GlbTopSlClss = string(Sheet_Info_Div.('Top soil'){:}(2:end, ColWithTitles));
    if numel(unique(GlbTopSlClss)) ~= numel(GlbTopSlClss)
        error(['Top Soil classes in Main sheet of association excel ' ...
               'must be unique! There are repetitions, check it!'])
    end

    if CategVars
        TopSoilStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    else
        TopSoilStudy = cellfun(@(x) zeros(size(x)),   xLongStudy, 'UniformOutput',false);
    end

    if exist([fold_var,sl,'TopSoilPolygonsStudyArea.mat'], 'file')
        load([fold_var,sl,'TopSoilPolygonsStudyArea.mat'], 'TopSoilAllUnique','TopSoilPolygonsStudyArea')
    
        [ColWithRawClasses, ColWithAss] = deal(false(1, size(Sheet_TopSoilClasses, 2)));
        for i1 = 1:length(ColWithRawClasses)
            ColWithRawClasses(i1) = any(cellfun(@(x) strcmp(string(x), 'Raw data name'), Sheet_TopSoilClasses(:,i1)));
            ColWithAss(i1)        = any(cellfun(@(x) strcmp(string(x), 'Ass. class'),    Sheet_TopSoilClasses(:,i1)));
        end
    
        [AssTopSoilClass, AssTopSoilNum, AssTopSoilDescr] = deal(cell(size(TopSoilAllUnique)));
        for i1 = 1:length(TopSoilAllUnique)
            RowToTakeLoc = strcmp(TopSoilAllUnique{i1}, string(Sheet_TopSoilClasses(:,ColWithRawClasses)));
            if not(any(RowToTakeLoc))
                warning(['Raw top soil class "',TopSoilAllUnique{i1},'" will be skipped (no row found in excel)'])
                continue
            end

            NumOfTopSoilClass = Sheet_TopSoilClasses{RowToTakeLoc, ColWithAss};
            if isempty(NumOfTopSoilClass) || ismissing(NumOfTopSoilClass)
                warning(['Raw top soil class "',TopSoilAllUnique{i1},'" will be skipped (no association)'])
                continue
            end
    
            RowToTakeGlb = find(NumOfTopSoilClass == [Sheet_Info_Div.('Top soil'){:}{2:end,ColWithClassNum}])+1; % +1 because the first row is char and was excluded in finding equal number, but anyway must be considered in taking the correct row!
            if isempty(RowToTakeGlb)
                error(['Raw top soil class "',TopSoilAllUnique{i1},'" has an associated number that is not present in main sheet! Check your excel.'])
            end
    
            AssTopSoilClass(i1) = Sheet_Info_Div.('Top soil'){:}(RowToTakeGlb, ColWithTitles);
            AssTopSoilNum(i1)   = Sheet_Info_Div.('Top soil'){:}(RowToTakeGlb, ColWithClassNum);
            AssTopSoilDescr(i1) = Sheet_Info_Div.('Top soil'){:}(RowToTakeGlb, ColWithDescript);
        end
    
        IndNumPart = cellfun(@(x) isnumeric(x) && not(isempty(x)), AssTopSoilClass);
        AssTopSoilClass(IndNumPart) = cellfun(@(x) num2str(x), AssTopSoilClass(IndNumPart), 'UniformOutput',false); % To convert all numerical values to char

        IndStrPart = cellfun(@(x) ischar(x)||isstring(x), AssTopSoilClass);

        [AssTopSoilClassUnq, IndUniqueTopSoil] = unique(AssTopSoilClass(IndStrPart));
        if numel(AssTopSoilClassUnq) ~= numel(GlbTopSlClss)
            warning(['The associated classes of top soil are less than the ' ...
                     'possible classes in the Main sheet of the association file.'])
        end

        AssTopSoilNumUnq = AssTopSoilNum(IndStrPart);
        AssTopSoilNumUnq = AssTopSoilNumUnq(IndUniqueTopSoil);

        AssTopSoilDescrUnq = AssTopSoilDescr(IndStrPart);
        AssTopSoilDescrUnq = AssTopSoilDescrUnq(IndUniqueTopSoil);

        TopSoilPolygons = repmat(polyshape, 1, length(AssTopSoilClassUnq));
        for i1 = 1:length(AssTopSoilClassUnq)
            ProgressBar.Message = ['Dataset: union of topsoil poly n. ',num2str(i1),' of ',num2str(length(AssTopSoilClassUnq))];
            IndToUnify = strcmp(AssTopSoilClassUnq{i1}, AssTopSoilClass);
            TopSoilPolygons(i1) = union(TopSoilPolygonsStudyArea(IndToUnify));
        end
    
        ProgressBar.Message = "Dataset: indexing of topsoil classes...";
        for i1 = 1:length(TopSoilPolygons)
            [pp1,ee1] = getnan2([TopSoilPolygons(i1).Vertices; nan, nan]);
            IndexInsideTopSoilPolygon = cellfun(@(x,y) inpoly([x,y],pp1,ee1), xLongStudy, yLatStudy, 'Uniform',false);
            for i2 = 1:size(xLongAll,2)
                if not(any(IndexInsideTopSoilPolygon{i2})); continue; end
                if CategVars
                    TopSoilStudy{i2}(IndexInsideTopSoilPolygon{i2}) = string(AssTopSoilClassUnq{i1});
                else
                    TopSoilStudy{i2}(IndexInsideTopSoilPolygon{i2}) = AssTopSoilNumUnq{i1};
                end
            end
        end
    
        ClassPolys(TopFeatName,{'Polys','ClassNames', ...
                                'ClassNum','ClassDescr'}) = {TopSoilPolygons', AssTopSoilClassUnq', ...
                                                             AssTopSoilNumUnq', AssTopSoilDescrUnq'};

    else
        warning(['You have selected Top Soil as a feature but there is no file containing ' ...
                 'polygons. Zero values or empty string will be generated for this feature!' ...
                 'It is highly suggested to use this dataset only with pre-trained models.'])
    end

    Prmpt4Fts = [Prmpt4Fts, "Top Soil Class [-]"];
    if CategVars
        DatasetFeaturesStudy.(TopFeatName) = categorical(cat(1,TopSoilStudy{:}), ...
                                                         unique(GlbTopSlClss), 'Ordinal',true); % unique is to order the classes!
        FeatsType = [FeatsType, "Categorical"];
        RngsToAdd = [nan, nan];
    else
        DatasetFeaturesStudy.(TopFeatName) = cat(1,TopSoilStudy{:});
        FeatsType = [FeatsType, "Numerical"];
        RngsToAdd = [0, max([Sheet_Info_Div.('Top soil'){:}{2:end,ColWithClassNum}])];
    end

    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Land Use
if any(contains([FeatsToUse{:}], ["land", "allfeats"]))
    ProgressBar.Message = "Dataset: associating land use classes...";

    LndFeatName = 'LandUseClass';

    GlbLandUseClss = string(Sheet_Info_Div.('Land use'){:}(2:end, ColWithTitles));
    if numel(unique(GlbLandUseClss)) ~= numel(GlbLandUseClss)
        error(['Land Use classes in Main sheet of association excel ' ...
               'must be unique! There are repetitions, check it!'])
    end

    if CategVars
        LandUseStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    else
        LandUseStudy = cellfun(@(x) zeros(size(x)),   xLongStudy, 'UniformOutput',false);
    end

    if exist([fold_var,sl,'LandUsesVariables.mat'], 'file')
        load([fold_var,sl,'LandUsesVariables.mat'], 'AllLandUnique','LandUsePolygonsStudyArea')
    
        [ColWithRawClasses, ColWithAss] = deal(false(1, size(Sheet_LandUseClasses, 2)));
        for i1 = 1:length(ColWithRawClasses)
            ColWithRawClasses(i1) = any(cellfun(@(x) strcmp(string(x), 'Raw data name'), Sheet_LandUseClasses(:,i1)));
            ColWithAss(i1)        = any(cellfun(@(x) strcmp(string(x), 'Ass. class'),    Sheet_LandUseClasses(:,i1)));
        end
    
        [AssLandUseClass, AssLandUseNum, AssLandUseDescr] = deal(cell(size(AllLandUnique)));
        for i1 = 1:length(AllLandUnique)
            RowToTakeLoc = strcmp(AllLandUnique{i1}, string(Sheet_LandUseClasses(:,ColWithRawClasses)));
            if not(any(RowToTakeLoc))
                warning(['Raw land use class "',AllLandUnique{i1},'" will be skipped (no row found in excel)'])
                continue
            end
    
            NumOfLandUseClass = Sheet_LandUseClasses{RowToTakeLoc, ColWithAss};
            if isempty(NumOfLandUseClass) || ismissing(NumOfLandUseClass)
                warning(['Raw land use class "',AllLandUnique{i1},'" will be skipped (no association)'])
                continue
            end
    
            RowToTakeGlb = find(NumOfLandUseClass == [Sheet_Info_Div.('Land use'){:}{2:end,ColWithClassNum}])+1; % +1 because the first row is char and was excluded in finding equal number, but anyway must be considered in taking the correct row!
            if isempty(RowToTakeGlb)
                error(['Raw class "',AllLandUnique{i1},'" has an associated number that is not present in main sheet! Check your excel.'])
            end
    
            AssLandUseClass(i1) = Sheet_Info_Div.('Land use'){:}(RowToTakeGlb, ColWithTitles);
            AssLandUseNum(i1)   = Sheet_Info_Div.('Land use'){:}(RowToTakeGlb, ColWithClassNum);
            AssLandUseDescr(i1) = Sheet_Info_Div.('Land use'){:}(RowToTakeGlb, ColWithDescript);
        end
    
        IndNumPart = cellfun(@(x) isnumeric(x) && not(isempty(x)), AssLandUseClass);
        AssLandUseClass(IndNumPart) = cellfun(@(x) num2str(x), AssLandUseClass(IndNumPart), 'UniformOutput',false); % To convert all numerical values to char

        IndStrPart = cellfun(@(x) ischar(x)||isstring(x), AssLandUseClass);
    
        [AssLandUseClassUnq, IndUniqueLandUse] = unique(AssLandUseClass(IndStrPart));
        if numel(AssLandUseClassUnq) ~= numel(GlbLandUseClss)
            warning(['The associated classes of land use are less than the ' ...
                     'possible classes in the Main sheet of the association file.'])
        end
    
        AssLandUseNumUnq = AssLandUseNum(IndStrPart);
        AssLandUseNumUnq = AssLandUseNumUnq(IndUniqueLandUse);

        AssLandUseDescrUnq = AssLandUseDescr(IndStrPart);
        AssLandUseDescrUnq = AssLandUseDescrUnq(IndUniqueLandUse);
    
        LandUsePolygons = repmat(polyshape, 1, length(AssLandUseClassUnq));
        for i1 = 1:length(AssLandUseClassUnq)
            ProgressBar.Message = ['Dataset: union of land use poly n. ',num2str(i1),' of ',num2str(length(AssLandUseClassUnq))];
            IndToUnify = strcmp(AssLandUseClassUnq{i1}, AssLandUseClass);
            LandUsePolygons(i1) = union(LandUsePolygonsStudyArea(IndToUnify));
        end
    
        ProgressBar.Message = "Dataset: indexing of land use classes...";
        for i1 = 1:length(LandUsePolygons)
            [pp1,ee1] = getnan2([LandUsePolygons(i1).Vertices; nan, nan]);
            IndexInsideLandUsePolygon = cellfun(@(x,y) inpoly([x,y],pp1,ee1), xLongStudy, yLatStudy, 'Uniform',false);
            for i2 = 1:size(xLongAll,2)
                if CategVars
                    LandUseStudy{i2}(IndexInsideLandUsePolygon{i2}) = string(AssLandUseClassUnq{i1});
                else
                    LandUseStudy{i2}(IndexInsideLandUsePolygon{i2}) = AssLandUseNumUnq{i1};
                end
            end
        end
    
        ClassPolys(LndFeatName,{'Polys','ClassNames', ...
                                'ClassNum','ClassDescr'}) = {LandUsePolygons', AssLandUseClassUnq', ...
                                                             AssLandUseNumUnq', AssLandUseDescrUnq'};

    else
        warning(['You have selected Land Use as a feature but there is no file containing ' ...
                 'polygons. Zero values or empty string will be generated for this feature!' ...
                 'It is highly suggested to use this dataset only with pre-trained models.'])
    end

    Prmpt4Fts = [Prmpt4Fts, "Land Use Class [-]"];
    if CategVars
        DatasetFeaturesStudy.(LndFeatName) = categorical(cat(1,LandUseStudy{:}), ...
                                                         unique(GlbLandUseClss), 'Ordinal',true); % unique is to order the classes!
        FeatsType = [FeatsType, "Categorical"];
        RngsToAdd = [nan, nan];
    else
        DatasetFeaturesStudy.(LndFeatName) = cat(1,LandUseStudy{:});
        FeatsType = [FeatsType, "Numerical"];
        RngsToAdd = [0, max([Sheet_Info_Div.('Land use'){:}{2:end,ColWithClassNum}])];
    end

    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Vegetation
if any(contains([FeatsToUse{:}], ["vegetation", "allfeats"]))
    ProgressBar.Message = "Dataset: associating vegetation classes...";

    VgtFeatName = 'VegetationClass';

    GlbVegetClss = string(Sheet_Info_Div.('Vegetation'){:}(2:end, ColWithTitles));
    if numel(unique(GlbVegetClss)) ~= numel(GlbVegetClss)
        error(['Vegetation classes in Main sheet of association excel ' ...
               'must be unique! There are repetitions, check it!'])
    end

    if CategVars
        VegetStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    else
        VegetStudy = cellfun(@(x) zeros(size(x)),   xLongStudy, 'UniformOutput',false);
    end

    if exist([fold_var,sl,'VegPolygonsStudyArea.mat'], 'file')
        load([fold_var,sl,'VegPolygonsStudyArea.mat'], 'VegetationAllUnique','VegPolygonsStudyArea')
    
        [ColWithRawClasses, ColWithAss] = deal(false(1, size(Sheet_VegetClasses, 2))); % RIPRENDI QUA
        for i1 = 1:length(ColWithRawClasses)
            ColWithRawClasses(i1) = any(cellfun(@(x) strcmp(string(x), 'Raw data name'), Sheet_VegetClasses(:,i1)));
            ColWithAss(i1)        = any(cellfun(@(x) strcmp(string(x), 'Ass. class'),    Sheet_VegetClasses(:,i1)));
        end
    
        [AssVegetClass, AssVegetNum, AssVegetDescr] = deal(cell(size(VegetationAllUnique)));
        for i1 = 1:length(VegetationAllUnique)
            RowToTakeLoc = strcmp(VegetationAllUnique{i1}, string(Sheet_VegetClasses(:,ColWithRawClasses)));
            if not(any(RowToTakeLoc))
                warning(['Raw vegetation class "',VegetationAllUnique{i1},'" will be skipped (no row found in excel)'])
                continue
            end
    
            NumOfVegetClass = Sheet_VegetClasses{RowToTakeLoc, ColWithAss};
            if isempty(NumOfVegetClass) || ismissing(NumOfVegetClass)
                warning(['Raw vegetation class "',VegetationAllUnique{i1},'" will be skipped (no association)'])
                continue
            end
    
            RowToTakeGlb = find(NumOfVegetClass == [Sheet_Info_Div.('Vegetation'){:}{2:end,ColWithClassNum}])+1; % +1 because the first row is char and was excluded in finding equal number, but anyway must be considered in taking the correct row!
            if isempty(RowToTakeGlb)
                error(['Raw class "',VegetationAllUnique{i1},'" has an associated number that is not present in main sheet! Check your excel.'])
            end
    
            AssVegetClass(i1) = Sheet_Info_Div.('Vegetation'){:}(RowToTakeGlb, ColWithTitles);
            AssVegetNum(i1)   = Sheet_Info_Div.('Vegetation'){:}(RowToTakeGlb, ColWithClassNum);
            AssVegetDescr(i1) = Sheet_Info_Div.('Vegetation'){:}(RowToTakeGlb, ColWithDescript);
        end
    
        IndNumPart = cellfun(@(x) isnumeric(x) && not(isempty(x)), AssVegetClass);
        AssVegetClass(IndNumPart) = cellfun(@(x) num2str(x), AssVegetClass(IndNumPart), 'UniformOutput',false); % To convert all numerical values to char

        IndStrPart = cellfun(@(x) ischar(x)||isstring(x), AssVegetClass);
    
        [AssVegetClassUnq, IndUniqueVeget] = unique(AssVegetClass(IndStrPart));
        if numel(AssVegetClassUnq) ~= numel(GlbVegetClss)
            warning(['The associated classes of vegetation are less than the ' ...
                     'possible classes in the Main sheet of the association file.'])
        end
    
        AssVegetNumUnq = AssVegetNum(IndStrPart);
        AssVegetNumUnq = AssVegetNumUnq(IndUniqueVeget);

        AssVegetDescrUnq = AssVegetDescr(IndStrPart);
        AssVegetDescrUnq = AssVegetDescrUnq(IndUniqueVeget);
    
        VegetPolygons = repmat(polyshape, 1, length(AssVegetClassUnq));
        for i1 = 1:length(AssVegetClassUnq)
            ProgressBar.Message = ['Dataset: union of vegetation poly n. ',num2str(i1),' of ',num2str(length(AssVegetClassUnq))];
            IndToUnify = strcmp(AssVegetClassUnq{i1}, AssVegetClass);
            VegetPolygons(i1) = union(VegPolygonsStudyArea(IndToUnify));
        end
    
        ProgressBar.Message = "Dataset: indexing of vegetation classes...";
        for i1 = 1:length(VegetPolygons)
            [pp1,ee1] = getnan2([VegetPolygons(i1).Vertices; nan, nan]);
            IndexInsideVegetPolygon = cellfun(@(x,y) inpoly([x,y],pp1,ee1), xLongStudy, yLatStudy, 'Uniform',false);
            for i2 = 1:size(xLongAll,2)
                if CategVars
                    VegetStudy{i2}(IndexInsideVegetPolygon{i2}) = string(AssVegetClassUnq{i1});
                else
                    VegetStudy{i2}(IndexInsideVegetPolygon{i2}) = AssVegetNumUnq{i1};
                end
            end
        end
    
        ClassPolys(VgtFeatName,{'Polys','ClassNames', ...
                                'ClassNum','ClassDescr'}) = {VegetPolygons', AssVegetClassUnq', ...
                                                             AssVegetNumUnq', AssVegetDescrUnq'};

    else
        warning(['You have selected Vegetation as a feature but there is no file containing ' ...
                 'polygons. Zero values or empty string will be generated for this feature!' ...
                 'It is highly suggested to use this dataset only with pre-trained models.'])
    end

    Prmpt4Fts = [Prmpt4Fts, "Vegetation Class [-]"];
    if CategVars
        DatasetFeaturesStudy.(VgtFeatName) = categorical(cat(1,VegetStudy{:}), ...
                                                         unique(GlbVegetClss), 'Ordinal',true); % unique is to order the classes!
        FeatsType = [FeatsType, "Categorical"];
        RngsToAdd = [nan, nan];
    else
        DatasetFeaturesStudy.(VgtFeatName) = cat(1,VegetStudy{:});
        FeatsType = [FeatsType, "Numerical"];
        RngsToAdd = [0, max([Sheet_Info_Div.('Vegetation'){:}{2:end,ColWithClassNum}])];
    end

    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

%% Loading of features (time sensitive part)
ProgressBar.Message = 'Dataset: reading time sensitive part...';

[TimeSensitiveParam, TimeSensitiveData, TimeSensitiveDate, ...
    TimeSensitiveTrigg, TimeSensitivePeaks, TimeSensEventDates] = deal({});
CumulableParam = [];

% Rainfall
if any(contains([FeatsToUse{:}], ["rain", "allfeats"]))
    load([fold_var,sl,'RainInterpolated.mat'], 'RainInterpolated','RainDateInterpolationStarts')

    TimeSensitiveParam = [TimeSensitiveParam, {'Rainfall'}];
    CumulableParam     = [CumulableParam, 1];
    TimeSensitiveData  = [TimeSensitiveData, {RainInterpolated}];
    TimeSensitiveDate  = [TimeSensitiveDate, {RainDateInterpolationStarts}];
    clear('RainInterpolated')

    if strcmp(ModeForTS, "triggercausepeak")
        load([fold_var,sl,'RainEvents.mat'], 'RainAmountPerEventInterp','RainMaxPeakPerEventInterp','RainRecDatesPerEvent')

        TimeSensitiveTrigg = [TimeSensitiveTrigg, {RainAmountPerEventInterp} ];
        TimeSensitivePeaks = [TimeSensitivePeaks, {RainMaxPeakPerEventInterp}];
        TimeSensEventDates = [TimeSensEventDates, {RainRecDatesPerEvent}     ];
        clear('RainAmountPerEventInterp', 'RainMaxPeakPerEventInterp', 'RainRecDatesPerEvent')
    end

    if strcmp(ModeForTS, "condenseddays")
        Prmpt4Fts  = [Prmpt4Fts, strcat("Rainfall Cumulate ",num2str(DaysForTS), "d [mm]")];
        FeatsType  = [FeatsType, "TimeSensitive"];
        MaxDayRain = 30; % To discuss this value (max in Emilia was 134 mm in a day)
        RngsToAdd  = [0, MaxDayRain*DaysForTS];
    elseif strcmp(ModeForTS, "separatedays")
        Prmpt4Fts = [Prmpt4Fts, "Rainfall Daily [mm]"];
        FeatsType = [FeatsType, repmat("TimeSensitive",1,DaysForTS)];
        RngsToAdd = [0, 120];
    elseif strcmp(ModeForTS, "triggercausepeak")
        Prmpt4Fts  = [Prmpt4Fts, "Rainfall Triggering [mm]", "Rainfall Cause [mm]", "Rainfall Trigg Peak [mm/h]"];
        FeatsType  = [FeatsType, repmat("TimeSensitive",1,3)];
        MaxDayRain = 30; % To discuss this value (max in Emilia was 134 mm in a day)
        RngsToAdd  = [0, 200; 0, MaxDayRain*DaysForTS; 0, 40];
    end
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Temperature
if any(contains([FeatsToUse{:}], ["temp", "allfeats"]))
    load([fold_var,sl,'TempInterpolated.mat'], 'TempInterpolated','TempDateInterpolationStarts')

    TimeSensitiveParam = [TimeSensitiveParam, {'Temperature'}];
    CumulableParam     = [CumulableParam, 0];
    TimeSensitiveData  = [TimeSensitiveData, {TempInterpolated}];
    TimeSensitiveDate  = [TimeSensitiveDate, {TempDateInterpolationStarts}];
    clear('TempInterpolated')

    if strcmp(ModeForTS, "triggercausepeak")
        load([fold_var,sl,'TempEvents.mat'], 'TempAmountPerEventInterp','TempMaxPeakPerEventInterp','TempRecDatesPerEvent')

        TimeSensitiveTrigg = [TimeSensitiveTrigg, {TempAmountPerEventInterp} ];
        TimeSensitivePeaks = [TimeSensitivePeaks, {TempMaxPeakPerEventInterp}];
        TimeSensEventDates = [TimeSensEventDates, {TempRecDatesPerEvent}     ];
        clear('TempAmountPerEventInterp', 'TempMaxPeakPerEventInterp', 'TempRecDatesPerEvent')
    end

    if strcmp(ModeForTS, "condenseddays")
        Prmpt4Fts = [Prmpt4Fts, strcat("Temperature Average ",num2str(DaysForTS), "d [°]")];
        FeatsType = [FeatsType, "TimeSensitive"];
    elseif strcmp(ModeForTS, "separatedays")
        Prmpt4Fts = [Prmpt4Fts, "Temperature Daily [°]"];
        FeatsType = [FeatsType, repmat("TimeSensitive",1,DaysForTS)];
    elseif strcmp(ModeForTS, "triggercausepeak")
        Prmpt4Fts = [Prmpt4Fts, "Temperature [mm]"];
        FeatsType = [FeatsType, repmat("TimeSensitive",1,3)];
    end
    RngsToAdd = [-10, 35]; % In Celsius
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Uniformization of Time Sensitive
TimeSensExist = false;
if any(contains([FeatsToUse{:}], ["rain", "temp", "allfeats"]))
    TimeSensExist   = true;
    CumulableParam  = logical(CumulableParam);
    StartDateCommon = max(cellfun(@min, TimeSensitiveDate)); % Start in end dates
    EndDateCommon   = min(cellfun(@max, TimeSensitiveDate)); % End in end dates

    if EndDateCommon < StartDateCommon
        error('Time sensitive part has no datetime in common! Please re-interpolate time sensitive part.')
    end

    if length(TimeSensitiveParam) > 1
        for i1 = 1 : length(TimeSensitiveParam)
            IndStartCommon = find(StartDateCommon == TimeSensitiveDate{i1}); % You should put an equal related to days and not exact timing
            IndEventCommon = find(EndDateCommon   == TimeSensitiveDate{i1}); % You should put an equal related to days and not exact timing
            TimeSensitiveData{i1} = TimeSensitiveData{i1}(IndStartCommon:IndEventCommon,:);
            TimeSensitiveDate{i1} = TimeSensitiveDate{i1}(IndStartCommon:IndEventCommon);
        end
        if length(TimeSensitiveDate)>1 && ~isequal(TimeSensitiveDate{:})
            error('After uniformization of dates in time sensitive part, number of elements is not consistent! Please check it in the script.')
        end
    end

    TimeSensitiveDate = TimeSensitiveDate{1}; % Taking only the first one since they are identical!

    if exist('EventDay', 'var')
        RowToTake = find( abs(TimeSensitiveDate - EventDay) < minutes(1) );
        if isempty(RowToTake); error('The date you chosed as input does not exist in your merged data!'); end
    else
        RowToTake = listdlg2('Start time of 24 h:', TimeSensitiveDate, 'OutType','NumInd');
        figure(Fig)
        drawnow
    end

    TimeSensitiveDatetimeChosed = TimeSensitiveDate(RowToTake);

    if TimeSensitiveDate(RowToTake) < TimeSensitiveDate(DaysForTS)
        error(['You have selected a date that not allow to consider ',num2str(DaysForTS),' days before your choice! Please retry.'])
    end

    TimeSensitiveDataStudy = cell(1, length(TimeSensitiveParam));
    for i1 = 1:length(TimeSensitiveParam)
        TimeSensitiveDataStudy{i1} = cellfun(@full, TimeSensitiveData{i1}, 'UniformOutput',false);
    end
    clear('TimeSensitiveData')

    if strcmp(ModeForTS, "condenseddays")
        ColumnsToAdd = cell(1, length(TimeSensitiveParam));
        for i1 = 1:length(TimeSensitiveParam)
            ColumnToAddTemp = cell(1, size(TimeSensitiveDataStudy{i1}, 2));
            for i2 = 1:size(TimeSensitiveDataStudy{i1}, 2)
                if CumulableParam(i1)
                    ColumnToAddTemp{i2} = sum([TimeSensitiveDataStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                else
                    ColumnToAddTemp{i2} = mean([TimeSensitiveDataStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                end
            end
            ColumnsToAdd{i1} = cat(1,ColumnToAddTemp{:});
        end
    
        TimeSensitiveOper = repmat({'Averaged'}, 1, length(TimeSensitiveParam));
        TimeSensitiveOper(CumulableParam) = {'Cumulated'};
    
        FeaturesNamesToAdd  = cellfun(@(x, y) [x,y,num2str(DaysForTS),'d'], TimeSensitiveParam, TimeSensitiveOper, 'UniformOutput',false);
        
        for i1 = 1:length(TimeSensitiveParam)
            DatasetFeaturesStudy.(FeaturesNamesToAdd{i1}) = ColumnsToAdd{i1};
        end

    elseif strcmp(ModeForTS, "separatedays")
        ColumnsToAdd = cell(DaysForTS, length(TimeSensitiveParam));
        RowsToTake   = RowToTake : -1 : (RowToTake-DaysForTS+1);
        for i1 = 1:DaysForTS
            ColumnsToAdd(i1,:) = cellfun(@(x) cat(1,x{RowsToTake(i1),:}), TimeSensitiveDataStudy, 'UniformOutput',false);
        end

        FeaturesNamesToAdd = cellfun(@(x) strcat(x,'-',string(1:DaysForTS)','daysBefore'), TimeSensitiveParam, 'UniformOutput',false);

        for i1 = 1:length(TimeSensitiveParam) % It is important to follow this order (TimeSensitiveParam) for normalization!
            for i2 = 1:DaysForTS
                DatasetFeaturesStudy.(FeaturesNamesToAdd{i1}(i2)) = ColumnsToAdd{i2,i1};
            end
        end

    elseif strcmp(ModeForTS, "triggercausepeak")
        ColumnsToAdd = cell(3, length(TimeSensitiveParam)); % 3 because you will have Trigger, cause, and peak
        for i1 = 1:length(TimeSensitiveParam)
            if not(exist('StartDateTrigg', 'var'))
                IndsPossEvents = find(cellfun(@(x) min(abs(TimeSensitiveDatetimeChosed-x)) < days(2), TimeSensEventDates{i1}));
                if isempty(IndsPossEvents)
                    error('You have no events in a time window of 2 days around your datetime. Choose another datetime!')
                elseif IndsPossEvents > 1
                    PossEventNames = strcat("Event of ", char(cellfun(@(x) min(x), TimeSensEventDates{i1}(IndsPossEvents))), ' (+', ...
                                            num2str(cellfun(@(x) length(x), TimeSensEventDates{i1}(IndsPossEvents))'), ' h)');
                    RelIndEvent    = listdlg2('Rain event to consider :', PossEventNames, 'OutType','NumInd');
                    figure(Fig)
                    drawnow
                elseif IndsPossEvents == 1
                    RelIndEvent    = 1;
                end
                IndEventToTake = IndsPossEvents(RelIndEvent);
            else
                IndEventToTake = find(cellfun(@(x) min(abs(StartDateTrigg-x)) < minutes(1), TimeSensEventDates{i1}));
                if isempty(IndEventToTake) || (numel(IndEventToTake) > 1)
                    error(['Triggering event is not present in ',TimeSensitiveParam{i1},' or there are multiple possibilities. Please check it!'])
                end
            end
            StartDateTrigg = min(TimeSensEventDates{i1}{IndEventToTake});

            ColumnsToAdd{1, i1} = full(cat(1, TimeSensitiveTrigg{i1}{IndEventToTake,:})); % Pay attention to order! 1st row is Trigger

            switch CauseMode
                case "dailycumulate"
                    RowToTake = find( abs(TimeSensitiveDate - StartDateTrigg) < days(1), 1 ) - 1; % Overwriting of RowToTake with the first date before your event! I want only the first one. -1 to take the day before the start of the event!
                    ColumnToAddTemp = cell(1, size(TimeSensitiveDataStudy{i1}, 2));
                    for i2 = 1:size(TimeSensitiveDataStudy{i1}, 2)
                        if CumulableParam(i1)
                            ColumnToAddTemp{i2} = sum([TimeSensitiveDataStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                        else
                            ColumnToAddTemp{i2} = mean([TimeSensitiveDataStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                        end
                    end
                    ColumnsToAdd{2, i1} = cat(1,ColumnToAddTemp{:}); % Pay attention to order! 2nd row is Cause

                case "eventscumulate"
                    StartDateCause  = StartDateTrigg - days(DaysForTS);
                    IndsCauseEvents = find(cellfun(@(x) any(StartDateCause < x) && all(StartDateTrigg > x), TimeSensEventDates{i1})); % With any(StartDateCause < x) you could go before StartDateCause. change with all if you don't want (that event will be excluded)
                    ColumnToAddTemp = zeros(size(ColumnsToAdd{1, i1}, 1), length(IndsCauseEvents));
                    for i2 = 1:length(IndsCauseEvents)
                        ColumnToAddTemp(:,i2) = full(cat(1, TimeSensitiveTrigg{i1}{IndsCauseEvents(i2),:}));
                    end
                    if CumulableParam(i1)
                        ColumnsToAdd{2, i1} = sum(ColumnToAddTemp, 2); % Pay attention to order! 2nd row is Cause
                    else
                        ColumnsToAdd{2, i1} = mean(ColumnToAddTemp, 2); % Pay attention to order! 2nd row is Cause
                    end
            end

            ColumnsToAdd{3, i1} = full(cat(1, TimeSensitivePeaks{i1}{IndEventToTake,:})); % Pay attention to order! 3rd row is Peak
        end

        TimeSensType = ["Trigger"; strcat("Cause",num2str(DaysForTS),"d"); "TriggPeak"];
        FeaturesNamesToAdd = cellfun(@(x) strcat(x,TimeSensType), TimeSensitiveParam, 'UniformOutput',false);

        for i1 = 1:length(TimeSensitiveParam) % It is important to follow this order (TimeSensitiveParam) for normalization!
            for i2 = 1:length(TimeSensType)
                DatasetFeaturesStudy.(FeaturesNamesToAdd{i1}(i2)) = ColumnsToAdd{i2,i1};
            end
        end

    else

        error('Something went wrong in selecting the mode for time sensitive, please check "datasetstudy_creation"')
    end
end

%% Normalization
ProgressBar.Message = 'Dataset: normalization of data...';

FeatsDataset = DatasetFeaturesStudy.Properties.VariableNames;
if NormData
    if CreateRngs
        PromptForRanges = strcat("Ranges for ", Prmpt4Fts');
        RangesInputs = inputdlg2( PromptForRanges, 'DefInp',strcat("[",num2str(round(SuggRanges(:,1),3,'significant'), '%.2e'),", ", ...
                                                            num2str(round(SuggRanges(:,2),3,'significant'), '%.2e'),"]"));

        TSCount = 1;
        CurrRow = 1;
        Ranges  = zeros(length(FeatsDataset), 2);
        for i1 = 1:length(FeatsDataset)
            Ranges(i1,:) = str2num(RangesInputs{CurrRow}); % Pay attention to order!
            if not(strcmp(FeatsType(i1), "TimeSensitive"))
                CurrRow = CurrRow + 1;
            else
                switch ModeForTS
                    case "separatedays"
                        TSCount = TSCount + 1;
                        if TSCount > DaysForTS
                            TSCount = 1;
                            CurrRow = CurrRow + 1;
                        end

                    case "condenseddays"
                        CurrRow = CurrRow + 1;

                    case "triggercausepeak"
                        if contains(FeatsDataset(i1),'Temperature') && (TSCount < 3) % 3 because you have only Trigger, Cause, and Peak
                            TSCount = TSCount + 1;
                            continue
                        else
                            CurrRow = CurrRow + 1;
                        end

                    otherwise
                        error('Time Sensitive approach not recognized in creating ranges. Please check Normalization part!')
                end
            end
        end
        Ranges = array2table(Ranges, 'RowNames',FeatsDataset, 'VariableNames',["Min value", "Max value"]);
    end

    DatasetFeaturesStudyNorm = table();
    for i1 = 1:size(DatasetFeaturesStudy,2)
        if not(strcmp(FeatsType(i1), "Categorical"))
            DatasetFeaturesStudyNorm.(FeatsDataset{i1}) = rescale(DatasetFeaturesStudy.(FeatsDataset{i1}), ...
                                                                           'InputMin',Ranges{FeatsDataset{i1}, 1}, ...
                                                                           'InputMax',Ranges{FeatsDataset{i1}, 2});
        elseif strcmp(FeatsType(i1), "Categorical")
            DatasetFeaturesStudyNorm.(FeatsDataset{i1}) = DatasetFeaturesStudy.(FeatsDataset{i1});
        end
    end
else
    Ranges = array2table(nan(size(DatasetFeaturesStudy,2), 2), 'RowNames',FeatsDataset, ...
                                                               'VariableNames',["Min value", "Max value"]);
end

%% Output creation
ProgressBar.Message = 'Dataset: Outputs...';

if NormData
    varargout{1} = DatasetFeaturesStudyNorm;
    varargout{5} = DatasetFeaturesStudy;
else
    varargout{1} = DatasetFeaturesStudy;
    varargout{5} = DatasetFeaturesStudy;
end

varargout{2} = DatasetCoordinatesStudy;
varargout{3} = Ranges;

if TimeSensExist
    if strcmp(ModeForTS, "triggercausepeak")
        varargout{4} = table(TimeSensitiveParam, TimeSensitiveDatetimeChosed, TimeSensitiveDate, ...
                             TimeSensitiveDataStudy, CumulableParam, TimeSensitiveTrigg, TimeSensitivePeaks, ...
                             TimeSensEventDates, StartDateTrigg, 'VariableNames',{'ParamNames', 'EventTime', ...
                                                                                  'Datetimes', 'Data', ...
                                                                                  'Cumulable', 'TriggAmountPerEvent' ...
                                                                                  'PeaksPerEvent', 'DatesPerEvent', ...
                                                                                  'StartDateTriggering'});
    else
        varargout{4} = table(TimeSensitiveParam, TimeSensitiveDatetimeChosed, TimeSensitiveDate, ...
                             TimeSensitiveDataStudy, CumulableParam, 'VariableNames',{'ParamNames', 'EventTime', 'Datetimes', 'Data', 'Cumulable'});
    end
else
    varargout{4} = table("No Time Sensitive data selected as input!", 'VariableNames',{'EventTime'});
end

varargout{6} = FeatsType;
varargout{7} = ClassPolys;

end