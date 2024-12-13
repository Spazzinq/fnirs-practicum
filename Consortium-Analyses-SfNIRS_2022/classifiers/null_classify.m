function [classification, comparisons] = null_classify(train_data, train_labels, test_data, test_labels, opts)
%% wrapper for NULL classification
% takes in training data, training labels, testing data, testing labels and
% an opts struct with parameters for classification
% outputs the classification results and the test labels for comparison

%% determine if we use pairwise comparisons
if ~exist('opts','var') || ~isfield(opts, 'pairwise') || isempty(opts)
    pairwise = false;
else
    pairwise = opts.pairwise;
    opts = rmfield(opts,'pairwise');
end

if ~exist('pairwise','var')
    pairwise = false;
end

%% parse out the classification parameters
input = parse_opts(opts);

%% if pairwise classification
if pairwise
    
    % set up some parameters for our compairison loop
    number_classes = length(unique(train_labels));
    class_names = unique(train_labels);
    class_count = sum(strcmp(test_labels, class_names{1}));
    list_of_comparisons = combnk([1:number_classes],2);
    number_of_comparisons = size(list_of_comparisons,1);
    results_of_comparisons = cell((class_count*2), 2, number_of_comparisons);
    
    for this_comp = 1:number_of_comparisons
        
        % figure out what classes we need to keep for this round of
        % comparisons
        test_classes = list_of_comparisons(this_comp,:);
        test_class_names = class_names(test_classes);
        
        % select just the rows of the training data and labels that we will
        % need for this comparison
        train_dat = [train_data(strcmp(train_labels,test_class_names(1)),:);...
            train_data(strcmp(train_labels,test_class_names(2)),:)];
        train_labs = [train_labels(strcmp(train_labels,test_class_names(1)));...
            train_labels(strcmp(train_labels,test_class_names(2)))];
        
        
        % select just the rows of the test data and labels that we will
        % need for this comparison
        test_dat = [test_data(strcmp(test_labels,test_class_names(1)),:);...
            test_data(strcmp(test_labels,test_class_names(2)),:)];
        test_labs = [test_labels(strcmp(test_labels,test_class_names(1)));...
            test_labels(strcmp(test_labels,test_class_names(2)))];
        
        %% Classifier training goes here
        % example: knn_model = fitcknn(train_dat, train_labs, input{:});
        
        %% Classifier testing goes here
        % example: classification = predict(knn_model, test_dat);
        
        % THIS IS A PLACEHOLDER THAT REPRODUCES THE TEST LABELS
        classification = test_labs;
        % THIS IS A PLACEHOLDER THAT REPRODUCES THE TEST LABELS
        
        % Save the predicted labels (`classification`) to first column
        results_of_comparisons(:,1, this_comp) = classification;
        % Save the true test labels (`test_labs`) to second column
        results_of_comparisons(:,2, this_comp) = test_labs;
    end
    comparisons = list_of_comparisons;
    classification = results_of_comparisons;
    
%% if not pairwise classification
else
    %% Classifier training goes here
    % example: knn_model = fitcknn(train_data, train_labels, input{:});
    
    %% Classifier testing goes here
    % example: classification = predict(knn_model, test_data);
    
    % THIS IS A PLACEHOLDER THAT REPRODUCES THE TEST LABELS
    classification = test_labels;
    % THIS IS A PLACEHOLDER THAT REPRODUCES THE TEST LABELS
    
    comparisons = test_labels;
end

end
