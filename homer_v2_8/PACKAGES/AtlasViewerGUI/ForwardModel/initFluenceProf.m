function f = initFluenceProf()

f = struct(...
    'intensities',[], ...
    'voxPerNode',[], ...    
    'mesh',initMesh(), ...
    'srcpos',[], ...
    'normfactors',[], ...
    'nphotons', 0, ...
    'tiss_prop',[], ...
    'index',0, ...
    'last',[] ...
    );

