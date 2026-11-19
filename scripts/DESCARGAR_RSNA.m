function DESCARGAR_RSNA(nPacPorClase, destino, soloEtiquetas)
% Descarga parcial de RSNA Screening Mammography (Kaggle) balanceada por densidad A-D,
% para validacion externa de los modelos de densidad (mamografia digital FFDM).
% Requiere: haber aceptado las reglas de la competencia y el token de la API de Kaggle
% (kaggle.json) en %USERPROFILE%\.kaggle\ o en Descargas. El token NO se muestra ni se copia.
% Por defecto 300 pacientes por densidad (~1200 pacientes, ~4800 imagenes, ~28 GB) en D:\RSNA.
% Reanudable: volver a ejecutar continua donde quedo.
if nargin < 1 || isempty(nPacPorClase), nPacPorClase = 300; end
if nargin < 2 || isempty(destino), destino = 'D:\RSNA'; end
if nargin < 3, soloEtiquetas = false; end   % true: no descarga; solo arma la tabla con lo ya bajado
log = fullfile(getenv('USERPROFILE'), 'Downloads', 'tesis2026', 'descarga_rsna.txt');
fid = fopen(log, 'a'); c = onCleanup(@() fclose(fid));
msg = @(varargin) registrar(fid, sprintf(varargin{:}));

% ---------- Token ----------
cand = {fullfile(getenv('USERPROFILE'), '.kaggle', 'kaggle.json'), fullfile(getenv('USERPROFILE'), 'Downloads', 'kaggle.json')};
cand = cand(cellfun(@isfile, cand));
assert(~isempty(cand), 'No se encontro kaggle.json (Kaggle > Settings > API > Create New Token)');
tok = jsondecode(fileread(cand{1}));
auth = ['Basic ' matlab.net.base64encode(uint8([tok.username ':' tok.key]))];   % autenticacion preventiva (Kaggle no envia desafio 401)
op = weboptions('HeaderFields', {'Authorization', auth}, 'Timeout', 900);
clear auth
clear tok
api = 'https://www.kaggle.com/api/v1/competitions/data/download/rsna-breast-cancer-detection/';
if ~isfolder(destino), mkdir(destino); end
dirImg = fullfile(destino, 'train_images'); if ~isfolder(dirImg), mkdir(dirImg); end
f = java.io.File(destino(1:3)).getUsableSpace() / 1e9;
msg('Destino %s | %.1f GB libres', destino, f);

% ---------- train.csv ----------
csv = fullfile(destino, 'train.csv');
if ~isfile(csv)
    tmp = fullfile(destino, 'train_csv.tmp');
    websave(tmp, [api 'train.csv'], op);
    desempacar(tmp, destino, csv);
    msg('train.csv descargado');
end
T = readtable(csv, 'TextType', 'string');
T = T(~ismissing(T.density) & T.density ~= "" & ismember(T.view, ["CC" "MLO"]), :);
msg('train.csv: %d imagenes CC/MLO con densidad | %d pacientes', height(T), numel(unique(T.patient_id)));

% ---------- Seleccion balanceada por paciente (semilla fija) ----------
[g, pid] = findgroups(T.patient_id);
densPac = splitapply(@(d) moda(d), T.density, g);
rng(2026);
sel = [];
for L = ["A" "B" "C" "D"]
    p = pid(densPac == L); p = p(randperm(numel(p)));
    sel = [sel; p(1:min(nPacPorClase, numel(p)))]; %#ok<AGROW>
    msg('Densidad %s: %d pacientes disponibles, %d seleccionados', L, sum(densPac == L), min(nPacPorClase, numel(p)));
end
S = T(ismember(T.patient_id, sel), :);
msg('Imagenes a descargar: %d', height(S));

% ---------- Descarga imagen por imagen ----------
t0 = tic; ok = 0; fallas = 0; bytes = 0; espera429 = 30; pausaEntre = 2;   % ritmo moderado para no saturar la API
for i = 1:height(S) * ~soloEtiquetas
    rel = sprintf('train_images/%d/%d.dcm', S.patient_id(i), S.image_id(i));
    dst = fullfile(dirImg, num2str(S.patient_id(i)), sprintf('%d.dcm', S.image_id(i)));
    if isfile(dst), ok = ok + 1; continue; end
    if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
    for intento = 1:3
        try
            tmp = [dst '.tmp'];
            websave(tmp, [api strrep(rel, '/', '%2F')], op);
            desempacar(tmp, fileparts(dst), dst);
            ok = ok + 1; d = dir(dst); bytes = bytes + d.bytes; espera429 = max(30, espera429 / 2); pause(pausaEntre); break
        catch ME
            if contains(ME.message, '429')          % Kaggle limita la tasa: esperar y reintentar (sin contar como falla)
                espera = espera429 * 2; espera429 = min(espera, 900);
                msg('Kaggle 429 (demasiadas solicitudes): espera %d s', espera429); pause(espera429);
                if intento == 3, fallas = fallas + 1; msg('FALLA %s: %s', rel, ME.message); end
            elseif intento == 3, fallas = fallas + 1; msg('FALLA %s: %s', rel, ME.message); else, pause(15); end
        end
    end
    if mod(i, 50) == 0 || i == height(S)
        el = toc(t0) / 60;
        msg('%d/%d | OK %d | fallas %d | %.1f GB | %.1f min (resta ~%.0f min)', i, height(S), ok, fallas, bytes/1e9, el, el/i*(height(S)-i));
    end
end

% ---------- Tabla de etiquetas (mismo formato que CBIS: PatientID, vista, densidad, ACR, archivo) ----------
S.archivo = string(fullfile(dirImg, string(S.patient_id), string(S.image_id) + ".dcm"));
S = S(isfile(S.archivo), :);
E = table("RSNA_" + string(S.patient_id) + "_" + string(S.image_id), ...
    "R" + string(S.patient_id) + "_" + string(S.patient_id) + "_" + replace(S.laterality, ["L" "R"], ["LEFT" "RIGHT"]) + "_" + S.view, ...
    double(categorical(S.density, ["A" "B" "C" "D"])), S.density, S.archivo, ...
    'VariableNames', {'PatientID', 'vista', 'densidad', 'ACR', 'archivo'});
writetable(E, fullfile(destino, 'RSNA_etiquetas_densidad.csv'));
msg('Etiquetas: %d imagenes | A %d B %d C %d D %d', height(E), sum(E.ACR == "A"), sum(E.ACR == "B"), sum(E.ACR == "C"), sum(E.ACR == "D"));
msg('DESCARGA RSNA FINALIZADA en %.1f min. Carpeta: %s', toc(t0)/60, destino);
end

function desempacar(tmp, carpeta, dst)
% La API puede devolver el archivo directo o comprimido en zip
f = fopen(tmp, 'r'); m = fread(f, 2, '*uint8')'; fclose(f);
if isequal(m, uint8('PK'))
    z = unzip(tmp, carpeta); delete(tmp);
    if ~isfile(dst), movefile(z{1}, dst); end
else
    movefile(tmp, dst);
end
end

function m = moda(d)
[u, ~, j] = unique(d); m = u(mode(j));
end

function registrar(fid, s)
s = sprintf('[%s] %s', datestr(now, 'HH:MM:SS'), s); %#ok<TNOW1,DATST>
fprintf('%s\n', s); fprintf(fid, '%s\n', s);
end
