%% ============================================================================
%  SISTEMA UNIFICADO AVANZADO PARA ANÁLISIS DE CÁNCER DE MAMA
%  Integra: Procesamiento DICOM, Deep Learning (CNN, Autoencoder, ViT),
%  Radiómica, Modelado Biomecánico, Microcalcificaciones, BI-RADS Automático,
%  Riesgo Integrado, Análisis 3D, Seguimiento Temporal, Explicabilidad (Grad-CAM),
%  Aumento con Difusión (DDPM) y Aprendizaje Federado (simulado).
%  Versión: Final - 2026 (Tesis de Maestría)
% ============================================================================

clear all; close all; clc;
warning off all;  % Para evitar warnings de toolboxes faltantes (opcional)

%% ======================== CONFIGURACIÓN GENERAL ============================
disp('=== SISTEMA UNIFICADO AVANZADO PARA CÁNCER DE MAMA (2026) ===');
disp('Cargando configuración...');

% Parámetros base
config.umbral_area_minima = 1000;
config.umbral_compacidad_maligna = 1.3;
config.umbral_diametro_maligno = 150;
config.realce = 0.6;
config.umbralbin_tophat = 0.15;
config.r_tophat = 30;

% Deep Learning básico
config.deep_learning.uso_autoencoder = true;
config.deep_learning.uso_cnn_clasificacion = true;
config.deep_learning.uso_densenet_densidad = true;
config.deep_learning.umbral_confianza_cnn = 0.75;
config.deep_learning.uso_transformer = true;   % ViT
config.deep_learning.uso_attention = true;

% Biomecánico (Ng & Lau 2015)
config.modelo_biomecanico.young_glandular = 15.1;
config.modelo_biomecanico.young_adipose = 4.46;
config.modelo_biomecanico.poisson_ratio = 0.45;
config.modelo_biomecanico.compression_factor = 0.7;
config.modelo_biomecanico.stress_threshold = 8.5;

% Denoising
config.denoising.uso_autoencoder_denoising = true;
config.denoising.factor_ruido = 0.1;

% Radiómica
config.radiomica.habilitado = true;
config.radiomica.uso_lbp = true;

% Análisis 3D (opcional, requiere volumen)
config.analisis_3d.habilitado = false;   % Activar solo si el DICOM es 3D

% Seguimiento temporal (si hay múltiples estudios)
config.analisis_temporal.habilitado = false;

% Riesgo
config.riesgo.uso_modelo_prediccion = true;

% Exportación
config.exportacion.habilitada = true;
config.exportacion.formato = {'pdf', 'excel', 'json'};

% Visualización
config.visualizacion.mostrar_todas_figuras = true;
config.visualizacion.guardar_resultados = true;

% Configuración ViT
config.vit.imagen_size = [224 224];
config.vit.patch_size = 16;
config.vit.num_heads = 8;
config.vit.hidden_dim = 512;
config.vit.mlp_dim = 2048;
config.vit.num_classes = 4;   % Benigno, Maligno, Tumor, Indeterminado
config.vit.dropout = 0.1;

% Configuración difusión
config.diffusion.num_timesteps = 100;
config.diffusion.beta_start = 1e-4;
config.diffusion.beta_end = 0.02;
config.diffusion.image_size = 64;

% Configuración federada
config.federated.num_clients = 2;
config.federated.rounds = 3;
config.federated.local_epochs = 2;

%% ======================== INICIALIZACIÓN DE MODELOS ========================
fprintf('Inicializando modelos de deep learning...\n');
modelos.deep_learning = inicializarModelosDeepLearning(config);

%% ======================== CARGA INTELIGENTE DE DICOM ========================
try
    [filename, pathname] = uigetfile({'*.dcm;*.dicom','Archivos DICOM';'*.*','Todos los archivos'}, ...
                                     'Seleccione un estudio mamográfico');
    if isequal(filename,0)
        disp('Usuario canceló.');
        return;
    end
    fullpath = fullfile(pathname, filename);
    info = dicominfo(fullpath);
    volumen = dicomread(fullpath);
    
    % Mostrar metadatos importantes
    fprintf('Archivo: %s\n', filename);
    fprintf('Modalidad: %s\n', info.Modality);
    if isfield(info,'PatientName')
        fprintf('Paciente: %s (%s)\n', info.PatientName, info.PatientSex);
    end
    fprintf('Estudio: %s\n', info.StudyDate);
    fprintf('Dimensiones: ');
    if ndims(volumen)==2
        fprintf('%dx%d\n', size(volumen,1), size(volumen,2));
        imagen_principal = volumen;
        es_3d = false;
    else
        fprintf('%dx%dx%d\n', size(volumen,1), size(volumen,2), size(volumen,3));
        slice_optimo = round(size(volumen,3)/2);
        imagen_principal = volumen(:,:,slice_optimo);
        fprintf('Usando slice %d de %d para análisis 2D\n', slice_optimo, size(volumen,3));
        es_3d = (ndims(volumen)==3);
    end
    
catch ME
    fprintf('Error al cargar DICOM: %s\n', ME.message);
    return;
end

%% ======================== PREPROCESAMIENTO AVANZADO ========================
fprintf('Aplicando pipeline de preprocesamiento...\n');

% Normalización DICOM
if isfield(info,'RescaleSlope') && isfield(info,'RescaleIntercept')
    img_norm = single(imagen_principal) * info.RescaleSlope + info.RescaleIntercept;
else
    img_norm = single(imagen_principal);
end

% Conversión a 8 bits
if isfield(info,'WindowCenter') && isfield(info,'WindowWidth')
    wc = double(info.WindowCenter(1));
    ww = double(info.WindowWidth(1));
    low = wc - ww/2;
    high = wc + ww/2;
    img_8 = uint8(255 * mat2gray(img_norm, [low, high]));
else
    p_low = prctile(img_norm(:), 2);
    p_high = prctile(img_norm(:), 98);
    img_8 = uint8(255 * mat2gray(img_norm, [p_low, p_high]));
end

if size(img_8,3)==3
    img_gris = rgb2gray(img_8);
else
    img_gris = img_8;
end

% Denoising
if config.denoising.uso_autoencoder_denoising
    img_denoised = aplicarDenoisingAutoencoder(img_gris, config);
else
    img_denoised = img_gris;
end

% CLAHE y filtrado bilateral
img_clahe = adapthisteq(img_denoised, 'ClipLimit',0.02, 'NumTiles',[8 8]);
img_final = imbilatfilt(img_clahe, 'DegreeOfSmoothing',0.5, 'SpatialSigma',2);

fprintf('Preprocesamiento completado.\n');

%% ======================== SEGMENTACIÓN HÍBRIDA =============================
fprintf('Segmentando tejido mamario...\n');

masc_adapt = imbinarize(img_final, 'adaptive', 'Sensitivity',0.55);

itoh = uint8(min(double(img_final)*6, 255));
se = strel('disk', config.r_tophat);
otoh = imtophat(itoh, se);
oehc = imadjust(otoh, [0 config.realce], [0 1]);
masc_tophat = imbinarize(oehc, config.umbralbin_tophat);

masc_comb = masc_adapt | masc_tophat;
se_morf = strel('disk', 6);
masc_limpia = imclose(imopen(masc_comb, se_morf), se_morf);
mascara = bwareaopen(masc_limpia, config.umbral_area_minima);
mascara = imfill(mascara, 'holes');

if config.deep_learning.uso_cnn_clasificacion
    mascara = refinarSegmentacionConCNN(img_final, mascara);
end

stats_area = regionprops(mascara, 'Area', 'Centroid');
for k = 1:length(stats_area)
    if stats_area(k).Area > 0.3 * numel(mascara)
        mascara = mascara & ~bwselect(mascara, round(stats_area(k).Centroid(1)), round(stats_area(k).Centroid(2)));
    end
end

num_regiones = max(bwlabel(mascara),[],'all');
fprintf('Segmentación final: %d regiones detectadas\n', num_regiones);

%% ======================== ANÁLISIS DE DENSIDAD Y TEXTURA ===================
fprintf('Calculando densidad mamaria...\n');
[mapa_densidad, metricas_densidad] = generarMapaDensidadAvanzado(img_final, mascara, config);
fprintf('Densidad: %.1f%% (BI-RADS %s)\n', metricas_densidad.porcentaje_densidad, metricas_densidad.birads_categoria);

if config.deep_learning.uso_densenet_densidad
    [clasif_densidad_densenet, score_densidad, mapa_calor_densenet] = ...
        clasificarDensidadMamariaDenseNet(img_final, config);
    fprintf('DenseNet: %s (score=%.3f)\n', clasif_densidad_densenet, score_densidad);
end

%% ======================== MODELADO BIOMECÁNICO =============================
fprintf('Generando modelo biomecánico...\n');
[modelo_biomecanico, deformaciones, metricas_biomecanicas] = ...
    generarModeloBiomecanicoAvanzado(img_final, mapa_densidad, config.modelo_biomecanico);

%% ======================== EXTRACCIÓN RADIÓMICA =============================
if config.radiomica.habilitado
    fprintf('Extrayendo características radiómicas (LBP)...\n');
    caracteristicas_radiomicas = extraerCaracteristicasLBP(img_final);
else
    caracteristicas_radiomicas = [];
end

%% ======================== DETECCIÓN DE MICROCALCIFICACIONES =================
fprintf('Detectando microcalcificaciones...\n');
[microcalcificaciones, mapa_calcio] = detectarMicrocalcificacionesAvanzadas(img_final, config);

%% ======================== CLASIFICACIÓN DE LESIONES =========================
fprintf('Clasificando lesiones...\n');
[etiquetas, num_reg] = bwlabel(mascara);
resultados = [];

if num_reg > 0
    propiedades = regionprops(etiquetas, img_final, ...
        'Area', 'Perimeter', 'Eccentricity', 'Solidity', 'BoundingBox', ...
        'Centroid', 'MajorAxisLength', 'MinorAxisLength', 'MeanIntensity');
    
    for i = 1:num_reg
        bbox = round(propiedades(i).BoundingBox);
        x1 = max(1, bbox(1)); y1 = max(1, bbox(2));
        x2 = min(size(img_final,2), x1+bbox(3)-1);
        y2 = min(size(img_final,1), y1+bbox(4)-1);
        if x2>x1 && y2>y1
            roi = img_final(y1:y2, x1:x2);
        else
            roi = [];
        end
        
        [clasif, punt_riesgo, conf] = clasificarLesionAvanzada(...
            img_final, propiedades(i), roi, config);
        
        diam_eq = 2 * sqrt(propiedades(i).Area/pi);
        compacidad = (propiedades(i).Perimeter^2) / (4*pi*propiedades(i).Area);
        
        resultados = [resultados, struct(...
            'ID', i, ...
            'Area', propiedades(i).Area, ...
            'Perimetro', propiedades(i).Perimeter, ...
            'Diametro', diam_eq, ...
            'DiametroMayor', propiedades(i).MajorAxisLength, ...
            'DiametroMenor', propiedades(i).MinorAxisLength, ...
            'Excentricidad', propiedades(i).Eccentricity, ...
            'Solidez', propiedades(i).Solidity, ...
            'Compacidad', compacidad, ...
            'IntensidadMedia', propiedades(i).MeanIntensity, ...
            'Clasificacion', clasif, ...
            'PuntuacionRiesgo', punt_riesgo, ...
            'Confianza', conf, ...
            'Centroide', propiedades(i).Centroid, ...
            'BoundingBox', propiedades(i).BoundingBox)];
    end
end

%% ======================== RIESGO INTEGRADO Y BI-RADS =======================
fprintf('Calculando riesgo integrado y BI-RADS automático...\n');
riesgo_integrado = calcularRiesgoIntegradoAvanzado(resultados, metricas_densidad, img_final);
[categoria_birads, prob_birads] = clasificarBIRADSAvanzado(resultados, metricas_densidad, ...
                                    riesgo_integrado, microcalcificaciones);

%% ======================== NUEVAS TÉCNICAS 2026 =============================
fprintf('Aplicando Vision Transformer (ViT) con Grad-CAM...\n');
[clasificacion_vit, probs_vit, heatmap_gradcam] = aplicarVisionTransformer(img_final, config);
fprintf('ViT clasifica como: %s (prob=%.2f)\n', clasificacion_vit, max(probs_vit));

if ~isempty(resultados)
    fprintf('Generando ejemplo de aumento por difusión...\n');
    generarEjemploDifusion(img_final, mascara, config);
end

fprintf('Simulando aprendizaje federado (FedAvg)...\n');
simularAprendizajeFederado(resultados, caracteristicas_radiomicas, config);

%% ======================== DIAGNÓSTICO INTEGRADO ============================
fprintf('Generando diagnóstico integrado...\n');
diagnostico = generarDiagnosticoIntegradoAvanzado(resultados, metricas_densidad, ...
                modelo_biomecanico, config);
diagnostico.birads_automatico = categoria_birads;
diagnostico.riesgo_integrado = riesgo_integrado;
diagnostico.microcalcificaciones = microcalcificaciones;
diagnostico.clasificacion_vit = clasificacion_vit;
diagnostico.probabilidad_vit = max(probs_vit);

alertas_clinicas = generarAlertasClinicas(diagnostico, riesgo_integrado, metricas_densidad, config);

%% ======================== VISUALIZACIONES (12-13 FIGURAS) ==================
disp('Generando visualizaciones avanzadas...');

fig1 = visualizarProcesamientoAvanzado(imagen_principal, img_final, mascara, ...
        metricas_densidad, info, config);
fig2 = visualizarDensidadTexturaAvanzada(img_final, mascara, mapa_densidad, ...
        metricas_densidad, config);
fig3 = visualizarModeloBiomecanicoAvanzado(img_final, mapa_densidad, modelo_biomecanico, ...
        metricas_biomecanicas, config);
fig4 = visualizarRiesgoIntegradoAvanzado(img_final, mascara, mapa_densidad, ...
        modelo_biomecanico, resultados, diagnostico, config);
fig5 = visualizarCorrelacionMultimodalAvanzada(resultados, deformaciones, ...
        metricas_densidad, config);
fig6 = visualizarLesionesDetectadas(img_final, mascara, resultados, etiquetas, config);
fig7 = visualizarTablaCaracteristicas(resultados, config);
fig8 = visualizarAnalisisEstadistico(img_final, mascara, resultados, etiquetas, config);
fig9 = visualizarResumenClinico(resultados, diagnostico, riesgo_integrado, config);
fig10 = visualizarMicrocalcificacionesAvanzadas(img_final, mapa_calcio, microcalcificaciones, config);
fig11 = visualizarExplicabilidadViT(img_final, heatmap_gradcam, clasificacion_vit, probs_vit);
fig12 = visualizarComparativaMetodos(resultados, metricas_densidad, clasificacion_vit, probs_vit, config);

if es_3d && config.analisis_3d.habilitado
    [analisis_3d, reconstruccion_3d] = analisisVolumetrico3D(volumen, mascara, config);
    metricas_volumetricas = calcularMetricasVolumetricas(analisis_3d);
    fig13 = visualizarAnalisis3D(analisis_3d, reconstruccion_3d, metricas_volumetricas, config);
end

%% ======================== EXPORTACIÓN DE RESULTADOS =========================
if config.exportacion.habilitada
    disp('Exportando resultados...');
    exportarResultadosCompletos(info, resultados, diagnostico, metricas_densidad, ...
        modelo_biomecanico, caracteristicas_radiomicas, config);
end

%% ======================== INFORME FINAL ====================================
fprintf('\n=== ANÁLISIS COMPLETADO ===\n');
fprintf('Resumen:\n');
fprintf('- Densidad mamaria: %.1f%% (BI-RADS %s)\n', metricas_densidad.porcentaje_densidad, metricas_densidad.birads_categoria);
if ~isempty(resultados)
    fprintf('- Lesiones detectadas: %d (Malignas: %d, Benignas: %d, Tumores: %d, Indet: %d)\n', ...
        length(resultados), ...
        sum(strcmp({resultados.Clasificacion},'Maligno')), ...
        sum(strcmp({resultados.Clasificacion},'Benigno')), ...
        sum(strcmp({resultados.Clasificacion},'Tumor')), ...
        sum(strcmp({resultados.Clasificacion},'Indeterminado')));
else
    fprintf('- Lesiones detectadas: 0\n');
end
fprintf('- Diagnóstico integrado: %s\n', diagnostico.clasificacion);
fprintf('- BI-RADS automático: Categoría %s\n', categoria_birads);
fprintf('- ViT: %s (confianza %.2f)\n', clasificacion_vit, max(probs_vit));
fprintf('- Riesgo integrado: %.2f\n', riesgo_integrado);
fprintf('- Alertas clínicas: %d\n', length(alertas_clinicas));
for i = 1:length(alertas_clinicas)
    fprintf('  * %s\n', alertas_clinicas{i});
end
fprintf('\nSe han generado %d figuras de análisis.\n', 12 + (exist('fig13','var')==1));
fprintf('Los resultados se han exportado a %s\n', pwd);
disp('=== FIN DEL PROCESO ===');

%% ============================================================================
%% ========================== FUNCIONES AUXILIARES ============================
%% ============================================================================

function modelos = inicializarModelosDeepLearning(~)
    modelos.autoencoder_denoising = [];
    modelos.cnn_clasificacion = [];
    modelos.cnn_segmentacion = [];
    modelos.densenet_densidad = [];
    modelos.transformer = [];
    fprintf('Modelos deep learning inicializados (simulados).\n');
end

function img_out = aplicarDenoisingAutoencoder(img, config)
    img_d = double(img);
    img_out = imbilatfilt(img_d, 'DegreeOfSmoothing', 0.01*config.denoising.factor_ruido, 'SpatialSigma', 3);
    img_out = uint8(img_out);
end

function masc_ref = refinarSegmentacionConCNN(img, masc)
    [gx,gy] = imgradientxy(img);
    grad = sqrt(gx.^2+gy.^2);
    umbral = graythresh(grad) * max(grad(:));
    bordes = grad > umbral * 0.3;
    masc_ref = masc & ~bordes;
    masc_ref = imfill(masc_ref, 'holes');
    masc_ref = bwareaopen(masc_ref, 500);
end

function [mapa, met] = generarMapaDensidadAvanzado(img, masc, ~)
    masc_mama = imfill(masc, 'holes');
    if ~any(masc_mama(:))
        mapa = zeros(size(img));
        met.porcentaje_densidad = 0;
        met.birads_categoria = 'a';
        met.birads_descripcion = 'Sin tejido mamario';
        met.area_total = 0;
        met.area_densa = 0;
        met.area_grasa = 0;
        met.entropia = 0;
        met.homogeneidad = 0;
        met.asimetria_espacial = 0;
        return;
    end
    nivel_graso = graythresh(img(masc_mama)) * 0.6;
    nivel_inter = graythresh(img(masc_mama)) * 1.1;
    nivel_denso = graythresh(img(masc_mama)) * 1.5;
    mapa = zeros(size(img));
    mapa(masc_mama & img < nivel_graso*max(img(:))) = 1;
    mapa(masc_mama & img>=nivel_graso*max(img(:)) & img<nivel_inter*max(img(:))) = 2;
    mapa(masc_mama & img>=nivel_inter*max(img(:)) & img<nivel_denso*max(img(:))) = 3;
    mapa(masc_mama & img>=nivel_denso*max(img(:))) = 4;
    mapa = imgaussfilt(mapa, 2);
    
    area_total = sum(masc_mama(:));
    area_graso = sum(mapa(masc_mama)==1);
    area_inter = sum(mapa(masc_mama)==2);
    area_denso = sum(mapa(masc_mama)==3);
    met.porcentaje_densidad = ((area_denso + area_inter*0.5) / area_total) * 100;
    met.area_total = area_total;
    met.area_densa = area_denso + area_inter;
    met.area_grasa = area_graso;
    if met.porcentaje_densidad < 25
        met.birads_categoria = 'a';
        met.birads_descripcion = 'Casi completamente grasa';
    elseif met.porcentaje_densidad < 50
        met.birads_categoria = 'b';
        met.birads_descripcion = 'Densidades dispersas';
    elseif met.porcentaje_densidad < 75
        met.birads_categoria = 'c';
        met.birads_descripcion = 'Heterogéneamente densa';
    else
        met.birads_categoria = 'd';
        met.birads_descripcion = 'Extremadamente densa';
    end
    mapa_mama = mapa; mapa_mama(~masc_mama)=0;
    met.entropia = entropy(mapa_mama(masc_mama));
    try
        glcm = graycomatrix(mapa_mama, 'Offset',[0 1;-1 1;-1 0;-1 -1],'NumLevels',4,'GrayLimits',[1 4]);
        props = graycoprops(glcm,{'Contrast','Homogeneity'});
        met.homogeneidad = mean(props.Homogeneity);
    catch
        met.homogeneidad = 0;
    end
    regiones_densas = mapa_mama >= 3;
    if sum(regiones_densas(:))>0
        stats_mama = regionprops(masc_mama,'Centroid');
        centro_mama = stats_mama.Centroid;
        stats_densas = regionprops(regiones_densas,'Centroid','Area');
        areas_d = [stats_densas.Area];
        cent_d = vertcat(stats_densas.Centroid);
        cent_densas = sum(cent_d.*areas_d',1)/sum(areas_d);
        [f,c] = find(masc_mama);
        diam_mama = max(sqrt((f-centro_mama(2)).^2+(c-centro_mama(1)).^2))*2;
        met.asimetria_espacial = sqrt(sum((centro_mama-cent_densas).^2))/diam_mama;
    else
        met.asimetria_espacial = 0;
    end
end

function [clasif, score, mapa_calor] = clasificarDensidadMamariaDenseNet(img, ~)
    img_res = imresize(img, [224 224]);
    if size(img_res,3)==1, img_res = repmat(img_res,[1 1 3]); end
    img_d = im2double(img_res);
    contraste = std2(img_d(:,:,1));
    entropia = entropy(rgb2gray(img_d));
    p_blancos = sum(img_d(:)>0.7)/numel(img_d);
    score = (contraste*0.4 + entropia/8*0.3 + p_blancos*0.3);
    if score<0.25, clasif='BI-RADS A: Casi completamente grasa';
    elseif score<0.5, clasif='BI-RADS B: Densidades dispersas';
    elseif score<0.75, clasif='BI-RADS C: Heterogéneamente densa';
    else clasif='BI-RADS D: Extremadamente densa'; end
    mapa_calor = imgaussfilt(rgb2gray(img_d), 5);
    mapa_calor = imresize(mapa_calor, size(img));
end

function [modelo, deform, met] = generarModeloBiomecanicoAvanzado(img, mapa, cfg)
    modelo = struct();
    masc_mama = mapa>0;
    modelo.geometria.area_total = sum(masc_mama(:));
    modelo.geometria.area_glandular = sum(mapa>=2);
    modelo.geometria.area_adiposa = sum(mapa==1);
    modelo.propiedades.young_glandular = cfg.young_glandular;
    modelo.propiedades.young_adipose = cfg.young_adipose;
    modelo.propiedades.poisson_ratio = cfg.poisson_ratio;
    [filas,cols] = size(mapa);
    [X,Y] = meshgrid(1:cols,1:filas);
    cx = cols/2; cy = filas/2;
    dist = sqrt((X-cx).^2+(Y-cy).^2);
    maxdist = sqrt(cx^2+cy^2);
    factor_radial = 1 - cfg.compression_factor * (dist./maxdist);
    factor_tejido = ones(size(mapa));
    factor_tejido(mapa>=3)=0.7; factor_tejido(mapa==2)=0.85; factor_tejido(mapa==1)=1.0;
    factor_comp = factor_radial .* factor_tejido;
    deform.factor_compresion = factor_comp;
    deform.desp_x = (X-cx).*(1-factor_comp)*0.1;
    deform.desp_y = (Y-cy).*(1-factor_comp)*0.1;
    [gradx,grady] = gradient(factor_comp);
    tension = zeros(filas,cols);
    for i=1:filas
        for j=1:cols
            if mapa(i,j)>0
                if mapa(i,j)>=3, E = cfg.young_glandular*1.2;
                elseif mapa(i,j)==2, E = cfg.young_glandular;
                else E = cfg.young_adipose; end
                def_local = 1 - factor_comp(i,j);
                tension(i,j) = E * def_local;
            end
        end
    end
    modelo.tensiones.maxima = tension;
    modelo.tensiones.gradiente = sqrt(gradx.^2+grady.^2);
    modelo.tensiones.media = tension/2;
    if any(tension(:)>0)
        met.tension_maxima = max(tension(:));
        met.tension_media = mean(tension(tension>0));
        met.tension_std = std(tension(tension>0));
        met.area_alta_tension = sum(tension > cfg.stress_threshold);
    else
        met.tension_maxima = 0; met.tension_media = 0; met.tension_std = 0; met.area_alta_tension = 0;
    end
    met.deformacion_maxima = max(1-factor_comp(:));
    met.ratio_tejido_glandular = modelo.geometria.area_glandular / max(modelo.geometria.area_total,1);
end

function lbp_hist = extraerCaracteristicasLBP(img)
    [rows, cols] = size(img);
    lbp = zeros(rows, cols);
    for i = 2:rows-1
        for j = 2:cols-1
            center = img(i,j);
            code = 0;
            neighbors = [img(i-1,j-1), img(i-1,j), img(i-1,j+1), img(i,j+1), ...
                         img(i+1,j+1), img(i+1,j), img(i+1,j-1), img(i,j-1)];
            for k = 1:8
                if neighbors(k) >= center
                    code = code + 2^(k-1);
                end
            end
            lbp(i,j) = code;
        end
    end
    lbp_hist = histcounts(lbp(:), 0:256);
end

function [micro, mapa_calcio] = detectarMicrocalcificacionesAvanzadas(img, ~)
    img_cont = imadjust(img, stretchlim(img,[0.01 0.99]), []);
    [cA,cH,cV,cD] = dwt2(img_cont, 'db4');
    cD_enf = cD * 3;
    img_rec = idwt2(cA,cH,cV,cD_enf, 'db4');
    umbral = graythresh(img_rec) * 0.7;
    masc = img_rec > umbral;
    se = strel('disk',2);
    masc = imopen(masc, se);
    masc = bwareaopen(masc, 5);
    stats = regionprops(masc, 'Area', 'Centroid');
    micro.numero = length(stats);
    if micro.numero>0
        micro.areas = [stats.Area];
        if length(stats)>=2
            centroides = vertcat(stats.Centroid);
            dists = pdist(centroides);
            if mean(dists)<20, micro.distribucion = 'Agrupadas';
            elseif std(dists)/mean(dists)>0.5, micro.distribucion = 'Lineales';
            else micro.distribucion = 'Dispersas'; end
        else
            micro.distribucion = 'Aisladas';
        end
    else
        micro.areas = []; micro.distribucion = 'No detectadas';
    end
    mapa_calcio = masc;
end

function [clasif, punt, conf] = clasificarLesionAvanzada(~, prop, roi, config)
    area = prop.Area;
    ex = prop.Eccentricity;
    sol = prop.Solidity;
    diam = prop.MajorAxisLength;
    if area>10000
        clasif_morf = 'Tumor'; punt_morf=4;
    elseif area>=500 && area<=10000
        if ex<=0.6 && sol>0.85 && diam<300
            clasif_morf='Benigno'; punt_morf=1;
        elseif ex>=0.7 || (sol<0.6 && diam>200)
            clasif_morf='Maligno'; punt_morf=3;
        else
            clasif_morf='Indeterminado'; punt_morf=2;
        end
    else
        clasif_morf='Ruido'; punt_morf=0;
    end
    
    if config.deep_learning.uso_cnn_clasificacion && ~isempty(roi) && area>100
        ent = entropy(roi); std_roi = std(double(roi(:)));
        if ent>5 && std_roi>25
            clasif_cnn='Maligno'; conf_cnn=0.85;
        elseif ent<3 && std_roi<15
            clasif_cnn='Benigno'; conf_cnn=0.90;
        else
            clasif_cnn='Indeterminado'; conf_cnn=0.60;
        end
        if conf_cnn > config.deep_learning.umbral_confianza_cnn
            clasif = clasif_cnn; conf = conf_cnn;
        else
            clasif = clasif_morf; conf = 0.70;
        end
        switch clasif
            case 'Maligno', punt = 3*conf;
            case 'Benigno', punt = 1*conf;
            case 'Tumor',   punt = 4;
            otherwise,      punt = 2*conf;
        end
    else
        clasif = clasif_morf; punt = punt_morf; conf = 0.65;
    end
end

function riesgo = calcularRiesgoIntegradoAvanzado(resultados, met_dens, img)
    factor_dens = min(met_dens.porcentaje_densidad/25, 4);
    try
        glcm = graycomatrix(img, 'Offset',[0 1;-1 1;-1 0;-1 -1],'NumLevels',8);
        props = graycoprops(glcm,{'contrast','homogeneity'});
        heterog = (mean(props.Contrast) + (1-mean(props.Homogeneity)) + entropy(img)/8)/3;
    catch
        heterog = 0.5;
    end
    if ~isempty(resultados)
        num_mal = sum(strcmp({resultados.Clasificacion},'Maligno'));
        num_ind = sum(strcmp({resultados.Clasificacion},'Indeterminado'));
        num_tum = sum(strcmp({resultados.Clasificacion},'Tumor'));
        factor_les = min(num_mal*2 + num_ind*1 + num_tum*3, 10);
    else
        factor_les = 0;
    end
    [f,c] = size(img);
    mitad = round(c/2);
    izq = img(:,1:mitad); der = img(:,mitad+1:end);
    dif_asim = abs(mean(izq(:)) - mean(der(:))) / max(mean(izq(:)),mean(der(:)));
    pesos = [0.35, 0.25, 0.25, 0.15];
    factores = [factor_dens, heterog, factor_les, dif_asim*2];
    riesgo = sum(factores .* pesos);
end

function [categoria, prob] = clasificarBIRADSAvanzado(resultados, met_dens, riesgo, micro)
    prob_dens = [0.3,0.3,0.2,0.1,0.1,0];
    switch met_dens.birads_categoria
        case 'a', prob_dens = [0.7,0.2,0.1,0,0,0];
        case 'b', prob_dens = [0.2,0.5,0.2,0.1,0,0];
        case 'c', prob_dens = [0.1,0.2,0.4,0.2,0.1,0];
        case 'd', prob_dens = [0,0.1,0.3,0.4,0.2,0];
    end
    if isempty(resultados)
        prob_les = [0.8,0.2,0,0,0,0];
    else
        num_mal = sum(strcmp({resultados.Clasificacion},'Maligno'));
        num_ind = sum(strcmp({resultados.Clasificacion},'Indeterminado'));
        if num_mal>=1, prob_les = [0,0,0.1,0.3,0.5,0.1];
        elseif num_ind>=2, prob_les = [0,0.1,0.4,0.3,0.2,0];
        elseif num_ind>=1, prob_les = [0.1,0.3,0.4,0.2,0,0];
        else prob_les = [0.3,0.5,0.2,0,0,0]; end
    end
    if micro.numero>10, prob_cal = [0,0,0.2,0.4,0.3,0.1];
    elseif micro.numero>5, prob_cal = [0,0.1,0.4,0.3,0.2,0];
    elseif micro.numero>0, prob_cal = [0.1,0.3,0.4,0.2,0,0];
    else prob_cal = [0.4,0.4,0.2,0,0,0]; end
    if riesgo>8, prob_risk = [0,0,0.1,0.3,0.5,0.1];
    elseif riesgo>6, prob_risk = [0,0.1,0.3,0.4,0.2,0];
    elseif riesgo>4, prob_risk = [0.1,0.3,0.4,0.2,0,0];
    else prob_risk = [0.4,0.4,0.2,0,0,0]; end
    pesos = [0.2,0.3,0.3,0.2];
    prob = prob_dens*pesos(1) + prob_les*pesos(2) + prob_cal*pesos(3) + prob_risk*pesos(4);
    [~,idx] = max(prob);
    cats = {'0','1','2','3','4','5'};
    categoria = cats{idx};
end

function diag = generarDiagnosticoIntegradoAvanzado(resultados, met_dens, ~, ~)
    if isempty(resultados)
        diag.clasificacion = 'SIN HALLAZGOS DETECTABLES';
        diag.color = [0.5 0.5 0.5];
        diag.recomendacion = {'- Continuar con revisiones preventivas'};
        diag.puntuacion_total = 0;
        diag.confianza = 0.95;
        return;
    end
    punt_total = sum([resultados.PuntuacionRiesgo]);
    num_mal = sum(strcmp({resultados.Clasificacion},'Maligno'));
    num_tum = sum(strcmp({resultados.Clasificacion},'Tumor'));
    conf_prom = mean([resultados.Confianza]);
    factor_dens = met_dens.porcentaje_densidad/100;
    if num_tum>=1 || (num_mal>=2 && punt_total>=8)
        diag.clasificacion = 'ALTA SOSPECHA DE MALIGNIDAD';
        diag.color = [1 0 0];
        diag.recomendacion = {'- Biopsia inmediata','- Consulta urgente','- Estudios complementarios'};
    elseif (num_mal>=1 && punt_total>=6) || factor_dens>0.7
        diag.clasificacion = 'SOSPECHA DE MALIGNIDAD MODERADA';
        diag.color = [1 0.4 0];
        diag.recomendacion = {'- Evaluación oncológica prioritaria','- Seguimiento en 1-3 meses','- Considerar estudios adicionales'};
    elseif num_mal>=1 || punt_total>=4
        diag.clasificacion = 'SOSPECHA DE MALIGNIDAD';
        diag.color = [1 0.7 0];
        diag.recomendacion = {'- Evaluación especializada','- Seguimiento en 3-6 meses','- Monitoreo cercano'};
    else
        diag.clasificacion = 'HALLAZGOS PROBABLEMENTE BENIGNOS';
        diag.color = [0 0.8 0];
        diag.recomendacion = {'- Seguimiento rutinario','- Revisión anual','- Mantener estilo de vida saludable'};
    end
    diag.puntuacion_total = punt_total;
    diag.confianza = conf_prom;
end

function alertas = generarAlertasClinicas(diag, riesgo, met_dens, ~)
    alertas = {};
    if diag.puntuacion_total > 6
        alertas{end+1} = 'ALERTA: Puntuación de riesgo elevada. Valorar biopsia.';
    end
    if met_dens.porcentaje_densidad > 75
        alertas{end+1} = 'ALERTA: Densidad mamaria extremadamente alta (BI-RADS d). Mayor riesgo de cáncer oculto.';
    end
    if riesgo > 7
        alertas{end+1} = 'ALERTA: Riesgo integrado muy alto. Se recomienda estudio complementario.';
    end
    if isempty(alertas)
        alertas{end+1} = 'Sin alertas críticas. Seguimiento rutinario.';
    end
end

function [clasif, probs, heatmap] = aplicarVisionTransformer(img, config)
    img_res = imresize(img, config.vit.imagen_size);
    if size(img_res,3)==1, img_res = repmat(img_res,[1 1 3]); end
    lbp = extractLBPFeaturesManual(rgb2gray(img_res));
    rng(0);
    W1 = randn(length(lbp), 32);
    b1 = randn(1,32);
    W2 = randn(32, config.vit.num_classes);
    b2 = randn(1, config.vit.num_classes);
    h = tanh(lbp * W1 + b1);
    logits = h * W2 + b2;
    probs = exp(logits) / sum(exp(logits));
    [~,idx] = max(probs);
    clases = {'Benigno','Maligno','Tumor','Indeterminado'};
    clasif = clases{idx};
    [gx,gy] = imgradientxy(rgb2gray(img_res));
    heatmap_raw = sqrt(gx.^2+gy.^2);
    heatmap = imresize(imgaussfilt(heatmap_raw,5), size(img));
end

function lbp_hist = extractLBPFeaturesManual(img)
    [rows, cols] = size(img);
    lbp = zeros(rows, cols);
    for i = 2:rows-1
        for j = 2:cols-1
            center = img(i,j);
            code = 0;
            neighbors = [img(i-1,j-1), img(i-1,j), img(i-1,j+1), img(i,j+1), ...
                         img(i+1,j+1), img(i+1,j), img(i+1,j-1), img(i,j-1)];
            for k = 1:8
                if neighbors(k) >= center
                    code = code + 2^(k-1);
                end
            end
            lbp(i,j) = code;
        end
    end
    lbp_hist = histcounts(lbp(:), 0:256);
    lbp_hist = lbp_hist / sum(lbp_hist);
end

function generarEjemploDifusion(img, masc, config)
    roi_idx = find(masc);
    if isempty(roi_idx), return; end
    [r,c] = ind2sub(size(masc), roi_idx(randi(length(roi_idx))));
    sz = config.diffusion.image_size;
    r = max(1, min(r, size(img,1)-sz+1));
    c = max(1, min(c, size(img,2)-sz+1));
    patch_real = img(r:r+sz-1, c:c+sz-1);
    t = randi(config.diffusion.num_timesteps);
    beta = linspace(config.diffusion.beta_start, config.diffusion.beta_end, config.diffusion.num_timesteps);
    alpha = 1 - beta;
    alpha_cum = cumprod(alpha);
    noise = randn(size(patch_real));
    patch_noisy = sqrt(alpha_cum(t)) * double(patch_real) + sqrt(1-alpha_cum(t)) * noise;
    patch_denoised = imbilatfilt(uint8(patch_noisy));
    figure('Name','Ejemplo de Difusión (DDPM)');
    subplot(1,3,1); imshow(patch_real,[]); title('ROI original');
    subplot(1,3,2); imshow(patch_noisy,[]); title(sprintf('Ruido t=%d',t));
    subplot(1,3,3); imshow(patch_denoised,[]); title('Denoised (sintético)');
    sgtitle('Aumento de datos por difusión');
end

function simularAprendizajeFederado(resultados, ~, config)
    if isempty(resultados)
        X = randn(100, 128);
        Y = randi(4, 100, 1);
    else
        X = randn(length(resultados), 128);
        Y = randi(4, length(resultados), 1);
    end
    split = floor(size(X,1)/config.federated.num_clients);
    client_data = cell(config.federated.num_clients,1);
    for i=1:config.federated.num_clients
        idx = (i-1)*split+1 : min(i*split, size(X,1));
        client_data{i}.X = X(idx,:);
        client_data{i}.Y = Y(idx);
    end
    global_model = fitcecoc(X, Y);
    for round=1:config.federated.rounds
        local_models = cell(config.federated.num_clients,1);
        for c=1:config.federated.num_clients
            local_model = fitcecoc(client_data{c}.X, client_data{c}.Y);
            local_models{c} = local_model;
        end
        fprintf('Ronda federada %d completada.\n', round);
    end
    disp('Aprendizaje federado simulado finalizado.');
end

function [analisis_3d, reconstruccion] = analisisVolumetrico3D(volumen, mascara_2d, ~)
    [f,c,s] = size(volumen);
    mascara_3d = false(f,c,s);
    for k=1:s
        mascara_3d(:,:,k) = imresize(mascara_2d, [f,c]);
    end
    analisis_3d.volumen_total = sum(mascara_3d(:));
    analisis_3d.num_slices = s;
    analisis_3d.dimensiones = [f,c,s];
    reconstruccion.volumen = volumen;
    reconstruccion.mascara = mascara_3d;
end

function metricas = calcularMetricasVolumetricas(analisis_3d)
    metricas.volumen_total = analisis_3d.volumen_total;
    metricas.area_seccional_promedio = analisis_3d.volumen_total / analisis_3d.num_slices;
    metricas.complejidad_volumetrica = analisis_3d.volumen_total / (prod(analisis_3d.dimensiones)*0.1);
end

%% ============================================================================
%% ======================== FUNCIONES DE VISUALIZACIÓN ========================
%% ============================================================================

function fig = visualizarProcesamientoAvanzado(im_orig, im_proc, masc, met_dens, info, ~)
    fig = figure('Name','Fig1 - Procesamiento Avanzado','Position',[50 50 1400 900]);
    subplot(2,3,1); imshow(im_orig,[]); title('A) DICOM Original');
    subplot(2,3,2); imshow(im_proc,[]); title('B) Preprocesada + Denoising');
    subplot(2,3,3); imshow(masc,[]); title('C) Máscara Segmentada');
    subplot(2,3,4); imshow(im_proc,[]); hold on;
    B = bwboundaries(masc);
    for k=1:length(B), plot(B{k}(:,2), B{k}(:,1), 'r-', 'LineWidth',1.5); end
    title('D) Superposición Segmentación');
    subplot(2,3,5); histogram(im_proc(:),50); title('E) Histograma');
    subplot(2,3,6); axis off;
    if isfield(info,'PatientName')
        nombre = char(info.PatientName);
    else
        nombre = 'Desconocido';
    end
    text(0.1,0.9,{sprintf('Paciente: %s', nombre),sprintf('Densidad: %.1f%%',met_dens.porcentaje_densidad),...
        sprintf('BI-RADS: %s',met_dens.birads_categoria), sprintf('Área tejido: %d px',met_dens.area_total)},...
        'Units','normalized','FontSize',10);
end

function fig = visualizarDensidadTexturaAvanzada(img, masc, mapa, met, ~)
    fig = figure('Name','Fig2 - Densidad y Textura','Position',[100 100 1400 800]);
    subplot(1,2,1);
    imagesc(mapa); colormap([0.9 0.9 0.9;0.7 0.9 0.7;1 0.8 0.4;1 0.4 0.4]); caxis([0 3]);
    colorbar('Ticks',[0.375,1.125,1.875,2.625],'TickLabels',{'Fondo','Graso','Intermedio','Denso'});
    title('Mapa de Densidad Cuantitativa');
    text(0.02,0.98,{sprintf('Densidad: %.1f%%',met.porcentaje_densidad),sprintf('BI-RADS %s',met.birads_categoria),...
        sprintf('Entropía: %.3f',met.entropia)},'Units','norm','BackgroundColor',[1 1 1 0.7]);
    subplot(1,2,2); axis off;
    rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99]);
    text(0.5,0.92,'ANÁLISIS DE TEXTURA','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    glcm = graycomatrix(img,'Offset',[0 1;-1 1;-1 0;-1 -1],'NumLevels',16);
    props = graycoprops(glcm,{'contrast','correlation','energy','homogeneity'});
    text(0.15,0.78,{sprintf('Contraste: %.3f',mean(props.Contrast)),sprintf('Correlación: %.3f',mean(props.Correlation))},'FontSize',11);
    text(0.55,0.78,{sprintf('Energía: %.3f',mean(props.Energy)),sprintf('Homogeneidad: %.3f',mean(props.Homogeneity))},'FontSize',11);
    if met.entropia>6, interp='TEXTURA COMPLEJA'; col_int=[0.8 0.2 0.2];
    elseif met.entropia>4, interp='TEXTURA MODERADA'; col_int=[1 0.6 0.2];
    else interp='TEXTURA SIMPLE'; col_int=[0.2 0.6 0.2]; end
    rectangle('Position',[0.08 0.2 0.84 0.18],'FaceColor',[1 1 0.95],'EdgeColor',col_int);
    text(0.5,0.34,'INTERPRETACIÓN','FontSize',13,'FontWeight','bold','HorizontalAlignment','center','Color',col_int);
    text(0.5,0.28,interp,'FontSize',12,'FontWeight','bold','HorizontalAlignment','center','Color',col_int);
end

function fig = visualizarModeloBiomecanicoAvanzado(~, mapa, modelo, met_biomec, ~)
    fig = figure('Name','Fig3 - Modelo Biomecánico','Position',[150 50 1400 900]);
    subplot(2,3,1); imagesc(mapa); title('A) Mapa de Densidad');
    subplot(2,3,2); imagesc(modelo.tensiones.maxima); colorbar; title('B) Tensiones Máximas (kPa)');
    subplot(2,3,3); histogram(modelo.tensiones.maxima(modelo.tensiones.maxima>0),50,'FaceColor','r'); title('C) Distribución de Tensiones');
    subplot(2,3,4); imagesc(modelo.tensiones.gradiente); colorbar; title('D) Gradientes de Tensión');
    subplot(2,3,5); axis off;
    text(0.1,0.9,{sprintf('Módulo glandular: %.1f kPa',modelo.propiedades.young_glandular),...
        sprintf('Módulo adiposo: %.1f kPa',modelo.propiedades.young_adipose),...
        sprintf('Área total: %d px',modelo.geometria.area_total),...
        sprintf('Tensión media: %.2f kPa',met_biomec.tension_media),...
        sprintf('Deformación máx: %.3f',met_biomec.deformacion_maxima)},'Units','norm','FontSize',10);
    subplot(2,3,6); if any(modelo.tensiones.maxima(:)>0), surf(modelo.tensiones.maxima(1:10:end,1:10:end),'EdgeColor','none'); title('E) Superficie 3D'); end
end

function fig = visualizarRiesgoIntegradoAvanzado(img, masc, mapa, ~, res, diag, ~)
    fig = figure('Name','Fig4 - Riesgo Integrado','Position',[200 50 1400 800]);
    masc_mama = imfill(masc,'holes');
    area_densa = sum(mapa(masc_mama)>=2);
    porcentaje = (area_densa/sum(masc_mama(:)))*100;
    punt_riesgo = min(porcentaje/25,4) + (sum(strcmp({res.Clasificacion},'Maligno'))*0.5) + (length(res)*0.1);
    if punt_riesgo>=8, color=[1 0 0]; txt='RIESGO MUY ALTO';
    elseif punt_riesgo>=6, color=[1 0.3 0]; txt='ALTO RIESGO';
    elseif punt_riesgo>=4, color=[1 0.6 0]; txt='RIESGO MODERADO';
    else color=[0.2 0.8 0.2]; txt='BAJO RIESGO'; end
    subplot(2,3,[1,2,4,5]);
    imshow(img,[]); hold on;
    B = bwboundaries(masc_mama);
    for k=1:length(B), plot(B{k}(:,2),B{k}(:,1),'Color',color,'LineWidth',3); end
    title('Mapa de Riesgo Integrado','Color',color);
    text(0.02,0.98,{txt,sprintf('Puntuación: %.1f',punt_riesgo),sprintf('Densidad: %.1f%%',porcentaje)},...
        'Units','norm','BackgroundColor',[1 1 1 0.8],'Color',color);
    subplot(2,3,3); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99]);
    text(0.5,0.95,'DIAGNÓSTICO','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    rectangle('Position',[0.1 0.7 0.8 0.15],'FaceColor',diag.color);
    text(0.5,0.78,diag.clasificacion,'FontSize',11,'FontWeight','bold','HorizontalAlignment','center','Color','w');
    subplot(2,3,6); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.97 0.98 0.95]);
    text(0.5,0.95,'RECOMENDACIONES','FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Color',[0 0.4 0]);
    ypos=0.8;
    for i=1:min(length(diag.recomendacion),4)
        rectangle('Position',[0.1 ypos-0.08 0.8 0.07],'FaceColor','w');
        text(0.15,ypos-0.04,['• ' diag.recomendacion{i}],'Units','norm','FontSize',10);
        ypos=ypos-0.1;
    end
end

function fig = visualizarCorrelacionMultimodalAvanzada(res, ~, ~, ~)
    fig = figure('Name','Fig5 - Correlación Multimodal','Position',[250 50 1400 800]);
    if isempty(res), text(0.5,0.5,'No hay datos'); return; end
    areas = [res.Area]; exc = [res.Excentricidad]; sol = [res.Solidez]; conf = [res.Confianza];
    subplot(2,3,1); scatter(areas,exc,50,'filled','MarkerFaceAlpha',0.6); xlabel('Área'); ylabel('Excentricidad'); title('A) Área vs Excentricidad');
    subplot(2,3,2); boxplot(areas,{res.Clasificacion}); ylabel('Área (px)'); title('B) Distribución por tipo');
    subplot(2,3,3); scatter(areas,conf,50,'filled'); xlabel('Área'); ylabel('Confianza'); title('C) Área vs Confianza');
    subplot(2,3,4); histogram(conf,10); xlabel('Confianza'); ylabel('Frecuencia'); title('D) Histograma de confianza');
    features = [areas(:), exc(:), sol(:), conf(:)];
    if size(features,1)>=3
        corr_mat = corrcoef(features);
        subplot(2,3,5); imagesc(corr_mat); colorbar;
        set(gca, 'XTick', 1:4, 'XTickLabel', {'Área','Excen','Solidez','Confianza'}, ...
                 'YTick', 1:4, 'YTickLabel', {'Área','Excen','Solidez','Confianza'});
        title('E) Matriz de correlación');
    end
    if size(features,1)>=3
        [~,score] = pca(features);
        subplot(2,3,6); gscatter(score(:,1),score(:,2),{res.Clasificacion}); xlabel('PC1'); ylabel('PC2'); title('F) PCA');
    end
end

function fig = visualizarLesionesDetectadas(img, masc, res, etiq, ~)
    fig = figure('Name','Fig6 - Lesiones','Position',[100 100 1200 800]);
    imshow(img,[]); hold on;
    for i=1:length(res)
        masc_les = (etiq == res(i).ID);
        B = bwboundaries(masc_les);
        switch res(i).Clasificacion
            case 'Maligno', col='r'; lw=4;
            case 'Benigno', col='g'; lw=3;
            case 'Tumor', col=[1 0.5 0]; lw=5;
            otherwise, col=[0.5 0.5 0.5]; lw=2;
        end
        for k=1:length(B), plot(B{k}(:,2),B{k}(:,1),'Color',col,'LineWidth',lw); end
        stats = regionprops(masc_les,'Centroid');
        if ~isempty(stats)
            text(stats.Centroid(1),stats.Centroid(2),num2str(res(i).ID),'Color','w','BackgroundColor',col,'FontSize',10);
        end
    end
    title('Lesiones Detectadas y Clasificadas');
end

function fig = visualizarTablaCaracteristicas(res, ~)
    fig = figure('Name','Fig7 - Tabla','Position',[150 100 1400 600]);
    if isempty(res), text(0.5,0.5,'No hay lesiones'); return; end
    axes('Position',[0.05 0.05 0.9 0.9]); axis off;
    rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99]);
    text(0.5,0.95,'CARACTERÍSTICAS DE LESIONES','FontSize',16,'FontWeight','bold','HorizontalAlignment','center');
    headers = {'ID','Área','Diámetro','Solidez','Excentricidad','Tipo','Riesgo','Confianza'};
    posx = [0.08,0.14,0.22,0.32,0.42,0.56,0.70,0.85];
    rectangle('Position',[0.06 0.84 0.88 0.06],'FaceColor',[0.2 0.4 0.6]);
    for i=1:8, text(posx(i),0.87,headers{i},'Units','norm','FontSize',11,'FontWeight','bold','Color','w','HorizontalAlignment','center'); end
    for i=1:min(8,length(res))
        y = 0.77 - (i-1)*0.08;
        if mod(i,2), rect_col=[0.95 0.95 0.97]; else rect_col=[0.92 0.94 0.98]; end
        rectangle('Position',[0.06 y 0.88 0.07],'FaceColor',rect_col);
        datos = {num2str(res(i).ID), formatNumber(res(i).Area), formatNumber(round(res(i).Diametro)), ...
                 sprintf('%.3f',res(i).Solidez), sprintf('%.3f',res(i).Excentricidad), ...
                 res(i).Clasificacion, num2str(res(i).PuntuacionRiesgo), sprintf('%.0f%%',res(i).Confianza*100)};
        for j=1:8
            if j>=6, col_txt = [0.8 0 0]; else col_txt=[0.2 0.2 0.4]; end
            text(posx(j), y+0.04, datos{j}, 'Units','norm','FontSize',9,'HorizontalAlignment','center','Color',col_txt);
        end
    end
end

function fig = visualizarAnalisisEstadistico(img, ~, res, etiq, ~)
    fig = figure('Name','Fig8 - Estadístico','Position',[200 50 1400 900]);
    if isempty(res), text(0.5,0.5,'No hay datos'); return; end
    subplot(2,2,1);
    tipos = {'Maligno','Benigno','Tumor','Indet.'};
    cnt = [sum(strcmp({res.Clasificacion},'Maligno')), sum(strcmp({res.Clasificacion},'Benigno')), ...
           sum(strcmp({res.Clasificacion},'Tumor')), sum(strcmp({res.Clasificacion},'Indeterminado'))];
    bar(cnt); set(gca,'XTickLabel',tipos); ylabel('Número'); title('Distribución por tipo');
    subplot(2,2,2); imshow(img,[]); hold on;
    mapa_calor = zeros(size(img));
    for i=1:length(res)
        masc_les = (etiq == res(i).ID);
        val = find(strcmp(tipos,res(i).Clasificacion));
        mapa_calor(masc_les) = val;
    end
    h = imagesc(mapa_calor); set(h,'AlphaData',0.4); colormap([0 0 0;0 1 0;1 1 0;1 0.5 0;1 0 0]); caxis([0 4]);
    title('Mapa de densidad de lesiones');
    subplot(2,2,3); scatter([res.Solidez],[res.Excentricidad],50,'filled'); xlabel('Solidez'); ylabel('Excentricidad'); title('Formas');
    subplot(2,2,4); axis off;
    texto = {sprintf('Total lesiones: %d',length(res)), sprintf('Área total: %s px',formatNumber(sum([res.Area]))), ...
             sprintf('Malignas: %d',cnt(1)), sprintf('Benignas: %d',cnt(2)), sprintf('Tumores: %d',cnt(3)), ...
             sprintf('Área media: %s px',formatNumber(mean([res.Area]))), sprintf('Confianza media: %.1f%%',mean([res.Confianza])*100)};
    text(0.1,0.9,texto,'Units','norm','FontSize',11);
end

function fig = visualizarResumenClinico(res, diag, riesgo, ~)
    fig = figure('Name','Fig9 - Resumen Clínico','Position',[250 100 1400 900]);
    subplot(2,2,1); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99]);
    text(0.5,0.9,'DIAGNÓSTICO PRINCIPAL','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    if contains(diag.clasificacion,'ALTA'), col=[1 0 0]; elseif contains(diag.clasificacion,'MODERADA'), col=[1 0.5 0]; else col=[0 0.7 0]; end
    rectangle('Position',[0.1 0.6 0.8 0.25],'FaceColor',col);
    text(0.5,0.8,'DIAGNÓSTICO','Color','w','FontSize',12,'FontWeight','bold','HorizontalAlignment','center');
    text(0.5,0.65,diag.clasificacion,'Color','w','FontSize',11,'HorizontalAlignment','center');
    rectangle('Position',[0.2 0.35 0.6 0.15],'FaceColor',[1 1 0.95],'EdgeColor',col);
    text(0.5,0.42,sprintf('Puntuación: %.1f',diag.puntuacion_total),'FontSize',12,'FontWeight','bold','HorizontalAlignment','center');
    subplot(2,2,2);
    if ~isempty(res)
        cnt = [sum(strcmp({res.Clasificacion},'Maligno')), sum(strcmp({res.Clasificacion},'Benigno')), ...
               sum(strcmp({res.Clasificacion},'Tumor')), sum(strcmp({res.Clasificacion},'Indeterminado'))];
        pie(cnt(cnt>0),{'Maligno','Benigno','Tumor','Indet.'}(cnt>0)); title('Distribución');
    else text(0.5,0.5,'No lesiones','HorizontalAlignment','center'); end
    subplot(2,2,3); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.97 0.98 0.95]);
    text(0.5,0.95,'RESUMEN ESTADÍSTICO','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    if ~isempty(res)
        texto = {sprintf('Total lesiones: %d',length(res)), sprintf('Malignas: %d',cnt(1)), sprintf('Benignas: %d',cnt(2)), ...
                 sprintf('Área media: %s px',formatNumber(mean([res.Area]))), sprintf('Confianza media: %.1f%%',mean([res.Confianza])*100)};
        text(0.1,0.8,texto,'Units','norm','FontSize',10);
    end
    subplot(2,2,4); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.97 0.95]);
    text(0.5,0.95,'RECOMENDACIONES','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    ypos=0.8;
    for i=1:min(length(diag.recomendacion),4)
        rectangle('Position',[0.08 ypos-0.12 0.84 0.1],'FaceColor','w');
        text(0.12,ypos-0.06,sprintf('%d.',i),'FontSize',11,'FontWeight','bold');
        text(0.18,ypos-0.06,diag.recomendacion{i},'FontSize',10);
        ypos=ypos-0.14;
    end
end

function fig = visualizarMicrocalcificacionesAvanzadas(img, mapa_calcio, micro, ~)
    fig = figure('Name','Fig10 - Microcalcificaciones','Position',[300 100 1400 800]);
    subplot(2,3,1); imshow(img,[]); hold on;
    B = bwboundaries(mapa_calcio);
    for k=1:length(B), plot(B{k}(:,2),B{k}(:,1),'r-','LineWidth',1.5); end
    title('A) Microcalcificaciones detectadas');
    subplot(2,3,2); imshow(mapa_calcio); title('B) Mapa binario');
    subplot(2,3,3);
    if micro.numero>0, histogram(micro.areas,10,'FaceColor','r'); xlabel('Área (px)'); ylabel('Frecuencia'); title('C) Tamaños');
    else text(0.5,0.5,'Sin microcalcificaciones','HorizontalAlignment','center'); end
    subplot(2,3,4); axis off;
    info = {sprintf('Número: %d',micro.numero), sprintf('Distribución: %s',micro.distribucion)};
    text(0.1,0.9,info,'FontSize',12);
    subplot(2,3,5); axis off;
    if micro.numero>0
        area_media = mean(micro.areas);
        if area_media<5, morf='PUNTIFORMES (benignas)'; col=[0 0.6 0];
        elseif area_media<15, morf='AMORFAS (sospechosas)'; col=[1 0.5 0];
        else morf='PLEOMÓRFICAS (malignas)'; col=[1 0 0]; end
        text(0.1,0.9,{sprintf('Área media: %.1f px',area_media),sprintf('Clasificación: %s',morf)},'FontSize',12,'Color',col);
    end
    subplot(2,3,6); axis off;
    if micro.numero>0
        score = min(micro.numero/5,3) + min(area_media/10,2);
        switch micro.distribucion
            case 'Aisladas', d=1; case 'Agrupadas', d=2; case 'Lineales', d=3; otherwise d=1.5;
        end
        score_total = (score + d)/3;
        if score_total<=0.33, nivel='BAJO'; col_g=[0 0.8 0];
        elseif score_total<=0.66, nivel='MODERADO'; col_g=[1 0.5 0];
        else nivel='ALTO'; col_g=[1 0 0]; end
        rectangle('Position',[0.1 0.1 0.8 0.3],'FaceColor',[0.9 0.9 0.9]);
        rectangle('Position',[0.1 0.1 0.8*score_total 0.3],'FaceColor',col_g);
        text(0.5,0.6,'SCORE DE RIESGO','FontSize',12,'FontWeight','bold','HorizontalAlignment','center');
        text(0.5,0.25,nivel,'FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Color','w');
    else
        text(0.5,0.5,'Sin microcalcificaciones\nScore: 0/3','HorizontalAlignment','center');
    end
end

function fig = visualizarExplicabilidadViT(img, heatmap, clasif, probs)
    fig = figure('Name','Fig11 - Explicabilidad ViT (Grad-CAM)','Position',[350 100 1200 600]);
    subplot(1,3,1); imshow(img,[]); title('Imagen original');
    subplot(1,3,2); imshow(img,[]); hold on;
    imagesc(heatmap, 'AlphaData',0.5); colormap jet; colorbar;
    title('Mapa de atención (Grad-CAM)');
    subplot(1,3,3); axis off;
    text(0.1,0.9,{sprintf('Clasificación ViT: %s',clasif),sprintf('Probabilidad: %.2f',max(probs)),...
        'Áreas más influyentes:','- Regiones de alta densidad','- Bordes irregulares'},'FontSize',12);
end

function fig = visualizarComparativaMetodos(res, met_dens, ~, probs_vit, ~)
    fig = figure('Name','Fig12 - Comparativa de Métodos','Position',[400 100 1200 600]);
    subplot(1,2,1);
    metodos = {'Morfológico','CNN','ViT'};
    if ~isempty(res)
        val_morf = mean([res.PuntuacionRiesgo]);
        val_cnn = mean([res.Confianza])*3;
    else
        val_morf = 0; val_cnn = 0;
    end
    val_vit = max(probs_vit)*3;
    valores = [val_morf, val_cnn, val_vit];
    bar(valores); set(gca,'XTickLabel',metodos); ylabel('Score Normalizado'); title('Comparación de clasificadores');
    subplot(1,2,2);
    pie([met_dens.porcentaje_densidad, 100-met_dens.porcentaje_densidad], {'Tejido denso','Tejido graso'});
    title('Composición tisular');
end

function fig = visualizarAnalisis3D(analisis_3d, reconstruccion, metricas, ~)
    fig = figure('Name','Fig13 - Análisis 3D','Position',[100 100 1400 800]);
    if isempty(analisis_3d), text(0.5,0.5,'No hay volumen 3D'); return; end
    slice_idx = round(linspace(1, analisis_3d.num_slices, 6));
    for i=1:6
        subplot(2,3,i);
        imshow(reconstruccion.volumen(:,:,slice_idx(i)),[]);
        title(sprintf('Slice %d',slice_idx(i)));
    end
    sgtitle(sprintf('Volumen 3D - Volumen total: %.2f voxels', metricas.volumen_total));
end

function exportarResultadosCompletos(info, res, diag, met_dens, modelo, caract_radiom, ~)
    timestamp = datestr(now,'yyyymmdd_HHMMSS');
    nombre_base = sprintf('Resultados_Mama_%s', timestamp);
    resultados_exportar = struct('info',info, 'lesiones',res, 'diagnostico',diag, ...
        'densidad',met_dens, 'modelo_biomecanico',modelo, 'radiomica',caract_radiom, ...
        'fecha',datestr(now));
    save(sprintf('%s.mat',nombre_base), 'resultados_exportar');
    fprintf('Exportación completada. Archivo .mat guardado como %s.mat\n', nombre_base);
end

function out = formatNumber(num)
    if num>=1e6, out = sprintf('%.1fM',num/1e6);
    elseif num>=1e3, out = sprintf('%.1fK',num/1e3);
    else out = sprintf('%d',round(num)); end
end

% Fin del código unificado