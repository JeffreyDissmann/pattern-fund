classdef Stock < handle
    %STOCK Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        ticker = '';
        YahooDailyData = table();
        DailypTS = ptimeseries();
        DailypTSIndicator = ptimeseries();
        trainedClassifier = [];
    end
    
    methods
        function this = Stock(ticker,YahooDailyData)
            %Constructor
            
            %Ticker name
            this.ticker = ticker;
            
            %preload with Yahoo Daily Data
            this.YahooDailyData = YahooDailyData;
            
        end
        
        function updateYahooDailyData(this,endDate,startDate)        
            if nargin < 3
                startDate = datenum('1-1-2000','dd-mm-yyyy');
            end
            if nargin < 2
                endDate = now();
            end

            this.YahooDailyData = webread(['http://ichart.finance.yahoo.com/table.csv?',...
                                    sprintf('d=%d&e=%02d&f=%d',month(endDate)-1,[day(endDate),year(endDate)]),...
                                    '&g=d&',...
                                    sprintf('a=%d&b=%02d&c=%d',[month(startDate)-1,day(startDate),year(startDate)]),...
                                    '&ignore=.csv',...
                                    '&s=',this.ticker]);
        end
        
        function reduceDatesOfYahooDailyData(this,dates)
            olddates = datenum(this.YahooDailyData.Date,'yyyy-mm-dd');
            
            %check if all dates included
            ids = arrayfun(@(d) any(olddates == d),dates);
            
            %for each not included duplicate previous entry
            if ~all(ids)
                for notincludeddate = dates(~ids)
                    %find before and anfter
                    %afterdate = min(olddates(olddates > notincludeddate));
                    beforedate = max(olddates(olddates < notincludeddate));

                    %for now, set as before
                    ifbefore = find(olddates == beforedate);

                    %dublicate and change date
                    this.YahooDailyData = this.YahooDailyData([1:ifbefore,ifbefore,(ifbefore+1):end],:);
                    this.YahooDailyData.Date{ifbefore} = datestr(notincludeddate,'yyyy-mm-dd');

                    %Update dates
                    olddates = datenum(this.YahooDailyData.Date,'yyyy-mm-dd');
                end
            end
            
            %identify which rows corrospond to dates
            ids = arrayfun(@(d) find(olddates == d,1),dates);
            
            %reduce rows;
            this.YahooDailyData = this.YahooDailyData(ids,:);
            
        end
        
        function reduceNoVolumeDaysFromYahooDailyData(this)
            this.YahooDailyData = this.YahooDailyData(this.YahooDailyData.Volume ~= 0,:);
        end
        
        function convertYahooDailyData2timeseries(this)
            dates = datenum(this.YahooDailyData.Date,'yyyy-mm-dd');
            
            %create TS
            this.DailypTS = ptimeseries(dates,this.YahooDailyData(:,2:end),this.ticker,'daily');
                                
            %calculate Return
            Return = (this.DailypTS.AdjClose ./ lag(this.DailypTS.AdjClose,1)) - 1;
            Return = chVarName(Return,'AdjClose','Return');
            this.DailypTS = combineTS(this.DailypTS, Return);
            
        end 
        
        function calculateIndicators(this,MarketStockTS)
            
            %Reduce Market to my TS.
            MarketStockTS = MarketStockTS.reduceTodates(this.DailypTS.dates);
            
            %calculate market beta 60days
            Beta = trailingFunCombineFinTS(MarketStockTS.Return,this.DailypTS.Return,@tsBeta,60,'Beta_60Day');
            
            %calculate Beta adjusted Return
            BetaAdjustedReturn = this.DailypTS.Return - (MarketStockTS.Return .* lag(Beta.Beta_60Day,1));
            BetaAdjustedReturn = BetaAdjustedReturn.chVarName('Return','BetaAdjustedReturn');
            
            %Std
            Std25Day = BetaAdjustedReturn.trailingFunpTS(@std,25,'Std_25Day');
            Std250Day = BetaAdjustedReturn.trailingFunpTS(@std,250,'Std_250Day');
            
            Indicator_Std = Std25Day ./ Std250Day;
            Indicator_Std = Indicator_Std.chVarName('Std_25Day','Indicator_Std');
            
            %normalised return
            BetaAdjustedReturnNormalised = BetaAdjustedReturn ./ lag(Std25Day,1);
            BetaAdjustedReturnNormalised = chVarName(BetaAdjustedReturnNormalised,'BetaAdjustedReturn','BetaAdjustedReturnNormalised');
            
            BetaAdjustedReturnNormalised_l1 = chVarName(lag(BetaAdjustedReturnNormalised,1),'BetaAdjustedReturnNormalised','BetaAdjustedReturnNormalised_l1');
            BetaAdjustedReturnNormalised_l2 = chVarName(lag(BetaAdjustedReturnNormalised,2),'BetaAdjustedReturnNormalised','BetaAdjustedReturnNormalised_l2');
            BetaAdjustedReturnNormalised_l3 = chVarName(lag(BetaAdjustedReturnNormalised,3),'BetaAdjustedReturnNormalised','BetaAdjustedReturnNormalised_l3');
            BetaAdjustedReturnNormalised_l4 = chVarName(lag(BetaAdjustedReturnNormalised,4),'BetaAdjustedReturnNormalised','BetaAdjustedReturnNormalised_l4');

            %trading volume
            AverageVolume25Day = trailingFunpTS(this.DailypTS.Volume,@mean,25,'AverageVolume_25Day');
            AverageVolume250Day = trailingFunpTS(this.DailypTS.Volume,@mean,250,'AverageVolume_25Day');
            
            Indicator_AverageVolume = AverageVolume25Day ./ AverageVolume250Day;
            Indicator_AverageVolume = Indicator_AverageVolume.chVarName('AverageVolume_25Day','Indicator_AverageVolume');
            
            %daily trading band
            Indicator_DailyBand = (this.DailypTS.High - this.DailypTS.Low) ./ this.DailypTS.Open;
            Indicator_DailyBand = Indicator_DailyBand.chVarName('High','Indicator_DailyBand');


            %merge
            this.DailypTSIndicator = combineTS(Beta,...
                                    BetaAdjustedReturn,...
                                    BetaAdjustedReturnNormalised,...
                                    Std25Day,...
                                    Std250Day,...
                                    Indicator_Std,...
                                    Indicator_AverageVolume,...
                                    Indicator_DailyBand,... 
                                    BetaAdjustedReturnNormalised_l1,...
                                    BetaAdjustedReturnNormalised_l2,...
                                    BetaAdjustedReturnNormalised_l3,...
                                    BetaAdjustedReturnNormalised_l4);
                                
            this.DailypTSIndicator.Name = this.ticker;
            
        end
        
        function myTable = compileClassificationTable(this,startDate,endDate)
                
                subIndicators = this.DailyFinTSIndicator([datestr(startDate),'::',datestr(endDate)]);
                
                fn = fieldnames(subIndicators);
                
                myTable = array2table(fts2mat(subIndicators));
                myTable.Properties.VariableNames = fn(4:end)';
                
                ReturnCategories = cell(length(myTable.BetaAdjustedReturnNormalised),1);
%                 ReturnCategories( : ) = {'neutral'};
%                 ReturnCategories( myTable.BetaAdjustedReturnNormalised > 0.3)   = {'very positive'};
%                 ReturnCategories( myTable.BetaAdjustedReturnNormalised < -0.3)   = {'very negative'};
                
                ReturnCategories( myTable.BetaAdjustedReturnNormalised >= 0)    = {'positive'};
                ReturnCategories( myTable.BetaAdjustedReturnNormalised < 0)     = {'negative'};
                ReturnCategories( myTable.BetaAdjustedReturnNormalised > 0.5)   = {'very positive'};
                ReturnCategories( myTable.BetaAdjustedReturnNormalised < -0.5)  = {'very negative'};
                  
                ReturnCategories = categorical(ReturnCategories);                
                %summary(ReturnCategories)
                
                
                myTable = [myTable,table(ReturnCategories)];
                
        end
        
        function trainedClassifier = trainClassifier(this, useDataUpToDate)

            useDataUpToDate = datenum(useDataUpToDate);
            
                                                        
            subIndicators = this.DailypTSIndicator(this.DailypTSIndicator.dates <= useDataUpToDate);

%             ReturnCategories = cell(length(subIndicators.BetaAdjustedReturnNormalised),1);
% 
%             barn = fts2mat(subIndicators.BetaAdjustedReturnNormalised);
%             ReturnCategories( barn >= 0)    = {'positive'};
%             ReturnCategories( barn < 0)     = {'negative'};
%             ReturnCategories( barn > 0.5)   = {'very positive'};
%             ReturnCategories( barn < -0.5)  = {'very negative'};
% 
%             ReturnCategories = categorical(ReturnCategories);    
% 

            predictor_names = varnames(subIndicators);
            predictors = pt2Mat(subIndicators);
            predictors = predictors(1:end-1,:);
            
            response = pt2Mat(subIndicators.BetaAdjustedReturnNormalised);
            response = response(2:end);
            
            %filter out where predictors or responses are NaN
            isN = isnan(response) | any(isnan(predictors),2);
            
            disp([this.ticker ': Filter responses and predictors for NaNs.',sprintf('\n'),...
                repmat(' ',1,length(this.ticker)) '  Only  ' num2str(length(response)-sum(isN)) ' / ' num2str(length(response)) ' valid data points.']);

            response = response(~isN);
            predictors = predictors(~isN,:);
            
            
            % Train a classifier
            %trainedClassifier = fitctree(predictors, response, 'PredictorNames', predictor_names, 'ResponseName', 'ReturnCategories', 'ClassNames', categorical({'negative' 'positive' 'very negative' 'very positive'}), 'SplitCriterion', 'deviance', 'MaxNumSplits', 50, 'Surrogate', 'off');
            trainedClassifier = fitrtree(predictors, response, 'PredictorNames', predictor_names, 'ResponseName', 'BetaAdjustedReturnNormalised', 'MaxNumSplits', 50, 'Surrogate', 'off');
            this.trainedClassifier = trainedClassifier;

        end
        
        function [pReturn,pBetaAdjustedReturnNormalised] = predict(this,mydate)
                        
            predictors = pt2Mat(this.DailypTSIndicator.dateref(mydate));
            pBetaAdjustedReturnNormalised = this.trainedClassifier.predict(predictors);
            
            %Assumes Market Return = 0
            pReturn = pBetaAdjustedReturnNormalised .* pt2Mat(dateref(this.DailypTSIndicator.Std_25Day,mydate));
                        
        end
        
        
    end
    
end

