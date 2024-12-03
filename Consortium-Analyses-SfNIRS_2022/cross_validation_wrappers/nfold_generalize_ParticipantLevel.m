function allsubj_results = nfold_generalize_ParticipantLevel(MCP_struct,varargin)
%% nfold_generalize_ParticipantLevel takes an MCP struct and performs
% n-fold cross-validation for n subjects to classify individual
% participants' average response patterns to NOVEL stimuli. Training data
% are obtained from n-1 leftout participants and using *only the non-test*
% marker types for a given category. Test set data are the
% non-intersecting set of marker types in the left-out participant. This
% test is for generalization of a superordinate category.
%
% Example: Category A (m1, m2) vs. Category B (m3, m4)
% Training set will be CatA(m1) vs. CatB(m3) from n-1 participants
% Test set will be CatA(m2) vs. CatB(m4) from the nth participant
% After each such n-fold procedure, the marker types can be re-shuffled
% between training and test sets.

% Like nfold_classify_ParticipantLevel, this wrapper also assumes that
% features will be averaged within-participants to produce a single
% participant-level observation. Thus the training set is constrained to
% the number of participants minus 1. Several parameters can be changed,
% including which functions are used to generate features and what
% classifier is trained. See Arguments below:
%
% Arguments:
% MCP_struct: either an MCP-formatted struct or the path to a Matlab file
% (.mat or .mcp) containing the MCP_struct.
% incl_features: features to include in the analysis. Default: all features
% incl_subjects: index of participants to include. Default: all participants
% time_window: [onset, offset] in seconds. Default [2,6]
% conditions: cell array of condition names / trigger #s. Default: {1,2}
% summary_handle: function handle (or char of function name) to specify how
% time-x-feature data should be summarized into features. Default: nanmean
% setsize: number of features to analyze (for subset analyses) Default: all
% test_handle: function handle for classifier. Default: mcpa_classify
% cond_key: c-x-2 cell array matching conditions to superordinate groups
% test_marks: marks to be held out of the training set, used for test set
% opts_struct: contains additional classifier options. Default: empty struct
% verbose: logical flag to report status updates and results. Default: true

%% Load MCP struct if necessary
if isstring(MCP_struct) || ischar(MCP_struct)
    MCP_struct = load(MCP_struct,'-mat');
    varname = fieldnames(MCP_struct);
    MCP_struct = eval(['MCP_struct.' varname{1}]);
end

%% if data has already been summarized, leave as is. Otherwise, setup MCPA data and summarize it
if ~any(cellfun(@(x) strcmp(x, 'results_struct'), varargin(find(rem(1:length(varargin), 2)))))
    allsubj_results = varargin{2};
    
else
    allsubj_results = setup_MCPA_data(MCP_struct,varargin);
end

%% Prep some basic parameters
n_subj = length(allsubj_results.incl_subjects);
n_sets = size(allsubj_results.subsets,1);
n_feature = length(allsubj_results.incl_features);
% n_events = max(arrayfun(@(x) max(sum(x.fNIRS_Data.Onsets_Matrix)),MCP_struct));
n_cond = length(unique(allsubj_results.conditions));
groups = unique(allsubj_results.cond_key(:,2));
n_group = length(groups);

allsubj_results.groups = groups;


% This renames the conditions for the accuracy field - currently create_results_struct operates as
% though we're using all the conditions so it labels the accuracy fields as
% baby 1, baby 2, etc. when we really want baby, bottle, etc.
for group_id = 1:n_group
    allsubj_results.accuracy(group_id).condition = allsubj_results.groups(group_id);
end


%% Begin the n-fold process: Select one test subj at a time from MCPA struct
for s_idx = 1:n_subj
    if allsubj_results.verbose
        fprintf('Running %g feature subsets for Subject %g / %g',n_sets,s_idx,n_subj);
    end
    tic
    
    %% Run over feature subsets
    temp_set_results_cond = nan(n_group,n_sets,n_feature);
    
    if isempty(allsubj_results.test_marks)
        % If the marks to use in test set are not already specified,
        % then throw an error and quit. TO DO: throw an warning instead
        % and randomly select half of each superordinate category.
        error('Please specify ''test_marks''');
    else
        % If the condition names to use in the test are specified,
        % then create the list of superordinate groups
        % (event_groups), the test conditions (test_events), and
        % the training conditions (train_events)
        allsubj_results.event_groups = cellfun(@(x) allsubj_results.cond_key{strcmp(x,allsubj_results.cond_key(:,1)),2},allsubj_results.event_types, 'UniformOutput',false);
        allsubj_results.test_events = cellfun(@(x) any(strcmp(x,allsubj_results.test_marks)),allsubj_results.event_types);
        allsubj_results.train_events = cellfun(@(x) all(~strcmp(x,allsubj_results.test_marks)),allsubj_results.event_types);
    end
    
    
    %% Folding & Dispatcher: Here's the important part
    % Right now, the data have to be treated differently for 2
    % conditions vs. many conditions. In MCPA this is because 2
    % conditions can only be compared in feature space (or, hopefully,
    % MNI space some day). If there are a sufficient number of
    % conditions (6ish or more), we abstract away from feature space
    % using RSA methods. Then classifier is trained/tested on the RSA
    % structures. This works for our previous MCPA studies, but might
    % not be appropriate for other classifiers (like SVM).
    
    [group_data, group_labels, subj_data, subj_labels] = split_test_and_train(s_idx,...
        allsubj_results.conditions,...
        allsubj_results.patterns,...
        allsubj_results.event_groups,...
        allsubj_results.final_dimensions,...
        allsubj_results.dimensions,...
        allsubj_results.test_events,...
        allsubj_results.train_events);
    
    % permute the group labels if significance testing 
    if allsubj_results.permutation_test
        num_labels = length(group_labels);
        permuted_idx = randperm(num_labels)';
        group_labels = group_labels(permuted_idx);
    end
    
    for set_idx = 1:n_sets
        %% Progress reporting bit (not important to function. just sanity)
        % Report at every 5% progress
        if allsubj_results.verbose
            status_jump = floor(n_sets/20);
            if ~mod(set_idx,status_jump)
                fprintf(' .')
            end
        end
        % Select the features for this subset
        set_features = allsubj_results.subsets(set_idx,:);
        
        %% classify
        % call differently based on if we do RSA or not
        % if we do pairwise comparison, the result test_labels will be a 3d
        % matrix with the dimensions: predicted label x correct label x
        % index of comparison. The output 'comparisons' will be the
        % conditions that were compared and can either be a 2d cell array or a
        % matrix of integers. If we don't do pairwise comparisons, the
        % output 'test_labels' will be a 1d cell array of predicted labels.
        % The output 'comparisons' will be a 1d array of the correct
        % labels.
        
        % RSA
        if strcmp(func2str(allsubj_results.test_handle),'rsa_classify')
            [test_labels, comparisons] = allsubj_results.test_handle(...
                group_data(:,set_features,:,:), ...
                group_labels,...
                subj_data(:,set_features,:),...
                subj_labels,...
                allsubj_results.opts_struct);
            
        else
%             if any(strcmp('incl_sessions',varargin))
%                 error('incl_sessions parameter not available for non-rsa classifiers at this moment.');
%             end
            [test_labels, comparisons] = allsubj_results.test_handle(...
                group_data(:,set_features), ...
                group_labels,...
                subj_data(:,set_features),...
                subj_labels,...
                allsubj_results.opts_struct);
        end
        
        %% Compare the labels output by the classifier to the known labels
        if size(test_labels,2) > 1 % test labels will be a column vector if we don't do pairwise
            
            if s_idx==1 && set_idx == 1, allsubj_results.accuracy_matrix = nan(n_cond,n_cond,min(n_sets,allsubj_results.max_sets),n_subj); end
            
            if iscell(comparisons)
                subj_acc = nanmean(strcmp(test_labels(:,1,:), test_labels(:,2,:)));
                comparisons = cellfun(@(x) find(strcmp(x,unique(allsubj_results.event_groups))),comparisons);
            else
                subj_acc = nanmean(strcmp(test_labels(:,1,:), test_labels(:,2,:)));
            end
            
            for comp = 1:size(comparisons,1)
                if size(comparisons,2)==1
                    allsubj_results.accuracy_matrix(comparisons(comp,1),:,set_idx,s_idx) = subj_acc(comp);
                else
                    allsubj_results.accuracy_matrix(comparisons(comp,1),comparisons(comp,2),set_idx,s_idx) = subj_acc(comp);
                end
            end
            
        else
            for group_idx = 1:n_group
                temp_acc = cellfun(@strcmp,...
                    subj_labels(strcmp(string(groups{group_idx}),subj_labels)),... % known labels
                    test_labels(strcmp(string(groups{group_idx}),subj_labels))...% classifier labels
                    );
                
                temp_set_results_cond(group_idx,set_idx,set_features) = nanmean(temp_acc);
            end
            for group_idx = 1:n_group
                allsubj_results.accuracy(group_idx).subsetXsubj(:,s_idx) = nanmean(temp_set_results_cond(group_idx,:,:),3);
                allsubj_results.accuracy(group_idx).subjXfeature(s_idx,:) = nanmean(temp_set_results_cond(group_idx,:,:),2);
            end
        end
        
    end %set_idx loop
    %% Progress reporting
    if allsubj_results.verbose
        fprintf(' %0.1f mins\n',toc/60);
    end
end % s_idx loop

%% Visualization
if allsubj_results.verbose
    if n_sets > 1 && length(allsubj_results.conditions)==2
        
        figure
        errorbar(1:size(allsubj_results.accuracy.cond1.subjXfeature,2),mean(allsubj_results.accuracy.cond1.subjXfeature),std(allsubj_results.accuracy.cond1.subjXfeature)/sqrt(size(allsubj_results.accuracy.cond1.subjXfeature,1)),'r')
        hold;
        errorbar(1:size(allsubj_results.accuracy.cond2.subjXfeature,2),mean(allsubj_results.accuracy.cond2.subjXfeature),std(allsubj_results.accuracy.cond2.subjXfeature)/sqrt(size(allsubj_results.accuracy.cond2.subjXfeature,1)),'k')
        title('Decoding Accuracy across all features: Red = Cond1, Black = Cond2')
        set(gca,'XTick',[1:length(allsubj_results.incl_features)])
        set(gca,'XTickLabel',allsubj_results.incl_features)
        hold off;
        
        figure
        errorbar(1:size(allsubj_results.accuracy.cond1.subjXfeature,1),mean(allsubj_results.accuracy.cond1.subjXfeature'),repmat(std(mean(allsubj_results.accuracy.cond1.subjXfeature'))/sqrt(size(allsubj_results.accuracy.cond1.subjXfeature,2)),1,size(allsubj_results.accuracy.cond1.subjXfeature,1)),'r')
        hold;
        errorbar(1:size(allsubj_results.accuracy.cond2.subjXfeature,1),mean(allsubj_results.accuracy.cond2.subjXfeature'),repmat(std(mean(allsubj_results.accuracy.cond2.subjXfeature'))/sqrt(size(allsubj_results.accuracy.cond2.subjXfeature,2)),1,size(allsubj_results.accuracy.cond2.subjXfeature,1)),'k')
        title('Decoding Accuracy across all subjects: Red = Cond1, Black = Cond2')
        set(gca,'XTick',[1:allsubj_results.incl_subjects])
        hold off;
        
    end
end

end
