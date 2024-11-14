ages = [6]; %[6, 24, 36, 60];

%% Filter incl_channel
% Will take the MCP_struct and return front_MCP_Chan, which contains only
% the "frontal" channels for each age condition (Based on Emberson et al.
% 2017, as well as Fu & Richards 2023)
incl_channels = [1,2,3,4,5,6,7,8,9,10,11,14];
incl_features = zeros(2,32);
incl_features(:,incl_channels) = 1;
channels = find(incl_features(:))

for i = 1:length(ages)
    mvpa(ages(i), channels, 'ppPracF24') % the suffix for the preprocessed files
end