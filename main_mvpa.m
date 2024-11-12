ages = [6, 24, 36, 60];
included_channels = [];

for i = 1:length(ages)
    mvpa(ages(i), included_channels, 'ppPracF24') % the suffix for the preprocessed files
end