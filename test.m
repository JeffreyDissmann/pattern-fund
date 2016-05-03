
%TEST
startdate = datenum('2015-1-2');
enddate = datenum('2016-1-30');


range = [datestr(startdate),'::',datestr(enddate)];
subIndicators = DAX.DailyFinTSIndicator(range);
daterange = subIndicators.dates;

ReturnFinTS = arrayfun(@(MyS) MyS.DailyFinTS.Return, MyStocks,'UniformOutput',false);
ReturnFinTS = [ReturnFinTS{:},DAX.DailyFinTS.Return];

Returns = fts2mat(ReturnFinTS(datestr(daterange)));

%Investments
Investments1 = zeros(length(daterange),length(MyStocks)+1);
InvReturn1 = zeros(length(daterange),1);
Investments2 = zeros(length(daterange),length(MyStocks)+1);
InvReturn2 = zeros(length(daterange),1);
Investments3 = zeros(length(daterange),length(MyStocks)+1);
InvReturn3 = zeros(length(daterange),1);

%mydate = daterange(1);
for i = 1:length(daterange)
    
    mydate = daterange(i);
    datestr(mydate)
    
    %predict returns
    returnPredictions = arrayfun(@(myS) myS.predict(mydate),MyStocks);

    %lastReturn = 0 for DAX
    returnPredictions(end+1) = 0;
    returnPredictions(:) = 0;

    %Cov Matrix
    ReturnsForCov = zeros(250,length(MyStocks)+1);
    last250days = DAX.DailyFinTS.dates;
    last250days = last250days(last250days <= mydate);
    last250days = last250days(end-249:end);

    ReturnsForCov = fts2mat(ReturnFinTS(datestr(last250days)));

    %Setup portfolio optimisation
    p = Portfolio('assetmean', returnPredictions, 'assetcovar', cov(ReturnsForCov), ...
    'lowerbound', -1, 'upperbound',1,'lowerbudget',0.9,'upperbudget',1.1);

    Investments1(i,:) = p.estimateFrontierByRisk(0.00);
    %Investments3(i,:) = p.estimateFrontierByReturn(0.005);

    %find low allocations
    p.LowerBound(abs(Investments1(i,:)) < 0.05) = 0;
    p.UpperBound(abs(Investments1(i,:)) < 0.05) = 0;
    
    Investments2(i,:) = p.estimateFrontierByRisk(0.00);
    

    
    InvReturn1(i) = Investments1(i,:) * Returns(i+1,:)';
    InvReturn2(i) = Investments2(i,:) * Returns(i+1,:)';
    %InvReturn3(i) = Investments3(i,:) * Returns(i+1,:)';
    
    plot(daterange(1:i),cumprod(1+InvReturn1(1:i)));
    hold on;
    plot(daterange(1:i),cumprod(1+InvReturn2(1:i)));
    %plot(daterange(1:i),cumprod(1+InvReturn3(1:i)));
    hold off;
    datetick(gca);
    
    drawnow();
end


