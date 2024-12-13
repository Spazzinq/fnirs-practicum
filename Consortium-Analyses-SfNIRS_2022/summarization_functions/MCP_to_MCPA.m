function MCPA_struct = MCP_to_MCPA(mcp_multiple, incl_subjects, incl_features, incl_channels, time_window, baseline_window, hemoglobin)
%MCP_TO_MCPA Convert MCP format data to MCPA_struct for analysis
% The function is called with the following arguments:
% MCP_to_MCPA(mcp_multiple, incl_subjects, incl_features, incl_channels, time_window, baseline_window, hemoglobin)
%
% mcp_multiple: An customized MCP struct that contains all data for the 
% analysis. Using MCP struct to store data can unify the way that data are 
% stored in the struct. Enter either a struct in the current workspace or
% a path+filename of an *.mcp file. (Multiple MCP files can be entered as a
% cell array containing path+filename in each cell.)
%
% incl_subjects: a vector of indices for subjects to include in the
% analysis. Importantly the subject numbers correspond to the index in the
% struct array (e.g., MyData([1 3 5]) not any other subject number
% assignment. Use [] to just get all subjects.
%
% incl_features: a vector of indices for features to include in the
% analysis. Only the feature's position in the MCP struct matters, that is,
% the column it refers to in the Transformation_Matrix and not any other
% feature number assignment. Use [] to get all features.
%
% incl_channels: a vector of indices for features to include in the
% analysis. Again, only the channels's position in the MCP struct matters,
% (the row number in Transformation_Matrix and--equivalently--the column
% number in the Hb_data. If channels are features, this line is redundant,
% but if you are using a different feature-space (e.g., Brodmann's areas)
% and want to delete a single noisy channel from the calculation, you can
% use incl_features to include all features/regions, and incl_channels to
% exclude the noisy channels specifically from participating in the
% computation of the features. Use [] to get all channels.
%
% time_window: defined in number of seconds. If two subjects have different
% sampling frequencies, the same time window will be searched (except for
% rounding error of first and last samples). Time window can be specified
% as either [start, end] or [start : end] since only first and last times
% are used. Default (use []) is [0,20] sec.
%
% baseline_window: defined in number of seconds. If one baseline value is
% provided, data will be baselined on that point (e.g., at t=0 s). If two
% baseline values are provided, data will be baselined on the mean in that
% window (e.g., [-5 0] -> average level in time window -5 to 0 s). If NaN
% is provided, baselining will be skipped. Default (no value provided) 
% baseline is range [-5, 0] sec from stimulus marker.
%
% hemoglobin: a char-type input, either 'Oxy', 'Deoxy', or 'Total'
% indicating what species of Hemoglobin to use. Default is 'Oxy'
%
% The function will return a new struct containing some metadata and the
% multifeature patterns for each participant and condition.
%
% Chengyu Deng & Benjamin Zinszer 5 may 2017
% revised bdz 26 oct 2018
% expanded & revised by Anna Herbolzheimer 2019-2020

%% Check whether importing an MCP file or just converting from workspace
% Pulling from a file will be much faster for individual event
% classification later, so this method is preferred.

if isstruct(mcp_multiple)
    no_mcp_file = true;
else
    if iscell(mcp_multiple), mcp_multiple = mcp_multiple{:}; end
    MCPA_struct.data_file = {mcp_multiple};
    no_mcp_file = false;
    mcp_file_content = load(mcp_multiple,'-mat');
    varname = fieldnames(mcp_file_content);
    mcp_multiple = eval(['mcp_file_content.' varname{1}]);
    clear('mcp_file_content')
end

%% Double-check for missing data
if ~exist('hemoglobin','var')
    hemoglobin = 'Oxy';
end
if ~exist('incl_subjects','var') || isempty(incl_subjects)
    incl_subjects = 1:length(mcp_multiple);
end
if ~exist('incl_features','var') || isempty(incl_features)
    incl_features = [1:max(arrayfun(@(x) size(x.fNIRS_Data.Hb_data.(hemoglobin),2),mcp_multiple))];
end
if ~exist('incl_channels','var') || isempty(incl_channels)
    incl_channels = [1:max(arrayfun(@(x) size(x.fNIRS_Data.Hb_data.(hemoglobin),2),mcp_multiple))];
end
if ~exist('time_window','var') || isempty(time_window)
    time_window = [0,20];
end
if ~exist('baseline_window','var')
    baseline_window = [-5,0];
end


%% Convert time window from seconds to scans
% rounds off sampling frequencies to 8 places to accomodate floating point
% errors
Fs_val = unique(round(arrayfun(@(x) x.fNIRS_Data.Sampling_frequency,mcp_multiple),8));
if length(Fs_val) > 1 && ( (1/min(Fs_val) - 1/max(Fs_val)) > (1/3600) ) % 1 sec drift per hour
    minFs = min(Fs_val);
    maxFs = max(Fs_val);
    warning([num2str(length(Fs_val)) ' different sampling frequencies found, ranging from ' num2str(minFs) ' to ' num2str(maxFs) ' Hz. '...
        'Data may be resampled during analysis if comparisons are made in time-domain']);
end
num_time_samps = length(round(time_window(1)*max(Fs_val)) : round(time_window(end)*max(Fs_val)));

%% get the max amount of sessions needed to complete study
num_sessions = [];
for subj = 1:length(mcp_multiple)
    num_sessions = [num_sessions; length(mcp_multiple(subj).Experiment.Runs)];
end
max_num_sessions = max(num_sessions);

%% get the amount of repetitions for a category type
startidx = arrayfun(@(x) arrayfun(@(s) min(s.Index), x.Experiment.Runs, 'UniformOutput', false),mcp_multiple, 'UniformOutput', false);
stopidx = arrayfun(@(x) arrayfun(@(s) max(s.Index), x.Experiment.Runs, 'UniformOutput', false),mcp_multiple, 'UniformOutput', false);
num_events = nan(length(mcp_multiple), max_num_sessions);
for subj = 1:length(mcp_multiple)
    for session = 1:length(mcp_multiple(subj).Experiment.Runs)
        num_events(session,subj) = max(sum(mcp_multiple(subj).fNIRS_Data.Onsets_Matrix(startidx{subj}{session}:stopidx{subj}{session},:))); 
    end
end

% num_repetitions = max(num_events,[],'all');  
num_repetitions = max(max(num_events,[],'omitnan'));

%% Event type Handling

% % This version just gets integers up to the max number of conditions
% event_types = 1:max(arrayfun(@(x) length(x.Experiment.Conditions),MCP_data));

% This version uses names from the MCP array
all_names = arrayfun(@(x) unique({x.Experiment.Conditions.Name},'stable'),mcp_multiple(incl_subjects), 'UniformOutput',false);
unique_names = cellfun(@(x) char(x{:}),all_names,'UniformOutput',false);
[event_types, iev] = unique(cellstr(char(unique_names)),'stable');

%% Extract data from the data file into the empty output matrix
hemo_type = strsplit(hemoglobin,'+');

% Initiate the subj_mat matrix that will be output later(begin with NaN)
% Output matrix for MCPA_struct is in dimension: time_window x types x features x repetition x subjects
subj_mat = nan(num_time_samps, length(event_types), length(hemo_type)*length(incl_features), num_repetitions, max_num_sessions, length(incl_subjects));
% Extract data from each subject
for subj_idx = 1 : length(incl_subjects)
    
    for session_idx = 1:length(mcp_multiple(subj_idx).Experiment.Runs)
        if no_mcp_file
        MCPA_struct.data_file{subj_idx} = [mcp_multiple(incl_subjects(subj_idx)).Experiment.Runs.Source_files]';
        end
        
        % Some MCP files will not already have a transformation matrix
        % stored for translating channels into features. If that field is
        % missing, create an identity matrix 
        if ~isfield(mcp_multiple(incl_subjects(subj_idx)).Experiment.Runs(session_idx),'Transformation_Matrix') || ...
            isempty(mcp_multiple(incl_subjects(subj_idx)).Experiment.Runs(session_idx).Transformation_Matrix)
            
            mcp_multiple(incl_subjects(subj_idx)).Experiment.Runs(session_idx).Transformation_Matrix = eye(length(mcp_multiple(incl_subjects(subj_idx)).Experiment.Probe_arrays.Channels));
        end

        % Event_matrix format:
        % (time x features x repetition x types)
        event_matrix = MCP_get_subject_events(mcp_multiple(incl_subjects(subj_idx)), incl_features, incl_channels, time_window, event_types, baseline_window, hemoglobin, session_idx);
        event_matrix = permute(event_matrix, [1 4 2 3]);

       
        subj_time_samps = size(event_matrix,1);
        if subj_time_samps == num_time_samps
            repetitions_in_session = size(event_matrix,4);
            % Output format: subj_mat(time_window x event_types x features x repetition x subjects)
            subj_mat(:, :, :,1:repetitions_in_session, session_idx, subj_idx) = event_matrix;
        else
            time_mask = round(linspace(1,num_time_samps,subj_time_samps));
            % Output format: subj_mat(time_window x event_types x features x repetition x subjects)
            subj_mat(time_mask, :, :,1:repetitions_in_session, session_idx, subj_idx) = event_matrix;
        end

        
    end
    
end

%% Return the MCPA_struct
try
    MCPA_struct.created = datestr(now);
    MCPA_struct.time_window = [round(time_window(1)*max(Fs_val))/max(Fs_val) : 1/max(Fs_val) : round(time_window(end)*max(Fs_val))/max(Fs_val)];
    MCPA_struct.incl_subjects = incl_subjects;
    MCPA_struct.incl_features = incl_features;
    MCPA_struct.event_types = event_types;
    MCPA_struct.patterns = subj_mat;
    MCPA_struct.dimensions = {'time','condition', 'feature', 'repetition', 'session', 'subject'};
    
catch
    MCPA_struct = struct;
    error('Failed to create the new struct (MCP_to_MCPA).');
end


end

