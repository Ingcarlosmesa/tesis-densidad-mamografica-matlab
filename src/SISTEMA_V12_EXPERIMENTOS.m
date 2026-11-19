function SISTEMA_V12_EXPERIMENTOS(cfgUsuario)
%% ==========================================================================================
%  SISTEMA V12 - EXPERIMENTOS COMPLEMENTARIOS (no modifica SISTEMA_V12_RED_NEURONAL.m)
%  Reutiliza las mismas funciones locales (indexado, preprocesamiento en cache, construccion
%  de redes, entrenamiento AdamW con parada temprana por kappa, evaluacion a nivel de mama con
%  IC95% bootstrap por paciente). Por defecto ejecuta:
%    E1  ResNet-50 (ImageNet), lr 1e-4, en los 5 pliegues de validacion (variabilidad entre
%        pliegues) + ensamble (promedio de probabilidades de los 5 modelos)
%    E2  ViT-B/16 (ImageNet-384) solo, lr 1e-5 (la corrida principal con lr 1e-4 no aprendio)
%  El conjunto de prueba es el MISMO de la corrida principal (particion por paciente, semilla).
%  CMMD/IGR, federado y DDPM no se ejecutan aqui.
%
%  USO
%    >> c.opt.microLote = 4; c.opt.maxEpocas = 15; c.opt.paciencia = 5;
%    >> SISTEMA_V12_EXPERIMENTOS(c)
%    Experimentos propios:
%    >> c.experimentos = struct('nombre', {'vit_lr3e-5'}, 'modelo', {'vit'}, 'lr', {3e-5}, 'folds', {1});
%% ==========================================================================================
if nargin < 1, cfgUsuario = struct(); end
EXP = struct('nombre', {'resnet50_lr1e-4', 'vit_lr1e-5'}, 'modelo', {'resnet50', 'vit'}, ...
    'lr', {1e-4, 1e-5}, 'folds', {1:5, 1});
if isfield(cfgUsuario, 'experimentos'), EXP = cfgUsuario.experimentos; cfgUsuario = rmfield(cfgUsuario, 'experimentos'); end
cfg = configuracion(cfgUsuario);
assert(cfg.fuenteDensidad == "inbreast", 'Estos experimentos requieren INbreast (revise que la unidad G: este conectada).');
rng(cfg.semilla, 'twister');
warning('off', 'images:graycomatrix:scaledImageContainsNan');
warning('off', 'images:graycomatrix:imageContainsNan');
out = fullfile(cfg.salida, ['EXP_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))]);
for d = {'', 'figuras', 'tablas', 'modelos'}
    if ~isfolder(fullfile(out, d{1})), mkdir(fullfile(out, d{1})); end
end
diary(fullfile(out, 'registro_experimentos.txt')); diary on;
limpiar = onCleanup(@() diary('off'));
t0 = tic;
linea('=');
fprintf('  SISTEMA V12 - EXPERIMENTOS COMPLEMENTARIOS | Entrada %dx%d | GPU: %s\n', cfg.S, cfg.S, ternario(cfg.gpu, 'si', 'no'));
fprintf('  Salida: %s\n', out);
fprintf('  maxEpocas %d | paciencia %d | lote efectivo %d en micro-lotes de %d | nBoot %d\n', ...
    cfg.opt.maxEpocas, cfg.opt.paciencia, cfg.opt.lote, cfg.opt.microLote, cfg.nBoot);
linea('=');
verificar_entorno();

%% DATOS (mismo indexado y misma particion de prueba que la corrida principal)
fprintf('\n[1] Indexando INbreast y cargando preprocesamiento desde cache...\n');
[TR, TE] = indexar_inbreast(cfg);
[TR, excTR] = preparar_conjunto(TR, cfg, 'entrenamiento');
[TE, excTE] = preparar_conjunto(TE, cfg, 'prueba');
fprintf('    Entrenamiento %d | prueba %d imagenes | excluidas %d / %d\n', height(TR), height(TE), excTR, excTE);
TR.fold = pliegues_por_paciente(TR.paciente, TR.y, cfg.nFolds, cfg.semilla);
K = cfg.nClases;
etiq = {'kappa_cuadratico', 'exactitud', 'macroF1', 'AUC_macro', 'AUC_A', 'AUC_B', 'AUC_C', 'AUC_D', ...
    'AUC_denso', 'sensibilidad_denso', 'especificidad_denso', 'Brier_denso'};
filas = {}; RESUMEN = {};

for e = 1:numel(EXP)
    E = EXP(e);
    fprintf('\n[2.%d] Experimento %s: modelo %s, lr %.0e, pliegues %s\n', e, E.nombre, E.modelo, E.lr, mat2str(E.folds));
    cfgE = cfg; cfgE.opt.lr = E.lr;
    cols = columnas_modelo(E.modelo);
    Pacum = zeros(height(TE), K); nOK = 0; metPl = [];
    for k = E.folds
        tE = tic;
        idxTr = find(TR.fold ~= k); idxVa = find(TR.fold == k);
        Ftr = [TR.rad TR.Fstress]; mu = mean(Ftr(idxTr, :), 1); sd = std(Ftr(idxTr, :), 0, 1) + 1e-8;
        TR.feat = (Ftr - mu) ./ sd; TE.feat = ([TE.rad TE.Fstress] - mu) ./ sd;
        nombre = sprintf('%s_p%d', E.nombre, k); nombreArch = matlab.lang.makeValidName(nombre);
        fprintf('\n   >> %s | pliegue %d: %d entrenamiento / %d validacion (pacientes disjuntos)\n', ...
            nombre, k, numel(idxTr), numel(idxVa));
        rng(cfg.semilla + k, 'twister');
        [net, info] = construir_red(E.modelo, cfgE, numel(cols));
        fprintf('      %s | parametros %d\n', info.descripcion, contar_parametros(net));
        Dtr = datos_red(TR, cols); Dte = datos_red(TE, cols);
        [net, H] = entrenar_red(net, Dtr, idxTr, idxVa, cfgE, nombre);
        writetable(H, fullfile(out, 'tablas', ['historial_' nombreArch '.csv']));
        figura_curvas(H, nombreArch, out);
        P = predecir_red(net, Dte, 1:height(TE), cfgE);
        [Pb, yb, ~, pac] = agregar_mama(P, TE.y, TE.mama, TE.paciente);
        v = metricas_densidad(yb, Pb, K);
        B = bootstrap_paciente(pac, @(i) metricas_densidad(yb(i), Pb(i, :), K), cfg.nBoot, cfg.semilla);
        ci = prctile_simple_mat(B, [2.5 97.5]);
        fila = {string(E.nombre), k, max(H.kappa_val_mama), height(H)};
        for j = 1:numel(v), fila{end+1} = sprintf('%.3f [%.3f-%.3f]', v(j), ci(1, j), ci(2, j)); end %#ok<AGROW>
        filas(end+1, :) = fila; %#ok<AGROW>
        metPl(end+1, :) = v; %#ok<AGROW>
        [~, yp] = max(Pb, [], 2); figura_confusion(yb, yp, cfg, nombreArch, out);
        fprintf('      PRUEBA (nivel mama): kappa %.3f [%.3f-%.3f] | exact %.3f | AUC denso %.3f | %.1f min\n', ...
            v(1), ci(1, 1), ci(2, 1), v(2), v(9), toc(tE)/60);
        if all(isfinite(P(:))), Pacum = Pacum + P; nOK = nOK + 1; end
        if cfg.guardarModelos
            save(fullfile(out, 'modelos', [nombreArch '.mat']), 'net', 'info', 'mu', 'sd', 'cols', 'k', '-v7.3');
        end
        clear net Dtr Dte
        if cfg.gpu, reset(gpuDevice); end
    end
    % Resumen entre pliegues y ensamble
    if numel(E.folds) > 1
        m = mean(metPl, 1); s = std(metPl, 0, 1);
        fprintf('   >> %s: media +/- DE entre %d pliegues: kappa %.3f +/- %.3f | exact %.3f +/- %.3f | AUC denso %.3f +/- %.3f\n', ...
            E.nombre, numel(E.folds), m(1), s(1), m(2), s(2), m(9), s(9));
        fila = {string(E.nombre), "media+/-DE", NaN, NaN};
        for j = 1:numel(m), fila{end+1} = sprintf('%.3f +/- %.3f', m(j), s(j)); end %#ok<AGROW>
        RESUMEN(end+1, :) = fila; %#ok<AGROW>
        if nOK > 1
            [Pb, yb, ~, pac] = agregar_mama(Pacum / nOK, TE.y, TE.mama, TE.paciente);
            v = metricas_densidad(yb, Pb, K);
            B = bootstrap_paciente(pac, @(i) metricas_densidad(yb(i), Pb(i, :), K), cfg.nBoot, cfg.semilla);
            ci = prctile_simple_mat(B, [2.5 97.5]);
            fila = {string(E.nombre), "ensamble", NaN, NaN};
            for j = 1:numel(v), fila{end+1} = sprintf('%.3f [%.3f-%.3f]', v(j), ci(1, j), ci(2, j)); end %#ok<AGROW>
            RESUMEN(end+1, :) = fila; %#ok<AGROW>
            [~, yp] = max(Pb, [], 2); figura_confusion(yb, yp, cfg, matlab.lang.makeValidName([E.nombre '_ensamble']), out);
            fprintf('   >> %s ENSAMBLE (%d modelos): kappa %.3f [%.3f-%.3f] | exact %.3f | AUC denso %.3f\n', ...
                E.nombre, nOK, v(1), ci(1, 1), ci(2, 1), v(2), v(9));
        end
    end
    % Guardado parcial tras cada experimento (por si se interrumpe)
    T = cell2table(filas, 'VariableNames', [{'experimento', 'pliegue', 'mejor_kappa_val', 'epocas'} etiq]);
    writetable(T, fullfile(out, 'tablas', 'T7_experimentos_por_pliegue.csv'));
    if ~isempty(RESUMEN)
        R = cell2table(RESUMEN, 'VariableNames', [{'experimento', 'tipo', 'mejor_kappa_val', 'epocas'} etiq]);
        R = removevars(R, {'mejor_kappa_val', 'epocas'});
        writetable(R, fullfile(out, 'tablas', 'T8_experimentos_resumen.csv'));
    end
end
linea('=');
fprintf('  EXPERIMENTOS FINALIZADOS en %.1f min. Resultados en: %s\n', toc(t0)/60, out);
linea('=');
end

%% ==========================================================================================
%%  CONFIGURACION
%% ==========================================================================================
function cfg = configuracion(u)
% Rutas encontradas en este PC (se usan solo si existen)
cfg.vindrRoot   = '';                                                  % VinDr-Mammo (no hallado)
cfg.inbreastRoot = 'G:\tesis-base de datos\INbreast Release 1.0';    % INbreast (FFDM, ACR 1-4)
cfg.cbisRoot    = 'G:\tesis-base de datos\data\manifest-ZkhPvrLo5216730872708713142'; % CBIS-DDSM
%                 (copia parcial alternativa: D:\tesi data\manifest-ZkhPvrLo5216730872708713142)
cfg.fraccionPrueba = 0.15;       % INbreast sin particion oficial: 70/15/15 por paciente (tesis)
cfg.cmmdRoot    = 'F:\2021 tesis avances 2\data\manifest-1616439774456'; % CMMD (TCIA)
cfg.cmmdClinico = 'F:\2021 tesis avances 2\Mamografia\CMMD_clinicaldata_revision.xlsx';
cfg.salida      = fullfile(pwd, 'SALIDA_V12');
cfg.semilla     = 2026;
cfg.gpu         = canUseGPU;
cfg.clases      = ["A" "B" "C" "D"];
cfg.nClases     = 4;
% Preprocesamiento (seccion 2.2)
cfg.pixel_mm    = 0.1;
cfg.espaciadoDefecto = 0.05;     % mm/pixel si el DICOM no lo declara (CBIS-DDSM: escaneo ~50 um)
cfg.sigmaFlat   = 30;
cfg.mediana     = 7;
cfg.claheClip   = 0.02;
cfg.claheTiles  = [8 8];
cfg.areaMinFrac = 0.01;
cfg.featLado    = 512;           % lado mayor de trabajo para radiomica/FEM
% Red (seccion 2.5). 384 = resolucion nativa del ViT-B/16 preentrenado disponible en MATLAB
cfg.S           = 384;
cfg.usarPreentrenadas = true;
cfg.cnn.stack   = [3 4 6 3];     % ResNet-50
cfg.cnn.filtros = [64 128 256 512];
cfg.vit.patch   = 16;
cfg.vit.capas   = 12;
cfg.vit.cabezas = 12;
cfg.vit.D       = 768;
cfg.vit.mlp     = 3072;
cfg.vit.dropout = 0.1;
cfg.vit.preentrenada = "base-16-imagenet-384";
cfg.fusion.fc   = 512;
cfg.fusion.dropout = 0.5;
cfg.modelos     = ["fusion" "fusion_sinFstress" "resnet50" "vit"];
% Optimizacion
cfg.opt.lr      = 1e-4;
cfg.opt.wd      = 0.05;
cfg.opt.lote    = 16;             % lote EFECTIVO (manuscrito)
cfg.opt.microLote = 16;          % lote que cabe en la GPU; si < lote, se acumulan gradientes
cfg.opt.maxEpocas = 50;
cfg.opt.paciencia = 10;
cfg.aug.rot     = 10;
cfg.aug.escala  = [0.9 1.1];
cfg.aug.tras    = 0.05;
cfg.nFolds      = 5;              % con 15% de prueba, 1 de 5 pliegues ~ 17% de validacion
cfg.foldValidacion = 1;
% FEM (seccion 2.4)
cfg.fem.Ea      = 4.46;
cfg.fem.Eg      = 15.1;
cfg.fem.nu      = 0.49;
cfg.fem.sigRef  = 15;
cfg.fem.deform  = 0.01;          % desplazamiento compresivo (fraccion) en la piel
cfg.fem.malla   = 28;            % nodos por lado de la malla estructurada
% IGR (seccion 2.6) - preespecificado ANTES de ver el conjunto externo
cfg.igr.w       = [0.25 0.375 0.1875 0.1875];
cfg.igr.umbral  = 5.0;
cfg.igr.microNorm = 10;
% Estadistica
cfg.nBoot       = 2000;
% Federado y DDPM
cfg.fed.activo  = true;  cfg.fed.K = 5; cfg.fed.rondas = 30; cfg.fed.epLocal = 2;
cfg.fed.lr      = 1e-3;  cfg.fed.alphaDir = 0.5;
cfg.ddpm.activo = true;  cfg.ddpm.T = 300; cfg.ddpm.lado = 64; cfg.ddpm.iter = 4000;
cfg.ddpm.lote   = 32;    cfg.ddpm.lr = 2e-4; cfg.ddpm.tEval = 100; cfg.ddpm.nMuestras = 16;
% Fantoma
cfg.fantoma.lado = 320; cfg.fantoma.pacTr = 60; cfg.fantoma.pacTe = 25; cfg.fantoma.pacExt = 40;
cfg.guardarModelos = true;
% Verificacion DICOM [0]
cfg.soloVerificarDICOM = false;
cfg.forzarFantoma = false;
cfg.verif.activo = true;
cfg.verif.raices = {'C:\', 'D:\', 'F:\', 'G:\', 'J:\'};   % las que no existan se omiten
cfg.verif.pixelesTodo = false;    % false: pixeles solo en mamografia (MG/OT/CR/DX); RM solo cabecera
cfg.verif.reescanear = false;     % true: vuelve a recorrer las unidades aunque exista la lista en cache
cfg.verif.bloque = 200;           % carpetas por bloque (progreso y guardado)

uu = fusionar_struct(cfg, u);
cfg.fuenteDensidad = "fantoma";
if uu.forzarFantoma
    % se mantiene "fantoma"
elseif ~isempty(uu.vindrRoot) && isfolder(uu.vindrRoot)
    cfg.fuenteDensidad = "vindr";
elseif ~isempty(uu.inbreastRoot) && isfile(fullfile(uu.inbreastRoot, 'INbreast.csv'))
    cfg.fuenteDensidad = "inbreast";
elseif ~isempty(uu.cbisRoot) && isfolder(uu.cbisRoot) && ~isempty(buscar_descripciones_cbis(uu.cbisRoot))
    cfg.fuenteDensidad = "cbis";
end
cfg.modoFantoma = cfg.fuenteDensidad == "fantoma";
if cfg.modoFantoma
    % Tamano reducido para que la verificacion corra en CPU en tiempo razonable.
    cfg.S = 128; cfg.usarPreentrenadas = false;
    cfg.vit.D = 192; cfg.vit.cabezas = 3; cfg.vit.mlp = 768;      % mismas 12 capas
    cfg.opt.maxEpocas = 15; cfg.opt.paciencia = 5;
    cfg.nBoot = 500; cfg.fed.rondas = 15; cfg.ddpm.iter = 800; cfg.ddpm.T = 200;
    cfg.verif.activo = false;     % el fantoma no usa archivos DICOM
end
cfg = fusionar_struct(cfg, u);
cfg.cache = fullfile(cfg.salida, 'cache');
assert(mod(cfg.S, cfg.vit.patch) == 0, 'cfg.S debe ser multiplo de cfg.vit.patch');
assert(mod(cfg.vit.D, cfg.vit.cabezas) == 0, 'cfg.vit.D debe ser divisible por cfg.vit.cabezas');
end

function a = fusionar_struct(a, b)
for f = fieldnames(b)'
    k = f{1};
    if isstruct(b.(k)) && isfield(a, k) && isstruct(a.(k))
        a.(k) = fusionar_struct(a.(k), b.(k));
    else
        a.(k) = b.(k);
    end
end
end

function out = preparar_salida(cfg)
out = fullfile(cfg.salida, ['V12_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))]);
for d = {'', 'figuras', 'tablas', 'modelos'}
    if ~isfolder(fullfile(out, d{1})), mkdir(fullfile(out, d{1})); end
end
if ~isfolder(cfg.cache), mkdir(cfg.cache); end
end

function verificar_entorno()
if isMATLABReleaseOlderThan("R2024a")
    error('Se requiere MATLAB R2024a o posterior (resnetNetwork, dlnetwork vacio, imagePretrainedNetwork).');
end
req = {'Neural_Network_Toolbox', 'Deep Learning Toolbox'; 'Image_Toolbox', 'Image Processing Toolbox'};
for k = 1:size(req, 1)
    if ~license('test', req{k, 1}), error('Falta %s.', req{k, 2}); end
end
end

%% ==========================================================================================
%%  [0] VERIFICACION DE CADA ARCHIVO DICOM (todas las unidades, reanudable)
%% ==========================================================================================
function V = verificar_dicom(cfg, out)
dirV = fullfile(cfg.cache, 'verif_dicom'); if ~isfolder(dirV), mkdir(dirV); end
C = listar_carpetas_dicom(cfg.verif.raices, cfg, dirV);
n = numel(C);
fprintf('       %d carpetas con DICOM. Verificando archivo por archivo (cache: %s)\n', n, dirV);
R = cell(n, 1); t0 = tic; nArch = 0;
for b0 = 1:cfg.verif.bloque:n
    ii = b0:min(b0 + cfg.verif.bloque - 1, n);
    Cb = C(ii); Rb = cell(numel(ii), 1);
    parfor j = 1:numel(ii)
        Rb{j} = verificar_carpeta(Cb{j}, dirV, cfg);
    end
    R(ii) = Rb;
    nArch = nArch + sum(cellfun(@height, Rb));
    fprintf('       %d/%d carpetas | %d archivos | %.1f min\n', ii(end), n, nArch, toc(t0)/60);
end
R = R(~cellfun(@isempty, R));
if isempty(R), V = table(); fprintf('       No se hallaron archivos DICOM.\n'); return; end
V = vertcat(R{:});
% Duplicados (misma SOPInstanceUID en varias copias, p. ej. D:\tesi data vs G:\)
V.duplicado = false(height(V), 1);
ok = V.uid ~= "";
[~, ~, k] = unique(V.uid(ok)); cnt = accumarray(k, 1); V.duplicado(ok) = cnt(k) > 1;
% Resumen por coleccion
[g, col] = findgroups(V.coleccion);
unir = @(s) strjoin(unique(s(s ~= "")), ",");
RC = table(col, splitapply(@numel, V.bytes, g), ...
    splitapply(@(e) sum(e == "OK"), V.estado, g), splitapply(@(e) sum(e == "ADVERTENCIA"), V.estado, g), ...
    splitapply(@(e) sum(e == "ERROR"), V.estado, g), splitapply(@(e) sum(e == "EXCLUIDO"), V.estado, g), ...
    splitapply(@(p) numel(unique(p(p ~= ""))), V.paciente, g), ...
    splitapply(@(t) sum(t == "mamografia_completa"), V.tipo, g), ...
    splitapply(@(t) sum(t == "mascara_ROI"), V.tipo, g), splitapply(@(t) sum(t == "recorte_ROI"), V.tipo, g), ...
    splitapply(@sum, V.duplicado, g), splitapply(unir, V.modalidad, g), splitapply(unir, V.intencion, g), ...
    splitapply(@(b) sum(b) / 1e9, V.bytes, g), ...
    'VariableNames', {'coleccion', 'archivos', 'OK', 'ADVERTENCIA', 'ERROR', 'EXCLUIDO', 'pacientes', ...
    'mamografias_completas', 'mascaras_ROI', 'recortes_ROI', 'duplicados_UID', 'modalidades', ...
    'intencion_presentacion', 'GB'});
RC = sortrows(RC, 'archivos', 'descend');
% Motivos mas frecuentes de ERROR / ADVERTENCIA
m = V(V.estado == "ERROR" | V.estado == "ADVERTENCIA", :);
RM = table();
if ~isempty(m)
    [gm, ce, cm] = findgroups(m.estado, m.motivo);
    RM = sortrows(table(ce, cm, splitapply(@numel, m.bytes, gm), 'VariableNames', {'estado', 'motivo', 'archivos'}), ...
        'archivos', 'descend');
end
writetable(V, fullfile(out, 'tablas', 'verificacion_dicom_archivos.csv'), 'Encoding', 'UTF-8');
writetable(RC, fullfile(out, 'tablas', 'verificacion_dicom_colecciones.csv'), 'Encoding', 'UTF-8');
if ~isempty(RM), writetable(RM, fullfile(out, 'tablas', 'verificacion_dicom_motivos.csv'), 'Encoding', 'UTF-8'); end
% Informe de texto
fid = fopen(fullfile(out, 'INFORME_VERIFICACION_DICOM.txt'), 'w', 'n', 'UTF-8');
fprintf(fid, 'VERIFICACION DICOM - %s\nUnidades: %s\n', char(datetime('now')), strjoin(string(cfg.verif.raices), ', '));
fprintf(fid, 'Archivos: %d | OK %d | ADVERTENCIA %d | ERROR %d | EXCLUIDO (no DICOM) %d | %.1f GB\n\n', height(V), ...
    sum(V.estado == "OK"), sum(V.estado == "ADVERTENCIA"), sum(V.estado == "ERROR"), sum(V.estado == "EXCLUIDO"), sum(V.bytes) / 1e9);
fprintf(fid, '%s\n', formattedDisplayText(RC, 'SuppressMarkup', true));
if ~isempty(RM), fprintf(fid, '\nMOTIVOS\n%s\n', formattedDisplayText(RM(1:min(40, end), :), 'SuppressMarkup', true)); end
fclose(fid);
fprintf('       Total %d archivos: OK %d | ADVERTENCIA %d | ERROR %d | EXCLUIDO %d\n', height(V), ...
    sum(V.estado == "OK"), sum(V.estado == "ADVERTENCIA"), sum(V.estado == "ERROR"), sum(V.estado == "EXCLUIDO"));
disp(RC(:, {'coleccion', 'archivos', 'OK', 'ADVERTENCIA', 'ERROR', 'EXCLUIDO', 'pacientes', 'mamografias_completas', 'duplicados_UID'}));
end

function C = listar_carpetas_dicom(raices, cfg, dirV)
% Lista las carpetas que contienen archivos .dcm/.dicom/.dic (recorrido iterativo con exclusiones)
raices = cellstr(string(raices));
fcache = fullfile(dirV, ['carpetas_' hash_texto(strjoin(raices, '|')) '.mat']);
if isfile(fcache) && ~cfg.verif.reescanear
    s = load(fcache); C = s.C; fprintf('       Lista de carpetas tomada de cache (%d)\n', numel(C)); return;
end
excl = lower(["windows" "program files" "program files (x86)" "programdata" "appdata" "$recycle.bin" ...
    "system volume information" "recovery" "perflogs" "config.msi" "msocache" "windowsapps" "node_modules" ...
    ".git" "__macosx" "$windows.~bt" "$windows.~ws" "onedrivetemp" "anaconda3" "site-packages" ...
    "application data" "local settings" "documents and settings" "configuración local" "datos de programa" ...
    "mis documentos" "my documents" "cookies" "menú inicio" "start menu" "plantillas" "templates" "salida_v12"]);
% Carpetas de la instalacion de MATLAB (matlabroot puede ser la raiz de una unidad, p. ej. D:\)
raizML = regexprep(matlabroot, '[\\/]+$', '');
prefML = lower(string(raizML) + filesep + ["bin" "toolbox" "sys" "extern" "java" "resources" "help" ...
    "examples" "derived" "ui" "rtw" "simulink" "polyspace" "licenses" "mcr" "runtime" "cefclient" ...
    "notebook" "settings" "platform" "lib" "etc" "standalone" "appdata" "interprocess" "SupportPackages"]);
C = {}; nC = 0; t0 = tic;
for u = 1:numel(raices)
    raiz = raices{u};
    if ~isfolder(raiz), fprintf('       %s no existe, se omite\n', raiz); continue; end
    fprintf('       Recorriendo %s ...\n', raiz);
    pila = {raiz};
    while ~isempty(pila)
        c = pila{end}; pila(end) = []; nC = nC + 1;
        if mod(nC, 5000) == 0
            fprintf('         %d carpetas revisadas | %d con DICOM | %.0f s\n', nC, numel(C), toc(t0));
        end
        try, L = dir(c); catch, continue; end
        L = L(~ismember({L.name}, {'.', '..'}));
        if isempty(L), continue; end
        esDir = [L.isdir];
        for s = find(esDir)
            ruta = fullfile(c, L(s).name);
            if any(lower(string(L(s).name)) == excl) || any(startsWith(lower(string(ruta)), prefML)), continue; end
            if numel(strfind(ruta, filesep)) > 16, continue; end
            pila{end+1} = ruta; %#ok<AGROW>
        end
        F = L(~esDir);
        if isempty(F), continue; end
        [~, ~, e] = cellfun(@fileparts, {F.name}, 'UniformOutput', false);
        if any(ismember(lower(e), {'.dcm', '.dicom', '.dic'})), C{end+1} = c; end %#ok<AGROW>
    end
end
fprintf('       Recorrido: %d carpetas en %.0f s\n', nC, toc(t0));
save(fcache, 'C');
end

function T = verificar_carpeta(c, dirV, cfg)
fm = fullfile(dirV, ['c_' hash_texto(c) '.mat']);
if isfile(fm)
    s = load(fm); T = s.T; return;
end
L = dir(c); L = L(~[L.isdir]);
T = table();
if isempty(L), return; end
[~, ~, e] = cellfun(@fileparts, {L.name}, 'UniformOutput', false);
L = L(ismember(lower(e), {'.dcm', '.dicom', '.dic'}));
if isempty(L), return; end
filas = cell(numel(L), 1);
for k = 1:numel(L)
    filas{k} = verificar_archivo(fullfile(c, L(k).name), L(k).bytes, cfg);
end
T = struct2table(vertcat(filas{:}), 'AsArray', true);
save(fm, 'T');
end

function r = verificar_archivo(f, bytes, cfg)
r = struct('ruta', string(f), 'coleccion', coleccion_de(f), 'estado', "OK", 'motivo', "", ...
    'modalidad', "", 'sop', "", 'intencion', "", 'fabricante', "", 'fotometrica', "", ...
    'filas', NaN, 'columnas', NaN, 'bits', NaN, 'espaciado_mm', NaN, 'vista', "", 'lateralidad', "", ...
    'paciente', "", 'serie', "", 'uid', "", 'tipo', "", 'pix_min', NaN, 'pix_max', NaN, ...
    'pix_desv', NaN, 'frac_fondo', NaN, 'frac_saturado', NaN, 'bytes', double(bytes));
[~, nom] = fileparts(f);
if startsWith(nom, "._")
    r.estado = "EXCLUIDO"; r.motivo = "AppleDouble de macOS (no es DICOM)"; r.tipo = "no_dicom"; return;
end
if bytes < 1024
    r.estado = "ERROR"; r.motivo = "archivo vacio o truncado (<1 KB)"; return;
end
try
    info = dicominfo(f);
catch ME
    r.estado = "ERROR"; r.motivo = "cabecera ilegible: " + string(ME.message); return;
end
tx = @(nombres) strtrim(string(campo(info, nombres, "")));
r.modalidad = upper(tx({'Modality'}));
r.sop = tx({'SOPClassUID'});
r.intencion = upper(tx({'PresentationIntentType'}));
r.fabricante = tx({'Manufacturer'});
r.fotometrica = upper(tx({'PhotometricInterpretation'}));
r.paciente = tx({'PatientID'});
r.serie = tx({'SeriesDescription'});
r.uid = tx({'SOPInstanceUID'});
r.filas = double(campo(info, {'Rows'}, NaN));
r.columnas = double(campo(info, {'Columns'}, NaN));
r.bits = double(campo(info, {'BitsStored', 'BitsAllocated'}, NaN));
ps = campo(info, {'ImagerPixelSpacing', 'PixelSpacing'}, NaN); r.espaciado_mm = double(ps(1));
% vista y lateralidad: cabecera, y si falta, el nombre de archivo/carpeta
r.vista = upper(tx({'ViewPosition'}));
t = regexp(upper(f), '(?<![A-Z])(CC|MLO|ML)(?![A-Z])', 'match', 'once');
if r.vista == "" && ~isempty(t), r.vista = string(t); end
r.lateralidad = upper(tx({'ImageLaterality', 'Laterality'}));
if r.lateralidad == ""
    t = regexp(upper(f), '(LEFT|RIGHT|(?<=_)[LR](?=_))', 'match', 'once');
    if ~isempty(t), r.lateralidad = string(t(1)); end
end
esMamo = ismember(r.modalidad, ["MG" "OT" "CR" "DX"]) || startsWith(r.sop, "1.2.840.10008.5.1.4.1.1.1.2");
adv = strings(0);
if ~esMamo && ~cfg.verif.pixelesTodo
    r.tipo = lower(r.modalidad);
    if isnan(r.filas) || isnan(r.columnas), adv(end+1) = "sin Rows/Columns"; end
else
    try
        I = dicomread(info);
    catch ME
        r.estado = "ERROR"; r.motivo = "pixeles ilegibles: " + string(ME.message); return;
    end
    if isempty(I), r.estado = "ERROR"; r.motivo = "matriz de pixeles vacia"; return; end
    I = I(:, :, 1, 1);
    if size(I, 1) ~= r.filas || size(I, 2) ~= r.columnas
        adv(end+1) = sprintf("dimensiones %dx%d distintas de la cabecera", size(I, 1), size(I, 2));
    end
    vs = I(1:5:end);                                     % muestra sistematica (rapidez)
    v = double(vs);
    r.pix_min = min(v); r.pix_max = max(v); r.pix_desv = std(v);
    if r.pix_max == r.pix_min
        r.estado = "ERROR"; r.motivo = "imagen constante (sin informacion)"; return;
    end
    fondo = ternario(r.fotometrica == "MONOCHROME1", r.pix_max, r.pix_min);
    r.frac_fondo = mean(v == fondo);
    if ~isnan(r.bits), r.frac_saturado = mean(v >= 2^r.bits - 1); end
    serie = lower(r.serie + " " + string(f));
    if contains(serie, "roi mask") || contains(serie, "cropped")
        r.tipo = ternario(numel(unique(vs)) <= 2, "mascara_ROI", "recorte_ROI");
    elseif esMamo
        r.tipo = "mamografia_completa";
    else
        r.tipo = lower(r.modalidad);
    end
    if r.tipo == "mamografia_completa"
        if r.frac_fondo > 0.97, adv(end+1) = "imagen casi vacia (>97% fondo)"; end
        if r.frac_saturado > 0.20, adv(end+1) = "saturacion >20%"; end
        if isnan(r.espaciado_mm), adv(end+1) = "sin espaciado de pixel (se usa valor por defecto)"; end
        if ~ismember(r.vista, ["CC" "MLO" "ML"]), adv(end+1) = "vista CC/MLO no identificada"; end
        if r.lateralidad == "", adv(end+1) = "lateralidad no identificada"; end
        if min(size(I)) < 512, adv(end+1) = "resolucion baja (<512 px)"; end
    end
end
if r.uid == "", adv(end+1) = "sin SOPInstanceUID"; end
if ~isempty(adv), r.estado = "ADVERTENCIA"; r.motivo = strjoin(adv, "; "); end
end

function c = coleccion_de(f)
u = upper(string(f));
if contains(u, "INBREAST"), c = "INbreast";
elseif contains(u, "CBIS-DDSM"), c = "CBIS-DDSM";
elseif contains(u, "CMMD"), c = "CMMD";
elseif contains(u, "DUKE-BREAST-CANCER-MRI"), c = "Duke-Breast-Cancer-MRI";
elseif contains(u, "PDMR"), c = "NCI-PDMR (preclinico)";
elseif contains(u, "LIBRA"), c = "LIBRA (muestra)";
elseif contains(u, "IMAGENES 1ON"), c = "Estudio clinico local (excluido de la tesis)";
else, c = "Otra: " + string(fileparts(fileparts(f)));
end
end

function h = hash_texto(s)
md = java.security.MessageDigest.getInstance('MD5');
d = typecast(int8(md.digest(typecast(unicode2native(char(s), 'UTF-8'), 'int8'))), 'uint8');
h = lower(reshape(dec2hex(d, 2)', 1, []));
end

%% ==========================================================================================
%%  [1] VERIFICACION SOBRE FANTOMA
%% ==========================================================================================
function VER = verificacion_fantoma(cfg, out)
n = 20; dirV = fullfile(cfg.cache, 'verificacion'); if ~isfolder(dirV), mkdir(dirV); end
VER.dice = zeros(n, 1); VER.hd95 = zeros(n, 1);
for i = 1:n
    clase = mod(i - 1, 4) + 1; vista = ternario(mod(i, 2) == 0, "MLO", "CC");
    [raw, gt] = fantoma_mamografia(cfg.fantoma.lado, clase, vista, -1, cfg);
    f = fullfile(dirV, sprintf('ver_%02d.png', i)); imwrite(raw, f);
    S = preprocesar_imagen(f, "png", cfg.pixel_mm, vista, cfg);
    gtf = gt; if S.meta(2), gtf = fliplr(gtf); end
    VER.dice(i) = dice(S.mascaraCompleta, gtf);
    VER.hd95(i) = hd95(S.mascaraCompleta, gtf);
    if i == 1, VER.ejemplo = S; VER.gt = gtf; end
end
% FEM: disco homogeneo con contraccion radial uniforme -> solucion analitica exacta
[X, Y] = meshgrid(1:200, 1:200); M = (X - 100).^2 + (Y - 100).^2 <= 80^2;
[~, ~, fem] = fem_biomecanico(M, false(size(M)), cfg, true);
E = cfg.fem.Ea; nu = cfg.fem.nu; e = cfg.fem.deform;
sigTeo = E * e / ((1 + nu) * (1 - 2*nu));
VER.errFEM = abs(median(fem.vm) - sigTeo) / sigTeo;
VER.sigTeo = sigTeo; VER.sigFEM = median(fem.vm);
% Figura
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1400 420]);
tiledlayout(1, 4, 'TileSpacing', 'compact');
nexttile; imshow(VER.ejemplo.Ic, []); hold on; visboundaries(VER.ejemplo.mascaraCompleta, 'Color', 'r');
visboundaries(VER.gt, 'Color', 'g', 'LineStyle', '--'); title('Segmentacion (rojo) vs verdad (verde)');
nexttile; histogram(VER.dice, 10); xlabel('Dice'); ylabel('n'); title(sprintf('Dice %.3f \\pm %.3f', mean(VER.dice), std(VER.dice)));
nexttile; histogram(VER.hd95, 10); xlabel('HD95 (px)'); title(sprintf('HD95 %.1f px', mean(VER.hd95)));
nexttile; patch('Faces', fem.tri, 'Vertices', fem.nodos, 'FaceVertexCData', fem.vm, 'FaceColor', 'flat', 'EdgeColor', 'none');
axis image ij off; colorbar; title(sprintf('FEM analitico: %.2f vs %.2f kPa (err %.2f%%)', VER.sigFEM, sigTeo, 100*VER.errFEM));
sgtitle('Verificacion de implementacion (fantoma) - no es evidencia diagnostica');
guardar_figura(f, out, 'F01_verificacion_fantoma');
end

function d = dice(A, B)
d = 2 * nnz(A & B) / (nnz(A) + nnz(B) + eps);
end

function h = hd95(A, B)
pa = bwperim(A); pb = bwperim(B);
if ~any(pa(:)) || ~any(pb(:)), h = NaN; return; end
da = bwdist(pb); db = bwdist(pa);
h = max(prctile_simple(da(pa), 95), prctile_simple(db(pb), 95));
end

%% ==========================================================================================
%%  FANTOMA BEER-LAMBERT
%% ==========================================================================================
function [raw, gt, frac, cajas] = fantoma_mamografia(lado, clase, vista, lesion, cfg)
% lesion: -1 ninguna, 0 benigna, 1 maligna
H = lado; W = round(0.8 * lado);
[X, Y] = meshgrid(1:W, 1:H);
a = W * (0.80 + 0.12*rand); b = H * (0.40 + 0.06*rand); yc = H/2 + 0.02*H*randn;
sil = ((X - 1)/a).^2 + ((Y - yc)/b).^2 <= 1;
rangos = [0.05 0.20; 0.20 0.40; 0.40 0.62; 0.62 0.85];
frac = rangos(clase, 1) + rand * diff(rangos(clase, :));
n = ruido_potencia([H W], 3.0) + 0.8 * max(0, 1 - (X - 1)/a);
thr = prctile_simple(n(sil), 100 * (1 - frac));
g = imgaussfilt(double(n > thr & sil), 1.5);
mu = sil .* (0.80*g + 0.46*(1 - g));          % cm^-1 (mu_g, mu_a)
pect = false(H, W);
if vista == "MLO"
    pect = X < (0.35*W) * (1 - Y/(0.45*H)) & sil;
    mu = mu + 0.35*pect;
end
cajas = zeros(0, 4);
if lesion >= 0
    dens = find(g > 0.5 & sil & ~pect); if isempty(dens), dens = find(sil & ~pect); end
    [cy, cx] = ind2sub([H W], dens(randi(numel(dens))));
    r = lado * (0.025 + 0.015*rand);
    th = atan2(Y - cy, X - cx); rr = hypot(X - cx, Y - cy);
    if lesion == 1
        borde = r * (1 + 0.35*sin(7*th + rand*2*pi) + 0.15*randn(size(th)));   % espiculada
        masa = rr <= borde; mu = mu + 0.30*imgaussfilt(double(masa), 1);
        nc = randi([6 12]);
        for k = 1:nc
            px = round(cx + 2.5*r*randn); py = round(cy + 2.5*r*randn);
            if px > 2 && py > 2 && px < W - 2 && py < H - 2, mu(py-1:py+1, px-1:px+1) = mu(py-1:py+1, px-1:px+1) + 1.2; end
        end
    else
        masa = rr <= r; mu = mu + 0.22*imgaussfilt(double(masa), 2);             % redonda
    end
    [yy, xx] = find(masa);
    cajas = [min(xx) min(yy) max(xx) max(yy)];
end
T = 5; I0 = 2e4;
I = I0 * exp(-mu * T);
I = max(I + sqrt(I) .* randn(size(I)), 1);                       % ruido Poisson (aprox. gaussiana)
att = -log(I / I0); att(~sil) = 0;
raw = uint16(65535 * min(att / 6, 1));
gt = sil & ~pect;
end

function n = ruido_potencia(sz, beta)
[u, v] = meshgrid(ifftshift((0:sz(2)-1) - floor(sz(2)/2)), ifftshift((0:sz(1)-1) - floor(sz(1)/2)));
f = hypot(u, v); f(1, 1) = 1;
n = real(ifft2(fft2(randn(sz)) ./ f.^(beta/2)));
n = (n - mean(n(:))) / std(n(:));
end

function [TR, TE, EXT] = cohorte_fantoma(cfg)
dirR = fullfile(cfg.cache, 'fantoma_raw'); if ~isfolder(dirR), mkdir(dirR); end
TR = generar_grupo(cfg, cfg.fantoma.pacTr, 'tr', dirR, false);
TE = generar_grupo(cfg, cfg.fantoma.pacTe, 'te', dirR, false);
EXT = generar_grupo(cfg, cfg.fantoma.pacExt, 'ex', dirR, true);
end

function T = generar_grupo(cfg, nPac, pref, dirR, externo)
filas = {};
for p = 1:nPac
    clase = randi(4);
    for lat = ["L" "R"]
        if externo, les = double(rand < 0.5); else, les = ternario(rand < 0.3, randi([0 1]), -1); end
        estado = rng;
        for vista = ["CC" "MLO"]
            rng(estado);                                          % misma mama en ambas vistas
            [raw, ~, ~, cajas] = fantoma_mamografia(cfg.fantoma.lado, clase, vista, les, cfg);
            id = sprintf('%s_p%03d_%s_%s', pref, p, lat, vista);
            f = fullfile(dirR, [id '.png']); imwrite(raw, f);
            filas(end+1, :) = {string(id), string(sprintf('%s_p%03d', pref, p)), ...
                string(sprintf('%s_p%03d_%s', pref, p, lat)), vista, string(f), "png", cfg.pixel_mm, ...
                ternario(externo, NaN, clase), ternario(externo, les, NaN), {cajas}}; %#ok<AGROW>
        end
    end
end
T = cell2table(filas, 'VariableNames', {'id', 'paciente', 'mama', 'vista', 'fuente', 'tipo', ...
    'espaciado', 'y', 'maligno', 'cajas'});
end

%% ==========================================================================================
%%  [2] INDEXADO DE DATOS REALES
%% ==========================================================================================
function [TR, TE, FLUJO] = indexar_vindr(cfg)
A = readtable(fullfile(cfg.vindrRoot, 'breast-level_annotations.csv'), 'TextType', 'string');
FLUJO.inicial = height(A);
A = A(ismember(A.view_position, ["CC" "MLO"]), :);
FLUJO.vistas = height(A);
A.fuente = fullfile(cfg.vindrRoot, 'images', A.study_id, A.image_id + ".dicom");
existe = arrayfun(@isfile, A.fuente);
A = A(existe, :); FLUJO.archivos = height(A);
A.y = double(char(extractAfter(A.breast_density, "DENSITY "))) - 64;
A = A(A.y >= 1 & A.y <= 4, :);
A.mama = A.study_id + "_" + A.laterality;
% vistas completas: al menos una CC y una MLO por mama
[g, mamas] = findgroups(A.mama);
tieneCC = splitapply(@(v) any(v == "CC"), A.view_position, g);
tieneMLO = splitapply(@(v) any(v == "MLO"), A.view_position, g);
A = A(ismember(A.mama, mamas(tieneCC & tieneMLO)), :); FLUJO.completas = height(A);
% cajas de hallazgos (para localizacion Grad-CAM)
cajas = repmat({zeros(0, 4)}, height(A), 1);
ff = fullfile(cfg.vindrRoot, 'finding_annotations.csv');
if isfile(ff)
    B = readtable(ff, 'TextType', 'string');
    B = B(~isnan(B.xmin) & ~contains(B.finding_categories, "No Finding"), :);
    [tf, loc] = ismember(B.image_id, A.image_id);
    B = B(tf, :); loc = loc(tf);
    for k = 1:height(B)
        cajas{loc(k)}(end+1, :) = [B.xmin(k) B.ymin(k) B.xmax(k) B.ymax(k)];
    end
end
T = table(A.image_id, A.study_id, A.mama, A.view_position, A.fuente, repmat("dicom", height(A), 1), ...
    nan(height(A), 1), A.y, nan(height(A), 1), cajas, ...
    'VariableNames', {'id', 'paciente', 'mama', 'vista', 'fuente', 'tipo', 'espaciado', 'y', 'maligno', 'cajas'});
TR = T(A.split == "training", :);
TE = T(A.split == "test", :);
end

function [TR, TE, FLUJO] = indexar_inbreast(cfg)
% INbreast (INESC Porto): FFDM DICOM, densidad ACR 1-4 (= A-D) y BI-RADS por imagen,
% contornos XML (Osirix) de lesiones y del musculo pectoral. ID de paciente en el nombre del archivo.
root = cfg.inbreastRoot;
C = readtable(fullfile(root, 'INbreast.csv'), 'Delimiter', ';', 'TextType', 'string', 'VariableNamingRule', 'preserve');
FLUJO.inicial = height(C);
L = dir(fullfile(root, 'AllDICOMs', '*.dcm'));
L = L(~startsWith({L.name}, '._'));                       % AppleDouble de macOS (no son DICOM)
nombres = string({L.name})'; idsDcm = extractBefore(nombres, "_");
filas = {};
for k = 1:height(C)
    fid = strtrim(string(C.("File Name")(k)));
    j = find(idsDcm == fid, 1); if isempty(j), continue; end
    partes = split(nombres(j), "_");                      % id_paciente_MG_lat_vista_ANON.dcm
    if ~ismember(partes(5), ["CC" "ML" "MLO"]), continue; end
    acr = str2double(string(C.ACR(k)));
    if isnan(acr) || acr < 1 || acr > 4, continue; end
    br = strtrim(string(C.("Bi-Rads")(k))); nb = str2double(extractBefore(br + "x", 2));
    filas(end+1, :) = {fid, partes(2), partes(2) + "_" + partes(4), ternario(partes(5) == "CC", "CC", "MLO"), ...
        string(fullfile(root, 'AllDICOMs', nombres(j))), "dicom", 0.07, acr, double(nb >= 4), ...
        {cajas_inbreast(fullfile(root, 'AllXML', fid + ".xml"))}}; %#ok<AGROW>
end
T = cell2table(filas, 'VariableNames', {'id', 'paciente', 'mama', 'vista', 'fuente', 'tipo', 'espaciado', ...
    'y', 'maligno', 'cajas'});
FLUJO.conDensidad = height(T);
% Particion por paciente, estratificada por la densidad mayoritaria del paciente
[g, pacs] = findgroups(T.paciente); cp = splitapply(@(v) mode(v), T.y, g);
s = rng; rng(cfg.semilla + 1); prueba = false(numel(pacs), 1);
for c = 1:4
    ids = find(cp == c); ids = ids(randperm(numel(ids)));
    prueba(ids(1:round(cfg.fraccionPrueba * numel(ids)))) = true;
end
rng(s);
TE = T(prueba(g), :); TR = T(~prueba(g), :);
FLUJO.pacientes = numel(pacs); FLUJO.pacientesPrueba = sum(prueba);
FLUJO.entrenamiento = height(TR); FLUJO.prueba = height(TE);
end

function cajas = cajas_inbreast(f)
% Cajas [xmin ymin xmax ymax] (pixeles, base 1) de todos los ROI anotados en el XML de Osirix
cajas = zeros(0, 4);
if ~isfile(f), return; end
P = puntos_osirix(fileread(f));
for k = 1:numel(P)
    q = P{k}; if isempty(q), continue; end
    b = [min(q(:, 1)) min(q(:, 2)) max(q(:, 1)) max(q(:, 2))];
    if b(3) - b(1) < 20, b([1 3]) = mean(b([1 3])) + [-10 10]; end   % calcificacion puntual
    if b(4) - b(2) < 20, b([2 4]) = mean(b([2 4])) + [-10 10]; end
    cajas(end+1, :) = b; %#ok<AGROW>
end
end

function P = puntos_osirix(txt)
tok = regexp(txt, '<key>Point_px</key>\s*<array>(.*?)</array>', 'tokens');
P = cell(1, numel(tok));
for k = 1:numel(tok)
    pt = regexp(tok{k}{1}, '\(([-\d\.]+),\s*([-\d\.]+)\)', 'tokens');
    if isempty(pt), continue; end
    P{k} = str2double(vertcat(pt{:})) + 1;                % Osirix usa base 0
end
end

function V = verificacion_pectoral(T, cfg, out)
% Segmentacion pectoral automatica (Hough) vs contorno manual de INbreast en vistas MLO
V = struct('dice', [], 'hd95', []);
dirX = fullfile(cfg.inbreastRoot, 'PectoralMuscle', 'Pectoral Muscle XML');
idx = find(T.vista == "MLO" & arrayfun(@(i) isfile(fullfile(dirX, T.id(i) + "_muscle.xml")), (1:height(T))'));
idx = idx(1:min(40, end));
ej = [];
for i = idx'
    try
        S = preprocesar_imagen(T.fuente(i), T.tipo(i), T.espaciado(i), T.vista(i), cfg);
        P = puntos_osirix(fileread(fullfile(dirX, T.id(i) + "_muscle.xml")));
        q = vertcat(P{:}); if size(q, 1) < 3, continue; end
        q = q * S.meta(1);
        if S.meta(2), q(:, 1) = S.meta(3) - q(:, 1) + 1; end
        [~, o] = sort(q(:, 2)); q = q(o, :);
        pol = [q; 1 q(end, 2); 1 1; q(1, 1) 1];
        gt = poly2mask(pol(:, 1), pol(:, 2), size(S.pectoral, 1), size(S.pectoral, 2));
        V.dice(end+1) = dice(S.pectoral, gt); V.hd95(end+1) = hd95(S.pectoral, gt) * cfg.pixel_mm;
        if isempty(ej), ej = struct('I', S.Ic, 'p', S.pectoral, 'g', gt); end
    catch
    end
end
fprintf('       Pectoral (n=%d MLO): Dice %.3f +/- %.3f | HD95 %.1f mm\n', numel(V.dice), mean(V.dice), std(V.dice), mean(V.hd95, 'omitnan'));
if ~isempty(ej)
    f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1100 450]);
    tiledlayout(1, 2);
    nexttile; imshow(ej.I, []); hold on; visboundaries(ej.p, 'Color', 'r'); visboundaries(ej.g, 'Color', 'g', 'LineStyle', '--');
    title('Pectoral: automatico (rojo) vs manual INbreast (verde)');
    nexttile; histogram(V.dice, 10); xlabel('Dice'); ylabel('Imagenes MLO');
    title(sprintf('Dice %.3f \\pm %.3f (n=%d)', mean(V.dice), std(V.dice), numel(V.dice)));
    guardar_figura(f, out, 'F01b_pectoral_INbreast');
end
end

function f = buscar_descripciones_cbis(root)
% Busca los CSV de descripcion de casos de CBIS-DDSM (calc/mass, train/test) junto al manifiesto
f = {};
for d = {root, fileparts(root)}
    L = dir(fullfile(d{1}, '**', '*case_description*.csv'));
    f = [f, fullfile({L.folder}, {L.name})]; %#ok<AGROW>
end
f = unique(f);
end

function [TR, TE, FLUJO] = indexar_cbis(cfg)
% CBIS-DDSM: densidad BI-RADS 1-4 (-> A-D) por imagen; 'Training'/'Test' = particion oficial.
% Nota metodologica: CBIS-DDSM es mamografia de pelicula digitalizada (no FFDM).
M = readtable(fullfile(cfg.cbisRoot, 'metadata.csv'), 'TextType', 'string', 'VariableNamingRule', 'preserve');
full = M(M.("Series Description") == "full mammogram images", :);
FLUJO.inicial = height(full);
filas = {};
dens = containers.Map();
for f = buscar_descripciones_cbis(cfg.cbisRoot)
    Dd = readtable(f{1}, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    vn = string(Dd.Properties.VariableNames);
    cDen = vn(contains(lower(vn), "density")); cLat = vn(contains(lower(vn), "left or right"));
    cVis = vn(contains(lower(vn), "image view"));
    tipo = ternario(contains(lower(f{1}), "calc"), "Calc", "Mass");
    fase = ternario(contains(lower(f{1}), "train"), "Training", "Test");
    for k = 1:height(Dd)
        clave = tipo + "-" + fase + "_" + Dd.patient_id(k) + "_" + Dd.(cLat(1))(k) + "_" + Dd.(cVis(1))(k);
        dens(char(clave)) = double(Dd.(cDen(1))(k));
    end
end
for k = 1:height(full)
    sid = full.("Subject ID")(k);
    if ~isKey(dens, char(sid)), continue; end
    carpeta = fullfile(cfg.cbisRoot, strrep(full.("File Location")(k), ".\", ""));
    dc = dir(fullfile(carpeta, '*.dcm')); dc = dc(~startsWith({dc.name}, '._'));
    if isempty(dc), continue; end
    t = regexp(sid, '^(\w+)-(\w+)_(P_\d+)_(LEFT|RIGHT)_(CC|MLO)$', 'tokens', 'once');
    if isempty(t), continue; end
    y = dens(char(sid)); if y < 1 || y > 4, continue; end
    filas(end+1, :) = {sid, t(3), t(3) + "_" + t(4), t(5), string(fullfile(carpeta, dc(1).name)), "dicom", ...
        NaN, y, NaN, {zeros(0, 4)}, t(2)}; %#ok<AGROW>
end
T = cell2table(filas, 'VariableNames', {'id', 'paciente', 'mama', 'vista', 'fuente', 'tipo', 'espaciado', ...
    'y', 'maligno', 'cajas', 'fase'});
FLUJO.conDensidad = height(T);
% Un paciente no puede quedar en ambos lados: si aparece en Test, se retira de Training
enTest = unique(T.paciente(T.fase == "Test"));
TR = T(T.fase == "Training" & ~ismember(T.paciente, enTest), :);
TE = T(T.fase == "Test", :);
TR.fase = []; TE.fase = [];
FLUJO.entrenamiento = height(TR); FLUJO.prueba = height(TE);
end

function T = indexar_cmmd(cfg)
T = table();
if isempty(cfg.cmmdRoot) || ~isfolder(cfg.cmmdRoot) || ~isfile(cfg.cmmdClinico), return; end
C = readtable(cfg.cmmdClinico, 'TextType', 'string');
C.clave = C.ID1 + "_" + C.LeftRight;
C.mal = double(lower(C.classification) == "malignant");
L = dir(fullfile(cfg.cmmdRoot, '**', '*.dcm'));
L = L(~startsWith({L.name}, '._'));        % la copia de CMMD trae un "._1-x.dcm" de macOS por imagen
filas = {};
for k = 1:numel(L)
    f = fullfile(L(k).folder, L(k).name);
    try
        info = dicominfo(f);
        pid = string(info.PatientID);
        lat = string(campo(info, {'ImageLaterality', 'Laterality'}, ""));
        desc = upper(string(campo(info, {'ViewPosition', 'SeriesDescription'}, "")));
        vista = ternario(contains(desc, "MLO"), "MLO", "CC");
        j = find(C.clave == pid + "_" + lat, 1);
        if isempty(j), continue; end
        filas(end+1, :) = {string(L(k).name), pid, pid + "_" + lat, vista, string(f), "dicom", NaN, ...
            NaN, C.mal(j), {zeros(0, 4)}}; %#ok<AGROW>
    catch
    end
end
if ~isempty(filas)
    T = cell2table(filas, 'VariableNames', {'id', 'paciente', 'mama', 'vista', 'fuente', 'tipo', ...
        'espaciado', 'y', 'maligno', 'cajas'});
    T.id = T.paciente + "_" + string((1:height(T))');
end
end

function v = campo(s, nombres, def)
v = def;
for k = 1:numel(nombres)
    if isfield(s, nombres{k}) && ~isempty(s.(nombres{k})), v = s.(nombres{k}); return; end
end
end

%% ==========================================================================================
%%  [3-6] PREPROCESAMIENTO + CARACTERISTICAS (cache reanudable, parfor si hay pool)
%% ==========================================================================================
function [T, nExc] = preparar_conjunto(T, cfg, nombre)
dirC = fullfile(cfg.cache, sprintf('%s_%s_S%d', cfg.fuenteDensidad, nombre, cfg.S)); if ~isfolder(dirC), mkdir(dirC); end
n = height(T); R = cell(n, 1);
fuentes = T.fuente; tipos = T.tipo; esp = T.espaciado; vistas = T.vista; ids = T.id;
parfor i = 1:n
    R{i} = procesar_una(fuentes(i), tipos(i), esp(i), vistas(i), fullfile(dirC, char(ids(i))), cfg);
end
ok = cellfun(@(r) r.ok, R);
nExc = sum(~ok);
for i = find(~ok)', fprintf('       [excluida] %s: %s\n', ids(i), R{i}.msg); end
T = T(ok, :); R = R(ok);
T.png    = string(cellfun(@(r) r.png, R, 'UniformOutput', false));
T.rad    = cell2mat(cellfun(@(r) r.rad, R, 'UniformOutput', false));
T.Fstress = cellfun(@(r) r.Fstress, R);
T.Fdens  = cellfun(@(r) r.Fdens, R);
T.Fles   = cellfun(@(r) r.Fles, R);
T.Fmicro = cellfun(@(r) r.Fmicro, R);
T.igr    = cellfun(@(r) r.igr, R);
T.meta   = cell2mat(cellfun(@(r) r.meta, R, 'UniformOutput', false));
end

function R = procesar_una(fuente, tipo, esp, vista, base, cfg)
fmat = [base '.mat'];
if isfile(fmat)
    R = load(fmat); R = R.R;
    if isfile(R.png), return; end
end
R = struct('ok', false, 'msg', '', 'png', '', 'rad', nan(1, 16), 'Fstress', NaN, 'Fdens', NaN, ...
    'Fles', NaN, 'Fmicro', NaN, 'igr', NaN, 'meta', nan(1, 9));
try
    S = preprocesar_imagen(fuente, tipo, esp, vista, cfg);
    if nnz(S.Mw) < 500, error('mascara de mama demasiado pequena'); end
    R.rad = radiomica16(S.Iw, S.Mw, S.Dw);
    R.Fstress = fem_biomecanico(S.Mw, S.Dw, cfg, false);
    R.Fdens = nnz(S.Dw) / nnz(S.Mw);
    R.Fles = factor_lesiones(S.Iw, S.Mw);
    R.Fmicro = factor_micro(S.Iw, S.Mw, cfg);
    R.igr = 10 * (cfg.igr.w * [R.Fdens; R.Fles; R.Fmicro; R.Fstress]);
    R.meta = S.meta;
    R.png = [base '.png'];
    imwrite(uint16(65535 * S.netImg), R.png);
    R.ok = true;
    save(fmat, 'R');
catch ME
    R.msg = ME.message;
end
end

function S = preprocesar_imagen(fuente, tipo, esp, vista, cfg)
% --- lectura y conversion a intensidades fisicas
if tipo == "dicom"
    info = dicominfo(fuente); I = double(dicomread(info));
    I = I * double(campo(info, {'RescaleSlope'}, 1)) + double(campo(info, {'RescaleIntercept'}, 0));
    if strcmpi(strtrim(string(campo(info, {'PhotometricInterpretation'}, ""))), "MONOCHROME1")
        I = max(I(:)) - I;
    end
    if isnan(esp), esp = cfg.espaciadoDefecto; end
    ps = campo(info, {'ImagerPixelSpacing', 'PixelSpacing'}, esp); esp = double(ps(1));
else
    I = double(imread(fuente));
end
I = I(:, :, 1);
% --- remuestreo isotropico a cfg.pixel_mm
s1 = esp / cfg.pixel_mm;
if abs(s1 - 1) > 0.01, I = imresize(I, s1, 'bilinear'); end
% --- normalizacion robusta
lo = prctile_simple(I(:), 0.5); hi = prctile_simple(I(:), 99.5);
In = min(max((I - lo) / (hi - lo + eps), 0), 1);
% --- mascara de mama: Otsu + mayor componente + relleno
bw = In > graythresh(In);
bw = imopen(bw, strel('disk', 3));
bw = bwareaopen(bw, round(cfg.areaMinFrac * numel(bw)));
bw = bwareafilt(bw, 1); bw = imfill(bw, 'holes');
% --- orientacion: pared toracica a la izquierda
[~, W1] = size(bw);
voltear = nnz(bw(:, 1:floor(W1/2))) < nnz(bw(:, floor(W1/2)+1:end));
if voltear, In = fliplr(In); bw = fliplr(bw); end
% --- correccion de campo plano (division por copia gaussiana, sigma 30 px; en 1/4 de resolucion)
f4 = 0.25; G = imresize(imgaussfilt(imresize(In, f4), cfg.sigmaFlat * f4), size(In));
F = In ./ (G + 0.05); F(~bw) = 0;
v = F(bw); F = min(max((F - prctile_simple(v, 0.5)) / (prctile_simple(v, 99.5) - prctile_simple(v, 0.5) + eps), 0), 1);
F(~bw) = 0;
% --- mediana 7x7 y CLAHE
F = medfilt2(F, [cfg.mediana cfg.mediana]);
Ic = adapthisteq(F, 'ClipLimit', cfg.claheClip, 'NumTiles', cfg.claheTiles); Ic(~bw) = 0;
% --- musculo pectoral (solo MLO)
pect = false(size(bw));
if vista == "MLO", pect = pectoral_hough(Ic, bw); bw = bw & ~pect; end
% --- recorte a la mama
[r, c] = find(bw); m = round(0.02 * max(size(bw)));
r0 = max(min(r) - m, 1); r1 = min(max(r) + m, size(bw, 1));
c0 = max(min(c) - m, 1); c1 = min(max(c) + m, size(bw, 2));
Icr = Ic(r0:r1, c0:c1); Mr = bw(r0:r1, c0:c1);
% --- imagen de trabajo (radiomica/FEM): lado mayor = featLado
k = cfg.featLado / max(size(Icr));
Iw = imresize(Icr, k, 'bilinear'); Mw = imresize(Mr, size(Iw), 'nearest');
Iw = min(max(Iw, 0), 1); Iw(~Mw) = 0;
% --- mapa de tejido denso: top-hat + Otsu dentro de la mama
th = imtophat(Iw, strel('disk', 15));
E = min(Iw + 0.5 * th, 1);
Mint = imerode(Mw, strel('disk', max(3, round(0.03 * cfg.featLado))));   % excluye borde cutaneo
Dw = E > graythresh(E(Mint)) & Mint;
Dw = bwareaopen(Dw, 20);
% --- imagen para la red: cuadrado con relleno y reescalado a S x S
L = max(size(Icr)); pr = floor((L - size(Icr, 1))/2); pc = 0;       % pared toracica pegada a la izquierda
Q = zeros(L, L); Q(pr+1:pr+size(Icr, 1), pc+1:pc+size(Icr, 2)) = Icr .* Mr;
S.netImg = single(imresize(Q, [cfg.S cfg.S], 'bilinear'));
S.netImg = min(max(S.netImg, 0), 1);
S.Iw = Iw; S.Mw = Mw; S.Dw = Dw; S.Ic = Ic; S.mascaraCompleta = bw; S.pectoral = pect;
S.meta = [s1 voltear W1 r0 c0 L pr pc cfg.S];
end

function P = pectoral_hough(Ic, bw)
[H, W] = size(Ic); P = false(H, W);
rr = 1:round(H/2); cc = 1:round(W/2);
E = edge(Ic(rr, cc) .* bw(rr, cc), 'canny');
if nnz(E) < 50, return; end
[Hh, th, rho] = hough(E, 'Theta', 10:0.5:80);
pk = houghpeaks(Hh, 1, 'Threshold', 0.3 * max(Hh(:)));
if isempty(pk), return; end
t = th(pk(2)); p = rho(pk(1));
[X, Y] = meshgrid(1:W, 1:H);
cand = (X * cosd(t) + Y * sind(t) < p) & bw;
fr = nnz(cand) / nnz(bw);
if fr > 0.01 && fr < 0.35, P = cand; end
end

%% ---------------------------- RADIOMICA (16) ----------------------------------------------
function r = radiomica16(I, M, D)
v = I(M); m = mean(v); s = std(v) + eps;
primer = [m, s, mean((v - m).^3) / s^3, mean((v - m).^4) / s^4];
% GLCM: 4 direcciones, distancia 1, 32 niveles, simetrica (pixeles fuera de la mama = NaN)
Iq = I; Iq(~M) = NaN;
ws = warning('off', 'all');       % GLCM avisa que ignora los NaN (fuera de la mama): esperado
G = graycomatrix(Iq, 'Offset', [0 1; -1 1; -1 0; -1 -1], 'NumLevels', 32, 'GrayLimits', [0 1], 'Symmetric', true);
warning(ws);
pr = graycoprops(G, {'Contrast', 'Energy', 'Homogeneity'});
ent = zeros(1, 4);
for k = 1:4
    p = G(:, :, k) / max(sum(G(:, :, k), 'all'), 1); p = p(p > 0); ent(k) = -sum(p .* log2(p));
end
glcm = [mean(pr.Contrast), mean(ent), mean(pr.Energy), mean(pr.Homogeneity)];
% LBP uniforme invariante a rotacion (P=8, R=1): entropia del histograma
lbp = entropia_lbp(I, M);
% Gabor 0/45/90/135 (longitud de onda 8 px)
g = gabor(8, [0 45 90 135]); mag = imgaborfilt(I, g);
gab = zeros(1, 4);
for k = 1:4, mk = mag(:, :, k); gab(k) = mean(mk(M).^2); end
% Hu 1-3 de la mascara de tejido denso
hu = momentos_hu(double(D)); hu = hu(1:3);
r = [primer glcm lbp gab hu];
end

function e = entropia_lbp(I, M)
C = I(2:end-1, 2:end-1);
of = [0 1; -1 1; -1 0; -1 -1; 0 -1; 1 -1; 1 0; 1 1];
B = false([size(C) 8]);
for k = 1:8
    B(:, :, k) = I(2+of(k, 1):end-1+of(k, 1), 2+of(k, 2):end-1+of(k, 2)) >= C;
end
U = sum(B ~= circshift(B, 1, 3), 3);
cod = sum(B, 3); cod(U > 2) = 9;
mm = M(2:end-1, 2:end-1);
h = histcounts(cod(mm), -0.5:1:9.5); p = h / max(sum(h), 1); p = p(p > 0);
e = -sum(p .* log2(p));
end

function hu = momentos_hu(I)
[r, c] = size(I); [x, y] = meshgrid(1:c, 1:r);
m00 = sum(I(:)); if m00 == 0, hu = zeros(1, 7); return; end
xb = sum(x(:) .* I(:)) / m00; yb = sum(y(:) .* I(:)) / m00;
eta = @(p, q) sum(((x(:) - xb).^p) .* ((y(:) - yb).^q) .* I(:)) / m00^(1 + (p + q)/2);
n20 = eta(2, 0); n02 = eta(0, 2); n11 = eta(1, 1); n30 = eta(3, 0); n03 = eta(0, 3); n21 = eta(2, 1); n12 = eta(1, 2);
hu = zeros(1, 7);
hu(1) = n20 + n02;
hu(2) = (n20 - n02)^2 + 4*n11^2;
hu(3) = (n30 - 3*n12)^2 + (3*n21 - n03)^2;
hu(4) = (n30 + n12)^2 + (n21 + n03)^2;
hu(5) = (n30 - 3*n12)*(n30 + n12)*((n30 + n12)^2 - 3*(n21 + n03)^2) + (3*n21 - n03)*(n21 + n03)*(3*(n30 + n12)^2 - (n21 + n03)^2);
hu(6) = (n20 - n02)*((n30 + n12)^2 - (n21 + n03)^2) + 4*n11*(n30 + n12)*(n21 + n03);
hu(7) = (3*n21 - n03)*(n30 + n12)*((n30 + n12)^2 - 3*(n21 + n03)^2) - (n30 - 3*n12)*(n21 + n03)*(3*(n30 + n12)^2 - (n21 + n03)^2);
end

%% ---------------------------- FEM BIOMECANICO ---------------------------------------------
function [Fs, vmMax, fem] = fem_biomecanico(M, D, cfg, verificacion)
% Deformacion plana lineal elastica, triangulos lineales (CST).
% Pared toracica (borde izquierdo) fija; piel con desplazamiento compresivo uniforme hacia
% el centroide. En modo verificacion todo el contorno se desplaza (solucion analitica).
[H, W] = size(M); h = max(H, W) / cfg.fem.malla;
gx = linspace(1, W, max(3, ceil((W - 1)/h) + 1)); gy = linspace(1, H, max(3, ceil((H - 1)/h) + 1));
[GX, GY] = meshgrid(gx, gy); nod = [GX(:) GY(:)];
id = reshape(1:numel(GX), size(GX));
a = id(1:end-1, 1:end-1); b = id(2:end, 1:end-1); c = id(1:end-1, 2:end); d = id(2:end, 2:end);
tri = [a(:) b(:) d(:); a(:) d(:) c(:)];
cen = (nod(tri(:, 1), :) + nod(tri(:, 2), :) + nod(tri(:, 3), :)) / 3;
dentro = M(sub2ind([H W], round(cen(:, 2)), round(cen(:, 1))));
tri = tri(dentro, :); cen = cen(dentro, :);
fem = struct('tri', zeros(0, 3), 'nodos', zeros(0, 2), 'vm', zeros(0, 1));
if size(tri, 1) < 20, Fs = 0; vmMax = 0; return; end
[usados, ~, nuevo] = unique(tri(:)); tri = reshape(nuevo, [], 3); nod = nod(usados, :);
Ne = size(tri, 1); Nn = size(nod, 1);
denso = D(sub2ind([H W], round(cen(:, 2)), round(cen(:, 1))));
E = cfg.fem.Ea * ones(Ne, 1); E(denso) = cfg.fem.Eg;
nu = cfg.fem.nu;
D0 = [1-nu nu 0; nu 1-nu 0; 0 0 (1-2*nu)/2] / ((1 + nu) * (1 - 2*nu));
Ii = zeros(36*Ne, 1); Jj = Ii; Vv = Ii; Bs = zeros(3, 6, Ne);
for e = 1:Ne
    n = tri(e, :); x = nod(n, 1); y = nod(n, 2);
    Ae = abs((x(2) - x(1))*(y(3) - y(1)) - (x(3) - x(1))*(y(2) - y(1))) / 2;
    bb = [y(2) - y(3); y(3) - y(1); y(1) - y(2)]; cc = [x(3) - x(2); x(1) - x(3); x(2) - x(1)];
    B = zeros(3, 6); B(1, 1:2:6) = bb; B(2, 2:2:6) = cc; B(3, 1:2:6) = cc; B(3, 2:2:6) = bb;
    B = B / (2*Ae + eps); Bs(:, :, e) = B;
    Ke = Ae * (B' * (E(e) * D0) * B);
    dof = reshape([2*n - 1; 2*n], 1, []);
    [cI, rI] = meshgrid(dof, dof);
    k = (e - 1)*36 + (1:36);
    Ii(k) = rI(:); Jj(k) = cI(:); Vv(k) = Ke(:);
end
K = sparse(Ii, Jj, Vv, 2*Nn, 2*Nn);
ar = sort([tri(:, [1 2]); tri(:, [2 3]); tri(:, [3 1])], 2);
[ua, ~, ic] = unique(ar, 'rows'); cnt = accumarray(ic, 1);
bnd = unique(ua(cnt == 1, :));
cxy = mean(nod, 1);
U = zeros(2*Nn, 1);
if verificacion
    fijos = bnd; pared = [];
else
    pared = bnd(nod(bnd, 1) <= min(nod(:, 1)) + 1.01*h);
    fijos = setdiff(bnd, pared);
end
U(2*fijos - 1) = -cfg.fem.deform * (nod(fijos, 1) - cxy(1));
U(2*fijos)     = -cfg.fem.deform * (nod(fijos, 2) - cxy(2));
pres = sort([2*fijos - 1; 2*fijos; 2*pared(:) - 1; 2*pared(:)]);
libre = setdiff((1:2*Nn)', pres);
U(libre) = K(libre, libre) \ (-K(libre, pres) * U(pres));
vm = zeros(Ne, 1);
for e = 1:Ne
    n = tri(e, :); dof = reshape([2*n - 1; 2*n], 1, []);
    s = E(e) * D0 * (Bs(:, :, e) * U(dof));
    vm(e) = sqrt(s(1)^2 + s(2)^2 - s(1)*s(2) + 3*s(3)^2);
end
% Maximo sobre elementos interiores: las esquinas del contorno (union pared-piel) son
% singularidades numericas de la condicion de borde, no concentraciones fisicas de tension.
interior = ~any(ismember(tri, bnd), 2);
if any(interior), vmMax = max(vm(interior)); else, vmMax = max(vm); end
Fs = min(vmMax / cfg.fem.sigRef, 1);
fem.tri = tri; fem.nodos = nod; fem.vm = vm;
end

%% ---------------------------- LESIONES Y MICROCALCIFICACIONES ------------------------------
function F = factor_lesiones(I, M)
S = imgaussfilt(I, 3); v = S(M);
bw = S > mean(v) + 1.5*std(v) & M;
bw = imopen(bw, strel('disk', 3));
bw = bwareaopen(bw, max(20, round(0.001 * nnz(M))));
bw = bw & ~bwareaopen(bw, round(0.15 * nnz(M)));          % descarta parenquima extenso
st = regionprops(bw, 'Eccentricity', 'Solidity', 'Area', 'Perimeter');
F = 0;
for k = 1:numel(st)
    comp = min(4*pi*st(k).Area / max(st(k).Perimeter, 1)^2, 1);
    F = max(F, (st(k).Eccentricity + (1 - st(k).Solidity) + (1 - comp)) / 3);
end
end

function F = factor_micro(I, M, cfg)
h = [0.23037781330885523 0.7148465705525415 0.6308807679295904 -0.02798376941698385 ...
    -0.18703481171888114 0.030841381835986965 0.032883011666982945 -0.010597401784997278];
g = fliplr(h); g(2:2:end) = -g(2:2:end);                 % Daubechies-4 (8 coeficientes)
bajar = @(x, f) subsref(conv2(x, f, 'same'), struct('type', '()', 'subs', {{':', 1:2:size(x, 2)}}));
lo = bajar(I, h); hi = bajar(I, g);
LH = bajar(lo', g)'; HL = bajar(hi', h)'; HH = bajar(hi', g)';
det = LH.^2 + HL.^2 + HH.^2;
Md = imresize(M, size(det), 'nearest'); Md = imerode(Md, strel('disk', 3));
if nnz(Md) < 50, F = 0; return; end
v = det(Md);
bw = det > mean(v) + 4*std(v) & Md;
cc = bwconncomp(bw); a = cellfun(@numel, cc.PixelIdxList);
F = min(sum(a <= 30) / cfg.igr.microNorm, 1);
end

%% ==========================================================================================
%%  [7] DEFINICION DE LA RED NEURONAL
%% ==========================================================================================
function cols = columnas_modelo(nombre)
switch nombre
    case 'fusion',            cols = 1:17;   % radiomica (16) + F_stress
    case 'fusion_sinFstress', cols = 1:16;   % ablacion biomecanica
    otherwise,                cols = [];
end
end

function [net, info] = construir_red(tipo, cfg, nFeat)
usaCNN = any(strcmp(tipo, {'fusion', 'fusion_sinFstress', 'resnet50'}));
usaViT = any(strcmp(tipo, {'fusion', 'fusion_sinFstress', 'vit'}));
usaTab = nFeat > 0;
net = dlnetwork;
net = addLayers(net, imageInputLayer([cfg.S cfg.S 3], 'Normalization', 'none', 'Name', 'imagen'));
vecs = strings(0); info = struct('gradcam', "", 'atencion', strings(0), 'descripcion', '');
partes = {};
if usaCNN
    [cnn, pre, origen] = rama_cnn(cfg);
    [net, sal, info.gradcam] = injertar_rama(net, cnn, "cnn_", "imagen", pre);
    net = addLayers(net, functionLayer(@a_vector_CB, 'Name', 'cnn_vec', 'Formattable', true, 'Acceleratable', true));
    net = connectLayers(net, sal, 'cnn_vec'); vecs(end+1) = "cnn_vec";
    partes{end+1} = origen;
end
if usaViT
    [vit, pre, origen] = rama_vit(cfg);
    [net, sal] = injertar_rama(net, vit, "vit_", "imagen", pre);
    net = addLayers(net, functionLayer(@a_vector_CB, 'Name', 'vit_vec', 'Formattable', true, 'Acceleratable', true));
    net = connectLayers(net, sal, 'vit_vec'); vecs(end+1) = "vit_vec";
    partes{end+1} = origen;
end
if usaTab
    net = addLayers(net, featureInputLayer(nFeat, 'Normalization', 'none', 'Name', 'radiomica'));
    vecs(end+1) = "radiomica";
    partes{end+1} = sprintf('rama tabular (%d)', nFeat);
end
cabeza = [
    fullyConnectedLayer(cfg.fusion.fc, 'Name', 'fc_fusion')
    reluLayer('Name', 'relu_fusion')
    dropoutLayer(cfg.fusion.dropout, 'Name', 'drop_fusion')
    fullyConnectedLayer(cfg.nClases, 'Name', 'fc_out')
    softmaxLayer('Name', 'softmax')];
net = addLayers(net, cabeza);
if numel(vecs) > 1
    net = addLayers(net, concatenationLayer(1, numel(vecs), 'Name', 'concat'));
    for k = 1:numel(vecs), net = connectLayers(net, vecs(k), "concat/in" + k); end
    net = connectLayers(net, 'concat', 'fc_fusion');
else
    net = connectLayers(net, vecs(1), 'fc_fusion');
end
if usaViT, net = habilitar_puntajes_atencion(net); end
net = initialize(net);
L = net.Layers;
esAt = arrayfun(@(l) isa(l, 'nnet.cnn.layer.SelfAttentionLayer') && l.HasScoresOutput, L);
info.atencion = string({L(esAt).Name}) + "/scores";
info.descripcion = sprintf('%s: %s -> concat -> FC %d -> ReLU -> Dropout %.1f -> FC %d -> softmax', ...
    tipo, strjoin(partes, ' + '), cfg.fusion.fc, cfg.fusion.dropout, cfg.nClases);
end

function [red, pre, origen] = rama_cnn(cfg)
pre = false;
if cfg.usarPreentrenadas
    try
        red = imagePretrainedNetwork("resnet50"); pre = true;
    catch
        try, red = dag2dlnetwork(resnet50); pre = true; catch, end %#ok<NOCOM>
    end
end
if pre
    origen = 'ResNet-50 (ImageNet)';
else
    % ResNet-50 definido desde cero: 7x7/64 s2 + maxpool + [3 4 6 3] bloques cuello de botella
    red = resnetNetwork([cfg.S cfg.S 3], cfg.nClases, 'StackDepth', cfg.cnn.stack, ...
        'NumFilters', cfg.cnn.filtros, 'BottleneckType', 'downsample-first-conv');
    origen = 'ResNet-50 (desde cero, sin pesos ImageNet)';
end
end

function [red, pre, origen] = rama_vit(cfg)
pre = false;
if cfg.usarPreentrenadas
    try
        red = visionTransformer(cfg.vit.preentrenada);
        L = red.Layers(arrayfun(@(l) isa(l, 'nnet.cnn.layer.ImageInputLayer'), red.Layers));
        if ~isequal(L(1).InputSize(1:2), [cfg.S cfg.S])
            error('El ViT preentrenado requiere entrada %dx%d', L(1).InputSize(1), L(1).InputSize(2));
        end
        pre = true;
    catch ME
        fprintf('      ViT preentrenado no disponible (%s). Se define desde cero.\n', ME.message);
    end
end
if pre
    origen = sprintf('ViT-B/16 (%s)', cfg.vit.preentrenada);
else
    red = vit_desde_cero(cfg);
    origen = sprintf('ViT desde cero (parches %dx%d, %d capas, %d cabezas, D=%d)', ...
        cfg.vit.patch, cfg.vit.patch, cfg.vit.capas, cfg.vit.cabezas, cfg.vit.D);
end
end

function red = vit_desde_cero(cfg)
% Vision Transformer definido capa por capa (pre-norma):
%   parches PxP -> incrustacion lineal (conv PxP, paso P) -> tokens -> + posicion aprendida
%   -> N x [LN -> MHSA -> +residuo -> LN -> MLP(GELU) -> +residuo] -> LN -> promedio de tokens
P = cfg.vit.patch; D = cfg.vit.D; nTok = (cfg.S / P)^2;
red = dlnetwork;
red = addLayers(red, [
    imageInputLayer([cfg.S cfg.S 3], 'Normalization', 'none', 'Name', 'entrada')
    convolution2dLayer(P, D, 'Stride', P, 'Name', 'parches')
    functionLayer(@a_tokens, 'Name', 'tokens', 'Formattable', true, 'Acceleratable', true)]);
red = addLayers(red, positionEmbeddingLayer(D, nTok, 'Name', 'posicion'));
red = addLayers(red, additionLayer(2, 'Name', 'suma_pos'));
red = connectLayers(red, 'tokens', 'posicion');
red = connectLayers(red, 'tokens', 'suma_pos/in1');
red = connectLayers(red, 'posicion', 'suma_pos/in2');
prev = "suma_pos";
for k = 1:cfg.vit.capas
    b = sprintf('enc%02d_', k);
    red = addLayers(red, [
        layerNormalizationLayer('Name', [b 'ln1'])
        selfAttentionLayer(cfg.vit.cabezas, D, 'Name', [b 'mhsa'], 'HasScoresOutput', true, ...
            'DropoutProbability', cfg.vit.dropout)]);
    red = addLayers(red, additionLayer(2, 'Name', [b 'res1']));
    red = addLayers(red, [
        layerNormalizationLayer('Name', [b 'ln2'])
        fullyConnectedLayer(cfg.vit.mlp, 'Name', [b 'mlp1'])
        geluLayer('Name', [b 'gelu'])
        dropoutLayer(cfg.vit.dropout, 'Name', [b 'drop1'])
        fullyConnectedLayer(D, 'Name', [b 'mlp2'])
        dropoutLayer(cfg.vit.dropout, 'Name', [b 'drop2'])]);
    red = addLayers(red, additionLayer(2, 'Name', [b 'res2']));
    red = connectLayers(red, prev, [b 'ln1']);
    red = connectLayers(red, [b 'mhsa/out'], [b 'res1/in1']);
    red = connectLayers(red, prev, [b 'res1/in2']);
    red = connectLayers(red, [b 'res1'], [b 'ln2']);
    red = connectLayers(red, [b 'drop2'], [b 'res2/in1']);
    red = connectLayers(red, [b 'res1'], [b 'res2/in2']);
    prev = string([b 'res2']);
end
red = addLayers(red, [
    layerNormalizationLayer('Name', 'ln_final')
    functionLayer(@promedio_tokens, 'Name', 'pool_tokens', 'Formattable', true, 'Acceleratable', true)
    fullyConnectedLayer(cfg.nClases, 'Name', 'cabeza_vit')
    softmaxLayer('Name', 'softmax_vit')]);
red = connectLayers(red, prev, 'ln_final');
end

function Y = a_tokens(X)
% SSCB (h x w x C x B) -> CBT (C x B x h*w)
Xs = stripdims(X); sz = size(Xs, 1:4);
Y = reshape(permute(Xs, [3 4 1 2]), sz(3), sz(4), sz(1)*sz(2));
Y = dlarray(Y, 'CBT');
end

function Y = promedio_tokens(X)
% CBT -> CB (promedio sobre tokens)
Y = mean(X, finddim(X, 'T'));
Y = stripdims(Y); Y = dlarray(reshape(Y, size(Y, 1), []), 'CB');
end

function Y = a_vector_CB(X)
% Cualquier formato con dimension B -> vector de caracteristicas CB
f = dims(X); Xs = stripdims(X); nd = numel(f);
sz = size(Xs, 1:nd); ib = strfind(f, 'B');
if isempty(ib), Y = dlarray(reshape(Xs, [], 1), 'CB'); return; end
Xs = permute(Xs, [setdiff(1:nd, ib) ib]);
Y = dlarray(reshape(Xs, [], sz(ib)), 'CB');
end

function [net, salida, capaGC] = injertar_rama(net, src, pref, entrada, pre)
% Copia las capas (con sus pesos) de 'src' dentro de 'net' con prefijo 'pref', sustituye la capa
% de entrada por una normalizacion equivalente y retira la cabeza de clasificacion original.
L = src.Layers; C = src.Connections;
nom = string({L.Name});
base = @(s) extractBefore(string(s) + "/", "/");
esIn = arrayfun(@(l) isa(l, 'nnet.cnn.layer.ImageInputLayer'), L);
inL = L(find(esIn, 1)); inName = string(inL.Name);
outs = string(src.OutputNames);
k = find(arrayfun(@(o) isa(L(nom == base(o)), 'nnet.cnn.layer.SoftmaxLayer'), outs), 1);
if isempty(k), k = 1; end
quitar = inName; actual = base(outs(k)); salidaFull = outs(k);
while true
    Lc = L(nom == actual);
    if isa(Lc, 'nnet.cnn.layer.SoftmaxLayer') || isa(Lc, 'nnet.cnn.layer.FullyConnectedLayer')
        quitar(end+1) = actual; %#ok<AGROW>
        s = string(C.Source(base(C.Destination) == actual));
        salidaFull = s(1); actual = base(s(1));
    else
        break;
    end
end
prm = parametros_normalizacion(inL, pre);
net = addLayers(net, functionLayer(@(X) normalizar_entrada(X, prm), 'Name', pref + "norm", 'Acceleratable', true));
net = connectLayers(net, entrada, pref + "norm");
for i = 1:numel(L)
    if any(nom(i) == quitar), continue; end
    Li = L(i); Li.Name = char(pref + nom(i));
    net = addLayers(net, Li);
end
for r = 1:height(C)
    s = string(C.Source{r}); d = string(C.Destination{r});
    if any(base(d) == quitar), continue; end
    if base(s) == inName
        s2 = pref + "norm";
    elseif any(base(s) == quitar)
        continue;
    else
        s2 = pref + s;
    end
    net = connectLayers(net, s2, pref + d);
end
salida = pref + salidaFull;
capaGC = "";
Lf = L(nom == base(salidaFull));
if isa(Lf, 'nnet.cnn.layer.GlobalAveragePooling2DLayer')
    s = string(C.Source(base(C.Destination) == base(salidaFull)));
    capaGC = pref + base(s(1));
end
end

function prm = parametros_normalizacion(inL, pre)
prm.modo = "scratch"; prm.mu = 0; prm.sd = 1; prm.mn = 0; prm.mx = 255;
if ~pre, return; end
prm.modo = string(inL.Normalization);
red = @(v) single(ternario(isempty(v), 0, mean(reshape(v, [], size(v, 3)), 1)));
if ~isempty(inL.Mean), prm.mu = reshape(red(inL.Mean), 1, 1, []); end
if ~isempty(inL.StandardDeviation), prm.sd = reshape(red(inL.StandardDeviation), 1, 1, []); end
if ~isempty(inL.Min), prm.mn = reshape(red(inL.Min), 1, 1, []); end
if ~isempty(inL.Max), prm.mx = reshape(red(inL.Max), 1, 1, []); end
end

function Y = normalizar_entrada(X, prm)
% X en [0,1]. Reproduce la normalizacion de la capa de entrada original (imagenes en [0,255]).
switch prm.modo
    case "zscore",             Y = (255*X - prm.mu) ./ prm.sd;
    case "zerocenter",         Y = 255*X - prm.mu;
    case "rescale-symmetric",  Y = 2*(255*X - prm.mn) ./ (prm.mx - prm.mn) - 1;
    case "rescale-zero-one",   Y = (255*X - prm.mn) ./ (prm.mx - prm.mn);
    case "none",               Y = 255*X;
    otherwise,                 Y = (X - 0.5) / 0.25;
end
end

function net = habilitar_puntajes_atencion(net)
% Para attention rollout: si un bloque de atencion preentrenado no expone sus puntajes, se
% reemplaza por una copia identica (mismos pesos) con salida de puntajes.
L = net.Layers;
for i = 1:numel(L)
    l = L(i);
    if ~isa(l, 'nnet.cnn.layer.SelfAttentionLayer') || l.HasScoresOutput, continue; end
    try
        nl = selfAttentionLayer(l.NumHeads, l.NumKeyChannels, 'NumValueChannels', l.NumValueChannels, ...
            'OutputSize', l.OutputSize, 'HasScoresOutput', true, 'Name', l.Name, ...
            'QueryWeights', l.QueryWeights, 'KeyWeights', l.KeyWeights, 'ValueWeights', l.ValueWeights, ...
            'OutputWeights', l.OutputWeights, 'QueryBias', l.QueryBias, 'KeyBias', l.KeyBias, ...
            'ValueBias', l.ValueBias, 'OutputBias', l.OutputBias);
        net = replaceLayer(net, l.Name, nl);
    catch
    end
end
end

function n = contar_parametros(net)
n = sum(cellfun(@numel, net.Learnables.Value));
end

%% ==========================================================================================
%%  [7] ENTRENAMIENTO (bucle propio: AdamW + CE ponderada + parada temprana por kappa)
%% ==========================================================================================
function D = datos_red(T, cols)
D.png = T.png; D.y = T.y; D.mama = T.mama; D.paciente = T.paciente;
if isempty(cols), D.feat = zeros(height(T), 0); else, D.feat = T.feat(:, cols); end
end

function [mejor, H] = entrenar_red(net, D, idxTr, idxVa, cfg, nombre)
K = cfg.nClases; lote = cfg.opt.lote;
cuenta = accumarray(D.y(idxTr), 1, [K 1]);
w = single(numel(idxTr) ./ (K * max(cuenta, 1)));                 % pesos inversos a la frecuencia
if cfg.gpu, w = gpuArray(w); end
avgG = []; avgSq = []; it = 0; mejorK = -Inf; espera = 0; mejor = net;
filas = zeros(0, 7);
nb = ceil(numel(idxTr) / lote);
for ep = 1:cfg.opt.maxEpocas
    te = tic; perm = idxTr(randperm(numel(idxTr)));
    sl = 0; sa = 0; nv = 0;
    for b = 1:nb
        ii = perm((b - 1)*lote + 1:min(b*lote, numel(perm)));
        % Acumulacion de gradientes: el lote efectivo 'lote' se procesa en micro-lotes que caben
        % en la memoria de la GPU; los gradientes se promedian ponderados por tamano.
        mb = max(1, min(cfg.opt.microLote, numel(ii))); grad = []; perd = 0; yp = [];
        for m0 = 1:mb:numel(ii)
            jj = ii(m0:min(m0 + mb - 1, numel(ii))); f = numel(jj) / numel(ii);
            X = entradas_lote(net, D, jj, cfg, true);
            T = objetivo_onehot(D.y(jj), K, cfg);
            [pm, gm, estado, Y] = dlfeval(@perdida_modelo, net, X, T, w);
            net.State = estado;
            gm = dlupdate(@(g) f * g, gm);
            if isempty(grad), grad = gm; else, grad = dlupdate(@plus, grad, gm); end
            perd = perd + f * double(gather(extractdata(pm)));
            [~, ypm] = max(extractdata(gather(Y)), [], 1); yp = [yp; ypm(:)]; %#ok<AGROW>
        end
        it = it + 1;
        net = decaimiento_pesos(net, cfg.opt.lr * cfg.opt.wd);    % AdamW: decaimiento desacoplado
        [net, avgG, avgSq] = adamupdate(net, grad, avgG, avgSq, it, cfg.opt.lr);
        sl = sl + perd * numel(ii);
        sa = sa + sum(yp(:) == D.y(ii)); nv = nv + numel(ii);
    end
    P = predecir_red(net, D, idxVa, cfg);
    vl = ce_ponderada_num(P, D.y(idxVa), gather(w));
    [Pb, yb] = agregar_mama(P, D.y(idxVa), D.mama(idxVa));
    [~, ypb] = max(Pb, [], 2);
    kv = kappa_cuadratica(yb, ypb, K); av = mean(ypb == yb);
    filas(end+1, :) = [ep, sl/nv, sa/nv, vl, av, kv, toc(te)]; %#ok<AGROW>
    fprintf('      ep %2d | perdida %.4f exact %.3f | val perdida %.4f exact %.3f kappa %.3f | %.0f s\n', filas(end, :));
    if kv > mejorK + 1e-4
        mejorK = kv; mejor = net; espera = 0;
    else
        espera = espera + 1;
        if espera >= cfg.opt.paciencia
            fprintf('      Parada temprana (paciencia %d). Mejor kappa validacion = %.3f\n', cfg.opt.paciencia, mejorK);
            break;
        end
    end
end
H = array2table(filas, 'VariableNames', {'epoca', 'perdida_entr', 'exactitud_entr', ...
    'perdida_val', 'exactitud_val_mama', 'kappa_val_mama', 'segundos'});
H.modelo = repmat(string(nombre), height(H), 1);
end

function [perd, grad, estado, Y] = perdida_modelo(net, X, T, w)
[Y, estado] = forward(net, X{:}, 'Outputs', 'softmax');
perd = -sum(w .* T .* log(Y + 1e-8), 'all') / sum(w .* T, 'all');     % CE ponderada por clase
grad = dlgradient(perd, net.Learnables);
end

function l = ce_ponderada_num(P, y, w)
w = double(w(:)); idx = sub2ind(size(P), (1:numel(y))', y(:));
l = -sum(w(y) .* log(P(idx) + 1e-8)) / sum(w(y));
end

function net = decaimiento_pesos(net, f)
L = net.Learnables;
m = endsWith(string(L.Parameter), "Weights");
L.Value(m) = cellfun(@(v) v * (1 - f), L.Value(m), 'UniformOutput', false);
net.Learnables = L;
end

function T = objetivo_onehot(y, K, cfg)
T = zeros(K, numel(y), 'single'); T(sub2ind([K numel(y)], y(:)', 1:numel(y))) = 1;
T = dlarray(T, 'CB'); if cfg.gpu, T = gpuArray(T); end
end

function X = entradas_lote(net, D, ii, cfg, aumentar)
X = cell(1, numel(net.InputNames));
for k = 1:numel(net.InputNames)
    switch net.InputNames{k}
        case 'imagen'
            A = zeros(cfg.S, cfg.S, 1, numel(ii), 'single');
            for j = 1:numel(ii)
                I = im2single(imread(D.png(ii(j))));
                if aumentar, I = aumentar_imagen(I, cfg); end
                A(:, :, 1, j) = I;
            end
            A = dlarray(repmat(A, 1, 1, 3, 1), 'SSCB');
        case 'radiomica'
            A = dlarray(single(D.feat(ii, :)'), 'CB');
    end
    if cfg.gpu, A = gpuArray(A); end
    X{k} = A;
end
end

function I = aumentar_imagen(I, cfg)
if rand < 0.5, I = fliplr(I); end
t = cfg.aug.tras * cfg.S;
tf = randomAffine2d('Rotation', [-cfg.aug.rot cfg.aug.rot], 'Scale', cfg.aug.escala, ...
    'XTranslation', [-t t], 'YTranslation', [-t t]);
I = imwarp(I, tf, 'OutputView', affineOutputView(size(I), tf, 'BoundsStyle', 'centerOutput'));
end

function P = predecir_red(net, D, idx, cfg)
P = zeros(numel(idx), cfg.nClases);
lote = 2 * cfg.opt.microLote;
for b = 1:ceil(numel(idx) / lote)
    k = (b - 1)*lote + 1:min(b*lote, numel(idx));
    X = entradas_lote(net, D, idx(k), cfg, false);
    Y = predict(net, X{:}, 'Outputs', 'softmax');
    P(k, :) = double(gather(extractdata(Y)))';
end
end

function [Pb, yb, mamas, pacb] = agregar_mama(P, y, mama, paciente)
% Prediccion a nivel de mama: promedio de probabilidades CC + MLO
[g, mamas] = findgroups(mama);
Pb = splitapply(@(p) mean(p, 1), P, g);
yb = splitapply(@(v) v(1), y, g);
if nargin > 3, pacb = splitapply(@(v) v(1), paciente, g); else, pacb = mamas; end
end

%% ---------------------------- REGRESION LOGISTICA MULTINOMIAL -----------------------------
function W = logreg_multinomial(X, y, K, lambda)
X = [ones(size(X, 1), 1) X]; W = zeros(size(X, 2), K);
Y = full(sparse(1:numel(y), y, 1, numel(y), K));
cnt = sum(Y, 1); wc = numel(y) ./ (K * max(cnt, 1)); ws = Y * wc';
for it = 1:3000
    P = softmax_filas(X * W);
    G = X' * ((P - Y) .* ws) / numel(y) + lambda * [zeros(1, K); W(2:end, :)];
    W = W - 0.5 * G;
end
end

function P = softmax_lr(X, W)
P = softmax_filas([ones(size(X, 1), 1) X] * W);
end

function P = softmax_filas(Z)
Z = Z - max(Z, [], 2); E = exp(Z); P = E ./ sum(E, 2);
end

%% ==========================================================================================
%%  [9] EVALUACION Y ESTADISTICA
%% ==========================================================================================
function [RES, COMP] = evaluar_densidad(MOD, TE, cfg, out)
nombres = fieldnames(MOD)'; K = cfg.nClases;
filas = {}; Mb = struct();
for m = nombres
    [Pb, yb, ~, pac] = agregar_mama(MOD.(m{1}).P, TE.y, TE.mama, TE.paciente);
    Mb.(m{1}) = struct('P', Pb, 'y', yb, 'pac', pac);
    met = @(idx) metricas_densidad(yb(idx), Pb(idx, :), K);
    base = met(1:numel(yb));
    B = bootstrap_paciente(pac, met, cfg.nBoot, cfg.semilla);
    ci = prctile_simple_mat(B, [2.5 97.5]);
    etiquetas = {'kappa_cuadratico', 'exactitud', 'macroF1', 'AUC_macro', 'AUC_A', 'AUC_B', 'AUC_C', 'AUC_D', ...
        'AUC_denso', 'sensibilidad_denso', 'especificidad_denso', 'Brier_denso'};
    fila = {string(m{1})};
    for j = 1:numel(base)
        fila{end+1} = sprintf('%.3f [%.3f-%.3f]', base(j), ci(1, j), ci(2, j)); %#ok<AGROW>
    end
    filas(end+1, :) = fila; %#ok<AGROW>
    [~, yp] = max(Pb, [], 2);
    figura_confusion(yb, yp, cfg, m{1}, out);
end
RES = cell2table(filas, 'VariableNames', [{'modelo'} etiquetas]);
writetable(RES, fullfile(out, 'tablas', 'T4_densidad_prueba.csv'));
% Comparaciones preespecificadas contra la fusion (DeLong en denso vs no denso, McNemar, Holm)
ref = Mb.fusion; otros = setdiff(nombres, {'fusion'}, 'stable');
cf = {}; pD = []; pM = [];
for m = otros
    o = Mb.(m{1});
    sRef = ref.P(:, 3) + ref.P(:, 4); sOt = o.P(:, 3) + o.P(:, 4); yd = double(ref.y >= 3);
    [aR, aO, p1] = delong_pareado(yd, sRef, sOt);
    [~, ypR] = max(ref.P, [], 2); [~, ypO] = max(o.P, [], 2);
    p2 = mcnemar(ypR == ref.y, ypO == o.y);
    cf(end+1, :) = {"fusion vs " + string(m{1}), aR, aO, p1, mean(ypR == ref.y), mean(ypO == o.y), p2}; %#ok<AGROW>
    pD(end+1) = p1; pM(end+1) = p2; %#ok<AGROW>
end
COMP = cell2table(cf, 'VariableNames', {'comparacion', 'AUC_denso_fusion', 'AUC_denso_otro', 'p_DeLong', ...
    'exact_fusion', 'exact_otro', 'p_McNemar'});
COMP.p_DeLong_Holm = holm(pD(:)); COMP.p_McNemar_Holm = holm(pM(:));
writetable(COMP, fullfile(out, 'tablas', 'T5_comparaciones.csv'));
figura_roc_calibracion(Mb, out);
end

function v = metricas_densidad(y, P, K)
[~, yp] = max(P, [], 2);
C = accumarray([y yp], 1, [K K]);
f1 = 2*diag(C) ./ max(sum(C, 1)' + sum(C, 2), 1);
auc = zeros(1, K);
for k = 1:K, auc(k) = auc_mw(double(y == k), P(:, k)); end
yd = double(y >= 3); sd = P(:, 3) + P(:, 4); pd = yp >= 3;
v = [kappa_cuadratica(y, yp, K), mean(yp == y), mean(f1), mean(auc, 'omitnan'), auc, ...
    auc_mw(yd, sd), sum(pd & yd == 1) / max(sum(yd == 1), 1), sum(~pd & yd == 0) / max(sum(yd == 0), 1), ...
    mean((sd - yd).^2)];
end

function r = corr_spearman(a, b)
ra = rango_medio(a(:)); rb = rango_medio(b(:));
r = sum((ra - mean(ra)) .* (rb - mean(rb))) / sqrt(sum((ra - mean(ra)).^2) * sum((rb - mean(rb)).^2) + eps);
end

function k = kappa_cuadratica(y, yp, K)
O = accumarray([y(:) yp(:)], 1, [K K]);
[i, j] = meshgrid(1:K); Wt = (i - j).^2 / (K - 1)^2;
E = sum(O, 2) * sum(O, 1) / max(sum(O(:)), 1);
k = 1 - sum(Wt(:) .* O(:)) / max(sum(Wt(:) .* E(:)), eps);
end

function a = auc_mw(y, s)
y = y(:); s = s(:); n1 = sum(y == 1); n0 = sum(y == 0);
if n1 == 0 || n0 == 0, a = NaN; return; end
r = rango_medio(s);
a = (sum(r(y == 1)) - n1*(n1 + 1)/2) / (n1*n0);
end

function r = rango_medio(x)
[xs, o] = sort(x(:)); n = numel(xs); r = zeros(n, 1); i = 1;
while i <= n
    j = i; while j < n && xs(j + 1) == xs(i), j = j + 1; end
    r(o(i:j)) = (i + j) / 2; i = j + 1;
end
end

function [a1, a2, p] = delong_pareado(y, s1, s2)
y = y(:); pos = find(y == 1); neg = find(y == 0); m = numel(pos); n = numel(neg);
if m < 2 || n < 2, a1 = NaN; a2 = NaN; p = NaN; return; end
V10 = zeros(m, 2); V01 = zeros(n, 2); A = zeros(1, 2); S = {s1(:), s2(:)};
for k = 1:2
    s = S{k}; x = s(pos); z = s(neg);
    psi = (x > z') + 0.5*(x == z');
    V10(:, k) = mean(psi, 2); V01(:, k) = mean(psi, 1)'; A(k) = mean(psi(:));
end
Sc = cov(V10)/m + cov(V01)/n;
vd = Sc(1, 1) + Sc(2, 2) - 2*Sc(1, 2);
zv = (A(1) - A(2)) / sqrt(max(vd, eps));
p = erfc(abs(zv) / sqrt(2)); a1 = A(1); a2 = A(2);
end

function p = mcnemar(c1, c2)
b = sum(c1 & ~c2); c = sum(~c1 & c2); n = b + c;
if n == 0, p = 1; return; end
p = min(1, 2 * betainc(0.5, n - min(b, c), min(b, c) + 1));   % binomial exacta bilateral
end

function q = holm(p)
[ps, o] = sort(p(:)); m = numel(ps); q = zeros(m, 1);
aj = min(1, cummax((m - (1:m)' + 1) .* ps));
q(o) = aj;
end

function B = bootstrap_paciente(pac, fmet, nB, semilla)
s = rng; rng(semilla + 7);
[g, ~] = findgroups(pac); grupos = splitapply(@(i) {i}, (1:numel(pac))', g); nG = numel(grupos);
v0 = fmet(1:numel(pac)); B = nan(nB, numel(v0));
for b = 1:nB
    idx = vertcat(grupos{randi(nG, nG, 1)});
    B(b, :) = fmet(idx);
end
rng(s);
end

function q = prctile_simple(v, p)
v = sort(v(~isnan(v(:)))); if isempty(v), q = NaN; return; end
q = interp1(linspace(0, 100, numel(v)), v, p, 'linear');
if numel(v) == 1, q = v; end
end

function Q = prctile_simple_mat(B, ps)
Q = zeros(numel(ps), size(B, 2));
for j = 1:size(B, 2), for i = 1:numel(ps), Q(i, j) = prctile_simple(B(:, j), ps(i)); end, end
end

function [fpr, tpr] = curva_roc(y, s)
[~, o] = sort(s(:), 'descend'); y = y(o);
tpr = [0; cumsum(y == 1) / max(sum(y == 1), 1)]; fpr = [0; cumsum(y == 0) / max(sum(y == 0), 1)];
end

%% ==========================================================================================
%%  [10] EXPLICABILIDAD: GRAD-CAM Y ATTENTION ROLLOUT
%% ==========================================================================================
function XAI = explicabilidad(M, TE, cfg, out)
net = M.net; D = datos_red(TE, M.cols);
XAI.energiaCaja = [];
conCaja = find(cellfun(@(c) ~isempty(c), TE.cajas));
ej = unique([conCaja(1:min(3, end)); (1:min(3, height(TE)))'], 'stable'); ej = ej(1:min(4, end));
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1400 350*numel(ej)]);
tiledlayout(numel(ej), 3, 'TileSpacing', 'compact');
for i = [ej(:)' setdiff(conCaja(:)', ej(:)')]
    X = entradas_lote(net, D, i, cfg, false);
    Y = predict(net, X{:}, 'Outputs', 'softmax'); [~, c] = max(extractdata(gather(Y)));
    cam = [];
    if strlength(M.info.gradcam) > 0, cam = gradcam_red(net, X, M.info.gradcam, c, cfg.S); end
    if ~isempty(cam) && ~isempty(TE.cajas{i})
        msk = false(cfg.S);
        for b = 1:size(TE.cajas{i}, 1)
            bb = mapear_caja(TE.cajas{i}(b, :), TE.meta(i, :));
            msk(max(1, bb(2)):min(cfg.S, bb(4)), max(1, bb(1)):min(cfg.S, bb(3))) = true;
        end
        XAI.energiaCaja(end+1) = sum(cam(msk)) / max(sum(cam(:)), eps);
    end
    if ismember(i, ej)
        I = im2double(imread(TE.png(i))); I = repmat(I / max(I(:) + eps), 1, 1, 3);
        nexttile; imshow(I); title(sprintf('%s | real %s, pred %s', TE.id(i), cfg.clases(TE.y(i)), cfg.clases(c)), 'Interpreter', 'none');
        dibujar_cajas(TE.cajas{i}, TE.meta(i, :));
        nexttile; imshow(I); hold on;
        if ~isempty(cam), h = imagesc(cam); h.AlphaData = 0.45; colormap(gca, jet); end
        dibujar_cajas(TE.cajas{i}, TE.meta(i, :)); title('Grad-CAM (ultimo bloque ResNet-50)');
        nexttile; imshow(I); hold on;
        R = rollout_atencion(net, X, M.info.atencion, cfg.S);
        if ~isempty(R), h = imagesc(R); h.AlphaData = 0.45; colormap(gca, parula); title('Attention rollout (ViT)');
        else, title('Rollout no disponible'); end
    end
end
guardar_figura(f, out, 'F06_gradcam_rollout');
end

function cam = gradcam_red(net, X, capa, c, S)
cam = dlfeval(@gc_interno, net, X, capa, c);
cam = double(gather(extractdata(cam)));
cam = imresize(cam, [S S], 'bilinear'); cam = max(cam, 0); cam = cam / max(max(cam(:)), eps);
end

function cam = gc_interno(net, X, capa, c)
[A, Z] = predict(net, X{:}, 'Outputs', {char(capa), 'fc_out'});
g = dlgradient(sum(Z(c, :), 'all'), A);
w = mean(g, [1 2]);
cam = relu(sum(w .* A, 3));
cam = stripdims(cam);
end

function R = rollout_atencion(net, X, salidas, S)
R = [];
if isempty(salidas), return; end
try
    A = cell(1, numel(salidas));
    [A{:}] = predict(net, X{:}, 'Outputs', cellstr(salidas));
    Racc = [];
    for l = 1:numel(A)
        a = double(gather(extractdata(A{l})));             % claves x consultas x cabezas x obs
        Mq = mean(a(:, :, :, 1), 3)';                       % consultas x claves
        Mq = 0.5*Mq + 0.5*eye(size(Mq)); Mq = Mq ./ sum(Mq, 2);
        if isempty(Racc), Racc = Mq; else, Racc = Mq * Racc; end
    end
    n = size(Racc, 2); g = round(sqrt(n));
    if g^2 == n, r = mean(Racc, 1); else, r = Racc(1, 2:end); g = round(sqrt(n - 1)); end
    R = imresize(reshape(r, g, g), [S S], 'bilinear'); R = R / max(R(:));
catch
    R = [];
end
end

function bb = mapear_caja(b, meta)
% coordenadas DICOM originales -> imagen de la red (S x S)
s1 = meta(1); voltear = meta(2); W1 = meta(3); r0 = meta(4); c0 = meta(5); L = meta(6);
pr = meta(7); pc = meta(8); S = meta(9);
x = [b(1) b(3)] * s1; y = [b(2) b(4)] * s1;
if voltear, x = W1 - x + 1; end
x = x - c0 + 1 + pc; y = y - r0 + 1 + pr;
k = S / L;
bb = round([min(x)*k, min(y)*k, max(x)*k, max(y)*k]);
end

function dibujar_cajas(cajas, meta)
hold on;
for b = 1:size(cajas, 1)
    bb = mapear_caja(cajas(b, :), meta);
    rectangle('Position', [bb(1) bb(2) bb(3) - bb(1) bb(4) - bb(2)], 'EdgeColor', 'g', 'LineWidth', 1.5);
end
end

%% ==========================================================================================
%%  [11] IGR EN CONJUNTO EXTERNO (malignidad)
%% ==========================================================================================
function R = evaluar_igr(EXT, Pext, cfg, out, etiqueta)
if nargin < 5, etiqueta = 'externo'; end
suf = matlab.lang.makeValidName(etiqueta);
[g, ~] = findgroups(EXT.mama);
igr = splitapply(@mean, EXT.igr, g); fd = splitapply(@mean, EXT.Fdens, g);
y = splitapply(@max, EXT.maligno, g); pac = splitapply(@(v) v(1), EXT.paciente, g);
pd = splitapply(@(p) mean(p, 1), Pext, g); pd = pd(:, 3) + pd(:, 4);
R.auc = auc_mw(y, igr);
B = bootstrap_paciente(pac, @(i) auc_mw(y(i), igr(i)), cfg.nBoot, cfg.semilla);
R.ic = prctile_simple_mat(B, [2.5 97.5])';
pos = igr >= cfg.igr.umbral;
R.sens = mean(pos(y == 1)); R.espec = mean(~pos(y == 0));
[fpr, tpr] = curva_roc(y, igr); [~, k] = max(tpr - fpr);
s = sort(igr, 'descend'); R.umbralYouden = s(max(k - 1, 1));
R.sensY = tpr(k); R.especY = 1 - fpr(k);
[R.auc, R.aucDens, R.pDens] = delong_pareado(y, igr, fd);
[~, R.aucFusion, R.pFusion] = delong_pareado(y, igr, pd);
R.brier = mean((igr/10 - y).^2);
fprintf('       IGR AUC = %.3f [%.3f-%.3f] | Sens %.3f Espec %.3f (umbral %.1f) | vs densidad p=%.3g | vs fusion p=%.3g\n', ...
    R.auc, R.ic(1), R.ic(2), R.sens, R.espec, cfg.igr.umbral, R.pDens, R.pFusion);
T = table(R.auc, R.ic(1), R.ic(2), R.sens, R.espec, R.umbralYouden, R.sensY, R.especY, R.aucDens, R.pDens, ...
    R.aucFusion, R.pFusion, R.brier, 'VariableNames', {'AUC_IGR', 'IC_inf', 'IC_sup', 'Sens_umbral', ...
    'Espec_umbral', 'Umbral_Youden', 'Sens_Youden', 'Espec_Youden', 'AUC_densidad', 'p_vs_densidad', ...
    'AUC_prob_densa_fusion', 'p_vs_fusion', 'Brier_IGR'});
writetable(T, fullfile(out, 'tablas', ['T6_IGR_' suf '.csv']));
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1200 420]);
tiledlayout(1, 2);
nexttile; hold on;
[a, b] = curva_roc(y, igr); plot(a, b, 'LineWidth', 2);
[a, b] = curva_roc(y, fd); plot(a, b, '--', 'LineWidth', 1.5);
[a, b] = curva_roc(y, pd); plot(a, b, ':', 'LineWidth', 1.5); plot([0 1], [0 1], 'k:');
legend({sprintf('IGR (%.3f)', R.auc), sprintf('Densidad (%.3f)', R.aucDens), sprintf('P(denso) fusion (%.3f)', R.aucFusion)}, 'Location', 'southeast');
xlabel('1 - especificidad'); ylabel('Sensibilidad'); title(['Malignidad - ' etiqueta]); axis square; grid on;
nexttile; hold on;
histogram(igr(y == 0), 0:0.5:10, 'FaceAlpha', 0.6); histogram(igr(y == 1), 0:0.5:10, 'FaceAlpha', 0.6);
xline(cfg.igr.umbral, 'k--', 'umbral'); legend({'Benigno', 'Maligno'}); xlabel('IGR (0-10)'); ylabel('Mamas');
title('Distribucion del IGR');
guardar_figura(f, out, ['F07_IGR_' suf]);
end

%% ==========================================================================================
%%  [12a] APRENDIZAJE FEDERADO FedAvg (rondas reales)
%% ==========================================================================================
function R = federado_fedavg(TR, TE, idxTr, cfg, out)
K = cfg.nClases; Xtr = TR.feat(idxTr, :); ytr = TR.y(idxTr); ptr = TR.paciente(idxTr);
% Particion no-IID por paciente con Dirichlet(alpha) sobre la clase
[gp, pacs] = findgroups(ptr); cp = splitapply(@(v) mode(v), ytr, gp);
cliente = zeros(numel(pacs), 1);
for k = 1:K
    ids = find(cp == k); if isempty(ids), continue; end
    q = randg(cfg.fed.alphaDir * ones(1, cfg.fed.K)); q = q / sum(q);
    u = ((1:numel(ids))' - 0.5) / numel(ids);
    cliente(ids(randperm(numel(ids)))) = min(sum(u > cumsum(q), 2) + 1, cfg.fed.K);
end
cliente(cliente == 0) = randi(cfg.fed.K, sum(cliente == 0), 1);
cImg = cliente(gp);
red0 = red_tabular(size(Xtr, 2), K);
glob = red0; hist = zeros(cfg.fed.rondas, 3);
nk = accumarray(cImg, 1, [cfg.fed.K 1]);
for r = 1:cfg.fed.rondas
    locales = cell(cfg.fed.K, 1);
    for c = 1:cfg.fed.K
        if nk(c) == 0, continue; end
        locales{c} = entrenar_tabular(glob, Xtr(cImg == c, :), ytr(cImg == c), cfg.fed.epLocal, cfg.fed.lr, K);
    end
    L = glob.Learnables;
    for j = 1:height(L)
        acc = 0;
        for c = find(nk > 0)'
            acc = acc + (nk(c) / sum(nk)) * locales{c}.Learnables.Value{j};
        end
        L.Value{j} = acc;
    end
    glob.Learnables = L;
    [kap, ex] = eval_tabular(glob, TE, K);
    hist(r, :) = [r kap ex];
end
cent = entrenar_tabular(red0, Xtr, ytr, cfg.fed.rondas * cfg.fed.epLocal, cfg.fed.lr, K);
[kc, ec] = eval_tabular(cent, TE, K);
R.historial = array2table(hist, 'VariableNames', {'ronda', 'kappa_prueba', 'exactitud_prueba'});
R.kappaFed = hist(end, 2); R.exactFed = hist(end, 3); R.kappaCent = kc; R.exactCent = ec;
R.imagenesPorCliente = nk';
writetable(R.historial, fullfile(out, 'tablas', 'federado_historial.csv'));
fprintf('       FedAvg: kappa %.3f exact %.3f | Centralizado (mismo MLP): kappa %.3f exact %.3f | n por cliente: %s\n', ...
    R.kappaFed, R.exactFed, kc, ec, mat2str(nk'));
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 800 400]);
plot(hist(:, 1), hist(:, 2), '-o', 'LineWidth', 1.5); hold on; yline(kc, 'r--', 'centralizado');
xlabel('Ronda FedAvg'); ylabel('Kappa ponderado (prueba, nivel imagen)'); grid on;
title(sprintf('FedAvg con %d clientes simulados (particion no-IID por paciente)', cfg.fed.K));
guardar_figura(f, out, 'F08_federado');
end

function net = red_tabular(nIn, K)
net = dlnetwork([
    featureInputLayer(nIn, 'Normalization', 'none', 'Name', 'x')
    fullyConnectedLayer(64, 'Name', 'fc1')
    reluLayer('Name', 'relu1')
    fullyConnectedLayer(K, 'Name', 'fc2')
    softmaxLayer('Name', 'softmax')]);
end

function net = entrenar_tabular(net, X, y, ep, lr, K)
avgG = []; avgSq = []; it = 0; n = numel(y); lote = 32;
w = single(n ./ (K * max(accumarray(y, 1, [K 1]), 1)));
for e = 1:ep
    p = randperm(n);
    for b = 1:ceil(n / lote)
        ii = p((b - 1)*lote + 1:min(b*lote, n)); it = it + 1;
        T = zeros(K, numel(ii), 'single'); T(sub2ind([K numel(ii)], y(ii)', 1:numel(ii))) = 1;
        [~, g] = dlfeval(@perdida_tabular, net, dlarray(single(X(ii, :)'), 'CB'), dlarray(T, 'CB'), w);
        [net, avgG, avgSq] = adamupdate(net, g, avgG, avgSq, it, lr);
    end
end
end

function [l, g] = perdida_tabular(net, X, T, w)
Y = forward(net, X);
l = -sum(w .* T .* log(Y + 1e-8), 'all') / sum(w .* T, 'all');
g = dlgradient(l, net.Learnables);
end

function [kap, ex] = eval_tabular(net, TE, K)
Y = extractdata(predict(net, dlarray(single(TE.feat'), 'CB')));
[~, yp] = max(Y, [], 1);
kap = kappa_cuadratica(TE.y, yp(:), K); ex = mean(yp(:) == TE.y);
end

%% ==========================================================================================
%%  [12b] DDPM ENTRENADO (U-Net pequena, prediccion de ruido)
%% ==========================================================================================
function R = ddpm_entrenar(TR, TE, idxTr, cfg, out)
n = cfg.ddpm.lado; T = cfg.ddpm.T;
cargar = @(f) imresize(im2single(imread(f)), [n n], 'bilinear') * 2 - 1;
X0 = zeros(n, n, 1, numel(idxTr), 'single');
for i = 1:numel(idxTr), X0(:, :, 1, i) = cargar(TR.png(idxTr(i))); end
beta = linspace(1e-4, 0.02, T)'; alfa = 1 - beta; ab = cumprod(alfa);
net = unet_ddpm(n);
avgG = []; avgSq = []; perd = zeros(cfg.ddpm.iter, 1);
for it = 1:cfg.ddpm.iter
    ii = randi(size(X0, 4), cfg.ddpm.lote, 1); t = randi(T, cfg.ddpm.lote, 1);
    x0 = X0(:, :, :, ii); ep = randn(size(x0), 'single');
    a = reshape(single(ab(t)), 1, 1, 1, []);
    xt = sqrt(a) .* x0 + sqrt(1 - a) .* ep;
    tm = repmat(reshape(single(t / T), 1, 1, 1, []), n, n, 1, 1);
    Xin = dlarray(cat(3, xt, tm), 'SSCB'); E = dlarray(ep, 'SSCB');
    if cfg.gpu, Xin = gpuArray(Xin); E = gpuArray(E); end
    [l, g] = dlfeval(@perdida_ddpm, net, Xin, E);
    [net, avgG, avgSq] = adamupdate(net, g, avgG, avgSq, it, cfg.ddpm.lr);
    perd(it) = double(gather(extractdata(l)));
    if mod(it, max(1, round(cfg.ddpm.iter/10))) == 0, fprintf('       it %5d | MSE %.4f\n', it, perd(it)); end
end
% Muestreo ancestral
x = randn(n, n, 1, cfg.ddpm.nMuestras, 'single');
for t = T:-1:1
    tm = repmat(single(t / T), n, n, 1, size(x, 4));
    Xin = dlarray(cat(3, x, tm), 'SSCB'); if cfg.gpu, Xin = gpuArray(Xin); end
    eh = gather(extractdata(predict(net, Xin)));
    z = randn(size(x), 'single') * (t > 1);
    x = (x - beta(t) / sqrt(1 - ab(t)) * eh) / sqrt(alfa(t)) + sqrt(beta(t)) * z;
end
muestras = (min(max(x, -1), 1) + 1) / 2;
% Metricas de reconstruccion en un paso (t = tEval) sobre imagenes de prueba no vistas
te = min(height(TE), 32); ps = zeros(te, 1); ss = zeros(te, 1); t = min(cfg.ddpm.tEval, T);
for i = 1:te
    x0 = cargar(TE.png(i)); ep = randn(size(x0), 'single');
    xt = sqrt(ab(t))*x0 + sqrt(1 - ab(t))*ep;
    Xin = dlarray(cat(3, xt, repmat(single(t/T), n, n)), 'SSCB'); if cfg.gpu, Xin = gpuArray(Xin); end
    eh = gather(extractdata(predict(net, Xin)));
    xh = (xt - sqrt(1 - ab(t))*eh) / sqrt(ab(t));
    ps(i) = psnr((min(max(xh, -1), 1) + 1)/2, (x0 + 1)/2); ss(i) = ssim((min(max(xh, -1), 1) + 1)/2, (x0 + 1)/2);
end
R.perdida = perd; R.psnr = mean(ps); R.ssim = mean(ss); R.muestras = muestras;
fprintf('       Reconstruccion en un paso (t=%d): PSNR %.2f dB, SSIM %.3f (no son FID ni metricas clinicas)\n', t, R.psnr, R.ssim);
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1300 450]);
tiledlayout(1, 2);
nexttile; plot(movmean(perd, 50), 'LineWidth', 1.2); xlabel('Iteracion'); ylabel('MSE (media movil 50)');
title('Perdida de entrenamiento DDPM'); grid on;
nexttile; montage(muestras, 'Size', [4 ceil(cfg.ddpm.nMuestras/4)]); title('Muestras generadas');
guardar_figura(f, out, 'F09_DDPM');
end

function [l, g] = perdida_ddpm(net, X, E)
Eh = forward(net, X);
l = mean((Eh - E).^2, 'all');
g = dlgradient(l, net.Learnables);
end

function net = unet_ddpm(n)
net = dlnetwork;
net = addLayers(net, [
    imageInputLayer([n n 2], 'Normalization', 'none', 'Name', 'xt')
    convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'c1a')
    reluLayer('Name', 'r1a')
    convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'c1b')
    reluLayer('Name', 'r1b')]);
net = addLayers(net, [
    convolution2dLayer(3, 64, 'Stride', 2, 'Padding', 'same', 'Name', 'd1')
    reluLayer('Name', 'rd1')
    convolution2dLayer(3, 64, 'Padding', 'same', 'Name', 'c2')
    reluLayer('Name', 'r2')]);
net = addLayers(net, [
    convolution2dLayer(3, 128, 'Stride', 2, 'Padding', 'same', 'Name', 'd2')
    reluLayer('Name', 'rd2')
    convolution2dLayer(3, 128, 'Padding', 'same', 'Name', 'c3')
    reluLayer('Name', 'r3')
    transposedConv2dLayer(2, 64, 'Stride', 2, 'Name', 'u1')
    reluLayer('Name', 'ru1')]);
net = addLayers(net, [
    depthConcatenationLayer(2, 'Name', 'cat1')
    convolution2dLayer(3, 64, 'Padding', 'same', 'Name', 'c4')
    reluLayer('Name', 'r4')
    transposedConv2dLayer(2, 32, 'Stride', 2, 'Name', 'u2')
    reluLayer('Name', 'ru2')]);
net = addLayers(net, [
    depthConcatenationLayer(2, 'Name', 'cat2')
    convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'c5')
    reluLayer('Name', 'r5')
    convolution2dLayer(1, 1, 'Name', 'eps')]);
net = connectLayers(net, 'r1b', 'd1');
net = connectLayers(net, 'r2', 'd2');
net = connectLayers(net, 'ru1', 'cat1/in1'); net = connectLayers(net, 'r2', 'cat1/in2');
net = connectLayers(net, 'ru2', 'cat2/in1'); net = connectLayers(net, 'r1b', 'cat2/in2');
net = initialize(net);
end

%% ==========================================================================================
%%  PARTICION POR PACIENTE
%% ==========================================================================================
function fold = pliegues_por_paciente(pac, y, K, semilla)
s = rng; rng(semilla);
[g, ~] = findgroups(pac); cp = splitapply(@(v) mode(v), y, g);
fp = zeros(max(g), 1);
for c = unique(cp)'
    ids = find(cp == c); ids = ids(randperm(numel(ids)));
    fp(ids) = mod(0:numel(ids) - 1, K)' + 1;
end
fold = fp(g); rng(s);
end

%% ==========================================================================================
%%  FIGURAS
%% ==========================================================================================
function figura_pipeline(T, cfg, out)
i = 1; S = preprocesar_imagen(T.fuente(i), T.tipo(i), T.espaciado(i), T.vista(i), cfg);
[~, ~, fem] = fem_biomecanico(S.Mw, S.Dw, cfg, false);
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1500 380]);
tiledlayout(1, 5, 'TileSpacing', 'compact');
nexttile; imshow(S.Ic, []); title('Campo plano + mediana + CLAHE');
nexttile; imshow(S.Iw, []); hold on; visboundaries(S.Mw, 'Color', 'y'); title('Mama segmentada');
nexttile; imshow(S.Dw); title(sprintf('Tejido denso (F_{dens}=%.2f)', nnz(S.Dw)/nnz(S.Mw)));
nexttile; patch('Faces', fem.tri, 'Vertices', fem.nodos, 'FaceVertexCData', fem.vm, 'FaceColor', 'flat', 'EdgeColor', 'none');
axis image ij off; colorbar; title('von Mises (kPa)');
nexttile; imshow(S.netImg, []); title(sprintf('Entrada a la red %dx%d', cfg.S, cfg.S));
guardar_figura(f, out, 'F02_pipeline_ejemplo');
end

function figura_curvas(H, nombre, out)
if isempty(H), return; end
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1300 380]);
tiledlayout(1, 3);
nexttile; plot(H.epoca, H.perdida_entr, '-o', H.epoca, H.perdida_val, '-s', 'LineWidth', 1.3);
legend('entrenamiento', 'validacion'); xlabel('Epoca'); ylabel('CE ponderada'); grid on; title('Perdida');
nexttile; plot(H.epoca, H.exactitud_entr, '-o', H.epoca, H.exactitud_val_mama, '-s', 'LineWidth', 1.3);
legend('entrenamiento (imagen)', 'validacion (mama)', 'Location', 'southeast'); xlabel('Epoca'); ylabel('Exactitud'); grid on;
nexttile; plot(H.epoca, H.kappa_val_mama, '-d', 'LineWidth', 1.3); [~, k] = max(H.kappa_val_mama);
xline(H.epoca(k), 'r--', 'mejor'); xlabel('Epoca'); ylabel('\kappa ponderado'); grid on; title('Criterio de parada');
sgtitle(sprintf('Historial de entrenamiento: %s', nombre), 'Interpreter', 'none');
guardar_figura(f, out, ['F03_curvas_' nombre]);
end

function figura_confusion(y, yp, cfg, nombre, out)
K = cfg.nClases; C = accumarray([y yp], 1, [K K]); Cn = C ./ max(sum(C, 2), 1);
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 520 460]);
imagesc(Cn, [0 1]); colormap(flipud(gray)); colorbar; axis square;
for i = 1:K, for j = 1:K
    text(j, i, sprintf('%d\n(%.0f%%)', C(i, j), 100*Cn(i, j)), 'HorizontalAlignment', 'center', ...
        'Color', ternario(Cn(i, j) > 0.5, 'w', 'k'));
end, end
set(gca, 'XTick', 1:K, 'XTickLabel', cfg.clases, 'YTick', 1:K, 'YTickLabel', cfg.clases);
xlabel('Prediccion'); ylabel('Referencia (consenso BI-RADS)');
title(sprintf('Matriz de confusion (prueba, nivel mama): %s', nombre), 'Interpreter', 'none');
guardar_figura(f, out, ['F04_confusion_' nombre]);
end

function figura_roc_calibracion(Mb, out)
f = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1200 450]);
tiledlayout(1, 2); nexttile; hold on; lg = {};
for m = fieldnames(Mb)'
    s = Mb.(m{1}).P(:, 3) + Mb.(m{1}).P(:, 4); y = double(Mb.(m{1}).y >= 3);
    [a, b] = curva_roc(y, s); plot(a, b, 'LineWidth', 1.6); lg{end+1} = sprintf('%s (%.3f)', m{1}, auc_mw(y, s)); %#ok<AGROW>
end
plot([0 1], [0 1], 'k:'); legend(lg, 'Interpreter', 'none', 'Location', 'southeast'); axis square; grid on;
xlabel('1 - especificidad'); ylabel('Sensibilidad'); title('Denso (C/D) vs no denso (A/B)');
nexttile; hold on;
s = Mb.fusion.P(:, 3) + Mb.fusion.P(:, 4); y = double(Mb.fusion.y >= 3);
ed = linspace(0, 1, 11); [~, ~, bin] = histcounts(s, ed);
pm = accumarray(bin(bin > 0), s(bin > 0), [10 1], @mean, NaN); om = accumarray(bin(bin > 0), y(bin > 0), [10 1], @mean, NaN);
plot(pm, om, 'o-', 'LineWidth', 1.5); plot([0 1], [0 1], 'k:'); axis square; grid on;
xlabel('Probabilidad predicha (denso)'); ylabel('Frecuencia observada');
title(sprintf('Calibracion fusion (Brier %.3f)', mean((s - y).^2)));
guardar_figura(f, out, 'F05_ROC_calibracion');
end

function guardar_figura(f, out, nombre)
exportgraphics(f, fullfile(out, 'figuras', [nombre '.png']), 'Resolution', 300);
close(f);
end

%% ==========================================================================================
%%  INFORME
%% ==========================================================================================
function escribir_informe(out, cfg, VER, MOD, RES, COMP, XAI, IGR, FED, DDPM, ARCH)
fid = fopen(fullfile(out, 'INFORME_V12.txt'), 'w', 'n', 'UTF-8'); c = onCleanup(@() fclose(fid));
p = @(varargin) fprintf(fid, varargin{:});
p('SISTEMA V12 - INFORME DE EJECUCION (%s)\n\n', char(datetime('now')));
if cfg.modoFantoma
    p('*** MODO VERIFICACION CON FANTOMA ***\n');
    p('El entrenamiento es real pero sobre imagenes sinteticas. Estas cifras verifican la\n');
    p('implementacion y NO constituyen desempeno clinico. No reportarlas como resultados.\n\n');
end
p('1. VERIFICACION DE IMPLEMENTACION\n');
p('   Segmentacion (n=%d): Dice %.3f +/- %.3f | HD95 %.1f px\n', numel(VER.dice), mean(VER.dice), std(VER.dice), mean(VER.hd95));
if isfield(VER, 'pectoral') && ~isempty(VER.pectoral.dice)
    p('   Pectoral vs manual INbreast (n=%d MLO): Dice %.3f +/- %.3f | HD95 %.1f mm\n', numel(VER.pectoral.dice), ...
        mean(VER.pectoral.dice), std(VER.pectoral.dice), mean(VER.pectoral.hd95, 'omitnan'));
end
p('   FEM analitico: sigma_vm %.3f kPa vs teorico %.3f kPa (error %.2f%%)\n\n', VER.sigFEM, VER.sigTeo, 100*VER.errFEM);
p('2. DATOS\n   Imagenes: entrenamiento %d | prueba %d | externo %d | excluidas %s\n', ARCH.TR, ARCH.TE, ARCH.EXT, mat2str(ARCH.exc));
if isfield(ARCH, 'flujo'), p('   Flujo VinDr: %s\n', jsonencode(ARCH.flujo)); end
p('\n3. ARQUITECTURAS ENTRENADAS\n');
for m = fieldnames(MOD)'
    H = MOD.(m{1}).H;
    p('   - %s\n', MOD.(m{1}).info.descripcion);
    if ~isempty(H), p('     epocas %d | mejor kappa validacion %.3f\n', height(H), max(H.kappa_val_mama)); end
end
p('   Optimizacion: AdamW lr %.0e, wd %.2f, lote %d, CE ponderada, parada temprana (paciencia %d) por kappa\n\n', ...
    cfg.opt.lr, cfg.opt.wd, cfg.opt.lote, cfg.opt.paciencia);
p('4. DENSIDAD - CONJUNTO DE PRUEBA (nivel mama, IC95%% bootstrap por paciente)\n');
for i = 1:height(RES)
    p('   %-18s kappa %s | exact %s | macroF1 %s | AUC macro %s | AUC denso %s\n', RES.modelo(i), ...
        RES.kappa_cuadratico{i}, RES.exactitud{i}, RES.macroF1{i}, RES.AUC_macro{i}, RES.AUC_denso{i});
end
if isfield(RES.Properties.UserData, 'spearmanFdens')
    p('   F_dens cuantitativo vs categoria del radiologo: Spearman rho = %.3f\n', RES.Properties.UserData.spearmanFdens);
end
p('\n   Comparaciones (Holm):\n');
for i = 1:height(COMP)
    p('   %-30s AUC %.3f vs %.3f p=%.3g (Holm %.3g) | exact %.3f vs %.3f McNemar p=%.3g (Holm %.3g)\n', ...
        COMP.comparacion(i), COMP.AUC_denso_fusion(i), COMP.AUC_denso_otro(i), COMP.p_DeLong(i), ...
        COMP.p_DeLong_Holm(i), COMP.exact_fusion(i), COMP.exact_otro(i), COMP.p_McNemar(i), COMP.p_McNemar_Holm(i));
end
p('\n5. EXPLICABILIDAD\n   Fraccion de energia Grad-CAM dentro de hallazgos anotados: %s\n', texto_media(XAI.energiaCaja));
if isfield(IGR, 'auc')
    p('\n6. IGR - CONJUNTO EXTERNO (malignidad)\n   AUC %.3f [%.3f-%.3f] | umbral %.1f: sens %.3f espec %.3f | Youden %.2f: sens %.3f espec %.3f\n', ...
        IGR.auc, IGR.ic(1), IGR.ic(2), cfg.igr.umbral, IGR.sens, IGR.espec, IGR.umbralYouden, IGR.sensY, IGR.especY);
    p('   vs densidad: AUC %.3f p=%.3g | vs P(denso) fusion: AUC %.3f p=%.3g | Brier %.3f\n', ...
        IGR.aucDens, IGR.pDens, IGR.aucFusion, IGR.pFusion, IGR.brier);
end
if isfield(FED, 'kappaFed')
    p('\n7. FEDERADO (FedAvg, %d clientes simulados, %d rondas)\n   FedAvg kappa %.3f exact %.3f | centralizado kappa %.3f exact %.3f\n', ...
        cfg.fed.K, cfg.fed.rondas, FED.kappaFed, FED.exactFed, FED.kappaCent, FED.exactCent);
    p('   Nota: clientes = particiones por paciente de un mismo conjunto; no es un despliegue multi-institucional.\n');
end
if isfield(DDPM, 'psnr')
    p('\n8. DDPM (T=%d, %d iteraciones)\n   MSE final %.4f | reconstruccion un paso t=%d: PSNR %.2f dB, SSIM %.3f\n', ...
        cfg.ddpm.T, cfg.ddpm.iter, mean(DDPM.perdida(max(1, end-50):end)), cfg.ddpm.tEval, DDPM.psnr, DDPM.ssim);
    p('   Nota: sin FID ni validacion por radiologos; las muestras no se usan para entrenar.\n');
end
end

%% ==========================================================================================
%%  UTILIDADES
%% ==========================================================================================
function v = ternario(c, a, b)
if c, v = a; else, v = b; end
end

function linea(ch)
fprintf('%s\n', repmat(ch, 1, 92));
end

function s = texto_media(v)
if isempty(v), s = 'N/D (no hay imagenes de prueba con cajas anotadas)';
else, s = sprintf('%.3f +/- %.3f (n=%d)', mean(v), std(v), numel(v)); end
end
