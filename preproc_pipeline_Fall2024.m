function trial_counts = preproc_pipeline_Fall2024( nirs_file, new_suffix, age )
%PREPROC_PIPELINE2024 preprocesses one or more *.nirs files using Homer2 and
%the preprocessing steps specified in the SPL+WAV (spline + wavelet)
%pipeline of DiLorenzo et al.'s 2019 paper in Neuroimage.
%
% Homer2 must be added to Matlab's path before running this function.
% File db2.mat must be present in the path as well to run the wavelet
% motion correction. See Homer documentation re: obtaining this file.
%
% Input: 
% nirs_file - can be a single character vector containing the path to a
% *.nirs file. If a cell array of files or a file struct array (as returned 
% by the dir() function) is provided, the function will run over each entry
% of the array.
% new_suffix - a char vector to append to the end of the filename. To
% overwrite the original file, specify empty array ''. Deafult value is
% '_pp1' yielding 'old_path/old_name_pp1.nirs'
%
% Output: None, but a new file will be written to the same path.
%

%% Input handler
if ~exist('new_suffix','var'), new_suffix = '_pp24'; end
% If more than one file provided, call recursively
if (isstruct(nirs_file) || iscell(nirs_file)) && length(nirs_file)>1
    for file_idx = 1:length(nirs_file)
        try
            % Report what file is being processed
            if isstruct(nirs_file)
                filename_to_disp = nirs_file(file_idx).name;
            elseif iscell(nirs_file)
                [~,filename_to_disp] = fileparts(nirs_file{file_idx});
            else
                [~,filename_to_disp] = fileparts(nirs_file(file_idx));
            end
            fprintf('Preprocessing: %s...\n',filename_to_disp);
            
            % Make the recursive call back to the preprocessing script
            % Suppressing output by using evalc
            evalc('trial_counts_tmp = preproc_pipeline2024_bz(nirs_file(file_idx),new_suffix,age);');
            
            % Handles the output of the preprocessing (trial_counts)
            if ~exist('trial_counts','var')
                warning('Trial counts matrix not found. Creating one!')
                trial_counts = trial_counts_tmp;
            else
                %disp(size(trial_counts_tmp))
                if any(size(trial_counts_tmp)>size(trial_counts,1:ndims(trial_counts_tmp)))
                    warning('Changing size of trial_counts for file at index %g',file_idx);
                    trial_counts_new = nan(size(trial_counts_tmp,1),size(trial_counts_tmp,2),file_idx);
                    trial_counts_new(1:numel(trial_counts)) = trial_counts;
                    trial_counts_new(:,:,file_idx) = trial_counts_tmp;
                    trial_counts = trial_counts_new;
                else
                    trial_counts(1:size(trial_counts_tmp,1),1:size(trial_counts_tmp,2),file_idx) = trial_counts_tmp;
                end
            end
        catch ME
            disp('Error Message:')
            warning(ME.message)
        end           
    end
    return
end

% If nirs_file is a struct, convert to a string path
if isstruct(nirs_file)
    if strcmp(nirs_file.name,'.') || strcmp(nirs_file.name,'..')
        return
    end
    nirs_file = [nirs_file.folder filesep nirs_file.name];
end

% if nirs_file is a cell, convert to a string
if iscell(nirs_file), nirs_file = nirs_file{:}; end

% Finally, import the file's contents into 'nirs_data'
disp(['Loading file ' nirs_file]);
nirs_data = load(nirs_file,'-mat');

%% Set parameters 
% Infer some basic descriptives from the nirs_data
% nChannels = size(nirs_data.d,2) / max(size(nirs_data.SD.Lambda)); % not currently used
if ~isfield(nirs_data,'fs'), nirs_data.fs = 1/mean(diff(nirs_data.t)); end

% Settings chosen from DiLorenzo, Pirazzoli, et al., 2019, Neuroimage
tRange = [-2,16]; % artifact search range for stimulus rejection
tRangeBlock = [-2,20]; % block averaging time range
nirs_data.tInc = ones(size(nirs_data.t));

% enPruneChannels params
dRange = [3e-3,1e1]; % exclude channels with very low or high raw data
SNRthreshold = 0; % SNR criterion is not used
SDrange = [0,45]; % reject 45 SDs above the mean
reset = 0;

% hmrMotionArtifactByChannel params
% These will be applied to raw data and optical density data.
nirs_data.tIncMan = ones(size(nirs_data.t));
tMotion = 1;
tMask = 1;
STDEVthresh = 15;
AMPthresh = 0.4; % The units on this value are unclear and might not work across different machines

% hmrCorrectSpline params
p = .99;

% hmrMotionCorrectWavelet params
iqr = 0.8; % inter-quartile range

% hmrBandpassFilt params
hpf = 0.03; % high pass filter
lpf = 1; % low pass filter

% differential pathlength from Scholkmann & Wolf (2013) formula
if age==6
    ppf = [5.25, 4.25];
elseif age ==24
    ppf = [5.32, 4.33];
elseif age ==36
    ppf = [5.36, 4.37];
elseif age ==60
    ppf = [5.44, 4.44];
else 
    ppf = [5.1, 5.1];
end

%% Valid trials pre
valid_trials_pre = (sum(nirs_data.s>0));
auto_rej_trials_pre = (sum(nirs_data.s==-1));
manu_rej_trials_pre = (sum(nirs_data.s==-2));

%% Do preprocessing according to the SPL+WAV pipeline

% 1. Do channel pruning on raw data
nirs_data.SD = enPruneChannels(nirs_data.d,nirs_data.SD,nirs_data.tInc,dRange,SNRthreshold,SDrange,reset);
%nirs_data.old_d = nirs_data.d;
%nirs_data.d(:,~nirs_data.SD.MeasListAct) = NaN;    % Doing this breaks the bandpass filter
%nirs_data.d(:,~nirs_data.SD.MeasListAct) = 0;      % Doing this breaks the bandpass filter

% 2. Convert raw data (d) to optical density (procResult.dod)
nirs_data.procResult.dod = hmrIntensity2OD(nirs_data.d);

% 3. Identify motion artifacts in dod (will be used in correction)
[nirs_data.tInc,nirs_data.tIncCh1] = hmrMotionArtifactByChannel(nirs_data.procResult.dod, nirs_data.fs, nirs_data.SD, nirs_data.tIncMan, tMotion, tMask, STDEVthresh, AMPthresh);

% 4. Perform motion correction by Spline method
nirs_data.procResult.dodSplineCorr = hmrMotionCorrectSpline(nirs_data.procResult.dod,nirs_data.t,nirs_data.SD,nirs_data.tIncCh1,p);

% 5. Perform motion correction by Wavelet method
% WARNING: This function relies on a file db2.mat which is not included in
% the Homer2 software. It's supposed to be in the Wavelet toolbox for 
% Matlab, but I had to find it elsewhere, despite having the toolbox.
nirs_data.procResult.dodWaveletCorr = hmrMotionCorrectWavelet(nirs_data.procResult.dodSplineCorr,nirs_data.SD,iqr);
%nirs_data.procResult.dodWaveletCorr = nirs_data.procResult.dodSplineCorr; %temporary fix case to get aroudn slow wavelet for testing

% 6. Identify motion artifacts again
[nirs_data.tIncAuto, nirs_data.tIncCh2] = hmrMotionArtifactByChannel(nirs_data.procResult.dodWaveletCorr, nirs_data.fs, nirs_data.SD, nirs_data.tIncMan, tMotion, tMask, STDEVthresh, AMPthresh);
% Populate the default field tIncCh with the updated tIncCh2
nirs_data.tIncCh = nirs_data.tIncCh2;

% 7. Reject trials based on motion artifacts identified in previous step
nirs_data.s = enStimRejection(nirs_data.t,nirs_data.s,nirs_data.tIncAuto,nirs_data.tIncMan,tRange);
% output a list of changes from the artifact rejection (# of trials per
% condition)
valid_trials = (sum(nirs_data.s>0));
auto_rej_trials = (sum(nirs_data.s==-1));
manu_rej_trials = (sum(nirs_data.s==-2));

% 8. Bandpass filter optical density data
nirs_data.procResult.dodBP = hmrBandpassFilt(nirs_data.procResult.dodWaveletCorr,nirs_data.fs, hpf, lpf);

% 9. Convert optical density data to concentrations
nirs_data.procResult.dc = hmrOD2Conc( nirs_data.procResult.dodBP, nirs_data.SD, ppf );

% 10. Go back and remove the channels from dc that were flagged in Step 1
nirs_data.badChans = ~nirs_data.SD.MeasListAct( 1:(size(nirs_data.SD.MeasListAct,1) / length(nirs_data.SD.Lambda)));
nirs_data.procResult.dc(:,:,nirs_data.badChans) = NaN ;
% output a list of bad channels
%disp(nirs_data.badChans);
%disp(nirs_data.procResult.dc(:,:,nirs_data.badChans));

% 11. Block average the data
[nirs_data.procResult.dcAvg, nirs_data.procResult.dcStd, nirs_data.procResult.tHRF, nirs_data.procResult.nTrials, nirs_data.procResult.dcSum2, nirs_data.procResult.dcTrials] = hmrBlockAvg( nirs_data.procResult.dc, nirs_data.s, nirs_data.t, tRangeBlock );

%% Save the updated nirs_data over the old file
[p, f, x] = fileparts(nirs_file);
new_file = [p filesep f new_suffix x];
save(new_file,'-struct','nirs_data');

trial_counts = [valid_trials_pre; auto_rej_trials_pre; manu_rej_trials_pre; valid_trials; auto_rej_trials; manu_rej_trials];