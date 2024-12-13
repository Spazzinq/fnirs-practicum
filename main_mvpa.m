ages = [6, 24, 36, 60];

%% Define channels to filter for each region of interest
% See code documentation for channel selection rationale
frontal_struct = struct;
frontal_struct.name = 'frontal';
frontal_struct.channels_6mo = [12,13,14,15,28,29,30,31];
frontal_struct.channels_older = [15,16,17,18,34,35,36,37];

anterior_struct = struct;
anterior_struct.name = 'anterior';
anterior_struct.channels_6mo = [6,7,10,11,22,23,26,27];
anterior_struct.channels_older = [9,10,13,14,28,29,32,33];

posterior_struct = struct;
posterior_struct.name = 'posterior';
posterior_struct.channels_6mo = [1,2,4,8,17,18,20,24];
posterior_struct.channels_older = [2,3,4,5,21,22,23,24];

structs = [frontal_struct, anterior_struct, posterior_struct];
preprocessed_suffix = 'ppPracF24'; % Suffix of preprocessed files

for j = 1:length(structs)
    type_struct = structs(j);
    
    % Name of the output folder
    out_name = ['out_' type_struct.name];
    
    for i = 1:length(ages)
        age = ages(i);
        % Set the channels for each age group
        if age == 6
            included_channels = type_struct.channels_6mo;
        else
            included_channels = type_struct.channels_older;
        end

        fprintf("Running classifier with %g, %s, [", age, out_name);
        fprintf("%g ", included_channels);
        fprintf("]\n");
        
        % Actually run the classifier
        mvpa(age, included_channels, preprocessed_suffix, out_name)
    end
end