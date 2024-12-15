# Neuroscience Practicum Documentation
This repository includes everything you need to run the whole fNIRS pipeline EXCEPT for the confidential dataset. The steps are outlined below:
1. Preprocessing
2. Classification
3. Permutation-Based Null Hypothesis Testing
4. Regression Analysis

In general, the code is documented well enough that you should be able to modify any project-specific aspects yourself, except of course the classifier and Homer scripts that are already provided in the repository.

Outputted classifier and permutation-based null hypothesis data can be found in the PDFs in subfolders prefixed with `out_` followed by the region of interest. Output from linear regression and mixed effects can be found [here](https://docs.google.com/document/d/1TLibp-FIbkeyu_htAAK5yxhVb3vAz7XHBr9SJjCERdw/edit?usp=sharing). Running the scripts below on the raw data should reproduce all of the findings, though you may have to uncomment a line or two in `linear_regression.m` for extra linear/mixed-effects analyses that were ommited from the poster/paper itself.

This code uses the [Homer2 library](https://openfnirs.org/software/homer/) and [fNIRS classifier library](https://github.com/TeamMCPA/Consortium-Analyses/tree/SfNIRS_2022) from TeamMCPA which are already included. Any applicable licenses from those projects may apply.

## Preprocessing
To run the preprocessing, run `main_preprocessing.m`, modifying any data-specific variables in the script as necessary. Make sure the 2nd parameter to the `preprocessing_pipeline.m` call, which is the `new_suffix` parameter, is set to something that won't override your existing preprocessed data, if any.

## Classification
Modify any age or channel specifications in `main_mvpa.m`, then run the script. It will run iteratively over all age groups and ROIs to produce data in folders prefixed with `out_`.

## Permutation-Based Null Hypothesis Testing
Run `perm_test.m`, modifying any age or regions as needed.

## Regression Analysis
To run the linear regression (or the LME/mixed-effects model), run the script `linear_regression.m`. Modify the data-specific variables to match the ages and ROIs/types that you have already run the classifier on. 

## Extra Scripts
### Rename files
`for file in *peekaboo.nirs; do mv "$file" "${file%peekaboo.nirs}peekaboo_06mo.nirs"; done`

`for file in *data.mat; do mv "$file" "initial-analysis/${file}"; done`
`for file in *Accuracy.csv; do mv "$file" "initial-analysis/${file}"; done`
