clc;
clear;

%http://www.financialwisdomforum.org/gummy-stuff/Yahoo-data.htm
load('yahoodata.mat');

startDate = datenum('1-1-2010','dd-mm-yyyy');
endDate = datenum('31-03-2016','dd-mm-yyyy');

nStocks = length(ticker);
MyStocks = Stock.empty(nStocks,0);

for i = 1:nStocks
    MyStocks(i) = Stock(ticker{i},data{i});
end

%Remove young stocks from sample
MyStocks(30) = [];

%First Entry is Dax
DAX = MyStocks(1);

%Remove DAX
MyStocks = MyStocks(2:end);
nStocks = length(MyStocks);



%Reduce time points
DAX.convertYahooDailyData2timeseries();   
for i = 1:nStocks
    MyStocks(i).reduceNoVolumeDaysFromYahooDailyData();
    MyStocks(i).convertYahooDailyData2timeseries();   
    MyStocks(i).calculateIndicators(DAX.DailypTS)
end



%Train models
for i = 1:nStocks
    MyStocks(i).trainClassifier(datenum('2014-12-31'));
end


