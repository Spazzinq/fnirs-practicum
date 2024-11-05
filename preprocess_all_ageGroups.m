cd('/Users/conelab/Documents/fNIRS_Practicum/')
addpath(genpath("./homer_v2_8"))
db2 = [0.3415 0.5915 0.1585 -0.0915]
save("db2.mat","db2")  

%% Preprocess 6 month old data
filename_06mo = dir('./06mo_train_peekaboo/BCR*peekaboo.nirs');
trial_counts_06mo = preproc_pipeline_20241031(filename_06mo, '_ppPracF24', 6);

%% Preprocess 24 month old data
filename_24mo = dir('./24mo_train_peekaboo/BCR*peekaboo_24mo.nirs');
trial_counts_24mo = preproc_pipeline_20241031(filename_24mo, '_ppPracF24', 24);

%% Preprocess 36 month old data
filename_36mo = dir('./36mo_train_peekaboo/BP*peekaboo.nirs');
trial_counts_36mo = preproc_pipeline_20241031(filename_36mo, '_ppPracF24', 36);

%% Preprocess 60 month old data
filename_60mo = dir('./60mo_train_peekaboo/BP*peekaboo_60mo.nirs');
trial_counts_60mo = preproc_pipeline_20241031(filename_60mo, '_ppPracF24', 60);