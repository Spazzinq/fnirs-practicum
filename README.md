## Rename files
`for file in *peekaboo.nirs; do mv "$file" "${file%peekaboo.nirs}peekaboo_06mo.nirs"; done`

## To run devfOLD
Add the cloned repo to your path via right-click, `Add to Path > Selected Folders and Subfolders`
Or use `addpath(genpath("PATH"))` in the terminal, e.g. `addpath(genpath("./homer_v2_8"))`