function mri = MRIinit()

mri = struct(...
    'srcbext','', ...
    'analyzehdr',[], ...
    'bhdr',[], ...
    'vol',[], ...
    'niftihdr', [], ...
    'fspec','', ...
    'pwd','', ...
    'flip_angle',0, ...
    'tr',0, ...
    'te',0, ...
    'ti',0, ...
    'vox2ras0',eye(4), ...
    'volsize',[256, 256, 256], ...
    'height',256, ...
    'width',256, ...
    'depth',256, ...
    'nframes',0, ...
    'vox2ras',eye(4), ...
    'nvoxels',256^3, ...
    'xsize',1, ...
    'ysize',1, ...
    'zsize',1, ...
    'x_r',1, ...
    'x_a',0, ...
    'x_s',0, ...
    'y_r',0, ...
    'y_a',1, ...
    'y_s',0, ...
    'z_r',0, ...
    'z_a',0, ...
    'z_s',1, ...
    'c_r',0, ...
    'c_a',0, ...
    'c_s',0, ...
    'vox2ras1',eye(4), ...
    'Mdc',eye(3), ...
    'volres',[], ...
    'tkrvox2ras',eye(4) ...
    );
