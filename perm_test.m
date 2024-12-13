%% Permutation-based null hypothesis for significance testing
% This section permutes all four stimulus labels (Included Cars, Silent
% Video, Nonvocal Video, Vocal Video) randomly for each participant and
% then repeats the classifiation. The mean classification accuracy (all
% pairwise, as in the analysis above) is recorded to a null hypothesis
% distribution. This process is repeated "nPERM" many times (probably 5000
% or thereabouts, see parameter setting below).

nPERM = 3000;
hb_type = 'Oxy+Deoxy';

regions = {'frontal', 'anterior', 'posterior', 'whole'};
ages = [6,24,36,60];

for j = 1:length(regions)
    region = regions(j);
    region = region{:};
for i = 1:length(ages)
    age = ages(i);
    str_age = sprintf('%02dmo',age);

    % Clear workspace and re-import the data saved above
    clearvars('-except','nPERM','hb_type','regions','region','ages','age','str_age')
    load(['out_' region '/data/Peekaboo_' str_age '_' hb_type '_chan_data.mat'],'MCP_struct_chan','between_subj_level')
    
    % Set up the variables to store the null hypothesis distribution.
    PERM_acc = nan(nPERM,1);
    PERM_mat = nan(...
        length(between_subj_level.conditions),...
        length(between_subj_level.conditions),...
        nPERM);
    
    % Suppress all warnings so that they don't fill up the screen
    warning('off','all')
    
    for iter = 1:length(PERM_acc)
        
        MCP_struct_chan_permuted = MCP_struct_chan;
        
        for idx = 1:length(MCP_struct_chan)
            [cname, cond_id, ~] = intersect({MCP_struct_chan(idx).Experiment.Conditions.Name},between_subj_level.conditions);
            
%             fprintf('%s: Trials found per condition:\n',MCP_struct_chan(idx).Subject.Subject_ID);
%             fprintf('%g ', sum(MCP_struct_chan(idx).fNIRS_Data.Onsets_Matrix(:,cond_id),1));
%             fprintf('\n');
            
            MCP_struct_chan_permuted(idx).fNIRS_Data.Onsets_Matrix(:,cond_id) = ...
                MCP_struct_chan(idx).fNIRS_Data.Onsets_Matrix(:,...
                cond_id(randperm(length(cond_id)))...
                );
        end
        
        between_subj_PERMU = nfold_classify_ParticipantLevel(...
            MCP_struct_chan_permuted,...                  % MCP data struct
            'incl_channels', between_subj_level.incl_channels,...
            'incl_subjects',between_subj_level.incl_subjects,...
            'baseline_window',...                       % Baseline window to average and subtract from the time window
                [between_subj_level.baseline_window(1),...
                between_subj_level.baseline_window(end)],...                
            'time_window',...                           % Time window to analyze (in sec)
                [between_subj_level.time_window(1),...
                between_subj_level.time_window(end)],...                     
            'summary_handle',between_subj_level.summary_handle,...               % Which function to use to summarize data to features
            'conditions',between_subj_level.conditions,...
            'test_handle',between_subj_level.test_handle,...
            'hemoglobin',between_subj_level.hemoglobin,...
            'verbose',false,...
            'opts_struct', between_subj_level.opts_struct);                       % Which classifier to call (also can have opts_struct)
        
        PERM_acc(iter) = nanmean(between_subj_PERMU.accuracy_matrix(:));
        PERM_mat(:,:,iter) = nanmean(between_subj_PERMU.accuracy_matrix,4);
        fprintf('Finished Permutation #%g\n\n',iter)
    end
    
    % Plot histogram for significance test
    figure();
    % Overall accuracy for all permutations
    histogram(PERM_acc,0:0.005:1,'FaceColor','blue')
    hold on;
    % Compute and plot the 95th percentile (non-parametric p<=0.05)
    PERM_sig = PERM_acc;
    PERM_sig(PERM_acc<quantile(PERM_acc,.95)) = NaN;
    histogram(PERM_sig,0:0.005:1,'FaceColor','red')
    % Plot the original overall accuracy
    overall_acc = nanmean(nanmean(between_subj_level.accuracy_matrix(:)));
    vertpos = overall_acc;
    line([vertpos, vertpos], ylim, 'LineWidth', 2, 'Color', 'green');
    % Nicely format the figure
    xlabel('Mean Between-Subjects Classification Accuracy')
    ylabel('Frequency')
    fig = gca;
    fig.FontSize = 20;
    title(['Significance Test of ' str_age ' Peekaboo (All Stims) Classification Accuracy (' hb_type ')'],'FontSize',14)
    legend({'permuted labels','permuted p<0.05',['true labels p=' num2str(round(nanmean(PERM_acc>=overall_acc),3))]})
    hold off;
    save(['out_' region '/data/Permuted_' str_age '_' hb_type '_chan_data.mat'],'MCP_struct_chan','PERM_acc','PERM_mat','between_subj_level')
    saveas(gcf,sprintf(['out_' region '/figures/' str_age '_%s_AllClasses_permutation.pdf'],hb_type)); close gcf;
    
    %% Plot permutations for the Cars vs. Faces
    CF_perm = PERM_mat(...
        strcmp(between_subj_level.conditions,'Included Cars'),...
        strcmp(between_subj_level.conditions,'Silent Video'),:);
    CF_sig = CF_perm;
    CF_sig(CF_perm<quantile(CF_perm,.95)) = NaN;
    figure;
    histogram(CF_perm,0:0.005:1,'FaceColor','blue')
    hold on;
    histogram(CF_sig,0:0.005:1,'FaceColor','red')
    CF_acc = nanmean(...
        squeeze( between_subj_level.accuracy_matrix( ...
        strcmp(between_subj_level.conditions,'Included Cars'),...
        strcmp(between_subj_level.conditions,'Silent Video'),:,:)));
    vertpos=CF_acc;
    line([vertpos, vertpos], ylim, 'LineWidth', 2, 'Color', 'green');
    xlabel('Mean Between-Subjects Classification Accuracy')
    ylabel('Frequency')
    fig = gca;
    fig.FontSize = 20;
    title(['Significance Test of ' str_age ' Visual Contrast Accuracy (' hb_type ')'],'FontSize',14)
    legend({'permuted labels','permuted p<0.05',['true labels p=' num2str(round(nanmean(CF_perm>=CF_acc),3))]})
    hold off;
    saveas(gcf,sprintf(['out_' region '/figures/' str_age '_%s_Visual_permutation.pdf'],hb_type)); close gcf;
    
    %% Plot permutations for the Social vs. Nonsocial
    NV_perm = PERM_mat(...
        strcmp(between_subj_level.conditions,'Nonvocal Video'),...
        strcmp(between_subj_level.conditions,'Vocal Video'),:);
    NV_sig = NV_perm;
    NV_sig(NV_perm<quantile(NV_perm,.95)) = NaN;
    figure;
    histogram(NV_perm,0:0.005:1,'FaceColor','blue')
    hold on;
    histogram(NV_sig,0:0.005:1,'FaceColor','red')
    NV_acc = nanmean(...
        squeeze( between_subj_level.accuracy_matrix( ...
        strcmp(between_subj_level.conditions,'Nonvocal Video'),...
        strcmp(between_subj_level.conditions,'Vocal Video'),:,:)));
    vertpos = NV_acc;
    line([vertpos, vertpos], ylim, 'LineWidth', 2, 'Color', 'green');
    xlabel('Mean Between-Subjects Classification Accuracy')
    ylabel('Frequency')
    fig = gca;
    fig.FontSize = 20;
    title(['Significance Test of ' str_age ' Auditory Contrast Accuracy (' hb_type ')'],'FontSize',14)
    legend({'permuted labels','permuted p<0.05',['true labels p=' num2str(round(nanmean(NV_perm>=NV_acc),3))]})
    hold off;
    saveas(gcf,sprintf(['out_' region '/figures/' str_age '_%s_Auditory_permutation.pdf'],hb_type)); close gcf;
    
    
    %% Plot permutations for the Three Videos
    SV_perm = PERM_mat(...
        strcmp(between_subj_level.conditions,'Silent Video'),...
        strcmp(between_subj_level.conditions,'Vocal Video'),:);
    SN_perm = PERM_mat(...
        strcmp(between_subj_level.conditions,'Silent Video'),...
        strcmp(between_subj_level.conditions,'Nonvocal Video'),:);
    TV_perm = mean([squeeze(SN_perm), squeeze(SV_perm), squeeze(NV_perm)],2);
    TV_sig = TV_perm;
    TV_sig(TV_perm<quantile(TV_perm,.95)) = NaN;
    figure;
    histogram(TV_perm,0:0.005:1,'FaceColor','blue')
    hold on;
    histogram(TV_sig,0:0.005:1,'FaceColor','red')
    TV_realAcc = between_subj_level.accuracy_matrix( [2:4],[2:4],:);
    vertpos = nanmean(TV_realAcc(:));
    line([vertpos, vertpos], ylim, 'LineWidth', 2, 'Color', 'green');
    xlabel('Mean Between-Subjects Classification Accuracy')
    ylabel('Frequency')
    fig = gca;
    fig.FontSize = 20;
    title(['Significance Test of ' str_age ' Three Videos Accuracy (' hb_type ')'],'FontSize',14)
    legend({'permuted labels','permuted p<0.05',['true labels p=' num2str(round(nanmean(TV_perm>=nanmean(TV_realAcc(:))),3))]})
    hold off;
    saveas(gcf,sprintf(['out_' region '/figures/' str_age '_%s_Videos_permutation.pdf'],hb_type)); close gcf;
    
    %%
    fprintf([str_age ', %s: overall=%0.3f, videos=%0.3f, visual=%0.3f, auditory=%0.3f\n\n'], hb_type, nanmean(PERM_acc>=overall_acc), nanmean(TV_perm>=nanmean(TV_realAcc(:))), nanmean(CF_perm>=CF_acc), nanmean(NV_perm>=NV_acc));
    drawnow;
end
end