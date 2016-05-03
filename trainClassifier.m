function [trainedClassifier, validationAccuracy] = trainClassifier(datasetTable)
% Extract predictors and response
predictorNames = {'Indicator_Std', 'Indicator_AverageVolume', 'Indicator_DailyBand', 'BetaAdjustedReturnNormalised_l1', 'BetaAdjustedReturnNormalised_l2', 'BetaAdjustedReturnNormalised_l3'};
predictors = datasetTable(:,predictorNames);
predictors = table2array(varfun(@double, predictors));
response = datasetTable.ReturnCategories;
% Train a classifier
template = templateSVM('KernelFunction', 'gaussian', 'PolynomialOrder', [], 'KernelScale', 2.400000e+00, 'BoxConstraint', 1, 'Standardize', 1);
trainedClassifier = fitcecoc(predictors, response, 'Learners', template, 'Coding', 'onevsone', 'PredictorNames', {'Indicator_Std' 'Indicator_AverageVolume' 'Indicator_DailyBand' 'BetaAdjustedReturnNormalised_l1' 'BetaAdjustedReturnNormalised_l2' 'BetaAdjustedReturnNormalised_l3'}, 'ResponseName', 'ReturnCategories', 'ClassNames', categorical({'negative' 'positive' 'very negative' 'very positive'}));

% Set up holdout validation
cvp = cvpartition(response, 'Holdout', 0.25);
trainingPredictors = predictors(cvp.training,:);
trainingResponse = response(cvp.training,:);

% Train a classifier
template = templateSVM('KernelFunction', 'gaussian', 'PolynomialOrder', [], 'KernelScale', 2.400000e+00, 'BoxConstraint', 1, 'Standardize', 1);
validationModel = fitcecoc(trainingPredictors, trainingResponse, 'Learners', template, 'Coding', 'onevsone', 'PredictorNames', {'Indicator_Std' 'Indicator_AverageVolume' 'Indicator_DailyBand' 'BetaAdjustedReturnNormalised_l1' 'BetaAdjustedReturnNormalised_l2' 'BetaAdjustedReturnNormalised_l3'}, 'ResponseName', 'ReturnCategories', 'ClassNames', categorical({'negative' 'positive' 'very negative' 'very positive'}));

% Compute validation accuracy
validationPredictors = predictors(cvp.test,:);
validationResponse = response(cvp.test,:);
validationAccuracy = 1 - loss(validationModel, validationPredictors, validationResponse, 'LossFun', 'ClassifError');

%% Uncomment this section to compute validation predictions and scores:
% % Compute validation predictions and scores
% [validationPredictions, validationScores] = predict(validationModel, validationPredictors);