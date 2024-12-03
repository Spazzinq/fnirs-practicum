function input_struct = parse_inputs(MCP_struct, varargin)
%% Takes input into cross validation wrappers and creates a struct storing all parameters needed for classification

% Arguments:
% MCP_struct: MCP data structure
% varargin: input to main function

% created by Anna Herbolzheimer and Ben Zinszer 2019
% updated by Anna Herbolzheimer summer 2020

p = inputParser;

for s = 1:length(MCP_struct)
    % Some MCP files will not already have a transformation matrix
    % stored for translating channels into features. If that field is
    % missing, create an identity matrix. This field will be lost after
    % parsing the inputs, but the dimensions are needed to infer values for
    % incl_channels, incl_features, and setsize. If the transformation
    % matrix already exists, this default will not be used.
    if ~isfield(MCP_struct(s).Experiment.Runs(1),'Transformation_Matrix') || isempty(MCP_struct(s).Experiment.Runs(1).Transformation_Matrix)
        MCP_struct(s).Experiment.Runs(1).Transformation_Matrix = eye(length(MCP_struct(s).Experiment.Probe_arrays.Channels));
    end
end

% parameters used for all kinds of classifiers
addParameter(p,'incl_channels',[1:max(arrayfun(@(x) size(x.Experiment.Runs(1).Transformation_Matrix,1),MCP_struct))],@isnumeric);
addParameter(p,'incl_subjects',[1:length(MCP_struct)],@isnumeric);
addParameter(p,'conditions',unique(cellstr(char(cellfun(@(x) char(x{:}), arrayfun(@(x) unique({x.Experiment.Conditions.Name},'stable'),MCP_struct, 'UniformOutput',false),'UniformOutput',false))),'stable'),@iscell);
addParameter(p,'summary_handle',@nanmean);
addParameter(p,'setsize',max(arrayfun(@(x) size(x.Experiment.Runs(1).Transformation_Matrix,2),MCP_struct)),@isnumeric);
addParameter(p,'max_sets',1000000,@isnumeric);
addParameter(p,'test_handle',@mcpa_classify);
addParameter(p,'opts_struct',[],@isstruct);
addParameter(p,'verbose',true);
addParameter(p, 'summarize_dimensions', {});
addParameter(p, 'final_dimensions', {});
addParameter(p, 'suppress_warnings', false);
addParameter(p, 'permutation_test', false);

% parameters that can have more than one value set
addParameter(p, 'hemoglobin', 'Oxy');
addParameter(p,'time_window',[2,6]);
addParameter(p,'baseline_window',[-5 0]);
addParameter(p,'scale_data', false);
addParameter(p,'incl_sessions',[1:max(arrayfun(@(x) length(x.Experiment.Runs),MCP_struct))]);


% for within subjects 
addParameter(p, 'approach', 'loo', @ischar); 
addParameter(p, 'randomized_or_notrand', 'notrand', @ischar); 
addParameter(p, 'test_percent', .2); % for kf 
addParameter(p, 'randomsubset', []); % for kf 
addParameter(p, 'balance_classes', true);

% parameters for working in different feature spaces
addParameter(p, 'feature_space', 'channel_space', @ischar);
addParameter(p, 'incl_features', [1:max(arrayfun(@(x) size(x.Experiment.Runs(1).Transformation_Matrix,2),MCP_struct))],@isnumeric); 
 
% parameters used if norming the data
addParameter(p,'scale_withinSessions', true, @islogical);
addParameter(p, 'scale_function', @minMax_scale);
addParameter(p, 'minMax', [0,1], @isnumeric);

% parameters only used in nfold_generalize_ParticipantLevel
addParameter(p,'cond_key',{});
addParameter(p,'test_marks',{});

parse(p,varargin{:});

input_struct = p.Results;

end
