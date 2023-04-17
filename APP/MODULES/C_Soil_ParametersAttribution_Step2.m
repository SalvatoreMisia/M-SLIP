% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Attribution of soil parameters', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Loading of variables previously created
cd(fold_var)
load('GridCoordinates.mat');
load('SoilParameters.mat');
load('LithoPolygonsStudyArea.mat');
load('UserA_Answers.mat','SpecificWindow')

%% Excel reading and coefficient matrix writing
ProgressBar.Message = 'Reading excel...';

cd(fold_user)
Sheet_DSCPar = readcell(FileName_LithoAssociation, 'Sheet','DSCParameters');
Sheet_Ass = readcell(FileName_LithoAssociation, 'Sheet','Association');

LU2DSC = Sheet_Ass(2:size(Sheet_Ass,1),2);
SelectedSoil = find(cellfun(@ismissing,LU2DSC)==0);

LUAbbr = string(Sheet_Ass(SelectedSoil+1,3)); % Plus 1 because of headers

if isempty(SelectedSoil); error('L 1'); end

Options = {'Yes', 'No, yet assigned in excel'};
ChoiceLU = uiconfirm(Fig, 'Would you like to choose LU color?', ...
                          'Window type', 'Options',Options);
ChoiceDSC = uiconfirm(Fig, 'Would you like to choose DSC color?', ...
                           'Window type', 'Options',Options);

if string(ChoiceLU) == string(Options{2})

    try
        LUColors = cell2mat(cellfun(@(x) sscanf(x,'%d',[1 3]), ...
                                Sheet_Ass(SelectedSoil+1,4), 'UniformOutput',false));
    catch me
        getReport(me)
        uialert(Fig, ['An error occurred reading colors (see MATLAB command), ' ...
                      'LU Colors will be randomly generated...'], ...
                      'LU Color Error')
        LUColors = uint8(rand(size(SelectedSoil,1),3).*255);
    end

elseif string(ChoiceLU) == string(Options{1})

    for i1 = 1:size(SelectedSoil,1)
        LUColors(i1,:) = uisetcolor(strcat("Chose a color for ",LUAbbr(i1))).*255;
    end

end

if string(ChoiceDSC) == string(Options{2})

    try
        DSCColors = cell2mat(cellfun(@(x) sscanf(x,'%d',[1 3]), ...
                 Sheet_DSCPar(2:size(Sheet_DSCPar,1),7), 'UniformOutput',false));
    catch me
        getReport(me)
        uialert(Fig, ['An error occurred reading colors (see MATLAB command), ' ...
                      'DSC Colors will be randomly generated...'], ...
                      'DSC Color Error')
        DSCColors = uint8(rand(size(Sheet_DSCPar,1)-1, 3).*255);
    end

elseif string(ChoiceDSC) == string(Options{1})

    for i1 = 1:(size(Sheet_DSCPar,1)-1)
        DSCColors(i1,:) = uisetcolor(strcat("Chose a color for LU ",num2str(i1))).*255;
    end

end

% Correspondence LU->DSC
LithoAcronyms = LUAbbr(:,1);
DSC = LU2DSC(SelectedSoil,1);

% Soil parameter for the single-point assignment procedure
DSC_c = cat(1,Sheet_DSCPar{2:size(Sheet_DSCPar,1),2});
DSC_phi = cat(1,Sheet_DSCPar{2:size(Sheet_DSCPar,1),3});
DSC_kt = cat(1,Sheet_DSCPar{2:size(Sheet_DSCPar,1),4});
DSC_A = cat(1,Sheet_DSCPar{2:size(Sheet_DSCPar,1),5});
DSC_n = cat(1,Sheet_DSCPar{2:size(Sheet_DSCPar,1),6});

% Lithology not associated
SelectedLUByUserPolygons = LithoPolygonsStudyArea(SelectedSoil);

%% InPolygon Procedure
tic
ProgressBar.Indeterminate = 'off';
for i1 = 1:size(SelectedLUByUserPolygons,2)
    ProgressBar.Message = strcat("Attributing parameters of LU n. ",num2str(i1)," of ", num2str(size(SelectedLUByUserPolygons,2)));
    ProgressBar.Value = i1/size(SelectedLUByUserPolygons,2);

    LUPolygon = SelectedLUByUserPolygons(i1);
    [pp,ee] = getnan2([LUPolygon.Vertices; nan, nan]);
    for i2 = 1:size(xLongAll,2)  
        IndexInsideLithoPolygon = find(inpoly([xLongAll{i2}(IndexDTMPointsInsideStudyArea{i2}),...
                    yLatAll{i2}(IndexDTMPointsInsideStudyArea{i2})],pp,ee)==1);

        CohesionAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexInsideLithoPolygon)) = ...
                                            DSC_c(LU2DSC{SelectedSoil(i1),1});

        PhiAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexInsideLithoPolygon)) = ...
                                            DSC_phi(LU2DSC{SelectedSoil(i1),1});

        KtAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexInsideLithoPolygon)) = ...
                                            DSC_kt(LU2DSC{SelectedSoil(i1),1});

        AAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexInsideLithoPolygon)) = ...
                                            DSC_A(LU2DSC{SelectedSoil(i1),1});

        nAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexInsideLithoPolygon)) = ...
                                            DSC_n(LU2DSC{SelectedSoil(i1),1});
    end
    disp(strcat('Finished LU',num2str(i1),'of ',num2str(size(SelectedSoil,1))))
end
toc

LU_DSC = {LithoAcronyms DSC};
LU_DSCPlotColor = {LUColors DSCColors};
DSCParameters = {DSC_n DSC_phi DSC_c DSC_A DSC_kt};

% Creating variables to save at the end
VariablesLUPar = {'LU_DSCPlotColor','LUAbbr','DSCParameters','SelectedSoil','LU2DSC'};
VariablesSoilPar = {'CohesionAll','PhiAll','KtAll','AAll','nAll'};

ProgressBar.Indeterminate = 'on';
ProgressBar.Message = 'Finising...';

%% Saving...
cd(fold_var)
save('LUDSCMapParameters.mat', VariablesLUPar{:})
save('SoilParameters.mat', VariablesSoilPar{:})
if TopSoil % TO CONTINUE!!
    TSUAbbr = LUAbbr;
end
cd(fold0)

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version