ages = [6, 24, 36, 60];
types = {'Frontal', 'Whole', 'Nonfrontal'};
table = [];

for type = types
    typetable = [];
    
    for age = ages
        str_age = sprintf('%02dmo',age);

        newtable = readtable(['./out_' lower(type{:}) '/accuracy/Peekaboo_' str_age '_chan_Oxy+Deoxy_BetweenSubjAccuracy.csv']);
        newtable.Properties.VariableNames = ["ID", "Frontal", "Whole", "Nonfrontal", "Accuracy", "Type"];
        newtable.("ID") = erase(newtable.("ID"), "peekaboo");
        newtable.("Type") = [];
        ageCol = zeros(height(newtable), 1) + age;
        newtable.("Age") = ageCol;

        typetable = vertcat(typetable, newtable);
    end
    
    type_col = zeros(height(typetable), 1);
    
    for type_again = types
       if strcmp(type{:}, type_again{:})
           typetable.(type_again{:}) = type_col + 1; 
       else
           typetable.(type_again{:}) = type_col; 
       end
    end
    
    table = vertcat(table,typetable);
end

head_circumferences = readtable('./PSYC110_fNIRSProject_capInfo.csv');
head_circumferences = head_circumferences(:, {'ID', 'head_circ', 'Age'});
head_circumferences.Properties.VariableNames = ["ID", "Head Circumference", "Age"];

table = innerjoin(table, head_circumferences, 'Keys', {'ID', 'Age'});

% for id = head_circumferences.("ID")
%     table(strcmp(table.("ID"), id{:})). = 
% end

table