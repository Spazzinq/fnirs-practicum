cd('/Users/conelab/Documents/fNIRS_Practicum')
addpath(genpath("./homer_v2_8"))
db2 = [0.3415 0.5915 0.1585 -0.0915];
save('db2.mat','db2')

ages = [6, 24, 36, 60];
str_ages = string(arrayfun(@(age) sprintf('%02dmo', age), ages, 'UniformOutput', false));

for i = 1:length(ages)
    filename = dir('./' + str_ages(i) + '_train_peekaboo/BCR*peekaboo_' + str_ages(i) + '.nirs')
    preprocessing_pipeline(filename, '_ppPracF24', ages(i))
end