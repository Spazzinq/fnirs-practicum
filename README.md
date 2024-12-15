# Neuroscience Practicum Documentation
This repository includes everything you need to run the whole fNIRS pipeline EXCEPT for the confidential dataset. The steps are outlined below:
1. Preprocessing
2. Classification
3. Regression Analysis

In general, the code is documented well enough that you should be able to modify any project-specific aspects yourself, except of course the classifier and Homer scripts that are already provided in the repository.

## Preprocessing
To run the preprocessing, run `main_preprocessing.m`, modifying any data-specific variables in the script as necessary. Make sure the 2nd parameter to the `preprocessing_pipeline.m` call, which is the `new_suffix` parameter, is set to something that won't override your existing preprocessed data, if any.

## Classification
Modify any age or channel specifications in `main_mvpa.m`, then run the script. It will run iteratively over all age groups and ROIs to produce data in folders prefixed with `out_`.

## Regression Analysis
To run the linear regression (or the LME/mixed-effects model), run the script `linear_regression.m`. Modify the data-specific variables to match the ages and ROIs/types that you have already run the classifier on. 

## Extra Scripts
### Rename files
`for file in *peekaboo.nirs; do mv "$file" "${file%peekaboo.nirs}peekaboo_06mo.nirs"; done`

`for file in *data.mat; do mv "$file" "initial-analysis/${file}"; done`
`for file in *Accuracy.csv; do mv "$file" "initial-analysis/${file}"; done`
