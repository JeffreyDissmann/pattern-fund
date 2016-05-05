
%TEST
startdate = datenum('2015-1-2');
enddate = datenum('2016-1-30');


Returnspts = arrayfun(@(MyS) MyS.DailypTS.daterange(startdate,enddate), MyStocks,'UniformOutput',false);
Returnspts{end+1} = DAX.DailypTS.daterange(startdate,enddate);
Returnspts_dates = cellfun(@(pts) pts.dates, Returnspts,'UniformOutput',false);
Returnspts_dates = cat(2,Returnspts_dates{:});
daterange = Returnspts_dates(:,1);

%All Dates equal?
all(all(Returnspts_dates == repmat(daterange,1,30)))


Returns = cellfun(@(pts) pt2Mat(pts.Return), Returnspts,'UniformOutput',false);
Returns = cat(2,Returns{:});

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

    %Cov Matrix
    ReturnsForCov = zeros(250,length(MyStocks)+1);
    last250days = DAX.DailypTS.dates;
    last250days = last250days(last250days <= mydate);
    last250days = last250days(end-249:end);

    ReturnsForCov = arrayfun(@(MyS) dateref(MyS.DailypTS.Return,last250days), MyStocks,'UniformOutput',false);
    ReturnsForCov{end+1} = dateref(DAX.DailypTS.Return,last250days);
    ReturnsForCov = cellfun(@(pts) pt2Mat(pts.Return), ReturnsForCov,'UniformOutput',false);
    ReturnsForCov = cat(2,ReturnsForCov{:});

    %Setup portfolio optimisation
    p = Portfolio('assetmean', returnPredictions, 'assetcovar', cov(ReturnsForCov), ...
    'lowerbound', -1, 'upperbound',1,'lowerbudget',0.9,'upperbudget',1.1);

    Investments1(i,:) = p.estimateFrontierByRisk(0.00);
    
    %when return prediction positive, go long
    p.LowerBound(returnPredictions > 0) = 0;
    p.UpperBound(returnPredictions < 0) = 0;

    Investments2(i,:) = p.estimateFrontierByRisk(0.00);

    %find low allocations
    p.LowerBound(abs(Investments2(i,:)) < 0.05) = 0;
    p.UpperBound(abs(Investments2(i,:)) < 0.05) = 0;
    
    Investments3(i,:) = p.estimateFrontierByRisk(0.00);
    

    
    InvReturn1(i) = Investments1(i,:) * Returns(i+1,:)';
    InvReturn2(i) = Investments2(i,:) * Returns(i+1,:)';
    InvReturn3(i) = Investments3(i,:) * Returns(i+1,:)';
    
    plot(daterange(1:i),cumprod(1+InvReturn1(1:i)));
    hold on;
    plot(daterange(1:i),cumprod(1+InvReturn2(1:i)));
    plot(daterange(1:i),cumprod(1+InvReturn3(1:i)));
    hold off;
    datetick(gca);
    legend('Investment 1', 'Investment 2', 'Investment 3');
    
    drawnow();
end


