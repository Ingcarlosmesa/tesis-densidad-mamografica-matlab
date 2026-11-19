function diag_v13()
fid = fopen('diag_v13.txt', 'w');
fprintf(fid, 'G existe: %d | INbreast.csv: %d\n', isfolder('G:\'), isfile('G:\tesis-base de datos\INbreast Release 1.0\INbreast.csv'));
try
    e = MException.last;
    fprintf(fid, 'Ultimo error: %s\n', e.message);
    for k = 1:numel(e.stack), fprintf(fid, '  %s linea %d\n', e.stack(k).name, e.stack(k).line); end
catch
    fprintf(fid, 'Ultimo error (lasterr): %s\n', lasterr); %#ok<LERR>
end
L = dir('G:\tesis-base de datos\INbreast Release 1.0\AllDICOMs\*.dcm');
fprintf(fid, 'DICOM INbreast: %d\n', numel(L));
if ~isempty(L)
    try
        f = fullfile(L(1).folder, L(1).name); info = dicominfo(f); I = dicomread(info);
        fprintf(fid, 'Lectura OK: %s %dx%d\n', L(1).name, size(I, 1), size(I, 2));
    catch ME
        fprintf(fid, 'Lectura FALLA: %s\n', ME.message);
    end
end
fclose(fid);
end
