% Define our age groups and regions of interest that we already classified
% using main_mvpa
ages = [6, 24, 36, 60];
types = {'Frontal', 'Whole', 'Anterior', 'Posterior'};
table = [];

for type = types
    % typetable is a subtable that we will vertically concatenate with the
    % main table variable after we're done processing it
    type_table = [];
    
    for age = ages
        str_age = sprintf('%02dmo',age);

        % agetable is a subtable that we will vertically concatenate with the
        % typetable variable after we're done processing it
        age_table = readtable(['./out_' lower(type{:}) '/accuracy/Peekaboo_' str_age '_chan_Oxy+Deoxy_BetweenSubjAccuracy.csv']);
        
        % Give the table actual header names
        age_table.Properties.VariableNames = ["ID", "Visual", "Auditory", "Videos", "All", "Remove4"];
        age_table.("ID") = erase(age_table.("ID"), "peekaboo"); % Remove peekaboo from the ID names
        age_table.("Remove4") = []; % Remove irrelevant column
        age_col = zeros(height(age_table), 1) + age; % Make a column of the current age to append
        age_table.("Age") = age_col;
        
        % Print average accuracies for all of the age-type pairs
%         avg = mean(agetable.("All"), "omitnan");
%         fprintf("%s %s, Avg Acc: %f\n", type{:}, str_age, avg)

        % Vertical concatenation
        type_table = vertcat(type_table, age_table);
    end
    
    % Make a column of the current age to append
    type_col = zeros(height(type_table), 1);
    
    % Iterate again over the types so we can assign 1's to the right column
    for type_again = types
       if strcmp(type{:}, type_again{:})
           type_table.(type_again{:}) = type_col + 1; 
       else
           type_table.(type_again{:}) = type_col; 
       end
    end
    
    % Vertical concatenation
    table = vertcat(table, type_table);
end

% Join the head circumferences column from the cap info csv
% to check interaction effects
head_circumferences = readtable('./PSYC110_fNIRSProject_capInfo.csv');
head_circumferences = head_circumferences(:, {'ID', 'head_circ', 'Age'});
head_circumferences.Properties.VariableNames = ["ID", "HeadCircumference", "Age"];
table = innerjoin(table, head_circumferences, 'Keys', {'ID', 'Age'});

% Output table
table;

% Sanity check of original all-channel data
% fitlm(table(table.("Whole")==1,:), 'All ~ (Age + HeadCircumference)')
% fitglm(table(table.("Whole")==1,:), 'Auditory ~ (Age + HeadCircumference)', 'Distribution', 'binomial')

% Normal linear regression model, largest to smallest after removing
% insignificant interactions
% fitlm(table(table.("Whole")==0,:), 'All ~ (Posterior + Anterior) * (Age + HeadCircumference)')
% fitlm(table(table.("Whole")==0,:), 'All ~ (Posterior + Anterior) * (Age) + HeadCircumference')
fitlm(table(table.("Whole")==0,:), 'All ~ (Posterior + Anterior) + (Age) + HeadCircumference')

% Print the largest mixed-effects model that can actually run on Trashcan Mac
% (adding HeadCircumference as an interaction took too long)
lme_model = fitlme(table(table.("Whole")==0,:), 'All ~ (Anterior + Posterior) * Age + HeadCircumference + (1+(Anterior + Posterior) * Age + HeadCircumference | ID)')