if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

rng(10) % For reproducibility of the model

%% Data import and initialization
sl = filesep;
load([fold_var,sl,'DatasetMLA.mat'], 'DatasetInfo')

OutMode = DatasetInfo(end).Options.OutputType;
FeatsNm = DatasetInfo(end).Datasets.Feats;
RegrANN = false;
MltClss = false;
NNFnNme = 'fitcnet';
LossAlg = 'crossentropy';
switch OutMode
    case '4 risk classes'
        MltClss = true;
        ClssThr = arrayfun(@(x) num2str(x), DatasetInfo(end).Options.ThresholdsMC, 'UniformOutput',false);

    case 'L-NL classes'
        MinLnds = DatasetInfo(end).Options.MinLandsNumClassL;

    case 'Regression'
        RegrANN = true;
        NNFnNme = 'fitrnet';
        LossAlg = 'mse';

    otherwise
        error('OutMode choice not recognized!')
end

%% Neural Network Settings
Options = {'Classic (L)', 'Classic (V)', 'Cross Validation (K-Fold M)', ...
           'Cross Validation (K-Fold V)', 'Deep (V)', 'Deep (L)', 'Auto', ...
           'Logistic Regression', 'Sensitivity Analysis'};
ANNMode = char(listdlg2({'Type of training?'}, Options));

MdlOpt = checkbox2({'Compact models', 'Structures filter', ...
                    'Standardize inputs', 'Manual structures', ...
                    'Performance filter'}, 'DefInp',[true, false, true, false, true], ...
                                           'OutType','LogInd');
CmpMdl = MdlOpt(1);
StrFlt = MdlOpt(2);
StdInp = MdlOpt(3);
MnStrc = MdlOpt(4);
PrfFlt = MdlOpt(5);

[LyrSzs, LayAct] = deal({nan});
[ItrLim, RegStg, GrdTol, LssTol, ...
    StpTol, ValFrq, ValPat] = deal(nan);
DblOut = true;
MltCls = true;
switch ANNMode
    case {'Classic (V)', 'Classic (L)', 'Cross Validation (K-Fold M)', ...
            'Cross Validation (K-Fold V)', 'Sensitivity Analysis', 'Deep (V)', 'Deep (L)'}
        if MnStrc
            Strcts = inputdlg2({'Specify structure n.1:'}, 'Extendable',true, 'DefInp',{'[1, 1, 1, 1]'});
            LyrSzs = cellfun(@str2num, Strcts, 'UniformOutput',false);
            HddNmb = max(cellfun(@numel, LyrSzs));
    
        else 
            StcInp = inputdlg2({'Max neurons per layer:', 'Increase of neurons:'}, ...
                                    'DefInp',{'[120, 120, 120, 120, 120]', '40'});
            
            MxNeur = str2num(StcInp{1});
            Nr2Add = str2double(StcInp{2});
    
            HddNmb = numel(MxNeur);
        
            % Creation of permutations for possible structures
            [Neur2Trn4Mdl, MdlNeurCmbs] = deal(cell(1, HddNmb));
            for i1 = 1:HddNmb
                Neur2Trn4Mdl{i1} = [1, Nr2Add:Nr2Add:MxNeur(i1)];
                if Nr2Add == 1; Neur2Trn4Mdl{i1}(1) = []; end
                MdlNeurCmbs{i1} = combvec(Neur2Trn4Mdl{1:i1});
            end
        
            CmbsNmbr = sum(cellfun(@(x) size(x, 2), MdlNeurCmbs));
            LyrSzRaw = cell(1, CmbsNmbr);
            i3 = 1;
            for i1 = 1:HddNmb
                for i2 = 1:size(MdlNeurCmbs{i1}, 2)
                    LyrSzRaw{i3} = MdlNeurCmbs{i1}(:,i2)';
                    i3 = i3+1;
                end
            end
    
            if StrFlt
                if numel(LyrSzRaw) > 1000
                    StrHidd = str2double(inputdlg2('Min num of hidden layers:', 'DefInp',{'2'}));
                    if StrHidd > numel(MxNeur)
                        error(['You can not select a minimum number of hidden ', ...
                               'greater than your structure defined earlier!'])
                    end
                    IdL2Kp = cellfun(@(x) numel(x)>=StrHidd, LyrSzRaw);
                    LyrSzs = LyrSzRaw(IdL2Kp);
                else
                    PrpFlt = cellfun(@(x) join(string(x),'_'), LyrSzRaw);
                    IdL2Kp = checkbox2(PrpFlt, 'OutType','NumInd');
                    LyrSzs = LyrSzRaw(IdL2Kp);
                end
            end
        end

        LayOpt = {'sigmoid', 'relu', 'tanh', 'none'};
        if contains(ANNMode, 'Deep', 'IgnoreCase',true)
            LayOpt = [LayOpt, {'elu','gelu','softplus'}];
        end
        LyrPrm = strcat({'Activation fn layer '},string(1:HddNmb));
        LayAct = listdlg2(LyrPrm, LayOpt);

        TunPar = inputdlg2({'Iterations limit:', 'L2 Regularization:', ...
                            'Gradient tolerance:', 'LossTolerance:', ...
                            'Step tolerance:', 'Validation frequency:', ...
                            'Validation patience:'}, 'DefInp',{'1e3', '1e-7', '1e-8', '1e-5', '1e-7', '1', '8'});
        ItrLim = str2double(TunPar{1});
        RegStg = str2double(TunPar{2});
        GrdTol = str2double(TunPar{3});
        LssTol = str2double(TunPar{4});
        StpTol = str2double(TunPar{5});
        ValFrq = str2double(TunPar{6});
        ValPat = str2double(TunPar{7});

        if contains(ANNMode, 'Deep', 'IgnoreCase',true)
            HypParDp1 = listdlg2({'Solver:', 'Final model:', 'Drop learn rate:', 'Weights initializer:', 'Droput?'}, ...
                                 { {'sgdm','rmsprop','adam','lbfgs'}, ...
                                   {'last-iteration','best-validation'}, ...
                                   {'No','Yes'}, ...
                                   {'glorot','he','zeros','orthogonal'}, ...
                                   {'No', 'Yes'} });
            DpSlvr = HypParDp1{1};
            OutNet = HypParDp1{2};
            DrpScd = HypParDp1{3};
            WghtIn = HypParDp1{4};
            DrpOut = HypParDp1{5};
    
            if strcmp(DrpScd,'Yes'); DrpScd = true; else; DrpScd = false; end
            if strcmp(DrpOut,'Yes'); DrpOut = true; else; DrpOut = false; end
    
            HypParDp2 = inputdlg2({'Initial learn rate:'}, 'DefInp',{'0.015'});
            InLrRt = str2double(HypParDp2{1});

            DpPlot = true;
            DpMetr = {'auc', 'fscore', 'precision', 'recall'};
        end

    case 'Auto'
        MaxEvA = str2double(inputdlg2({'Max auto evaluations:'}, 'DefInp',{'80'}));

    case 'Logistic Regression'
        if not(strcmp(OutMode, 'L-NL classes'))
            error('Logistic Regression can be used only with Output Type "L-NL classes"!')
        end

        FnFtLRAns = uiconfirm(Fig, 'What type of shape do you want to use?', ...
                                   'Shape function', 'Options',{'Linear','S-shape'}, 'DefaultOption',1);
        switch FnFtLRAns
            case 'Linear'
                FncFitLR = 'normal';

            case 'S-shape'
                FncFitLR = 'binomial';

            otherwise
                error('Shape function not recognized!')
        end

        DblOut = false;
        MltCls = false;

    otherwise
        error('ANN Mode not recognized!')
end

if RegrANN
    DblOut = false;
    MltCls = false; 
end

MdlHist = false;
CrssVal = false;
NormVal = false;
switch ANNMode
    case {'Cross Validation (K-Fold M)', 'Cross Validation (K-Fold V)', 'Logistic Regression'}
        CrssVal = true;
        if CrssVal ~= DatasetInfo(end).Options.CrossDatasets
            error(['You can not use this ANNMode, because you do not ' ...
                   'have a dataset prepared for Cross Validation!'])
        end
        kFoldNum = DatasetInfo(end).Options.kFoldNumber;

        RepAUCAns = uiconfirm(Fig, 'Do you want to replace performances with results of Cross Validation?', ...
                                   'Replace quality par', 'Options',{'Yes','No'}, 'DefaultOption',1);
        if strcmp(RepAUCAns,'Yes'); RepAUC = true; else; RepAUC = false; end

    case {'Classic (V)', 'Deep (V)'}
        NormVal = true;
        if NormVal ~= DatasetInfo(end).Options.ValidDatasets
            error(['You can not use this ANNMode, because you do not have a ' ...
                   'dataset prepared for Cross Validation!'])
        end

    case {'Classic (L)', 'Auto', 'Deep (L)'}

    case 'Sensitivity Analysis'
        NormVal = true;
        if NormVal ~= DatasetInfo(end).Options.ValidDatasets
            error(['You can not use this ANNMode, because you do not have a ' ...
                   'dataset prepared for Cross Validation!'])
        end

        MdlHist = true;
        HistLim = str2double(inputdlg2('Max number of iterations:', 'DefInp',{'100'}));
        HstStre = uiconfirm(Fig, 'Do you want to save also all the models history or just metrics?', ...
                                 'Replace quality par', 'Options',{'Save','Just metrics'}, 'DefaultOption',2);
        if strcmp(HstStre,'Save'); HstSave = true; else; HstSave = false; end

    otherwise
        error('ANNMode not recognized!')
end

%% Initialization of tables
ANNsRows    = {'Model', 'FeatsConsidered', 'Structure'}; % If you touch these, please modify row below when you write ANNs
ANNsRaw     = table('RowNames',ANNsRows);
ANNsResRows = {'PredTrain', 'PredTest'}; % If you touch these, please modify row below when you write ANNsResRaw
ANNsResRaw  = table('RowNames',ANNsResRows);

%% Dataset recreation
DsetTbl = dataset_extraction(DatasetInfo);

DatasetEvsFeatsTot = DsetTbl{'Total', 'Feats'}{:};
DatasetEvsFeatsTrn = DsetTbl{'Train', 'Feats'}{:};
DatasetEvsFeatsTst = DsetTbl{'Test' , 'Feats'}{:};

ExpectedOutputsTot = DsetTbl{'Total', 'ExpOuts'}{:};
ExpectedOutputsTrn = DsetTbl{'Train', 'ExpOuts'}{:};
ExpectedOutputsTst = DsetTbl{'Test' , 'ExpOuts'}{:};

if CrssVal
    DatasetFeatsCvTrn = DsetTbl{'CvTrain', 'Feats'}{:};
    DatasetFeatsCvVal = DsetTbl{'CvValid', 'Feats'}{:};

    ExpOutputsCvTrn = DsetTbl{'CvTrain', 'ExpOuts'}{:};
    ExpOutputsCvVal = DsetTbl{'CvValid', 'ExpOuts'}{:};
end

if NormVal
    DatasetEvsFeatsNvTrn = DsetTbl{'NvTrain', 'Feats'}{:};
    DatasetEvsFeatsNvVal = DsetTbl{'NvValid', 'Feats'}{:};

    ExpectedOutputsNvTrn = DsetTbl{'NvTrain', 'ExpOuts'}{:};
    ExpectedOutputsNvVal = DsetTbl{'NvValid', 'ExpOuts'}{:};
end

%% Creation of ModelInfo
ModelInfo                  = struct('Type','Temporal ANN - Model A');
ModelInfo.Dataset          = DatasetInfo;
ModelInfo.ANNsOptions      = struct('TrainMode',ANNMode, 'ActivationFunction',{LayAct}, ...
                                    'Standardize',StdInp, 'LimitIteration',ItrLim, ...
                                    'Regularization',RegStg, 'GradientTolerance',GrdTol, ...
                                    'LossTolerance',LssTol, 'LossAlgorithm',LossAlg, ...
                                    'StepTolerance',StpTol, 'ModelHistory',MdlHist);

switch ANNMode
    case 'Classic (V)'
        ModelInfo.ANNsOptions.ValidationFrequency = ValFrq;
        ModelInfo.ANNsOptions.ValidationPatience  = ValPat;

    case {'Cross Validation (K-Fold M)', 'Logistic Regression'}
        ModelInfo.ANNsOptions.KFolds = kFoldNum;

    case 'Cross Validation (K-Fold V)'
        ModelInfo.ANNsOptions.KFolds              = kFoldNum;
        ModelInfo.ANNsOptions.ValidationFrequency = ValFrq;
        ModelInfo.ANNsOptions.ValidationPatience  = ValPat;

    case {'Classic (L)', 'Sensitivity Analysis'}

    case 'Auto'
        ModelInfo.ANNsOptions.NumberOfAttempts = MaxEvA;

    case {'Deep (V)', 'Deep (L)'}

    otherwise
        error('ANNMode to insert in ModelInfo not recognized!')
end

%% Neural Network Training
ANNsNumber = length(LyrSzs);

% Initialization
[TrainLossRaw, TrainMSERaw, TestLossRaw, TestMSERaw] = deal(zeros(1,ANNsNumber));
if CrssVal
    [CrossMdlsRaw, CrossTrnIndRaw, CrossValIndRaw] = deal(cell(kFoldNum, ANNsNumber));
    [CrossTrnMSERaw, CrossValMSERaw, CrossTstMSERaw, ...
        CrossTrnAUCRaw, CrossValAUCRaw, CrossTstAUCRaw] = deal(zeros(kFoldNum, ANNsNumber));
end
if NormVal
    [NvTrnAUCRaw, NvValAUCRaw, ...
        NvTrnMSERaw, NvValMSERaw] = deal(zeros(1,ANNsNumber));
end
if MdlHist
    HistMdlsRaw = cell(HistLim, ANNsNumber);
    [HistTrnMSERaw, HistValMSERaw, HistTstMSERaw, ...
        HistTrnAUCRaw, HistValAUCRaw, HistTstAUCRaw, ...
            HistTrnLossRaw, HistValLossRaw, HistTstLossRaw] = deal(nan(HistLim, ANNsNumber));
end

% Training process
rng(7)
ProgressBar.Indeterminate = 'off';
for i1 = 1:ANNsNumber
    ProgressBar.Value = i1/ANNsNumber;
    ProgressBar.Message = ['Training model n. ',num2str(i1),' of ',num2str(ANNsNumber)];

    CLN = numel(LyrSzs{i1});

    switch ANNMode
        case 'Classic (L)' % Normal training without validation, just loss
            Model = feval(NNFnNme, DatasetEvsFeatsTrn, ExpectedOutputsTrn, ...
                                            'LayerSizes',LyrSzs{i1}, 'Activations',LayAct(1:CLN), ...
                                            'Standardize',StdInp, 'Lambda',RegStg, ...
                                            'IterationLimit',ItrLim, 'LossTolerance',LssTol, ...
                                            'StepTolerance',StpTol, 'GradientTolerance',GrdTol);

            FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
            if FailedConvergence
                warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge! Please analyze it."))
            end

        case 'Classic (V)' % Normal training with validation, train stops in the best spot for validation and training
            Model = feval(NNFnNme, DatasetEvsFeatsNvTrn, ExpectedOutputsNvTrn, ...
                                            'ValidationData',{DatasetEvsFeatsNvVal, ExpectedOutputsNvVal}, ...
                                            'ValidationFrequency',ValFrq, 'ValidationPatience',ValPat, ...
                                            'LayerSizes',LyrSzs{i1}, 'Activations',LayAct(1:CLN), ...
                                            'GradientTolerance',GrdTol, 'Standardize',StdInp, ...
                                            'Lambda',RegStg, 'IterationLimit',ItrLim, ...
                                            'LossTolerance',LssTol);

            FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
            if FailedConvergence
                warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge! Please analyze it."))
            end

            PredsNvTrnTemp = mdlpredict(Model, DatasetEvsFeatsNvTrn, 'SecondOut',DblOut, 'SingleCol',true); % Thanks to SingleCol, outputs are always in 1 column!
            PredsNvValTemp = mdlpredict(Model, DatasetEvsFeatsNvVal, 'SecondOut',DblOut, 'SingleCol',true);
            if RegrANN
                NvTrnMSERaw(i1) = mse(PredsNvTrnTemp, ExpectedOutputsNvTrn); % This is necessary because both outputs and predictions are not numbers in 0-1 range!
                NvValMSERaw(i1) = mse(PredsNvValTemp, ExpectedOutputsNvVal);
                PredsNvTrnTemp  = rescale(PredsNvTrnTemp); % Now predictions are in range 0-1 (to evaluate AUC)
                PredsNvValTemp  = rescale(PredsNvValTemp);
            else
                NvTrnMSERaw(i1) = mse(PredsNvTrnTemp, double(ExpectedOutputsNvTrn >= 1));
                NvValMSERaw(i1) = mse(PredsNvValTemp, double(ExpectedOutputsNvVal >= 1));
            end

            [~, ~, ~, NvTrnAUCRaw(i1), ~] = perfcurve(double(ExpectedOutputsNvTrn >=1 ), PredsNvTrnTemp, 1);
            [~, ~, ~, NvValAUCRaw(i1), ~] = perfcurve(double(ExpectedOutputsNvVal >=1 ), PredsNvValTemp, 1);

        case 'Cross Validation (K-Fold M)' % Cross validation k-fold, training just with loss
            ModelCV = feval(NNFnNme, DatasetEvsFeatsTrn, ExpectedOutputsTrn, ...
                                            'LayerSizes',LyrSzs{i1}, 'Activations',LayAct(1:CLN), ...
                                            'Standardize',StdInp, 'Lambda',RegStg, ...
                                            'IterationLimit',ItrLim, 'LossTolerance',LssTol, ...
                                            'StepTolerance',StpTol, 'GradientTolerance',GrdTol, ...
                                            'Crossval','on', 'KFold',kFoldNum); % Remember that instead of 'KFold' you can use for example: 'Holdout',0.1
            for i2 = 1:kFoldNum
                CrossMdlsRaw{i2, i1} = ModelCV.Trained{i2};
                % if CmpMdl; CrossMdlsRaw{i2, i1} = compact(CrossMdlsRaw{i2, i1}); end % Already compact!

                CrossTrnIndRaw{i2, i1} = training(ModelCV.Partition, i2);
                CrossValIndRaw{i2, i1} = test(ModelCV.Partition, i2);

                DatasetEvsFeatsTrnTemp = DatasetEvsFeatsTrn(CrossTrnIndRaw{i2, i1}, :);
                ExpOutsCrossTrnTemp    = ExpectedOutputsTrn(CrossTrnIndRaw{i2, i1});

                DatasetEvsFeatsValTemp = DatasetEvsFeatsTrn(CrossValIndRaw{i2, i1}, :);
                ExpOutsCrossValTemp    = ExpectedOutputsTrn(CrossValIndRaw{i2, i1});

                PredsCrossTrnTemp = mdlpredict(ModelCV.Trained{i2}, DatasetEvsFeatsTrnTemp, 'SecondOut',DblOut, 'SingleCol',true); % Thanks to SingleCol, outputs are always in 1 column!
                PredsCrossValTemp = mdlpredict(ModelCV.Trained{i2}, DatasetEvsFeatsValTemp, 'SecondOut',DblOut, 'SingleCol',true);
                PredsCrossTstTemp = mdlpredict(ModelCV.Trained{i2}, DatasetEvsFeatsTst    , 'SecondOut',DblOut, 'SingleCol',true);
                if RegrANN
                    CrossTrnMSERaw(i2, i1) = mse(PredsCrossTrnTemp, ExpOutsCrossTrnTemp); % This is necessary because both outputs and predictions are not numbers in 0-1 range!
                    CrossValMSERaw(i2, i1) = mse(PredsCrossValTemp, ExpOutsCrossValTemp);
                    CrossTstMSERaw(i2, i1) = mse(PredsCrossTstTemp, ExpectedOutputsTst );
                    PredsCrossTrnTemp      = rescale(PredsCrossTrnTemp); % Now predictions are in range 0-1 (to evaluate AUC)
                    PredsCrossValTemp      = rescale(PredsCrossValTemp);
                    PredsCrossTstTemp      = rescale(PredsCrossTstTemp);
                else
                    CrossTrnMSERaw(i2, i1) = mse(PredsCrossTrnTemp, double(ExpOutsCrossTrnTemp >= 1));
                    CrossValMSERaw(i2, i1) = mse(PredsCrossValTemp, double(ExpOutsCrossValTemp >= 1));
                    CrossTstMSERaw(i2, i1) = mse(PredsCrossTstTemp, double(ExpectedOutputsTst  >= 1));
                end
    
                [~, ~, ~, CrossTrnAUCRaw(i2, i1), ~] = perfcurve(double(ExpOutsCrossTrnTemp >= 1), PredsCrossTrnTemp, 1);
                [~, ~, ~, CrossValAUCRaw(i2, i1), ~] = perfcurve(double(ExpOutsCrossValTemp >= 1), PredsCrossValTemp, 1);
                [~, ~, ~, CrossTstAUCRaw(i2, i1), ~] = perfcurve(double(ExpectedOutputsTst  >= 1), PredsCrossTstTemp, 1);
            end

            LossesOfModels = kfoldLoss(ModelCV, 'Mode','individual');
            [~, IndBestModel] = min(LossesOfModels);
            Model = ModelCV.Trained{IndBestModel};

        case 'Cross Validation (K-Fold V)' % Cross validation k-fold, training with validation (ki dataset as val)
            for i2 = 1:kFoldNum
                CurrMdlCV = feval(NNFnNme, DatasetFeatsCvTrn{i2}, ExpOutputsCvTrn{i2}, ...
                                                      'ValidationData',{DatasetFeatsCvVal{i2}, ExpOutputsCvVal{i2}}, ...
                                                      'ValidationFrequency',ValFrq, 'ValidationPatience',ValPat, ...
                                                      'LayerSizes',LyrSzs{i1}, 'Activations',LayAct(1:CLN), ...
                                                      'GradientTolerance',GrdTol, 'Standardize',StdInp, ...
                                                      'Lambda',RegStg, 'IterationLimit',ItrLim, ...
                                                      'LossTolerance',LssTol);

                CrossMdlsRaw{i2, i1}   = CurrMdlCV;
                if CmpMdl; CrossMdlsRaw{i2, i1} = compact(CrossMdlsRaw{i2, i1}); end

                DatasetEvsFeatsTrnTemp = DatasetFeatsCvTrn{i2};
                ExpOutsCrossTrnTemp    = ExpOutputsCvTrn{i2};

                DatasetEvsFeatsValTemp = DatasetFeatsCvVal{i2};
                ExpOutsCrossValTemp    = ExpOutputsCvVal{i2};

                PredsCrossTrnTemp = mdlpredict(CurrMdlCV, DatasetEvsFeatsTrnTemp, 'SecondOut',DblOut, 'SingleCol',true); % Thanks to SingleCol, outputs are always in 1 column!
                PredsCrossValTemp = mdlpredict(CurrMdlCV, DatasetEvsFeatsValTemp, 'SecondOut',DblOut, 'SingleCol',true);
                PredsCrossTstTemp = mdlpredict(CurrMdlCV, DatasetEvsFeatsTst    , 'SecondOut',DblOut, 'SingleCol',true);
                if RegrANN
                    CrossTrnMSERaw(i2, i1) = mse(PredsCrossTrnTemp, ExpOutsCrossTrnTemp);
                    CrossValMSERaw(i2, i1) = mse(PredsCrossValTemp, ExpOutsCrossValTemp);
                    CrossTstMSERaw(i2, i1) = mse(PredsCrossTstTemp, ExpectedOutputsTst );
                    PredsCrossTrnTemp      = rescale(PredsCrossTrnTemp);
                    PredsCrossValTemp      = rescale(PredsCrossValTemp);
                    PredsCrossTstTemp      = rescale(PredsCrossTstTemp);
                else
                    CrossTrnMSERaw(i2, i1) = mse(PredsCrossTrnTemp, double(ExpOutsCrossTrnTemp >= 1));
                    CrossValMSERaw(i2, i1) = mse(PredsCrossValTemp, double(ExpOutsCrossValTemp >= 1));
                    CrossTstMSERaw(i2, i1) = mse(PredsCrossTstTemp, double(ExpectedOutputsTst  >= 1));
                end
    
                [~, ~, ~, CrossTrnAUCRaw(i2, i1), ~] = perfcurve(double(ExpOutsCrossTrnTemp >= 1), PredsCrossTrnTemp, 1);
                [~, ~, ~, CrossValAUCRaw(i2, i1), ~] = perfcurve(double(ExpOutsCrossValTemp >= 1), PredsCrossValTemp, 1);
                [~, ~, ~, CrossTstAUCRaw(i2, i1), ~] = perfcurve(double(ExpectedOutputsTst  >= 1), PredsCrossTstTemp, 1);
            end

            [~, IndBestModel] = min(CrossValMSERaw(:, i1));
            Model = CrossMdlsRaw{IndBestModel, i1};

        case 'Auto' % Searching for best structure and best activation functions
            Model = feval(NNFnNme, DatasetEvsFeatsTrn, ExpectedOutputsTrn, 'OptimizeHyperparameters','auto', ...
                                                'HyperparameterOptimizationOptions',struct('Optimizer','bayesopt', ...
                                                                                           'AcquisitionFunctionName','expected-improvement-plus', ...
                                                                                           'MaxObjectiveEvaluations',MaxEvA, ...
                                                                                           'MaxTime',Inf, ...
                                                                                           'ShowPlots',true, ...
                                                                                           'Verbose',1, ...
                                                                                           'UseParallel',false, ...
                                                                                           'Repartition',true, ...
                                                                                           'Kfold',kFoldNum));

            LyrSzs{i1} = Model.LayerSizes;

        case 'Deep (L)'
            Model = trainann2(DatasetEvsFeatsTrn, ExpectedOutputsTrn, ...
                                          'Solver',DpSlvr, 'LayerSizes',LyrSzs{i1}, ...
                                          'ShowTrainPlot',DpPlot, 'MetricsToUse',DpMetr, ...
                                          'LayerActivations',LayAct(1:CLN), 'IterationLimit',ItrLim, ...
                                          'L2Regularization',RegStg, 'StandardizeInput',StdInp, ...
                                          'ObjTolerance',LssTol, 'FinalNetwork',OutNet, ...
                                          'WeightsInit',WghtIn, 'Dropout',DrpOut, ...
                                          'InitialLearnRate',InLrRt, 'LRDropSchedule',DrpScd, ...
                                          'GradTolerance',GrdTol, 'StepTolerance',StpTol);

        case 'Deep (V)'
            Model = trainann2(DatasetEvsFeatsNvTrn, ExpectedOutputsNvTrn, ...
                                          'Solver',DpSlvr, 'LayerSizes',LyrSzs{i1}, ...
                                          'ShowTrainPlot',DpPlot, 'MetricsToUse',DpMetr, ...
                                          'LayerActivations',LayAct(1:CLN), 'IterationLimit',ItrLim, ...
                                          'L2Regularization',RegStg, 'StandardizeInput',StdInp, ...
                                          'ObjTolerance',LssTol, 'FinalNetwork',OutNet, ...
                                          'ValidationData',{DatasetEvsFeatsNvVal, ExpectedOutputsNvVal}, ...
                                          'ValidFrequency',ValFrq, 'ValidPatience',ValPat, ...
                                          'WeightsInit',WghtIn, 'Dropout',DrpOut, ...
                                          'InitialLearnRate',InLrRt, 'LRDropSchedule',DrpScd, ...
                                          'GradTolerance',GrdTol, 'StepTolerance',StpTol);

        case 'Logistic Regression' % Logistic regression with cross validation ans s-shape function
            for i2 = 1:kFoldNum
                DatasetEvsFeatsTrnTemp = DatasetFeatsCvTrn{i2};
                ExpOutsCrossTrnTemp    = ExpOutputsCvTrn{i2};

                DatasetEvsFeatsValTemp = DatasetFeatsCvVal{i2};
                ExpOutsCrossValTemp    = ExpOutputsCvVal{i2};

                DatasetTrnWithOutsTmp  = [DatasetEvsFeatsTrnTemp, ...
                                          array2table(ExpOutsCrossTrnTemp, 'VariableNames',{'ExpOut'})];

                CurrMdlCV = fitglm(DatasetTrnWithOutsTmp, 'ResponseVar','ExpOut', 'Distribution',FncFitLR);

                CrossMdlsRaw{i2, i1} = CurrMdlCV;
                if CmpMdl; CrossMdlsRaw{i2, i1} = compact(CrossMdlsRaw{i2, i1}); end

                PredsCrossTrnTemp = mdlpredict(CurrMdlCV, DatasetEvsFeatsTrnTemp, 'SecondOut',DblOut, 'SingleCol',true);
                PredsCrossValTemp = mdlpredict(CurrMdlCV, DatasetEvsFeatsValTemp, 'SecondOut',DblOut, 'SingleCol',true);
                PredsCrossTstTemp = mdlpredict(CurrMdlCV, DatasetEvsFeatsTst    , 'SecondOut',DblOut, 'SingleCol',true);

                CrossTrnMSERaw(i2, i1) = mse(PredsCrossTrnTemp, double(ExpOutsCrossTrnTemp >= 1));
                CrossValMSERaw(i2, i1) = mse(PredsCrossValTemp, double(ExpOutsCrossValTemp >= 1));
                CrossTstMSERaw(i2, i1) = mse(PredsCrossTstTemp, double(ExpectedOutputsTst  >= 1));
    
                [~, ~, ~, CrossTrnAUCRaw(i2, i1), ~] = perfcurve(double(ExpOutsCrossTrnTemp >= 1), PredsCrossTrnTemp, 1);
                [~, ~, ~, CrossValAUCRaw(i2, i1), ~] = perfcurve(double(ExpOutsCrossValTemp >= 1), PredsCrossValTemp, 1);
                [~, ~, ~, CrossTstAUCRaw(i2, i1), ~] = perfcurve(double(ExpectedOutputsTst  >= 1), PredsCrossTstTemp, 1);
            end

            [~, IndBestModel] = min(CrossValMSERaw(:, i1));
            Model = CrossMdlsRaw{IndBestModel, i1};

        case 'Sensitivity Analysis'
            if not(MdlHist); error('MdlHist must be set to true, check the script!'); end
            for i2 = 1:HistLim
                rng(1) % To start everytime from the same point!
                Model = feval(NNFnNme, DatasetEvsFeatsNvTrn, ExpectedOutputsNvTrn, ...
                                                'LayerSizes',LyrSzs{i1}, 'Activations',LayAct(1:CLN), ...
                                                'Standardize',StdInp, 'Lambda',RegStg, ...
                                                'IterationLimit',i2, 'LossTolerance',LssTol, ...
                                                'StepTolerance',StpTol, 'GradientTolerance',GrdTol);

                FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                EarlyConvergence  = size(Model.TrainingHistory, 1) < i2;
                if FailedConvergence || EarlyConvergence
                    warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge at ", ...
                                   num2str(i2)," iteration! Please analyze it."))
                    break
                end

                if HstSave
                    HistMdlsRaw{i2,i1} = Model;
                    if CmpMdl; HistMdlsRaw{i2,i1} = compact(HistMdlsRaw{i2,i1}); end
                end

                PredsHistTrnTemp = mdlpredict(Model, DatasetEvsFeatsNvTrn, 'SecondOut',DblOut, 'SingleCol',true); % Thanks to SingleCol, outputs are always in 1 column!
                PredsHistValTemp = mdlpredict(Model, DatasetEvsFeatsNvVal, 'SecondOut',DblOut, 'SingleCol',true);
                PredsHistTstTemp = mdlpredict(Model, DatasetEvsFeatsTst  , 'SecondOut',DblOut, 'SingleCol',true);
                if RegrANN
                    HistTrnMSERaw(i2,i1)  = mse(PredsHistTrnTemp, ExpectedOutputsNvTrn); % This is necessary because both outputs and predictions are not numbers in 0-1 range!
                    HistValMSERaw(i2,i1)  = mse(PredsHistValTemp, ExpectedOutputsNvVal);
                    HistTstMSERaw(i2,i1)  = mse(PredsHistTstTemp, ExpectedOutputsTst  );

                    HistTrnLossRaw(i2,i1) = crossentropy2(PredsHistTrnTemp, ExpectedOutputsNvTrn);
                    HistValLossRaw(i2,i1) = crossentropy2(PredsHistValTemp, ExpectedOutputsNvVal);
                    HistTstLossRaw(i2,i1) = crossentropy2(PredsHistTstTemp, ExpectedOutputsTst  );

                    PredsHistTrnTemp     = rescale(PredsHistTrnTemp); % Now predictions are in range 0-1 (to evaluate AUC)
                    PredsHistValTemp     = rescale(PredsHistValTemp);
                    PredsHistTstTemp     = rescale(PredsHistTstTemp);
                else
                    HistTrnMSERaw(i2,i1) = mse(PredsHistTrnTemp, double(ExpectedOutputsNvTrn >= 1));
                    HistValMSERaw(i2,i1) = mse(PredsHistValTemp, double(ExpectedOutputsNvVal >= 1));
                    HistTstMSERaw(i2,i1) = mse(PredsHistTstTemp, double(ExpectedOutputsTst   >= 1));

                    HistTrnLossRaw(i2,i1) = crossentropy2(PredsHistTrnTemp, double(ExpectedOutputsNvTrn >= 1));
                    HistValLossRaw(i2,i1) = crossentropy2(PredsHistValTemp, double(ExpectedOutputsNvVal >= 1));
                    HistTstLossRaw(i2,i1) = crossentropy2(PredsHistTstTemp, double(ExpectedOutputsTst   >= 1));
                end
    
                [~, ~, ~, HistTrnAUCRaw(i2,i1), ~] = perfcurve(double(ExpectedOutputsNvTrn >=1 ), PredsHistTrnTemp, 1);
                [~, ~, ~, HistValAUCRaw(i2,i1), ~] = perfcurve(double(ExpectedOutputsNvVal >=1 ), PredsHistValTemp, 1);
                [~, ~, ~, HistTstAUCRaw(i2,i1), ~] = perfcurve(double(ExpectedOutputsTst   >=1 ), PredsHistTstTemp, 1);
            end

        otherwise
            error('Training mode not recognized!')
    end
    
    % Common prediction process
    PredProbsTrain = mdlpredict(Model, DatasetEvsFeatsTrn, 'SecondOut',DblOut);
    PredProbsTest  = mdlpredict(Model, DatasetEvsFeatsTst, 'SecondOut',DblOut);

    TrainLossRaw(i1) = crossentropy2(PredProbsTrain, ExpectedOutputsTrn); % 'crossentropy' is appropriate only for neural network models.
    TestLossRaw(i1)  = crossentropy2(PredProbsTest,  ExpectedOutputsTst); % 'crossentropy' is appropriate only for neural network models.

    if RegrANN
        TrainMSERaw(i1) = mse(PredProbsTrain, ExpectedOutputsTrn);
        TestMSERaw(i1)  = mse(PredProbsTest , ExpectedOutputsTst);
    else
        TrainMSERaw(i1) = mse( PredProbsTrain, double(ExpectedOutputsTrn == (1:size(PredProbsTrain, 2))) );
        TestMSERaw(i1)  = mse( PredProbsTest , double(ExpectedOutputsTst == (1:size(PredProbsTest, 2)))  );
    end

    if CmpMdl && not(contains(ANNMode, 'Deep', 'IgnoreCase',true)) && not(contains(class(Model), 'Compact', 'IgnoreCase',true))
        Model = compact(Model); % To eliminate training dataset and reduce size of the object!
    end

    ANNsRaw{ANNsRows, i1} = {Model; FeatsNm; LyrSzs{i1}}; % Pay attention to the order!
    ANNsResRaw{ANNsResRows, i1} = {PredProbsTrain; PredProbsTest}; % Pay attention to the order!
end
ProgressBar.Indeterminate = 'on';

% Naming of columns
ANNsColsRaw = strcat("ANN",string(1:ANNsNumber));
ANNsRaw.Properties.VariableNames    = ANNsColsRaw;
ANNsResRaw.Properties.VariableNames = ANNsColsRaw;

% Averaging of cross values
if CrssVal
    AvCrossTrnAUCRaw = mean(CrossTrnAUCRaw, 1);
    AvCrossValAUCRaw = mean(CrossValAUCRaw, 1);
    AvCrossTstAUCRaw = mean(CrossTstAUCRaw, 1);
end

%% Neural Network Quality Evaluation
ProgressBar.Indeterminate = 'on';
ProgressBar.Message       = 'Analyzing quality of models...';

ANNsPerfRows = {'FPR', 'TPR', 'AUC', 'BestThreshold', 'BestThrInd'};
ANNsPerfRaw  = table('RowNames',{'ROC','Err'});

ANNsPerfRaw{'Err','Train'} = {array2table([TrainMSERaw; TrainLossRaw], ...
                                            'VariableNames',ANNsColsRaw, ...
                                            'RowNames',{'MSE','Loss'})};
ANNsPerfRaw{'Err','Test'}  = {array2table([TestMSERaw; TestLossRaw], ...
                                            'VariableNames',ANNsColsRaw, ...
                                            'RowNames',{'MSE','Loss'})};

if CrssVal && RepAUC
    ANNsPerfRaw{'Err','Train'} = {array2table([ mean(CrossTrnMSERaw,1);
                                                nan(size(TrainLossRaw)) ], ...
                                                'VariableNames',ANNsColsRaw, ...
                                                'RowNames',{'MSE','Loss'})};
    ANNsPerfRaw{'Err','Test'}  = {array2table([ mean(CrossValMSERaw,1);
                                                nan(size(TestLossRaw)) ], ...
                                                'VariableNames',ANNsColsRaw, ...
                                                'RowNames',{'MSE','Loss'})};
end

ANNsPerfRaw{'ROC',{'Train','Test'}} = {table('RowNames',ANNsPerfRows)};
if MltClss
    ANNsPerfRawMC = table('RowNames',{'ROC'});
    ANNsPerfRawMC{'ROC',{'Train','Test'}} = {table('RowNames',ANNsPerfRows)};

    ANNsPrfSmmRows    = {'MeanAUC', 'MinAUC', 'MaxAUC', 'StDvAUC'};
    ANNsPerfRawSummMC = table('RowNames',{'ROC'});
    ANNsPerfRawSummMC{'ROC',{'Train','Test'}} = {table('RowNames',ANNsPrfSmmRows)};
end
for i1 = 1:size(ANNsRaw,2)
    if RegrANN
        PredProbsTest  = rescale(ANNsResRaw{'PredTest' , i1}{:});
        PredProbsTrain = rescale(ANNsResRaw{'PredTrain', i1}{:});
    else
        PredProbsTest  = ANNsResRaw{'PredTest' , i1}{:};
        PredProbsTrain = ANNsResRaw{'PredTrain', i1}{:};
    end

    ExpOutsTest  = ExpectedOutputsTst;
    ExpOutsTrain = ExpectedOutputsTrn;

    % Test performance
    [FPR4ROC_Test_L, TPR4ROC_Test_L, ThresholdsROC_Test_L, ...
            AUC_Test_L, OptPoint_Test_L] = perfcurve(double(ExpOutsTest>=1), sum(PredProbsTest,2), 1); % The quality in predicting a landslide, independently from class
    IndBest_Test_L = find(ismember([FPR4ROC_Test_L, TPR4ROC_Test_L], OptPoint_Test_L, 'rows'));
    BestThreshold_Test_L = ThresholdsROC_Test_L(IndBest_Test_L);
    
    % Train performance
    [FPR4ROC_Train_L, TPR4ROC_Train_L, ThresholdsROC_Train_L, ...
            AUC_Train_L, OptPoint_Train_L] = perfcurve(double(ExpOutsTrain>=1), sum(PredProbsTrain,2), 1); % The quality in predicting a landslide, independently from class
    IndBest_Train_L = find(ismember([FPR4ROC_Train_L, TPR4ROC_Train_L], OptPoint_Train_L, 'rows'));
    BestThreshold_Train_L = ThresholdsROC_Train_L(IndBest_Train_L);

    if CrssVal && RepAUC
        AUC_Train_L = AvCrossTrnAUCRaw(i1);
        AUC_Test_L  = AvCrossValAUCRaw(i1);

        [FPR4ROC_Test_L, TPR4ROC_Test_L, BestThreshold_Test_L, IndBest_Test_L, ...
            FPR4ROC_Train_L, TPR4ROC_Train_L, BestThreshold_Train_L, IndBest_Train_L] = deal(NaN);
    end
    
    % General matrices creation
    ANNsPerfRaw{'ROC','Test'}{:}{ANNsPerfRows,  i1} = {FPR4ROC_Test_L ; TPR4ROC_Test_L ; AUC_Test_L ; BestThreshold_Test_L ; IndBest_Test_L }; % Pay attention to the order!
    ANNsPerfRaw{'ROC','Train'}{:}{ANNsPerfRows, i1} = {FPR4ROC_Train_L; TPR4ROC_Train_L; AUC_Train_L; BestThreshold_Train_L; IndBest_Train_L}; % Pay attention to the order!

    if MltClss
        % Test performance
        [FPR4ROC_Test, TPR4ROC_Test, ThresholdsROC_Test, AUC_Test, OptPoint_Test, ...
                IndBest_Test, BestThreshold_Test] = deal(cell(1, size(PredProbsTest, 2)));
        for i2 = 1:size(PredProbsTest, 2)
            [FPR4ROC_Test{i2}, TPR4ROC_Test{i2}, ThresholdsROC_Test{i2}, ...
                    AUC_Test{i2}, OptPoint_Test{i2}] = perfcurve(ExpOutsTest, PredProbsTest(:,i2), i2); % To adjust ExpectedOutputsTst for CrossValidation
            IndBest_Test{i2} = find(ismember([FPR4ROC_Test{i2}, TPR4ROC_Test{i2}], OptPoint_Test{i2}, 'rows'));
            BestThreshold_Test{i2} = ThresholdsROC_Test{i2}(IndBest_Test{i2});
        end

        MeanAUC_Test = mean(cell2mat(AUC_Test));
        MinAUC_Test  = min(cell2mat(AUC_Test));
        MaxAUC_Test  = max(cell2mat(AUC_Test));
        StDvAUC_Test = std(cell2mat(AUC_Test));

        % Train performance
        [FPR4ROC_Train, TPR4ROC_Train, ThresholdsROC_Train, AUC_Train, OptPoint_Train, ...
                IndBest_Train, BestThreshold_Train] = deal(cell(1, size(PredProbsTrain, 2)));
        for i2 = 1:size(PredProbsTrain, 2)
            [FPR4ROC_Train{i2}, TPR4ROC_Train{i2}, ThresholdsROC_Train{i2}, ...
                    AUC_Train{i2}, OptPoint_Train{i2}] = perfcurve(ExpOutsTrain, PredProbsTrain(:,i2), i2);
            IndBest_Train{i2} = find(ismember([FPR4ROC_Train{i2}, TPR4ROC_Train{i2}], OptPoint_Train{i2}, 'rows'));
            BestThreshold_Train{i2} = ThresholdsROC_Train{i2}(IndBest_Train{i2});
        end

        MeanAUC_Train = mean(cell2mat(AUC_Train));
        MinAUC_Train  = min(cell2mat(AUC_Train));
        MaxAUC_Train  = max(cell2mat(AUC_Train));
        StDvAUC_Train = std(cell2mat(AUC_Train));

        % General matrices creation
        ANNsPerfRawMC{'ROC','Test' }{:}{ANNsPerfRows, i1} = {FPR4ROC_Test ; TPR4ROC_Test ; AUC_Test ; BestThreshold_Test ; IndBest_Test }; % Pay attention to the order!
        ANNsPerfRawMC{'ROC','Train'}{:}{ANNsPerfRows, i1} = {FPR4ROC_Train; TPR4ROC_Train; AUC_Train; BestThreshold_Train; IndBest_Train}; % Pay attention to the order!

        ANNsPerfRawSummMC{'ROC','Test' }{:}{ANNsPrfSmmRows, i1} = {MeanAUC_Test ; MinAUC_Test ; MaxAUC_Test ; StDvAUC_Test }; % Pay attention to the order!
        ANNsPerfRawSummMC{'ROC','Train'}{:}{ANNsPrfSmmRows, i1} = {MeanAUC_Train; MinAUC_Train; MaxAUC_Train; StDvAUC_Train}; % Pay attention to the order!
    end
end

ANNsPerfRaw{'ROC','Test' }{:}.Properties.VariableNames = ANNsColsRaw;
ANNsPerfRaw{'ROC','Train'}{:}.Properties.VariableNames = ANNsColsRaw;
if MltClss
    ANNsPerfRawMC{'ROC','Test' }{:}.Properties.VariableNames = ANNsColsRaw;
    ANNsPerfRawMC{'ROC','Train'}{:}.Properties.VariableNames = ANNsColsRaw;

    ANNsPerfRawSummMC{'ROC','Test' }{:}.Properties.VariableNames = ANNsColsRaw;
    ANNsPerfRawSummMC{'ROC','Train'}{:}.Properties.VariableNames = ANNsColsRaw;
end

%% Neural Network First Filter (Euclidean Minimization)
if PrfFlt
    FrstVecToMinimize = [1 - cell2mat(ANNsPerfRaw{'ROC','Train'}{:}{'AUC' ,:}); ... % The opposit of AUC because you want to minimize!
                         1 - cell2mat(ANNsPerfRaw{'ROC','Test' }{:}{'AUC' ,:}); ... % The opposit of AUC because you want to minimize!
                         ANNsPerfRaw{'Err','Train'}{:}{'Loss',:}; ...
                         ANNsPerfRaw{'Err','Test' }{:}{'Loss',:}];
    if CrssVal
        FrstVecToMinimize = [ FrstVecToMinimize ;
                              1-AvCrossTrnAUCRaw;
                              1-AvCrossValAUCRaw ];
    end
    
    EuclDistMdls = vecnorm(FrstVecToMinimize, 2, 1);
    
    LossRngs = [min([ANNsPerfRaw{'Err','Train'}{:}{'Loss',:}, ANNsPerfRaw{'Err','Test' }{:}{'Loss',:}]), ...
                max([ANNsPerfRaw{'Err','Train'}{:}{'Loss',:}, ANNsPerfRaw{'Err','Test' }{:}{'Loss',:}])];
    AUCRngs  = [min([cell2mat(ANNsPerfRaw{'ROC','Train'}{:}{'AUC' ,:}), cell2mat(ANNsPerfRaw{'ROC','Test' }{:}{'AUC' ,:})]), ...
                max([cell2mat(ANNsPerfRaw{'ROC','Train'}{:}{'AUC' ,:}), cell2mat(ANNsPerfRaw{'ROC','Test' }{:}{'AUC' ,:})])];
    
    ThrValsFilter = str2double(inputdlg2([strcat("Choose AUC threshold for a good model. Min is ", ...
                                                 string(AUCRngs(1))," and max is ",string(AUCRngs(2)))
                                          strcat("Choose Loss threshold for a good model. Min is ", ...
                                                 string(LossRngs(1))," and max is ",string(LossRngs(2)))], ...
                                         'DefInp',{num2str(mean(AUCRngs)), num2str(mean(LossRngs))}));
    
    VecThrGoodMdl = [1 - ThrValsFilter(1); 1 - ThrValsFilter(1); ThrValsFilter(2); ThrValsFilter(2)];
    if CrssVal
        VecThrGoodMdl = [VecThrGoodMdl; 1-ThrValsFilter(1); 1-ThrValsFilter(1)];
    end
    EuclThrGoodMdl = vecnorm(VecThrGoodMdl, 2, 1);
    
    IndGdsMdls = EuclDistMdls <= EuclThrGoodMdl;
    
    % Update of ModelInfo
    ModelInfo.ThrGoodModels.MinAUC  = ThrValsFilter(1);
    ModelInfo.ThrGoodModels.MaxLoss = ThrValsFilter(2);

else
    IndGdsMdls = true(1, size(ANNsRaw,2));
end

ANNs     = ANNsRaw(:,IndGdsMdls);
ANNsRes  = ANNsResRaw(:,IndGdsMdls);
ANNsCols = ANNsColsRaw(:,IndGdsMdls);
ANNsPerf = ANNsPerfRaw;
for i1 = 1:size(ANNsPerfRaw, 1)
    for i2 = 1:size(ANNsPerfRaw, 2)
        ANNsPerf{i1,i2}{:}(:,not(IndGdsMdls)) = [];
    end
end

if MltClss
    ANNsPerfMC     = ANNsPerfRawMC;
    ANNsPerfSummMC = ANNsPerfRawSummMC;
    for i1 = 1:size(ANNsPerfMC, 1)
        for i2 = 1:size(ANNsPerfMC, 2)
            ANNsPerfMC{i1,i2}{:}(:,not(IndGdsMdls))     = [];
            ANNsPerfSummMC{i1,i2}{:}(:,not(IndGdsMdls)) = [];
        end
    end
end

if CrssVal
    CrossModels   = CrossMdlsRaw(:,IndGdsMdls);
    CrossValidInd = CrossValIndRaw(:,IndGdsMdls);
    CrossTrainInd = CrossTrnIndRaw(:,IndGdsMdls);
    CrossValMSE   = CrossValMSERaw(:,IndGdsMdls);
    CrossTrnMSE   = CrossTrnMSERaw(:,IndGdsMdls);
    CrossTstMSE   = CrossTstMSERaw(:,IndGdsMdls);
    CrossValAUROC = CrossValAUCRaw(:,IndGdsMdls);
    CrossTrnAUROC = CrossTrnAUCRaw(:,IndGdsMdls);
    CrossTstAUROC = CrossTstAUCRaw(:,IndGdsMdls);
    CrossValAUCAv = AvCrossValAUCRaw(:,IndGdsMdls);
    CrossTrnAUCAv = AvCrossTrnAUCRaw(:,IndGdsMdls);
    CrossTstAUCAv = AvCrossTstAUCRaw(:,IndGdsMdls);
end
if NormVal
    NvTrnAUROC = NvTrnAUCRaw(:,IndGdsMdls);
    NvValAUROC = NvValAUCRaw(:,IndGdsMdls);
    NvTrnMSE   = NvTrnMSERaw(:,IndGdsMdls);
    NvValMSE   = NvValMSERaw(:,IndGdsMdls);
end
if MdlHist
    HistMdls     = HistMdlsRaw(:,IndGdsMdls);
    HistTrnMSE   = HistTrnMSERaw(:,IndGdsMdls);
    HistValMSE   = HistValMSERaw(:,IndGdsMdls);
    HistTstMSE   = HistTstMSERaw(:,IndGdsMdls);
    HistTrnAUROC = HistTrnAUCRaw(:,IndGdsMdls);
    HistValAUROC = HistValAUCRaw(:,IndGdsMdls);
    HistTstAUROC = HistTstAUCRaw(:,IndGdsMdls);
    HistTrnLoss  = HistTrnLossRaw(:,IndGdsMdls);
    HistValLoss  = HistValLossRaw(:,IndGdsMdls);
    HistTstLoss  = HistTstLossRaw(:,IndGdsMdls);
end

%% Creation of CrossInfo, NormInfo, and HistInfo structure
if CrssVal
    CrossInfo = struct('CrossType',ANNMode, 'Models',{CrossModels}, ...
                       'Indices',struct('Train',CrossTrainInd, 'Valid',CrossValidInd), ...
                       'MSE',struct('Train',CrossTrnMSE, 'Valid',CrossValMSE, 'Test',CrossTstMSE), ...
                       'AUROC',struct('Train',CrossTrnAUROC, 'Valid',CrossValAUROC, 'Test',CrossTstAUROC));
end

if NormVal
    ValidInfo = struct('ValidType',ANNMode, ...
                       'MSE',struct('Train',NvTrnMSE, 'Valid',NvValMSE), ...
                       'AUROC',struct('Train',NvTrnAUROC, 'Valid',NvValAUROC));
end

if MdlHist
    HistInfo = struct('HistType',ANNMode, 'Models',{HistMdls}, ...
                      'MSE',struct('Train',HistTrnMSE, 'Valid',HistValMSE, 'Test',HistTstMSE), ...
                      'AUROC',struct('Train',HistTrnAUROC, 'Valid',HistValAUROC, 'Test',HistTstAUROC), ...
                      'Loss',struct('Train',HistTrnLoss, 'Valid',HistValLoss, 'Test',HistTstLoss));
end

%% Creation of a folder where save model and future predictions
switch OutMode
    case '4 risk classes'
        NetType = '4RC';

    case 'L-NL classes'
        NetType = '2LC';

    case 'Regression'
        NetType = 'Reg';

    otherwise
        error('OutMode choice not recognized!')
end

switch ANNMode
    case 'Classic (L)'
        TrnType = 'Loss';

    case 'Classic (V)'
        TrnType = 'Val';

    case 'Cross Validation (K-Fold M)'
        TrnType = 'CrssM';

    case 'Cross Validation (K-Fold V)'
        TrnType = 'CrssV';

    case {'Deep (V)', 'Deep (L)'}
        TrnType = 'Deep';

    case 'Auto'
        TrnType = 'Auto';

    case 'Logistic Regression'
        TrnType = 'LR';

    case 'Sensitivity Analysis'
        TrnType = 'Sens';

    otherwise
        error('Train type not recognized!')
end

AcFnAbb = cell(1, numel(LayAct));
for i1 = 1:numel(LayAct)
    switch LayAct{i1}
        case 'sigmoid'
            AcFnAbb{i1} = 'Sigm';
    
        case 'relu'
            AcFnAbb{i1} = 'ReLU';
    
        case 'tanh'
            AcFnAbb{i1} = 'Tanh';

        case 'none'
            AcFnAbb{i1} = 'None';

        case 'elu'
            AcFnAbb{i1} = 'ELU';

        case 'gelu'
            AcFnAbb{i1} = 'GeLU';

        case 'softplus'
            AcFnAbb{i1} = 'Sft+';
    
        otherwise
            error('Layer activation function not recognized!')
    end
end

SuggFldNme = [NetType,'_',TrnType,'_',strjoin(unique(AcFnAbb), '_')];
MLFoldName = [char(inputdlg2({'Folder name (Results->ML Models and Predictions):'}, 'DefInp',{SuggFldNme}))];

fold_res_ml_curr = [fold_res_ml,sl,MLFoldName];

if exist(fold_res_ml_curr, 'dir')
    Options = {'Yes, thanks', 'No, for God!'};
    Answer  = uiconfirm(Fig, strcat(fold_res_ml_curr, " is an existing folder. Do you want to overwrite it?"), ...
                             'Existing ML Folder', 'Options',Options, 'DefaultOption',2);
    switch Answer
        case 'Yes, thanks.'
            rmdir(fold_res_ml_curr,'s')
            mkdir(fold_res_ml_curr)
        case 'No, for God!'
            fold_res_ml_curr = [fold_res_ml_curr,'-new'];
    end
else
    mkdir(fold_res_ml_curr)
end

%% Neural Network Saving
ProgressBar.Message = 'Saving files...';

VariablesML = {'ModelInfo', 'ANNs', 'ANNsRes', 'ANNsPerf'};
if CrssVal
    VariablesML = [VariablesML, {'CrossInfo'}];
end
if NormVal
    VariablesML = [VariablesML, {'ValidInfo'}];
end
if MdlHist
    VariablesML = [VariablesML, {'HistInfo' }];
end
if MltClss
    VariablesML = [VariablesML, {'ANNsPerfMC', 'ANNsPerfSummMC'}];
end

saveswitch([fold_res_ml_curr,sl,'ANNsMdlA.mat'], VariablesML)