function mvpa(age, included_channels, preprocessed_suffix)
%% Build a list of the .nirs files
% Keep in mind that build_MCP expects a certain structure, and the file names
% need to be nested by subject. Even if there is only one file per subject, it
% needs the nested cells format: nirs_files_cell = { {subj1_file1} ; {subj2_file1}
% ; {subj3_file1} }
str_age = sprintf('%02dmo',age)
nirs_folder = ['/Users/conelab/Documents/fNIRS_Practicum/' str_age '_train_peekaboo']
nirs_files = dir([nirs_folder filesep '*' preprocessed_suffix '.nirs'])

% Open each of the .nirs files and fix the s-matrix. Negative numbers mess
% up the logical flagging, so they are removed in the new s_fix matrix.
for file_index = 1:length(nirs_files)
    nir_dat = load([nirs_files(file_index).folder filesep nirs_files(file_index).name],'-mat');
    if ~isfield(nir_dat,'s_fix')
        nir_dat.s_fix = nir_dat.s>0;
        save([nirs_files(file_index).folder filesep nirs_files(file_index).name],'-struct','nir_dat');
    end
    clear('nir_dat');
end
%% Build the MCP struct

restoredefaultpath;
% Download Consortium toolbox at: https://github.com/TeamMCPA/Consortium-Analyses
addpath(genpath([pwd filesep 'Consortium-Analyses-SfNIRS_2022']));

if age == 6 || age == 24
    type = 'BCR';
elseif age == 36 || age == 60
    type = 'BP';
end

[nirs_files_cell, subject_ids] = prep_nirsfiles_mcp(nirs_files , '_' , type);

if age == 6
    probe_id = {'BeanSmall'};
else
    probe_id = {'BeanLarge'};
end

MCP_struct_chan = build_MCP(nirs_files_cell,subject_ids,probe_id,'s_fix');

% Reassign all the condition names based on the names stored in the .nirs
% files. Ideally they'd be the same order, but who knows!
for file_index = 1:length(nirs_files)
    try
        nir_dat = load(MCP_struct_chan(file_index).Experiment.Runs(1).Source_files{:},'-mat');
        fprintf('Subject: %s\n', MCP_struct_chan(file_index).Subject.Subject_ID);
        cond_names = nir_dat.CondNames;
        for old_mark = 1:length(cond_names)
            fprintf('%s -> %s ', cond_names{old_mark}, MCP_struct_chan(file_index).Experiment.Conditions(old_mark).Name)
            MCP_struct_chan(file_index) = MCP_relabel_stimuli(MCP_struct_chan(file_index),old_mark,cond_names{old_mark},0);
        end
        fprintf('\n');
    catch
        warning('Index out of bounds');
        break;
    end
end

% Reassign all the condition names to something interpretable
for file_index = 1:length(nirs_files)
    fprintf('Subject: %s\n', MCP_struct_chan(file_index).Subject.Subject_ID);
    old_cond_names = {'C','S','N','V'};
    cond_names = {'Cars','Silent Video','Nonvocal Video','Vocal Video'};
    for old_index = 1:length(cond_names)
        fprintf('%s -> %s ', cond_names{old_index}, old_cond_names{old_index})
        MCP_struct_chan(file_index) = MCP_relabel_stimuli(MCP_struct_chan(file_index),old_cond_names{old_index},cond_names{old_index},0);
    end
    fprintf('\n');
end

% Drop any subjects with fewer than 5 of the Vocal Video condition
% (This applies to all the social conditions, since they should be balanced)
MCP_struct_chan = MCP_struct_chan(arrayfun( @(x) sum(x.fNIRS_Data.Onsets_Matrix(:,strcmp({x.Experiment.Conditions.Name},'Vocal Video'))), MCP_struct_chan)>=5);

% Match the number of Cars trials to the number of trials in the other
% three conditions. Cars onsets/triggers are randomly selected
for file_index = 1:length(MCP_struct_chan)
    fprintf('Subject: %s\n', MCP_struct_chan(file_index).Subject.Subject_ID);

    % Identify the column of Onsets Matrix containing Cars and count onsets
    cars_bool_index = strcmp('Cars',{MCP_struct_chan(file_index).Experiment.Conditions(:).Name});
    n_cars = sum(MCP_struct_chan(file_index).fNIRS_Data.Onsets_Matrix(:,cars_bool_index));

    % Identify the column of Onsets Matrix containing other conditions and
    % count their onsets as well. Average across the other conditions to
    % determine the number of Cars trials to retain
    sil_bool_index = strcmp('Silent Video',{MCP_struct_chan(file_index).Experiment.Conditions(:).Name});
    non_bool_index = strcmp('Nonvocal Video',{MCP_struct_chan(file_index).Experiment.Conditions(:).Name});
    voc_bool_index = strcmp('Vocal Video',{MCP_struct_chan(file_index).Experiment.Conditions(:).Name});
    not_cars_bool_index = logical(sil_bool_index+non_bool_index+voc_bool_index);
    n_cars_new = round(mean(sum(MCP_struct_chan(file_index).fNIRS_Data.Onsets_Matrix(:,not_cars_bool_index),1)),0);

    fprintf('Found %g car onsets, keeping %g as "Included Cars".\n',n_cars,n_cars_new);

    % Randomly sample the subset of Cars to keep as Included
    index_cars_to_keep = randsample(n_cars,n_cars_new);

    % Rename the Cars onsets as either Excluded Cars or Included Cars.
    % Included Cars will be used for the analysis
    new_labels = repmat({'Excluded Cars'},n_cars,1);
    new_labels(index_cars_to_keep) = {'Included Cars'};
    MCP_struct_chan(file_index) = MCP_relabel_stimuli(MCP_struct_chan(file_index),'Cars',new_labels,0);

    fprintf('\n');
end
%% Classification

hb_species_list = {'Oxy+Deoxy'}; %% {'Oxy','Deoxy','Oxy+Deoxy'};

for hb_type = hb_species_list
    opts = struct;
    opts.pairwise = true;
    opts.comparison_type = 'correlation';
    opts.metric = 'spearman';
    
    total_channels = min(arrayfun(@(x) length(x.Experiment.Probe_arrays.Channels), MCP_struct_chan));
    n_feats_per_channel = length(strfind(hb_type{:},'+'))+1;
    incl_features = zeros(n_feats_per_channel, total_channels);
    incl_features(:,included_channels) = 1;
    incl_features = find(incl_features(:));

    between_subj_level = nfold_classify_ParticipantLevel(...
        MCP_struct_chan,...                         % MCP data struct%         'incl_features',incl_features,... 
        'incl_channels',included_channels,...
        'baseline_window',[-3,0],...                % Baseline window to average and subtract from the time window
        'time_window',[2,8],...                     % Time window to analyze (in sec)
        'summary_handle',@nanmean,...               % Which function to use to summarize data to features
        'conditions',{'Nonvocal Video','Vocal Video','Included Cars','Silent Video'},...
        'test_handle',@mcpa_classify,...
        'hemoglobin',hb_type{:},...
        'verbose',false,...
        'opts_struct', opts);                       % Which classifier to call (also can have opts_struct)

    OverallAcc = nanmean(between_subj_level.accuracy_matrix(:));

    CarsVsFaces = squeeze( between_subj_level.accuracy_matrix( ...
        strcmp(between_subj_level.conditions,'Included Cars'),...
        strcmp(between_subj_level.conditions,'Silent Video'),:,:));

    SocialVsNonsocial = squeeze( between_subj_level.accuracy_matrix( ...
        strcmp(between_subj_level.conditions,'Nonvocal Video'),...
        strcmp(between_subj_level.conditions,'Vocal Video'),:,:));

    VideoOnly = nanmean(...
        reshape(...
        between_subj_level.accuracy_matrix( ...
        ~strcmp(between_subj_level.conditions,'Included Cars'),...
        ~strcmp(between_subj_level.conditions,'Included Cars'),:,:),...
        9,size(between_subj_level.accuracy_matrix,4)),1)';

    AllClasses = nanmean(...
        reshape(...
        between_subj_level.accuracy_matrix( ...
        :,...
        :,...
        :,:),...
        16,size(between_subj_level.accuracy_matrix,4)),1)';

    SubjectIDs = arrayfun(@(x) x.Subject.Subject_ID, MCP_struct_chan(between_subj_level.incl_subjects),'UniformOutput',false)';

    mkdir("./out")
    mkdir("./out/accuracy")
    mkdir("./out/figures")
    mkdir("./out/data")
    out_filename = sprintf('out/accuracy/Peekaboo_%s_chan_%s_BetweenSubjAccuracy.csv', str_age, hb_type{:});
    writecell([SubjectIDs, num2cell(CarsVsFaces), num2cell(SocialVsNonsocial), num2cell(VideoOnly), num2cell(AllClasses), repmat(hb_type,length(SubjectIDs),1)],out_filename);

    draw_mcpa_output( between_subj_level );
    saveas(gcf,sprintf('out/figures/%s_%s_accuracy.pdf', str_age, hb_type{:})); close gcf;
    saveas(gcf,sprintf('out/figures/%s_%s_features.pdf', str_age, hb_type{:})); close gcf;

    fprintf('%s, %s: overall=%0.2f, videos=%0.2f, visual=%0.2f, auditory=%0.2f\n', str_age, hb_type{:}, OverallAcc, nanmean(VideoOnly),nanmean(CarsVsFaces), nanmean(SocialVsNonsocial));
    save(['out/data/Peekaboo_' str_age '_' hb_type{:} '_chan_data.mat'],'MCP_struct_chan','between_subj_level')

end