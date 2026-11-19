function DESCARGAR_CBIS_DDSM(subconjuntos, destinoRaiz)
% Descarga CBIS-DDSM (TCIA, licencia CC BY 3.0) para validacion externa de densidad.
% Por defecto: solo mamografias completas de PRUEBA (Mass-Test + Calc-Test, ~700 imagenes).
% Uso:  DESCARGAR_CBIS_DDSM                                 % prueba, disco con mas espacio
%       DESCARGAR_CBIS_DDSM(["Mass-Test" "Calc-Test" "Mass-Training" "Calc-Training"])  % todas las completas
% Reanudable: si se interrumpe, volver a ejecutar y salta lo ya descargado.
% Cita obligatoria: Sawyer-Lee R, et al. CBIS-DDSM. TCIA 2016. doi:10.7937/K9/TCIA.2016.7O02S9CY
if nargin < 1 || isempty(subconjuntos), subconjuntos = ["Mass-Test" "Calc-Test"]; end
subconjuntos = string(subconjuntos);
log = fullfile(getenv('USERPROFILE'), 'Downloads', 'tesis2026', 'descarga_cbis.txt');
fid = fopen(log, 'a'); c = onCleanup(@() fclose(fid));
msg = @(varargin) registrar(fid, sprintf(varargin{:}));

% ---------- 1. Disco con mas espacio libre ----------
if nargin < 2 || isempty(destinoRaiz)
    mejor = ""; libre = -1;
    for d = 'CDEFGH'
        r = [d ':\'];
        if isfolder(r)
            f = java.io.File(r).getUsableSpace() / 1e9;
            msg('Disco %s libre %.1f GB', r, f);
            if f > libre, libre = f; mejor = string(r); end
        end
    end
    destinoRaiz = fullfile(mejor, 'CBIS-DDSM');
    msg('Destino elegido: %s (%.1f GB libres)', destinoRaiz, libre);
    if libre < 40, error('Menos de 40 GB libres en el mejor disco; libere espacio.'); end
end
if ~isfolder(destinoRaiz), mkdir(destinoRaiz); end
dirDicom = fullfile(destinoRaiz, 'DICOM'); if ~isfolder(dirDicom), mkdir(dirDicom); end
op = weboptions('Timeout', 600);
% Copias parciales ya existentes en el PC (descarga NBIA previa): no se vuelven a bajar
previas = ["G:\tesis-base de datos\data\manifest-ZkhPvrLo5216730872708713142\CBIS-DDSM" ...
           "D:\tesi data\manifest-ZkhPvrLo5216730872708713142\CBIS-DDSM"];
previas = previas(isfolder(previas));
msg('Copias previas encontradas: %s', strjoin([previas ""], ' | '));

% ---------- 2. CSV de descripcion (contienen la densidad BI-RADS 1-4) ----------
base = 'https://wiki.cancerimagingarchive.net/download/attachments/22516629/';
csvs = {'mass_case_description_test_set.csv?version=1&modificationDate=1506796343175&api=v2', ...
        'calc_case_description_test_set.csv?version=1&modificationDate=1506796343686&api=v2', ...
        'mass_case_description_train_set.csv?version=1&modificationDate=1506796355038&api=v2', ...
        'calc_case_description_train_set.csv?version=1&modificationDate=1506796349666&api=v2'};
for k = 1:numel(csvs)
    nom = extractBefore(csvs{k}, '?'); dst = fullfile(destinoRaiz, nom);
    if ~isfile(dst)
        try, websave(dst, [base csvs{k}], op); msg('CSV OK: %s', nom);
        catch ME, msg('CSV FALLA %s: %s', nom, ME.message); end
    end
end

% ---------- 3. Lista de series (API publica NBIA v1, sin cuenta) ----------
api = 'https://services.cancerimagingarchive.net/nbia-api/services/v1/';
S = webread([api 'getSeries'], 'Collection', 'CBIS-DDSM', 'format', 'json', op);
if isstruct(S), S = struct2table(S); end
pid = string(S.PatientID); des = lower(string(S.SeriesDescription));
sel = startsWith(pid, subconjuntos) & contains(des, 'full');
% Las imagenes completas no tienen sufijo _1, _2 (esos son recortes/mascaras)
sel = sel & ~endsWith(pid, "_" + digitsPattern(1));
S = S(sel, :);
msg('Series a descargar: %d (subconjuntos: %s)', height(S), strjoin(subconjuntos, ', '));

% ---------- 4. Descarga ----------
t0 = tic; okN = 0; falla = 0; previa = 0;
for i = 1:height(S)
    p = string(S.PatientID(i)); carpeta = fullfile(dirDicom, p);
    if buscar_dcm(p, dirDicom, previas) ~= "", okN = okN + 1; previa = previa + 1; continue; end
    z = fullfile(tempdir, 'cbis_tmp.zip');
    for intento = 1:3
        try
            websave(z, [api 'getImage?SeriesInstanceUID=' char(S.SeriesInstanceUID(i))], op);
            if ~isfolder(carpeta), mkdir(carpeta); end
            unzip(z, carpeta); delete(z); okN = okN + 1; break
        catch ME
            if intento == 3, falla = falla + 1; msg('FALLA %s: %s', p, ME.message); else, pause(10); end
        end
    end
    if mod(i, 20) == 0 || i == height(S)
        msg('%d/%d series | OK %d (ya existentes %d) | fallas %d | %.1f min', i, height(S), okN, previa, falla, toc(t0)/60);
    end
end

% ---------- 5. Tabla de etiquetas (id, densidad 1-4 -> A-D, ruta DICOM) ----------
E = table();
for k = 1:numel(csvs)
    f = fullfile(destinoRaiz, extractBefore(csvs{k}, '?'));
    if ~isfile(f), continue; end
    T = readtable(f, 'VariableNamingRule', 'preserve');
    v = T.Properties.VariableNames;
    cD = v{find(contains(lower(v), 'density'), 1)};
    id = "P_" + compose('%05d', str2double(erase(string(T.patient_id), 'P_'))) + "_" + string(T.("left or right breast")) + "_" + string(T.("image view"));
    tipo = "Mass"; if startsWith(extractBefore(csvs{k}, '?'), 'calc'), tipo = "Calc"; end
    parte = "Test"; if contains(csvs{k}, 'train'), parte = "Training"; end
    E = [E; table(tipo + "-" + parte + "_" + id, id, T.(cD), 'VariableNames', {'PatientID', 'vista', 'densidad'})]; %#ok<AGROW>
end
if ~isempty(E)
    [~, u] = unique(E.PatientID); E = E(u, :);
    letras = 'ABCD'; E.ACR = string(letras(min(max(E.densidad, 1), 4))');
    E.archivo = strings(height(E), 1);
    for i = 1:height(E)
        E.archivo(i) = buscar_dcm(E.PatientID(i), dirDicom, previas);
    end
    E = E(E.archivo ~= "", :);
    % Una misma vista puede figurar como Mass y Calc: se conserva una sola imagen por vista
    [~, u] = unique(E.vista); E = E(u, :);
    writetable(E, fullfile(destinoRaiz, 'CBIS_DDSM_etiquetas_densidad.csv'));
    msg('Etiquetas: %d imagenes unicas | A %d B %d C %d D %d', height(E), sum(E.ACR == "A"), sum(E.ACR == "B"), sum(E.ACR == "C"), sum(E.ACR == "D"));
end
msg('DESCARGA FINALIZADA en %.1f min. Carpeta: %s', toc(t0)/60, destinoRaiz);
end

function f = buscar_dcm(p, dirDicom, previas)
f = "";
for r = [string(dirDicom) previas]
    if isfolder(fullfile(r, p))
        L = dir(fullfile(r, p, '**', '*.dcm'));
        if ~isempty(L), f = string(fullfile(L(1).folder, L(1).name)); return; end
    end
end
end

function registrar(fid, s)
s = sprintf('[%s] %s', datestr(now, 'HH:MM:SS'), s); %#ok<TNOW1,DATST>
fprintf('%s\n', s); fprintf(fid, '%s\n', s);
end
