function beta = tsBeta(ts_market,ts_stock)
    beta = corr(ts_market,ts_stock) * std(ts_stock) / std(ts_market);
end