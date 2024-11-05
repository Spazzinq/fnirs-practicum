function [classification, comparisons] = mcpa_classify(model_data, model_labels, test_data, test_labels, opts)
%% mcpa_classify implements a correlation-based, channel-space classifier
% following Emberson, Zinszer, Raizada & Aslin's (2017, PLoS One) method
% and extending this approach to multiple conditions (>2). The MCPA
% approach treats channels as features and compares the correlation
% coefficients between classes in the training data (averaged across all
% examples) and instances in the test data.
%
% Correlation statistic (pearson, spearman, or kendall) may be selected
% using opts.corr_stat, e.g., opts.corr_stat='pearson'
%
% In 'non-exclusive' mode (the default), classification decisions are based
% simply on the greatest Fisher-adjusted correlation between test instance
% and classes in training set.
% In 'exclusive' mode (opts.exclusive=true), the pairwise matches between
% test classes are training classes are optimized for greatest sum of
% Fisher-adjusted correlations.
%
% If opts.tiebreak is set to true (default), the correlation coefficients
% are adjusted by <1% of the smallest observed difference to prevent exact
% matches and thus prevent ties in the classification. If opts.tiebreak is
% set to false, the classifier will prefer classes appearing earlier in the
% training set.
%
% All-possible-pairwise comparison (opts.pairwise) is under development

%% Pull a list of all the unique classes / conditions, preserving order
model_classes = unique(model_labels,'stable');

%% check to see the orders of test and train data - this is to see if they match
% this is necessary for nfold_generalize

%[~,train_order] = sort(model_labels);
[~,train_order] = sort(model_labels(:));
[~,test_order] = sort(test_labels);

%% sort test data based on the re-ordered data
test_labs = test_labels(test_order);
test_dat = test_data(test_order, :);

model_labs = model_labels(train_order);
model_dat = model_data(train_order, :);


%% Average across training data to get model features for each class
model_patterns = nan(size(model_dat,2),length(model_classes));
test_patterns = nan(length(model_classes), size(test_dat,2));
for class_idx = 1:length(model_classes)
    model_patterns(:,class_idx) = nanmean(model_dat(strcmp(model_classes{class_idx},model_labs),:),1)';
    test_patterns(class_idx,:) = nanmean(test_dat(strcmp(model_classes{class_idx}, test_labs),:),1);
end

test_dat= test_patterns;

%% Perform correlation (default: Pearson) between all model patterns and the test patterns
% This is a quick and easy way to compute all the test items at once.

% 1. Build a matrix with [ModelA, ModelB,... ModelN, Test1, Test2,... TestN]
% 2. Run correlation over all of them, and get a the matrix of corr coeffs.
% 3. First column is Model A vs. all others, Second column is Model B vs.
%	all others, nth column is Model N vs. all others.
if strcmp(opts.comparison_type, 'correlation')
    comparison_matrix = atanh(corr([model_patterns,test_dat'],'type',opts.metric,'rows','pairwise'));
else
    comparison_matrix = squareform(pdist([model_patterns,test_dat']', opts.metric)); 
end
    
%% Save out the classification results based on greatest correlation coefficient for each test pattern
% Initialize empty cell matrix for classifications
classification = cell(size(test_dat,1),1);

if opts.exclusive && length(model_classes)==size(test_dat,1) && ~opts.pairwise 
    %% case for exclusive labels
    % wherein each class can only be assigned to one row of test data
    % (e.g., at Participant level when you are looking at
    % condition-averaged data, and only one pattern per condition)
    % only works for 2 categories
    
    % Isolate the columns representing the model_patterns, and the rows
    % representing the test_data to get the correlations for each item
    % in test data against all the model patterns.
    if sum(isnan(test_dat(:)))==numel(test_dat) 
        comparisons = test_labels;
        classification = cell(size(test_labels));
        classification(:) = {NaN};
        
        disp('\nOne or both input matrices contains all NaN values. I quit!');
        return
    end
    
    test_model_corrs = comparison_matrix(length(model_classes)+1:end,1:length(model_classes));

    if size(test_model_corrs,1)==2 && strcmp(opts.comparison_type, 'correlation')
        if trace(test_model_corrs) > trace(rot90(test_model_corrs))
            classification(1) = model_classes(1);
            classification(2) = model_classes(2);
        elseif trace(test_model_corrs) < trace(rot90(test_model_corrs))
            classification(1) = model_classes(2);
            classification(2) = model_classes(1);
        else
            % If both options are equal, randomly assign the two labels to
            % the two observations.
            if ~isfield(opts,'tiebreak') || opts.tiebreak
                order = randperm(2); % returns [1 2] or [2 1] with equal probability
                classification(1) = model_classes(order(1));
                classification(2) = model_classes(order(2));
            else
                classification(1) = model_classes(1);
                classification(2) = model_classes(2);
            end
        end
    elseif size(test_model_corrs,1)==2 && strcmp(opts.comparison_type, 'distance')
        if trace(test_model_corrs) < trace(rot90(test_model_corrs))
            classification(1) = model_classes(1);
            classification(2) = model_classes(2);
        elseif trace(test_model_corrs) > trace(rot90(test_model_corrs))
            classification(1) = model_classes(2);
            classification(2) = model_classes(1);
        else
            % If both options are equal, randomly assign the two labels to
            % the two observations.
            if ~isfield(opts,'tiebreak') || opts.tiebreak
                order = randperm(2); % returns [1 2] or [2 1] with equal probability
                classification(1) = model_classes(order(1));
                classification(2) = model_classes(order(2));
            else
                classification(1) = model_classes(1);
                classification(2) = model_classes(2);
            end
        end        
    else
        % The search-all-label-permutations method would work here for 3 to
        % 10 classes, but the search space becomes too large after 10.
        disp('Currently no method for exclusive labeling with >2 test cases');
    end
    
    comparisons = test_labels;
elseif opts.exclusive && length(model_classes)==size(test_dat,1) && opts.pairwise 
    %% case for pairwise classification
    % works for multiple classes
    
    number_classes = length(model_classes);

    % Generate a list of every pairwise comparison and the results array
    list_of_comparisons = combnk([1:number_classes],2);
    number_of_comparisons = size(list_of_comparisons,1);
    results_of_comparisons = cell(2, 2, number_of_comparisons);
    
    if sum(isnan(test_dat(:)))==numel(test_dat) 
        results_of_comparisons(:) = {NaN};
        comparisons = list_of_comparisons;
        classification = results_of_comparisons;
        
        disp('\nOne or both input matrices contains all NaN values. I quit!');
        return
    end

    for this_comp = 1:number_of_comparisons
        test_classes = list_of_comparisons(this_comp,:);

        test_model_corrs = comparison_matrix(length(model_classes)+test_classes,test_classes);

        if strcmp(opts.comparison_type, 'correlation')
            if trace(test_model_corrs) > trace(rot90(test_model_corrs))
                classification(1) = model_classes(test_classes(1));
                classification(2) = model_classes(test_classes(2));
            elseif trace(test_model_corrs) < trace(rot90(test_model_corrs))
                classification(1) = model_classes(test_classes(2));
                classification(2) = model_classes(test_classes(1));
            else
                % If both options are equal, randomly assign the two labels to
                % the two observations.
                if ~isfield(opts,'tiebreak') || opts.tiebreak
                    disp('tiebreak')
                    order = randperm(2); % returns [1 2] or [2 1] with equal probability
                    classification(1) = model_classes(test_classes(order(1)));
                    classification(2) = model_classes(test_classes(order(2)));
                else
                    classification(1) = model_classes(test_classes(1));
                    classification(2) = model_classes(test_classes(2));
                end
            end
        elseif strcmp(opts.comparison_type, 'distance')
            if trace(test_model_corrs) < trace(rot90(test_model_corrs))
                classification(1) = model_classes(test_classes(1));
                classification(2) = model_classes(test_classes(2));
            elseif trace(test_model_corrs) > trace(rot90(test_model_corrs))
                classification(1) = model_classes(test_classes(2));
                classification(2) = model_classes(test_classes(1));
            else
                % If both options are equal, randomly assign the two labels to
                % the two observations.
                if ~isfield(opts,'tiebreak') || opts.tiebreak
                    order = randperm(2); % returns [1 2] or [2 1] with equal probability
                    classification(1) = model_classes(test_classes(order(1)));
                    classification(2) = model_classes(test_classes(order(2)));
                else
                    classification(1) = model_classes(test_classes(1));
                    classification(2) = model_classes(test_classes(2));
                end
            end
        end
        results_of_comparisons(1,1,this_comp) = classification(1);
        results_of_comparisons(2,1,this_comp) = classification(2);
        results_of_comparisons(1,2,this_comp) = model_classes(test_classes(1));
        results_of_comparisons(2,2,this_comp) = model_classes(test_classes(2));
    end

    comparisons = list_of_comparisons;
    classification = results_of_comparisons;

    
else
    %% case for n-way classification (not all-possible-pairwise)
    % works for more than 2 classes
    
    if ~isfield(opts,'pairwise') || opts.pairwise==false
        test_model_corrs = comparison_matrix(length(model_classes)+1:end,1:length(model_classes));
        % Adjust all values in test_model_corrs by <1% of the smallest
        % observed difference to prevent ties (randomly adjusts matched
        % values by tiny amount not relevant to classification).
        diffs = diff(sort(test_model_corrs(:)));
        min_diff = min(diffs(diffs>0));
        if isempty(min_diff), min_diff = min(test_model_corrs(:)); end
        test_model_corrs = test_model_corrs + rand(size(test_model_corrs))*min_diff/100;
        
        % Classify based on the maximum correlation
        [~, test_class_idx] = max(test_model_corrs,[],2);
        classification = model_classes(test_class_idx);
        
    end
    % put the labels back in the order they were put in as
    [~,reorder_test] = sort(test_order);
    classification = classification(reorder_test);
    
    comparisons = 1:length(test_labels);
end
