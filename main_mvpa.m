ages = [6, 24, 36, 60];

%% Filter incl_channel
% Will take the MCP_struct and return front_MCP_Chan, which contains only
% the "frontal" channels for each age condition (Based on Emberson et al.
% 2017, as well as Fu & Richards 2023)
incl_channels_6mo = [12, 13, 14, 15, 28, 29, 30, 31];
incl_channels_older = [15, 16, 17, 18, 34, 35, 36, 37];

for i = 1:length(ages)
    if ages(i) == 6
        included_channels = setdiff(1:32, incl_channels_6mo);
    else
        included_channels = setdiff(1:38, incl_channels_older);
    end

    mvpa(ages(i), included_channels, 'ppPracF24') % the suffix for the preprocessed files
end