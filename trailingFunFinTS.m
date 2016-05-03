function trailingTS = trailingFunFinTS(fun,ts,interval,name)

    %convert to array
    tsmat = fts2mat(ts);

    %calculate statistic
    trailingTS = arrayfun(@(i) fun(tsmat((end-interval+1-i+1):(end-i+1))), (length(ts)-interval+1):-1:1)';
    
    %form ts
    trailingTS = fints(ts.dates(interval:end), trailingTS, {name}, ts.freq);
    
end
