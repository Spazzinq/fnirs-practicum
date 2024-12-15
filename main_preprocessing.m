% Comment this line out if you're operating from the right
% directory NOT on the conelab PC
cd('/Users/conelab/Documents/fNIRS_Practicum')

addpath(genpath("./homer_v2_8"))
% Some magic numbers that you need to run a toolbox without paying for it
db2 = [0.3415 0.5915 0.1585 -0.0915];
save('db2.mat','db2')

ages = [6, 24, 36, 60];
% Format a string in the format 00mo
str_ages = string(arrayfun(@(age) sprintf('%02dmo', age), ages, 'UniformOutput', false));

%% Iterate over all ages and save output with specified suffix
for i = 1:length(ages)
    filename = dir('./' + str_ages(i) + '_train_peekaboo/BCR*peekaboo_' + str_ages(i) + '.nirs')
    preprocessing_pipeline(filename, '_ppPracF24', ages(i))
end