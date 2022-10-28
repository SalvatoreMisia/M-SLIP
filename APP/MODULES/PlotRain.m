%% Loading
cd(fold_var)
load('StudyAreaVariables.mat')
load('GridCoordinates.mat')
load('AnalysisInformation.mat')
load('GeneralRainfall.mat')

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'Best';
end

%% Plot based on selection
switch RainFallType
    case 1
        filename2 = 'LocationRainGauges';
        f2 = figure(2);

        set(f2, ...
            'Color',[1 1 1], ...
            'PaperType','a4', ...
            'PaperSize',[29.68, 20.98 ], ...    
            'PaperUnits','centimeters', ...
            'PaperPositionMode','manual', ...
            'PaperPosition',[0 1 14 12], ...
            'InvertHardcopy','off');

        set(gcf, 'Name',filename2);
        
        scatter(RainGauges{2}(:,1), RainGauges{2}(:,2), '*k')
        hold on
        plot(StudyAreaPolygon, 'LineWidth',1, 'FaceColor',[255 64 64]./255, ...
                               'EdgeColor',[179 40 33]./255, 'FaceAlpha',0.3);
        
        for i1 = 1:size(dataInstationSelected,1)
            text(RainGauges{2}(i1,1)+.01, RainGauges{2}(i1,2), ...
                 strcat(RainGauges{1}(i1),'(',num2str(dataInstationSelected(i1)),')'), ...
                 'FontName',SelectedFont)
        end
        
        fig_settings(fold0)
    
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(f2, strcat(filename2,'.png'), 'Resolution',600);

    case 2
        ChoiceRecSta = listdlg('PromptString',{'Select the recording station :',''}, ...
                               'ListString',RainGauges{1});
    
        SelectedRecordingStation = RainGauges{1}(ChoiceRecSta);
    
        PosSelRecStation = find( arrayfun(@(x) strcmp(x,SelectedRecordingStation), RainGauges{1}) );
    
        filename1 = strcat('RecordedRainfall',SelectedRecordingStation);
        f1 = figure(1);

        set(f1, ...
            'Color',[1 1 1], ...
            'PaperType','a4', ...
            'PaperSize',[29.68 20.98 ], ...    
            'PaperUnits','centimeters', ...
            'PaperPositionMode','manual', ...
            'PaperPosition',[0 1 14 12], ...
            'InvertHardcopy','off');

        set(gcf, 'Name',filename1);

        yyaxis left
        bar(RainfallDates, GeneralRainData(PosSelRecStation,:), 'FaceColor',[0 127 255]./255);
        ylabel('{\it h_w} [mm]', 'FontName',SelectedFont)
    
        set(gca, ...
            'XLim',[min(RainfallDates), max(RainfallDates)], ...
            'YLim',[0, 9], ...
            'Box','on', ...
            'TickDir','in', ...
            'TickLength',[.01, .01], ...
            'XMinorTick','off', ...
            'YMinorTick','off', ...
            'XGrid','off', ...
            'YGrid','off', ...
            'XColor',[0, 0, 0], ...
            'YColor',[0, 127, 255]./255, ...
            'XTick',RainfallDates(1):days(5):RainfallDates(end), ...
            'FontSize',SelectedFontSize, ...
            'FontName',SelectedFont, ...
            'YTick',0:1:9, ...
            'LineWidth',.5)
    
        yyaxis right
        plot(RainfallDates, cumsum(GeneralRainData(PosSelRecStation,:)), 'k')
        ylabel('Cumulative [mm]', 'FontName',SelectedFont)
    
        daspect auto
        
        set(gca, ...
            'XLim',[min(RainfallDates) max(RainfallDates)], ...
            'YLim',[0 200], ...
            'Box','on', ...
            'TickDir','in', ...
            'TickLength',[.01 .01], ...
            'XMinorTick','off', ...
            'YMinorTick','off', ...
            'XGrid','off', ...
            'YGrid','off', ...
            'XColor',[0 0 0], ...
            'YColor',[0 0 0]./255, ...
            'XTick',RainfallDates(1):days(5):RainfallDates(end), ...
            'FontSize',10, ...
            'FontName',SelectedFont, ...
            'YTick',0:20:200, ...
            'LineWidth',.5)
    
        cd(fold_fig)
        exportgraphics(f1, strcat(filename1,'.png'), 'Resolution',600);
    
        if RainFallType==1
            load('RainInterpolated.mat')
            EventsInterpolated = RainfallDates(IndexInterpolation);
            IndPlot = listdlg('PromptString',{'Select event analysed to plot:',''}, ...
                              'ListString',EventsInterpolated);
            RainSelected = RainInterpolated(IndPlot,:);
            dataInstationSelected = GeneralRainData(:,(IndPlot+IndexInterpolation(1)-1));
            RainfallEvent = EventsInterpolated(IndPlot);
            RainfallEvent = strcat(string(RainfallEvent),'Rec');
        
        elseif RainFallType==0
            load('RainInterpolated.mat', 'SelectedHoursRun');
            ForecastRunUnique = unique([SelectedHoursRun{:,2}]);
        
            for i4=1:length(ForecastRunUnique)
                IndexForecastRun=cellfun(@(x) x==ForecastRunUnique(i4),SelectedHoursRun(:,2));
                IndexForecastInterpolated{i4}=unique([SelectedHoursRun{IndexForecastRun,1}]);
            end
    
            RunInterpolated=string(ForecastData(ForecastRunUnique));
            choice1=listdlg('PromptString',...
            {'Select the run time of the forcast model :',''},'ListString',RunInterpolated);
            RunSel=datetime(RunInterpolated(choice1),'Format','dd/MM/yyyy HH');
            RunSel=cellfun(@(x) x==RunSel,ForecastData(:,1));
            RunSel1=find(RunSel);
    
            EventsInterpolated = [ForecastData{RunSel,2}(IndexForecastInterpolated{(ForecastRunUnique==RunSel1)})];
        
            IndPlot = listdlg('PromptString',{'Select interpolated rainfall:',''}, ...
                              'ListString',EventsInterpolated);
        
            cd(fold_var_rain_for)
            load(strcat('RainForecastInterpolated',num2str(RunSel1)));
        
            RainSelected = RainForecastInterpolated(IndPlot,:);
            RainfallEvent = EventsInterpolated(IndPlot);
            RainfallEvent = strcat(string(RainfallEvent),'For');
        end
    
        rain_range=[1 1.5 2 2.5 3 4];
    
        xLongStudyArea=cell(size(xLongAll));
        yLatStudyArea=cell(size(xLongAll));
        RainStudyArea=cell(size(xLongAll));
        
        ColorRain=[228 229 224;
            171 189 227;
            169 200 244;
            48 127 226;
            0 0 255;
            18 10 143;
            19 41 75];
        
        for i1=1:size(xLongAll,2)
            
        xLongStudyArea{i1}=xLongAll{i1}(IndexDTMPointsInsideStudyArea{i1});
        yLatStudyArea{i1}=yLatAll{i1}(IndexDTMPointsInsideStudyArea{i1});
        % RainStudyArea{i1}=RainSelected{i1}(IndexDTMPointsInsideStudyArea{i1});
        
        Rain_range1{i1}=find(RainSelected{i1}<=rain_range(1));
        Rain_range2{i1}=find(RainSelected{i1}>rain_range(1) & RainSelected{i1}<=rain_range(2) );
        Rain_range3{i1}=find(RainSelected{i1}>rain_range(2) & RainSelected{i1}<=rain_range(3) );
        Rain_range4{i1}=find(RainSelected{i1}>rain_range(3) & RainSelected{i1}<=rain_range(4) );
        Rain_range5{i1}=find(RainSelected{i1}>rain_range(4) & RainSelected{i1}<=rain_range(5) );
        Rain_range6{i1}=find(RainSelected{i1}>rain_range(5) & RainSelected{i1}<=rain_range(6) );
        Rain_range7{i1}=find(RainSelected{i1}>=rain_range(6));
        
        end
        
        %%
        cd(fold0)
        filename1=strcat('Rain ',RainfallEvent);
        f1=figure(1);
        set(f1 , ...
            'Color',[1 1 1],...
            'PaperType','a4',...
            'PaperSize',[29.68 20.98 ],...    
            'PaperUnits', 'centimeters',...
            'PaperPositionMode','manual',...
            'PaperPosition', [0 1 14 12],...
            'InvertHardcopy','off');
        set( gcf ,'Name' , filename1);
        
        for i2=1:size(xLongAll,2)
        %for i2=1:1
        hrain1=scatter(xLongStudyArea{i2}(Rain_range1{i2}),yLatStudyArea{i2}(Rain_range1{i2}),.1,'o','MarkerFaceColor',ColorRain(1,:)./255,'MarkerEdgeColor','none');
        hold on
        hrain2=scatter(xLongStudyArea{i2}(Rain_range2{i2}),yLatStudyArea{i2}(Rain_range2{i2}),.1,'o','MarkerFaceColor',ColorRain(2,:)./255,'MarkerEdgeColor','none');
        hold on
        hrain3=scatter(xLongStudyArea{i2}(Rain_range3{i2}),yLatStudyArea{i2}(Rain_range3{i2}),.1,'o','MarkerFaceColor',ColorRain(3,:)./255,'MarkerEdgeColor','none');
        hold on
        hrain4=scatter(xLongStudyArea{i2}(Rain_range4{i2}),yLatStudyArea{i2}(Rain_range4{i2}),.1,'o','MarkerFaceColor',ColorRain(4,:)./255,'MarkerEdgeColor','none');
        hold on
        hrain5=scatter(xLongStudyArea{i2}(Rain_range5{i2}),yLatStudyArea{i2}(Rain_range5{i2}),.1,'o','MarkerFaceColor',ColorRain(5,:)./255,'MarkerEdgeColor','none');
        hold on
        hrain6=scatter(xLongStudyArea{i2}(Rain_range6{i2}),yLatStudyArea{i2}(Rain_range6{i2}),.1,'o','MarkerFaceColor',ColorRain(6,:)./255,'MarkerEdgeColor','none');
        hold on
        hrain7=scatter(xLongStudyArea{i2}(Rain_range7{i2}),yLatStudyArea{i2}(Rain_range7{i2}),.1,'o','MarkerFaceColor',ColorRain(7,:)./255,'MarkerEdgeColor','none');
        hold on
        end
        %scatter(Rain_Gauges{2}(:,1),Rain_Gauges{2}(:,2),'*k')
        hold on
        plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1.5)
        hold on
        
        hleg=legend([hrain1,hrain2,hrain3,hrain4,hrain5,hrain6,hrain7],...
            '< 1',...
            '1 - 1.5',...
            '1.5 - 2',...
            '2 - 2.5',...
            '2.5 - 3',...
            '3 - 4',...
            '> 4',...
            '> 60',...
            'NumColumns',2,...
            'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize);
        hleg.ItemTokenSize(1)=10;
        
        legend('AutoUpdate','off');
        legend boxoff
        
        title(hleg,'Rain [mm]','FontName',SelectedFont,'FontSize',SelectedFontSize*1.2,'FontWeight','bold')
    
        fig_settings(fold0)
        
        set(gca,'visible','off')
        cd(fold_fig)
        exportgraphics(f1,strcat(filename1,'.png'),'Resolution',600);
end