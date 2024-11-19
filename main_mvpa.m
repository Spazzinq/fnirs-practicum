ages = [6, 24, 36, 60]; %[6, 24, 36, 60];

%% Filter incl_channel
% Will take the MCP_struct and return front_MCP_Chan, which contains only
% the "frontal" channels for each age condition (Based on Emberson et al.
% 2017, as well as Fu & Richards 2023)
incl_channels_6mo = [12, 13, 14, 15, 28, 29, 30, 31];
incl_channels_older = [15, 16, 17, 18, 34, 35, 36, 37];

for i = 1:length(ages)
    if ages(i) == 6
        included_channels = incl_channels_6mo;
        total_channels = 32;
    else
        included_channels = incl_channels_older;
        total_channels = 38;
    end

    incl_features = zeros(2, total_channels);
    incl_features(:,included_channels) = 1;
    included_channels = find(incl_features(:))


    mvpa(ages(i), included_channels, 'ppPracF24') % the suffix for the preprocessed files
end