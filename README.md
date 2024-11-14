# Running 
## Clone the Repo
`git clone --recurse-submodules -j8 git@github.com:Spazzinq/fnirs-practicum.git`
`git clone --recurse-submodules -j8 https://github.com/Spazzinq/fnirs-practicum.git`

## To run devfOLD
1. Make sure the submodule is cloned. If it isn't, `cd` into `devfOLD` and `git submodule init`
2. Right-click the `devfOLD` folder in MATLAB, `Add to Path > Selected Folders and Subfolders`
3. Or, use `addpath(genpath("PATH"))` in the MATLAB terminal, e.g. `addpath(genpath("./devfOLD"))`
4. Run `devfOLD` in the MATLAB terminal

# Extra Scripts
## Rename files
`for file in *peekaboo.nirs; do mv "$file" "${file%peekaboo.nirs}peekaboo_06mo.nirs"; done`

`for file in *data.mat; do mv "$file" "initial-analysis/${file}"; done`
`for file in *Accuracy.csv; do mv "$file" "initial-analysis/${file}"; done`
