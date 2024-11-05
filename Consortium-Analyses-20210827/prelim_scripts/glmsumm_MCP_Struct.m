function summarized_MCPA_struct = glmsumm_MCP_Struct(MCP_struct, incl_subjects, incl_channels, incl_conditions, offset)
%GLMSUMM_MCP_STRUCT Convert an MCP struct of nirs data to
%multivariate patterns based on GLM beta estimates from Oxy data.
%
%The function will return a new MCPA struct whose field patterns are
%summarized by the beta values.
%
% Benjamin Zinszer 25 april 2019

%% Initalize values
% By default, include all subjects and channels unless specified
if ~exist('incl_subjects','var') || isempty(incl_subjects)
    incl_subjects = 1:length(MCP_struct);
end

if ~exist('incl_channels','var') || isempty(incl_channels)
    incl_channels = [1:max(arrayfun(@(x) size(x.fNIRS_Data.Hb_data.Oxy,2),MCP_struct))];
end

if ~exist('offset','var') || isempty(offset)
    offset=0;
end

% Set up the pattern matrix: conditions x channels x subjects
max_cond = max(arrayfun(@(x) length(x.Experiment.Conditions),MCP_struct));

if ~exist('incl_conditions','var') || isempty(incl_conditions)
    incl_conditions = 1:max_cond;
end

betas = nan(max_cond,length(incl_channels),length(incl_subjects));

%% Compute betas
% Loop through each subject indiviually
for s_idx = 1:length(incl_subjects)
    % Identify subject for this iteration
    sub = incl_subjects(s_idx);

    % Pull that subject's onset matrix and convolve it with a canonical HRF
    % from spm_hrf to create the Design_Matrix
    MCP_struct(sub).fNIRS_Data.Design_Matrix = filter2(...
        spm_hrf(1/MCP_struct(sub).fNIRS_Data.Sampling_frequency,[6 16 1 1 6 0 32]),...
        MCP_struct(sub).fNIRS_Data.Onsets_Matrix(:,incl_conditions));
    
    if offset
        MCP_struct(sub).fNIRS_Data.Design_Matrix = [MCP_struct(sub).fNIRS_Data.Design_Matrix(offset:end,:); zeros(offset-1,size(MCP_struct(sub).fNIRS_Data.Design_Matrix(offset:end,:),2))];
    end
    
    
    betas(incl_conditions,:,s_idx) = MCP_struct(sub).fNIRS_Data.Design_Matrix \ MCP_struct(sub).fNIRS_Data.Hb_data.Oxy(:,incl_channels);
end

%% Build dummy MCPA and summarize
% We skip outputting the MCPA_struct entirely and go to summarized MCPA
% because there is no time_windowed (non-summarized) version of the MCPA
% possible with the GLM. We don't epoch the data (divide into time
% windows) but instead analyze the whole time series at once.

MCPA_struct = MCP_to_MCPA(MCP_struct,incl_subjects,incl_channels,incl_channels,[0,1]);
summarized_MCPA_struct = MCPA_struct;
summarized_MCPA_struct.created = datestr(now);
summarized_MCPA_struct.summarizing_function = @glmsumm_MCP_Struct;
summarized_MCPA_struct.subsets = MCPA_struct.incl_features;
summarized_MCPA_struct.conditions = {MCP_struct(1).Experiment.Conditions(2:5).Name};
summarized_MCPA_struct.dimensions = {'condition' 'feature' 'subject'};
summarized_MCPA_struct.final_dimensions = {'condition' 'feature' 'subject'};

summarized_MCPA_struct.permutation_test = false;
summarized_MCPA_struct.suppress_warnings = false;
summarized_MCPA_struct.verbose = true;
summarized_MCPA_struct.max_sets = 10000;

% Override the time_window since we don't use a time_window
summarized_MCPA_struct.time_window = NaN;

% Override the patterns with new patterns
summarized_MCPA_struct.patterns = betas;

end