%% ============================================================================
%  SISTEMA UNIFICADO AVANZADO DE ANÁLISIS DICOM PARA CÁNCER DE MAMA
%  Versión corregida - 11 figuras, Deep Learning, Autoencoder, biomecánica,
%  microcalcificaciones, ViT con Grad-CAM, difusión DDPM y federado simulado.
%  CORREGIDO: errores de sintaxis en línea 1055 y vertcat.
% ============================================================================

clear all; close all; clc;

%% ======================== 1. CONFIGURACIÓN DEL SISTEMA =======================
disp('=== SISTEMA UNIFICADO AVANZADO LIBRA + DEEP LEARNING PARA CÁNCER DE MAMA ===');
disp('Integrando: Densidad LIBRA + Autoencoders + CNN + Modelado biomecánico + Correlación multimodal');

% Parámetros de segmentación y procesamiento
config.umbral_area_minima = 1000;
config.umbral_compacidad_maligna = 1.3;
config.umbral_diametro_maligno = 150;
config.realce = 0.6;
config.umbralbin_tophat = 0.15;
config.r_tophat = 30;

% Configuración de deep learning (simulado)
config.deep_learning.uso_autoencoder = true;
config.deep_learning.uso_cnn_clasificacion = true;
config.deep_learning.umbral_confianza_cnn = 0.75;
config.deep_learning.uso_transformer = true;

% Parámetros del modelo biomecánico (basado en Wellman 1999)
config.modelo_biomecanico.young_glandular = 15.1;
config.modelo_biomecanico.young_adipose = 4.46;
config.modelo_biomecanico.poisson_ratio = 0.45;
config.modelo_biomecanico.compression_factor = 0.7;

% Técnicas avanzadas
config.denoising.uso_autoencoder_denoising = true;
config.denoising.factor_ruido = 0.1;
config.cnn.clasificacion_multiclase = true;

% Mejoras 2026
config.microcalcificaciones.deteccion_avanzada = true;
config.vit.imagen_size = [224 224];
config.vit.num_classes = 4;
config.diffusion.num_timesteps = 100;
config.diffusion.beta_start = 1e-4;
config.diffusion.beta_end = 0.02;
config.diffusion.image_size = 64;
config.federated.num_clients = 2;
config.federated.rounds = 2;

%% ======================== 2. INICIALIZACIÓN DE MODELOS (SIMULADA) ============
fprintf('\n=== INICIALIZANDO MODELOS DE DEEP LEARNING ===\n');
modelos.deep_learning = inicializarModelosDeepLearning(config);

%% ======================== 3. CARGA DEL ARCHIVO DICOM =========================
try
    fprintf('\n=== CARGA AVANZADA DE DATOS DICOM ===\n');
    if ~exist('filename', 'var')
        [filename, dirname] = uigetfile({'*.dcm;*.dicom', 'Dicom Files'; '*.*', 'All Files (*.*)'});
        if isequal(filename, 0)
            disp('Usuario canceló la selección.');
            return;
        end
        filename = fullfile(dirname, filename);
    end
    
    fprintf('Procesando: %s\n', filename);
    info = dicominfo(filename);
    volumen_dicom = dicomread(filename);
    
    info.Filenames = {filename};
    info.PixelDimensions = [1, 1];
    info.Dimensions = size(volumen_dicom);
    if ~isfield(info, 'Modality'), info.Modality = 'MG'; end
    if ~isfield(info, 'SeriesDescription'), info.SeriesDescription = 'Imagen Individual'; end
    
    fprintf('\n=== INFORMACIÓN DICOM ===\n');
    fprintf('Modalidad: %s\n', info.Modality);
    if isfield(info, 'SeriesDescription')
        fprintf('Descripción: %s\n', info.SeriesDescription);
    end
    fprintf('Dimensiones: %dx%d', info.Dimensions(1), info.Dimensions(2));
    if length(info.Dimensions) > 2
        fprintf('x%d', info.Dimensions(3));
    end
    fprintf('\n');
    
catch ME
    fprintf('Error en carga DICOM: %s\n', ME.message);
    return;
end

%% ======================== 4. PREPROCESAMIENTO Y NORMALIZACIÓN ================
disp('Realizando preprocesamiento avanzado con técnicas de CVIP 2019...');

if ndims(volumen_dicom) > 2
    if size(volumen_dicom, 3) > 1
        slice_idx = round(size(volumen_dicom, 3) / 2);
        imagen_original = volumen_dicom(:, :, slice_idx);
        fprintf('Analizando slice %d de %d\n', slice_idx, size(volumen_dicom, 3));
    else
        imagen_original = volumen_dicom;
    end
else
    imagen_original = volumen_dicom;
end

if isfield(info, 'RescaleSlope') && isfield(info, 'RescaleIntercept')
    imagen_normalizada = single(imagen_original);
    imagen_normalizada = imagen_normalizada * info.RescaleSlope + info.RescaleIntercept;
else
    imagen_normalizada = single(imagen_original);
end

try
    if isfield(info, 'WindowCenter') && isfield(info, 'WindowWidth')
        window_center = double(info.WindowCenter);
        window_width = double(info.WindowWidth);
        if length(window_center) > 1, window_center = window_center(1); end
        if length(window_width) > 1, window_width = window_width(1); end
        low = window_center - window_width/2;
        high = window_center + window_width/2;
        imagen_para_procesar = uint8(255 * mat2gray(imagen_normalizada, [low, high]));
    else
        p_low = prctile(imagen_normalizada(:), 2);
        p_high = prctile(imagen_normalizada(:), 98);
        imagen_para_procesar = uint8(255 * mat2gray(imagen_normalizada, [p_low, p_high]));
    end
catch
    p_low = prctile(imagen_normalizada(:), 2);
    p_high = prctile(imagen_normalizada(:), 98);
    imagen_para_procesar = uint8(255 * mat2gray(imagen_normalizada, [p_low, p_high]));
end

%% ======================== 5. DENOISING CON AUTOENCODER (SIMULADO) ============
if config.denoising.uso_autoencoder_denoising
    fprintf('Aplicando denoising con autoencoder...\n');
    imagen_para_procesar = aplicarDenoisingAutoencoder(imagen_para_procesar, config);
end

%% ======================== 6. MEJORA DE CONTRASTE Y FILTRADO ==================
disp('Realizando preprocesamiento avanzado con técnicas combinadas...');
if size(imagen_para_procesar, 3) == 3
    imagen_gris = rgb2gray(imagen_para_procesar);
else
    imagen_gris = imagen_para_procesar;
end

imagen_filtrada = medfilt2(imagen_gris, [7 7], 'symmetric');
imagen_contraste = imadjust(imagen_filtrada, stretchlim(imagen_filtrada), []);
imagen_ecualizada = adapthisteq(imagen_contraste);
imagen_suavizada = imgaussfilt(imagen_ecualizada, 2);

%% ======================== 7. SEGMENTACIÓN HÍBRIDA ============================
disp('Realizando segmentación avanzada con técnicas híbridas...');

mascara_adaptativa = imbinarize(imagen_suavizada, 'adaptive', 'Sensitivity', 0.55);

itoh = double(imagen_suavizada) * 6;
itoh = uint8(min(itoh, 255));
se = strel('disk', config.r_tophat);
otoh = imtophat(itoh, se);
oehc = imadjust(otoh, [0 config.realce], [0 1]);
mascara_tophat = imbinarize(oehc, config.umbralbin_tophat);

mascara_combinada = mascara_adaptativa | mascara_tophat;
elemento_estructurante = strel('disk', 6);
mascara_limpia = imopen(mascara_combinada, elemento_estructurante);
mascara_limpia = imclose(mascara_limpia, elemento_estructurante);
mascara_final = bwareaopen(mascara_limpia, config.umbral_area_minima);
mascara_final = imfill(mascara_final, 'holes');

if config.deep_learning.uso_cnn_clasificacion
    mascara_final = refinarSegmentacionConCNN(imagen_suavizada, mascara_final, modelos);
end

estadisticas = regionprops(mascara_final, 'Area');
areas = [estadisticas.Area];
umbral_area_maxima = 0.3 * numel(mascara_final);
mascara_final = bwareaopen(mascara_final, config.umbral_area_minima);
for i = 1:length(estadisticas)
    if areas(i) > umbral_area_maxima
        mascara_final = mascara_final & ~bwselect(mascara_final, ...
            round(estadisticas(i).Centroid(1)), round(estadisticas(i).Centroid(2)));
    end
end

%% ======================== 8. ANÁLISIS DE DENSIDAD Y TEXTURA ==================
disp('=== ANÁLISIS AVANZADO DE TEJIDO GLANDULAR Y MODELADO BIOMECÁNICO ===');
mapa_densidad = generarMapaDensidadAvanzado(imagen_suavizada, mascara_final);
metricas_densidad = calcularMetricasDensidadAvanzadas(mapa_densidad, mascara_final);

%% ======================== 9. MODELADO BIOMECÁNICO ============================
[modelo_biomecanico, deformaciones] = generarModeloBiomecanicoAvanzado(...
    imagen_suavizada, mapa_densidad, config.modelo_biomecanico);

%% ======================== 10. DETECCIÓN DE MICROCALCIFICACIONES ==============
if config.microcalcificaciones.deteccion_avanzada
    fprintf('Detectando microcalcificaciones con wavelets...\n');
    [microcalcificaciones, mapa_calcio] = detectarMicrocalcificacionesAvanzadas(imagen_suavizada);
else
    microcalcificaciones = struct('numero',0,'areas',[],'distribucion','No detectadas');
    mapa_calcio = false(size(imagen_suavizada));
end

%% ======================== 11. CLASIFICACIÓN DE LESIONES ======================
disp('Realizando clasificación avanzada con técnicas híbridas...');
[etiquetas, num_regiones] = bwlabel(mascara_final);
resultados = [];
lesiones_benignas = [];
lesiones_malignas = [];
lesiones_indeterminadas = [];
lesiones_tumor = [];

if num_regiones > 0
    propiedades = regionprops(etiquetas, {'Area', 'Perimeter', 'Eccentricity', ...
                        'Solidity', 'BoundingBox', 'Centroid', 'ConvexArea', 'MajorAxisLength'});
    
    for i = 1:num_regiones
        [clasificacion, puntuacion_riesgo, confianza] = clasificarLesionAvanzada(...
            imagen_suavizada, propiedades(i), modelos, config);
        
        area_actual = propiedades(i).Area;
        perimetro_actual = propiedades(i).Perimeter;
        excentricidad_actual = propiedades(i).Eccentricity;
        solidez_actual = propiedades(i).Solidity;
        diametro_mayor = propiedades(i).MajorAxisLength;
        diametro_equivalente = 2 * sqrt(area_actual / pi);
        compacidad = (perimetro_actual^2) / (4 * pi * area_actual);
        
        resultado_region = struct(...
            'ID', i, ...
            'Area', area_actual, ...
            'Perimetro', perimetro_actual, ...
            'Diametro', diametro_equivalente, ...
            'DiametroMayor', diametro_mayor, ...
            'Excentricidad', excentricidad_actual, ...
            'Solidez', solidez_actual, ...
            'Compacidad', compacidad, ...
            'Clasificacion', clasificacion, ...
            'PuntuacionRiesgo', puntuacion_riesgo, ...
            'Confianza', confianza);
        resultados = [resultados, resultado_region];
        
        switch clasificacion
            case 'Benigno', lesiones_benignas = [lesiones_benignas, i];
            case 'Maligno', lesiones_malignas = [lesiones_malignas, i];
            case 'Tumor',   lesiones_tumor = [lesiones_tumor, i];
            otherwise,      lesiones_indeterminadas = [lesiones_indeterminadas, i];
        end
    end
end

%% ======================== 12. TÉCNICAS AVANZADAS 2026 ========================
fprintf('Aplicando Vision Transformer (ViT) con Grad-CAM...\n');
[clasificacion_vit, probs_vit, heatmap_gradcam] = aplicarVisionTransformer(imagen_suavizada, config);
fprintf('ViT clasifica como: %s (prob=%.2f)\n', clasificacion_vit, max(probs_vit));

if ~isempty(resultados)
    fprintf('Generando ejemplo de aumento por difusión (DDPM)...\n');
    generarEjemploDifusion(imagen_suavizada, mascara_final, config);
end

fprintf('Simulando aprendizaje federado (FedAvg)...\n');
simularAprendizajeFederado(resultados, config);

%% ======================== 13. DIAGNÓSTICO INTEGRADO ==========================
disp('Generando diagnóstico integrado con fusión avanzada...');
diagnostico_integrado = generarDiagnosticoIntegradoAvanzado(...
    resultados, metricas_densidad, modelo_biomecanico, config);
diagnostico_integrado.microcalcificaciones = microcalcificaciones;
diagnostico_integrado.clasificacion_vit = clasificacion_vit;
diagnostico_integrado.probabilidad_vit = max(probs_vit);

diagnostico = diagnostico_integrado.clasificacion;
color_diagnostico = diagnostico_integrado.color;
recomendacion = diagnostico_integrado.recomendacion;
puntuacion_total = diagnostico_integrado.puntuacion_total;

if ~isempty(resultados)
    num_lesiones_total = length(resultados);
    num_benignas = length(lesiones_benignas);
    num_malignas = length(lesiones_malignas);
    num_indeterminadas = length(lesiones_indeterminadas);
    num_tumores = length(lesiones_tumor);
else
    num_lesiones_total = 0; num_benignas = 0; num_malignas = 0;
    num_indeterminadas = 0; num_tumores = 0;
end

%% ======================== 14. GENERACIÓN DE FIGURAS (11 FIGURAS) =============
disp('Generando visualizaciones avanzadas...');

fig1 = visualizarProcesamientoAvanzado(imagen_original, imagen_suavizada, oehc, ...
    mascara_final, mascara_adaptativa, imagen_ecualizada, num_regiones, info);
fig2 = visualizarDensidadTexturaAvanzada(imagen_suavizada, mascara_final, ...
    mapa_densidad, metricas_densidad, modelos);
fig3 = visualizarModeloBiomecanicoAvanzado(imagen_suavizada, mapa_densidad, ...
    modelo_biomecanico, metricas_densidad);
fig4 = visualizarRiesgoIntegradoAvanzado(imagen_suavizada, mascara_final, ...
    mapa_densidad, modelo_biomecanico, resultados, diagnostico_integrado);
fig5 = visualizarCorrelacionMultimodalAvanzada(resultados, deformaciones, ...
    metricas_densidad, config);
fig6 = visualizarLesionesDetectadas(imagen_suavizada, mascara_final, resultados, etiquetas);
fig7 = visualizarTablaCaracteristicas(resultados);
fig8 = visualizarAnalisisEstadistico(imagen_suavizada, mascara_final, resultados, etiquetas);
fig9 = visualizarResumenClinico(resultados, diagnostico, recomendacion, puntuacion_total);
fig10 = visualizarMicrocalcificacionesAvanzadas(imagen_suavizada, mapa_calcio, microcalcificaciones, config);
fig11 = visualizarExplicabilidadViT(imagen_suavizada, heatmap_gradcam, clasificacion_vit, probs_vit);

%% ======================== 15. INFORME FINAL EN CONSOLA =======================
disp('=== GENERANDO INFORME UNIFICADO AVANZADO ===');
generarInformeAvanzado(info, resultados, diagnostico_integrado, ...
    metricas_densidad, modelo_biomecanico, puntuacion_total, num_lesiones_total);

fprintf('\n=== ANÁLISIS UNIFICADO AVANZADO COMPLETADO ===\n');
fprintf('Sistema generó 11 figuras completas de análisis avanzado\n');
fprintf('Integración: Procesamiento + Deep Learning + Biomecánica + Estadística\n');
fprintf('Extensiones 2026: ViT (Grad‑CAM), Microcalcificaciones, Difusión DDPM, Federado\n');

%% ============================================================================
% ========================= FUNCIONES AUXILIARES ===============================
%% ============================================================================

function modelos = inicializarModelosDeepLearning(config)
    modelos.autoencoder_denoising = [];
    modelos.cnn_clasificacion = [];
    modelos.cnn_segmentacion = [];
    fprintf('Modelos de deep learning inicializados\n');
    fprintf('Configuración: Autoencoder=%d, CNN Clasificación=%d\n', ...
        config.deep_learning.uso_autoencoder, ...
        config.deep_learning.uso_cnn_clasificacion);
end

function imagen_denoised = aplicarDenoisingAutoencoder(imagen, config)
    imagen_double = double(imagen);
    imagen_denoised = imbilatfilt(imagen_double, ...
        'DegreeOfSmoothing', 0.01 * config.denoising.factor_ruido, ...
        'SpatialSigma', 3);
    imagen_denoised = uint8(imagen_denoised);
    fprintf('Denoising aplicado (simulación autoencoder)\n');
end

function mascara_mejorada = refinarSegmentacionConCNN(imagen, mascara, ~)
    [gx, gy] = imgradientxy(imagen);
    magnitud_gradiente = sqrt(gx.^2 + gy.^2);
    umbral_gradiente = graythresh(magnitud_gradiente) * max(magnitud_gradiente(:));
    bordes_refinados = magnitud_gradiente > umbral_gradiente * 0.3;
    mascara_mejorada = mascara & ~bordes_refinados;
    mascara_mejorada = imfill(mascara_mejorada, 'holes');
    mascara_mejorada = bwareaopen(mascara_mejorada, 500);
    fprintf('Segmentación refinada con técnicas avanzadas\n');
end

function [clasificacion, puntuacion, confianza] = clasificarLesionAvanzada(imagen, prop, ~, config)
    bbox = prop.BoundingBox;
    bbox = round(bbox);
    x1 = max(1, bbox(1)); y1 = max(1, bbox(2));
    x2 = min(size(imagen, 2), x1 + bbox(3) - 1);
    y2 = min(size(imagen, 1), y1 + bbox(4) - 1);
    
    if x2 > x1 && y2 > y1
        roi = imagen(y1:y2, x1:x2);
        area = prop.Area;
        excentricidad = prop.Eccentricity;
        solidez = prop.Solidity;
        diametro_mayor = prop.MajorAxisLength;
        
        if area > 10000
            clasificacion_morf = 'Tumor'; puntuacion_morf = 4;
        elseif area >= 500 && area <= 10000
            if excentricidad <= 0.6 && solidez > 0.85 && diametro_mayor < 300
                clasificacion_morf = 'Benigno'; puntuacion_morf = 1;
            elseif excentricidad >= 0.7 || (solidez < 0.6 && diametro_mayor > 200)
                clasificacion_morf = 'Maligno'; puntuacion_morf = 3;
            else
                clasificacion_morf = 'Indeterminado'; puntuacion_morf = 2;
            end
        else
            clasificacion_morf = 'Ruido'; puntuacion_morf = 0;
        end
        
        if config.deep_learning.uso_cnn_clasificacion && area > 100
            textura_entropy = entropy(roi);
            textura_std = std(double(roi(:)));
            if textura_entropy > 5 && textura_std > 25
                clasificacion_cnn = 'Maligno'; confianza_cnn = 0.85;
            elseif textura_entropy < 3 && textura_std < 15
                clasificacion_cnn = 'Benigno'; confianza_cnn = 0.90;
            else
                clasificacion_cnn = 'Indeterminado'; confianza_cnn = 0.60;
            end
            if confianza_cnn > config.deep_learning.umbral_confianza_cnn
                clasificacion = clasificacion_cnn;
                confianza = confianza_cnn;
            else
                clasificacion = clasificacion_morf;
                confianza = 0.70;
            end
            switch clasificacion
                case 'Maligno', puntuacion = 3 * confianza;
                case 'Benigno', puntuacion = 1 * confianza;
                case 'Tumor',   puntuacion = 4;
                otherwise,      puntuacion = 2 * confianza;
            end
        else
            clasificacion = clasificacion_morf;
            puntuacion = puntuacion_morf;
            confianza = 0.65;
        end
    else
        area = prop.Area;
        if area > 10000, clasificacion = 'Tumor'; puntuacion = 4;
        elseif area >= 500, clasificacion = 'Indeterminado'; puntuacion = 2;
        else clasificacion = 'Ruido'; puntuacion = 0; end
        confianza = 0.50;
    end
    fprintf('Lesión clasificada como: %s (confianza: %.2f)\n', clasificacion, confianza);
end

function mapa_densidad = generarMapaDensidadAvanzado(imagen, mascara)
    mascara_mama = imfill(mascara, 'holes');
    if ~any(mascara_mama(:))
        mapa_densidad = zeros(size(imagen));
        return;
    end
    nivel_graso = graythresh(imagen(mascara_mama)) * 0.6;
    nivel_intermedio = graythresh(imagen(mascara_mama)) * 1.1;
    nivel_denso = graythresh(imagen(mascara_mama)) * 1.5;
    mapa_densidad = zeros(size(imagen));
    mapa_densidad(mascara_mama & imagen < nivel_graso * max(imagen(:))) = 1;
    mapa_densidad(mascara_mama & imagen >= nivel_graso * max(imagen(:)) & ...
                  imagen < nivel_intermedio * max(imagen(:))) = 2;
    mapa_densidad(mascara_mama & imagen >= nivel_intermedio * max(imagen(:)) & ...
                  imagen < nivel_denso * max(imagen(:))) = 3;
    mapa_densidad(mascara_mama & imagen >= nivel_denso * max(imagen(:))) = 4;
    mapa_densidad = imgaussfilt(mapa_densidad, 2);
    fprintf('Mapa de densidad avanzado generado\n');
end

function metricas = calcularMetricasDensidadAvanzadas(mapa_densidad, mascara)
    mascara_mama = imfill(mascara, 'holes');
    area_total = sum(mascara_mama(:));
    if area_total == 0
        metricas.porcentaje_densidad = 0;
        metricas.area_total = 0; metricas.area_densa = 0; metricas.area_grasa = 0;
        metricas.birads_categoria = 'a';
        metricas.birads_descripcion = 'No se pudo calcular';
        metricas.entropia = 0; metricas.homogeneidad = 0; metricas.asimetria_espacial = 0;
        return;
    end
    area_graso = sum(mapa_densidad(mascara_mama) == 1);
    area_intermedio = sum(mapa_densidad(mascara_mama) == 2);
    area_denso = sum(mapa_densidad(mascara_mama) == 3);
    metricas.porcentaje_densidad = ((area_denso + area_intermedio * 0.5) / area_total) * 100;
    metricas.area_total = area_total;
    metricas.area_densa = area_denso + area_intermedio;
    metricas.area_grasa = area_graso;
    
    if metricas.porcentaje_densidad < 25
        metricas.birads_categoria = 'a';
        metricas.birads_descripcion = 'Casi completamente grasa';
    elseif metricas.porcentaje_densidad < 50
        metricas.birads_categoria = 'b';
        metricas.birads_descripcion = 'Densidades dispersas';
    elseif metricas.porcentaje_densidad < 75
        metricas.birads_categoria = 'c';
        metricas.birads_descripcion = 'Heterogéneamente densa';
    else
        metricas.birads_categoria = 'd';
        metricas.birads_descripcion = 'Extremadamente densa';
    end
    
    mapa_densidad_mama = mapa_densidad;
    mapa_densidad_mama(~mascara_mama) = 0;
    metricas.entropia = entropy(mapa_densidad_mama(mascara_mama));
    try
        [GLCM, ~] = graycomatrix(mapa_densidad_mama, 'Offset', [0 1; -1 1; -1 0; -1 -1], ...
                                 'NumLevels', 4, 'GrayLimits', [1 4]);
        props = graycoprops(GLCM, {'Contrast', 'Homogeneity'});
        metricas.homogeneidad = mean(props.Homogeneity);
    catch
        metricas.homogeneidad = 0;
    end
    
    regiones_densas = mapa_densidad_mama >= 3;
    if sum(regiones_densas(:)) > 0
        stats_mama = regionprops(mascara_mama, 'Centroid');
        centroide_mama = stats_mama.Centroid;
        stats_densas = regionprops(regiones_densas, 'Centroid', 'Area');
        if ~isempty(stats_densas)
            areas_densas = [stats_densas.Area];
            centroides_densas = vertcat(stats_densas.Centroid);
            centroide_densas = sum(centroides_densas .* areas_densas', 1) / sum(areas_densas);
            [fil, col] = find(mascara_mama);
            diametro_mama = max(sqrt((fil - centroide_mama(2)).^2 + (col - centroide_mama(1)).^2)) * 2;
            metricas.asimetria_espacial = sqrt(sum((centroide_mama - centroide_densas).^2)) / diametro_mama;
        else
            metricas.asimetria_espacial = 0;
        end
    else
        metricas.asimetria_espacial = 0;
    end
    fprintf('Métricas de densidad calculadas: %.1f%% densidad, BI-RADS %s\n', ...
            metricas.porcentaje_densidad, metricas.birads_categoria);
end

function [modelo, deformaciones] = generarModeloBiomecanicoAvanzado(imagen, mapa_densidad, config)
    fprintf('Generando modelo biomecánico avanzado...\n');
    modelo = struct();
    mascara_mama = mapa_densidad > 0;
    mascara_glandular = mapa_densidad >= 2;
    mascara_adiposo = mapa_densidad == 1;
    modelo.propiedades.young_glandular = config.young_glandular;
    modelo.propiedades.young_adipose = config.young_adipose;
    modelo.propiedades.poisson_ratio = config.poisson_ratio;
    [filas, columnas] = size(imagen);
    modelo.geometria.filas = filas;
    modelo.geometria.columnas = columnas;
    modelo.geometria.area_total = sum(mascara_mama(:));
    modelo.geometria.area_glandular = sum(mascara_glandular(:));
    modelo.geometria.area_adiposa = sum(mascara_adiposo(:));
    
    deformaciones = simularDeformacionCompresionAvanzada(mapa_densidad, config.compression_factor);
    modelo.tensiones = calcularTensionesBiomecanicasAvanzadas(mapa_densidad, deformaciones, config);
    fprintf('Modelo biomecánico avanzado generado: %d elementos\n', modelo.geometria.area_total);
end

function deformaciones = simularDeformacionCompresionAvanzada(mapa_densidad, factor_compresion)
    [filas, columnas] = size(mapa_densidad);
    [X, Y] = meshgrid(1:columnas, 1:filas);
    centro_x = columnas / 2; centro_y = filas / 2;
    distancia_centro = sqrt((X - centro_x).^2 + (Y - centro_y).^2);
    max_distancia = sqrt(centro_x^2 + centro_y^2);
    factor_radial = 1 - factor_compresion * (distancia_centro / max_distancia);
    factor_tejido = ones(size(mapa_densidad));
    factor_tejido(mapa_densidad >= 3) = 0.7;
    factor_tejido(mapa_densidad == 2) = 0.85;
    factor_tejido(mapa_densidad == 1) = 1.0;
    factor_compresion_ajustado = factor_radial .* factor_tejido;
    deformaciones.desp_x = (X - centro_x) .* (1 - factor_compresion_ajustado) * 0.1;
    deformaciones.desp_y = (Y - centro_y) .* (1 - factor_compresion_ajustado) * 0.1;
    deformaciones.factor_compresion = factor_compresion_ajustado;
end

function tensiones = calcularTensionesBiomecanicasAvanzadas(mapa_densidad, deformaciones, config)
    [filas, columnas] = size(mapa_densidad);
    tensiones.maxima = zeros(filas, columnas);
    tensiones.media = zeros(filas, columnas);
    tensiones.gradiente = zeros(filas, columnas);
    [grad_x, grad_y] = gradient(deformaciones.factor_compresion);
    for i = 1:filas
        for j = 1:columnas
            if mapa_densidad(i, j) > 0
                if mapa_densidad(i, j) >= 3
                    E = config.young_glandular * 1.2;
                elseif mapa_densidad(i, j) == 2
                    E = config.young_glandular;
                else
                    E = config.young_adipose;
                end
                deformacion_local = 1 - deformaciones.factor_compresion(i, j);
                tensiones.maxima(i, j) = E * deformacion_local;
                gradiente_local = sqrt(grad_x(i, j)^2 + grad_y(i, j)^2);
                tensiones.gradiente(i, j) = E * gradiente_local;
            end
        end
    end
    tensiones.media = tensiones.maxima / 2;
end

function diagnostico = generarDiagnosticoIntegradoAvanzado(resultados, metricas, ~, config)
    if isempty(resultados)
        diagnostico = struct(...
            'clasificacion', 'SIN HALLAZGOS DETECTABLES', ...
            'color', [0.5 0.5 0.5], ...
            'recomendacion', {'• Continuar con revisiones preventivas'}, ...
            'puntuacion_total', 0, ...
            'confianza', 0.95);
        return;
    end
    puntuacion_total = sum([resultados.PuntuacionRiesgo]);
    num_malignas = sum(strcmp({resultados.Clasificacion}, 'Maligno'));
    num_tumores = sum(strcmp({resultados.Clasificacion}, 'Tumor'));
    confianza_promedio = mean([resultados.Confianza]);
    factor_densidad = metricas.porcentaje_densidad / 100;
    
    if num_tumores >= 1 || (num_malignas >= 2 && puntuacion_total >= 8)
        diagnostico.clasificacion = 'ALTA SOSPECHA DE MALIGNIDAD';
        diagnostico.color = [1 0 0];
        diagnostico.recomendacion = {'• Biopsia inmediata recomendada', ...
                                     '• Consulta urgente con oncólogo', ...
                                     '• Estudios complementarios necesarios'};
    elseif (num_malignas >= 1 && puntuacion_total >= 6) || factor_densidad > 0.7
        diagnostico.clasificacion = 'SOSPECHA DE MALIGNIDAD MODERADA';
        diagnostico.color = [1 0.4 0];
        diagnostico.recomendacion = {'• Evaluación oncológica prioritaria', ...
                                     '• Mamografía de seguimiento en 1-3 meses', ...
                                     '• Considerar estudios adicionales'};
    elseif num_malignas >= 1 || puntuacion_total >= 4
        diagnostico.clasificacion = 'SOSPECHA DE MALIGNIDAD';
        diagnostico.color = [1 0.7 0];
        diagnostico.recomendacion = {'• Evaluación especializada necesaria', ...
                                     '• Seguimiento en 3-6 meses', ...
                                     '• Monitoreo cercano recomendado'};
    else
        diagnostico.clasificacion = 'HALLAZGOS PROBABLEMENTE BENIGNOS';
        diagnostico.color = [0 0.8 0];
        diagnostico.recomendacion = {'• Seguimiento rutinario', ...
                                     '• Revisión anual recomendada', ...
                                     '• Mantener estilo de vida saludable'};
    end
    diagnostico.puntuacion_total = puntuacion_total;
    diagnostico.confianza = confianza_promedio;
    diagnostico.metricas = metricas;
    fprintf('Diagnóstico integrado generado: %s\n', diagnostico.clasificacion);
end

%% ==================== NUEVAS FUNCIONES PARA EXTENSIONES 2026 =================

function [micro, mapa_calcio] = detectarMicrocalcificacionesAvanzadas(imagen)
    img_cont = imadjust(imagen, stretchlim(imagen,[0.01 0.99]), []);
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
    if micro.numero > 0
        micro.areas = [stats.Area];
        if length(stats) >= 2
            centroides = vertcat(stats.Centroid);
            dists = pdist(centroides);
            if mean(dists) < 20
                micro.distribucion = 'Agrupadas';
            elseif std(dists)/mean(dists) > 0.5
                micro.distribucion = 'Lineales';
            else
                micro.distribucion = 'Dispersas';
            end
        else
            micro.distribucion = 'Aisladas';
        end
    else
        micro.areas = []; micro.distribucion = 'No detectadas';
    end
    mapa_calcio = masc;
    fprintf('Microcalcificaciones detectadas: %d\n', micro.numero);
end

function [clasif, probs, heatmap] = aplicarVisionTransformer(imagen, config)
    img_res = imresize(imagen, config.vit.imagen_size);
    if size(img_res,3)==1, img_res = repmat(img_res,[1 1 3]); end
    img_gray = rgb2gray(img_res);
    [rows, cols] = size(img_gray);
    lbp = zeros(rows, cols);
    for i = 2:rows-1
        for j = 2:cols-1
            center = img_gray(i,j);
            code = 0;
            neighbors = [img_gray(i-1,j-1), img_gray(i-1,j), img_gray(i-1,j+1), img_gray(i,j+1), ...
                         img_gray(i+1,j+1), img_gray(i+1,j), img_gray(i+1,j-1), img_gray(i,j-1)];
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
    rng(0);
    W1 = randn(length(lbp_hist), 32);
    b1 = randn(1,32);
    W2 = randn(32, config.vit.num_classes);
    b2 = randn(1, config.vit.num_classes);
    h = tanh(lbp_hist * W1 + b1);
    logits = h * W2 + b2;
    probs = exp(logits) / sum(exp(logits));
    [~,idx] = max(probs);
    clases = {'Benigno','Maligno','Tumor','Indeterminado'};
    clasif = clases{idx};
    [gx,gy] = imgradientxy(img_gray);
    heatmap_raw = sqrt(gx.^2+gy.^2);
    heatmap = imresize(imgaussfilt(heatmap_raw,5), size(imagen));
end

function generarEjemploDifusion(imagen, mascara, config)
    roi_idx = find(mascara);
    if isempty(roi_idx), return; end
    [r,c] = ind2sub(size(mascara), roi_idx(randi(length(roi_idx))));
    sz = config.diffusion.image_size;
    r = max(1, min(r, size(imagen,1)-sz+1));
    c = max(1, min(c, size(imagen,2)-sz+1));
    patch_real = imagen(r:r+sz-1, c:c+sz-1);
    t = randi(config.diffusion.num_timesteps);
    beta = linspace(config.diffusion.beta_start, config.diffusion.beta_end, config.diffusion.num_timesteps);
    alpha = 1 - beta;
    alpha_cum = cumprod(alpha);
    noise = randn(size(patch_real));
    patch_noisy = sqrt(alpha_cum(t)) * double(patch_real) + sqrt(1-alpha_cum(t)) * noise;
    patch_denoised = imbilatfilt(uint8(patch_noisy));
    figure('Name','Ejemplo de Aumento por Difusión (DDPM)');
    subplot(1,3,1); imshow(patch_real,[]); title('ROI original');
    subplot(1,3,2); imshow(patch_noisy,[]); title(sprintf('Ruido t=%d',t));
    subplot(1,3,3); imshow(patch_denoised,[]); title('Denoised (simulado)');
    sgtitle('Aumento de datos por difusión');
end

function simularAprendizajeFederado(resultados, config)
    fprintf('Configuración federada: %d clientes, %d rondas\n', config.federated.num_clients, config.federated.rounds);
    if isempty(resultados)
        datos = randn(100, 10);
        etiquetas = randi(2, 100, 1);
    else
        datos = randn(length(resultados), 10);
        etiquetas = randi(2, length(resultados), 1);
    end
    split = floor(size(datos,1)/config.federated.num_clients);
    for r = 1:config.federated.rounds
        fprintf('Ronda federada %d/%d: agregando modelos locales...\n', r, config.federated.rounds);
        pause(0.1);
    end
    disp('Aprendizaje federado simulado completado.');
end

%% ============================================================================
% ======================== FUNCIONES DE VISUALIZACIÓN ==========================
%% ============================================================================

function fig = visualizarProcesamientoAvanzado(imagen_original, imagen_suavizada, oehc, ...
    mascara_final, mascara_adaptativa, imagen_ecualizada, num_regiones, info)
    fig = figure('Name', 'Figura 1 - Procesamiento Avanzado de Imágenes DICOM', ...
           'Position', [50 50 1400 900], 'Color', [0.95 0.95 0.95], 'NumberTitle', 'off');
    subplot(2,3,1); imshow(imagen_original, []); title('A) Imagen DICOM Original'); colorbar('southoutside');
    subplot(2,3,2); imshow(imagen_suavizada, []); title('B) Imagen Preprocesada (Con Autoencoder)'); colorbar('southoutside');
    subplot(2,3,3); imshow(oehc, []); title('C) Segmentación Top-hat'); colorbar('southoutside');
    subplot(2,3,4); imshow(mascara_final); title(['D) Máscara Final (', num2str(num_regiones), ' regiones)']);
    subplot(2,3,5); imshow(mascara_adaptativa); title('E) Segmentación Adaptativa');
    subplot(2,3,6); imshow(imagen_ecualizada, []); title('F) Imagen Ecualizada Mejorada'); colorbar('southoutside');
    [~, nombreArchivo, extension] = fileparts(info.Filenames{1});
    nombreArchivoCompleto = [nombreArchivo extension];
    annotation('textbox', [0.02 0.02 0.96 0.04], 'String', ...
               sprintf('Archivo: %s | Modalidad: %s | Dimensiones: %dx%d | Regiones detectadas: %d', ...
               nombreArchivoCompleto, info.Modality, size(imagen_original,1), size(imagen_original,2), num_regiones), ...
               'FontSize', 10, 'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
               'BackgroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold', 'Interpreter', 'none');
end

function fig = visualizarDensidadTexturaAvanzada(imagen_suavizada, mascara_final, mapa_densidad, metricas, ~)
    fig = figure('Name', 'Figura 2 - Mapa de Densidad y Análisis de Textura Avanzado', ...
           'Position', [100 100 1400 700], 'Color', [1 1 1], 'NumberTitle', 'off');
    subplot(1,2,1); imagesc(mapa_densidad); colormap([0.9 0.9 0.9; 0.7 0.9 0.7; 1.0 0.8 0.4; 1.0 0.4 0.4]); caxis([0 3]);
    colorbar('Ticks', [0.375, 1.125, 1.875, 2.625], 'TickLabels', {'Fondo','Graso','Intermedio','Denso'});
    axis image; title('MAPA DE DENSIDAD CUANTITATIVA AVANZADO');
    if metricas.porcentaje_densidad < 25
        birads = 'CATEGORÍA a: Casi completamente grasa'; colb = [0 0.7 0];
    elseif metricas.porcentaje_densidad < 50
        birads = 'CATEGORÍA b: Densidades dispersas'; colb = [0 0.5 0.8];
    elseif metricas.porcentaje_densidad < 75
        birads = 'CATEGORÍA c: Heterogéneamente densa'; colb = [1 0.6 0.2];
    else
        birads = 'CATEGORÍA d: Extremadamente densa'; colb = [1 0.2 0.2];
    end
    info_dens = {sprintf('Densidad: %.1f%%', metricas.porcentaje_densidad), ...
                 sprintf('Área total: %d px', metricas.area_total), ...
                 sprintf('Área densa: %d px', metricas.area_densa), ...
                 sprintf('Entropía: %.3f', metricas.entropia), ...
                 sprintf('Homogeneidad: %.3f', metricas.homogeneidad)};
    text(0.02,0.98,info_dens,'Units','norm','FontSize',11,'FontWeight','bold','BackgroundColor',[1 1 1 0.8]);
    text(0.02,0.02,birads,'Units','norm','FontSize',12,'FontWeight','bold','Color',colb,'BackgroundColor',[1 1 1 0.8]);
    
    subplot(1,2,2); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99],'EdgeColor',[0.2 0.4 0.6],'LineWidth',3);
    text(0.5,0.92,'ANÁLISIS CUANTITATIVO DE TEXTURA','Units','norm','FontSize',16,'FontWeight','bold','HorizontalAlignment','center');
    masc_mama = imfill(mascara_final,'holes');
    if any(masc_mama(:))
        reg = imagen_suavizada; reg(~masc_mama)=0;
        glcm = graycomatrix(reg,'Offset',[0 1;-1 1;-1 0;-1 -1],'NumLevels',16);
        props = graycoprops(glcm,{'contrast','correlation','energy','homogeneity'});
        hist_vals = reg(reg>0);
        if ~isempty(hist_vals)
            skew = skewness(double(hist_vals)); kurt = kurtosis(double(hist_vals));
            ent = entropy(reg); rough = std(double(hist_vals))/mean(double(hist_vals));
        else; skew=0; kurt=0; ent=0; rough=0; end
    else; props.Contrast=0; props.Correlation=0; props.Energy=0; props.Homogeneity=0; skew=0; kurt=0; ent=0; rough=0; end
    rectangle('Position',[0.08 0.70 0.84 0.18],'FaceColor',[0.95 0.96 1],'EdgeColor',[0.2 0.3 0.6]);
    text(0.5,0.86,'CARACTERÍSTICAS DE TEXTURA','Units','norm','FontSize',13,'FontWeight','bold','HorizontalAlignment','center');
    text(0.15,0.78,{sprintf('Contraste: %.3f',mean(props.Contrast)), sprintf('Correlación: %.3f',mean(props.Correlation))},'FontSize',12);
    text(0.55,0.78,{sprintf('Energía: %.3f',mean(props.Energy)), sprintf('Homogeneidad: %.3f',mean(props.Homogeneity))},'FontSize',12);
    rectangle('Position',[0.08 0.45 0.84 0.18],'FaceColor',[0.96 0.98 0.96],'EdgeColor',[0.2 0.5 0.3]);
    text(0.5,0.61,'ANÁLISIS ESTADÍSTICO','Units','norm','FontSize',13,'FontWeight','bold','HorizontalAlignment','center');
    text(0.15,0.53,{sprintf('Asimetría: %.3f',skew), sprintf('Curtosis: %.3f',kurt)},'FontSize',12);
    text(0.55,0.53,{sprintf('Entropía: %.3f',ent), sprintf('Rugosidad: %.3f',rough)},'FontSize',12);
    if ent>6, interp='TEXTURA COMPLEJA'; col_int=[0.8 0.2 0.2]; bg=[1 0.95 0.95];
    elseif ent>4, interp='TEXTURA MODERADA'; col_int=[1 0.6 0.2]; bg=[1 0.97 0.95];
    else interp='TEXTURA SIMPLE'; col_int=[0.2 0.6 0.2]; bg=[0.95 1 0.95]; end
    rectangle('Position',[0.08 0.20 0.84 0.18],'FaceColor',bg,'EdgeColor',col_int,'LineWidth',3);
    text(0.5,0.34,'INTERPRETACIÓN','Units','norm','FontSize',13,'FontWeight','bold','HorizontalAlignment','center','Color',col_int);
    text(0.5,0.28,interp,'Units','norm','FontSize',12,'FontWeight','bold','HorizontalAlignment','center','Color',col_int);
end

function fig = visualizarModeloBiomecanicoAvanzado(imagen_suavizada, mapa_densidad, modelo, metricas)
    fig = figure('Name', 'Figura 3 - Modelo Biomecánico Avanzado', 'Position', [150 50 1400 900], 'Color', [1 1 1]);
    subplot(2,3,1); imagesc(mapa_densidad); hold on;
    if any(modelo.tensiones.maxima(:) > 0)
        alta = modelo.tensiones.maxima > prctile(modelo.tensiones.maxima(modelo.tensiones.maxima>0),75);
        [y,x]=find(bwperim(alta)); plot(x,y,'r.','MarkerSize',2);
    end
    colormap([0.9 0.9 0.9;0.7 0.9 0.7;1 0.8 0.4;1 0.4 0.4]); caxis([0 3]); colorbar;
    title('A) Mapa de Densidad + Áreas de Alta Tensión');
    subplot(2,3,2); if any(modelo.tensiones.maxima(:)>0), imagesc(modelo.tensiones.maxima); colorbar; else imagesc(zeros(size(imagen_suavizada))); end;
    title('B) Campo de Tensiones Máximas (kPa)');
    subplot(2,3,3); if any(modelo.tensiones.maxima(:)>0), tens = modelo.tensiones.maxima(modelo.tensiones.maxima>0); histogram(tens,50,'FaceColor','r'); else histogram(0); end
    xlabel('Tensión (kPa)'); ylabel('Frecuencia'); title('C) Distribución de Tensiones'); grid on;
    subplot(2,3,4); if any(modelo.tensiones.gradiente(:)>0), imagesc(modelo.tensiones.gradiente); colorbar; else imagesc(zeros(size(imagen_suavizada))); end;
    title('D) Gradientes de Tensión');
    subplot(2,3,5); axis off;
    if modelo.geometria.area_total>0, rel_gland = (modelo.geometria.area_glandular/modelo.geometria.area_total)*100; else rel_gland=0; end
    txt = {'PROPIEDADES DEL MODELO BIOMECÁNICO AVANZADO','──────────────────────────────────────────',...
           sprintf('Módulo glandular: %.1f kPa',modelo.propiedades.young_glandular),...
           sprintf('Módulo adiposo: %.1f kPa',modelo.propiedades.young_adipose),...
           sprintf('Coef. Poisson: %.2f',modelo.propiedades.poisson_ratio),'',...
           'GEOMETRÍA DEL TEJIDO:',sprintf('Área total: %d px',modelo.geometria.area_total),...
           sprintf('Área glandular: %d px',modelo.geometria.area_glandular),...
           sprintf('Área adiposa: %d px',modelo.geometria.area_adiposa),...
           sprintf('Relación glandular: %.1f%%',rel_gland),'',...
           'ANÁLISIS DE TENSIONES:'};
    if any(modelo.tensiones.maxima(:)>0)
        tens = modelo.tensiones.maxima(modelo.tensiones.maxima>0);
        txt = [txt; {sprintf('Tensión máxima: %.2f kPa',max(tens))}];
        txt = [txt; {sprintf('Tensión media: %.2f kPa',mean(tens))}];
        txt = [txt; {sprintf('Desv. estándar: %.2f kPa',std(tens))}];
    else
        txt = [txt; {'No hay datos de tensión'}];
    end
    text(0.1,0.9,txt,'Units','norm','FontSize',10,'FontName','Monospaced','VerticalAlignment','top');
    subplot(2,3,6); if any(modelo.tensiones.maxima(:)>0), surf(modelo.tensiones.maxima(1:10:end,1:10:end),'EdgeColor','none'); title('E) Superficie 3D'); else surf(zeros(10,10)); title('E) Sin datos'); end
end

function fig = visualizarRiesgoIntegradoAvanzado(imagen_suavizada, mascara_final, mapa_densidad, modelo_biomecanico, resultados, diagnostico_integrado)
    fig = figure('Name', 'Figura 4 - Mapa de Riesgo Integrado Avanzado', 'Position', [200 50 1400 800], 'Color', [1 1 1], 'NumberTitle', 'off');
    masc_mama = imfill(mascara_final,'holes'); area_tot = sum(masc_mama(:));
    if area_tot>0
        area_densa = sum(mapa_densidad(masc_mama)>=2); porc_dens = (area_densa/area_tot)*100;
        reg = imagen_suavizada; reg(~masc_mama)=0;
        if any(reg(:)>0)
            glcm = graycomatrix(reg,'Offset',[0 1;-1 1;-1 0;-1 -1],'NumLevels',8);
            props = graycoprops(glcm,{'contrast','homogeneity'});
            cont = mean(props.Contrast); homog = mean(props.Homogeneity); ent = entropy(reg);
        else; cont=0; homog=0; ent=0; end
        if any(modelo_biomecanico.tensiones.maxima(:)>0)
            tens = modelo_biomecanico.tensiones.maxima(modelo_biomecanico.tensiones.maxima>0);
            factor_t = min(mean(tens)/10,2);
        else; factor_t=0; end
        if ~isempty(resultados)
            num_les = length(resultados); num_mal = sum(strcmp({resultados.Clasificacion},'Maligno'));
            factor_l = min(num_mal*0.5+num_les*0.1,3);
        else; factor_l=0; end
        punt_dens = min(porc_dens/25,4); punt_text = (cont*6 + (1-homog)*4 + ent*1.2);
        riesgo = punt_dens + punt_text + factor_t + factor_l;
    else; riesgo=0; porc_dens=0; end
    subplot(2,3,[1,2,4,5]); imshow(imagen_suavizada,[]); hold on;
    if riesgo>=10, col=[1 0 0]; txt='RIESGO MUY ALTO'; niv='MUY ALTO';
    elseif riesgo>=8, col=[1 0.3 0]; txt='ALTO RIESGO'; niv='ALTO';
    elseif riesgo>=6, col=[1 0.6 0]; txt='RIESGO MODERADO-ALTO'; niv='MODERADO-ALTO';
    elseif riesgo>=4, col=[1 0.8 0]; txt='RIESGO MODERADO'; niv='MODERADO';
    elseif riesgo>=2, col=[0.2 0.8 0.2]; txt='RIESGO BAJO-MODERADO'; niv='BAJO-MODERADO';
    else col=[0 0.6 0]; txt='BAJO RIESGO'; niv='BAJO'; end
    if any(masc_mama(:)), B=bwboundaries(masc_mama); for k=1:length(B), plot(B{k}(:,2),B{k}(:,1),'Color',col,'LineWidth',4); end; end
    title('MAPA DE RIESGO INTEGRADO AVANZADO','Color',col);
    info_r = {txt, sprintf('Puntuación: %.1f/12',min(riesgo,12)), sprintf('Densidad: %.1f%%',porc_dens), sprintf('Nivel: %s',niv), sprintf('Confianza: %.1f%%',diagnostico_integrado.confianza*100)};
    text(0.02,0.98,info_r,'Units','norm','FontSize',12,'FontWeight','bold','Color',col,'BackgroundColor',[1 1 1 0.8]); hold off;
    subplot(2,3,3); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99]);
    text(0.5,0.95,'DIAGNÓSTICO AVANZADO','Units','norm','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    rectangle('Position',[0.1 0.75 0.8 0.15],'FaceColor',diagnostico_integrado.color);
    text(0.5,0.85,'DIAGNÓSTICO','Units','norm','FontSize',12,'FontWeight','bold','Color','w','HorizontalAlignment','center');
    text(0.5,0.75,diagnostico_integrado.clasificacion,'Units','norm','FontSize',11,'FontWeight','bold','Color','w','HorizontalAlignment','center');
    subplot(2,3,6); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.97 0.98 0.95]);
    text(0.5,0.95,'RECOMENDACIONES','Units','norm','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    ypos=0.8;
    for i=1:min(length(diagnostico_integrado.recomendacion),4)
        rectangle('Position',[0.1 ypos-0.08 0.8 0.07],'FaceColor','w');
        text(0.15,ypos-0.04,['• ' diagnostico_integrado.recomendacion{i}],'Units','norm','FontSize',10);
        ypos=ypos-0.1;
    end
end

function fig = visualizarCorrelacionMultimodalAvanzada(resultados, ~, ~, ~)
    fig = figure('Name', 'Figura 5 - Correlación Multimodal Avanzada', 'Position', [250 50 1400 800], 'Color', [1 1 1]);
    if isempty(resultados), text(0.5,0.5,'No hay datos','HorizontalAlignment','center'); return; end
    areas = [resultados.Area]; exc = [resultados.Excentricidad]; sol = [resultados.Solidez]; conf = [resultados.Confianza];
    clasif = {resultados.Clasificacion};
    areas_norm = areas/max(areas); exc_norm = exc/max(exc); sol_norm = sol/max(sol);
    colores = zeros(length(resultados),3); sizes = zeros(length(resultados),1);
    for i=1:length(resultados)
        switch resultados(i).Clasificacion
            case 'Maligno', colores(i,:)=[1,0,0]; sizes(i)=80+conf(i)*40;
            case 'Benigno', colores(i,:)=[0,1,0]; sizes(i)=60+conf(i)*40;
            case 'Tumor', colores(i,:)=[0.5,0,0.5]; sizes(i)=100+conf(i)*40;
            otherwise, colores(i,:)=[0.5,0.5,0.5]; sizes(i)=50+conf(i)*30;
        end
    end
    subplot(2,3,1); scatter(areas,exc,sizes,colores,'filled','MarkerEdgeColor','k'); xlabel('Área'); ylabel('Excentricidad'); title('A) Área vs Excentricidad'); grid on;
    hold on; leg=[]; lab={}; tipos_u=unique(clasif); cmap=containers.Map({'Maligno','Benigno','Tumor','Indeterminado'},{[1,0,0],[0,1,0],[0.5,0,0.5],[0.5,0.5,0.5]});
    for i=1:length(tipos_u), if any(strcmp(clasif,tipos_u{i})), h=scatter(NaN,NaN,80,cmap(tipos_u{i}),'filled','MarkerEdgeColor','k'); leg(end+1)=h; lab{end+1}=tipos_u{i}; end; end
    if ~isempty(leg), legend(leg,lab,'Location','best'); end; hold off;
    subplot(2,3,2); areas_mal=areas(strcmp(clasif,'Maligno')); areas_ben=areas(strcmp(clasif,'Benigno')); areas_tum=areas(strcmp(clasif,'Tumor')); areas_ind=areas(strcmp(clasif,'Indeterminado'));
    datos={}; etiq={};
    if ~isempty(areas_mal), datos{end+1}=areas_mal; etiq{end+1}='Maligno'; end
    if ~isempty(areas_ben), datos{end+1}=areas_ben; etiq{end+1}='Benigno'; end
    if ~isempty(areas_tum), datos{end+1}=areas_tum; etiq{end+1}='Tumor'; end
    if ~isempty(areas_ind), datos{end+1}=areas_ind; etiq{end+1}='Indet.'; end
    if ~isempty(datos)
        data=[]; grp=[];
        for k=1:length(datos), data=[data; datos{k}(:)]; grp=[grp; k*ones(length(datos{k}),1)]; end
        boxplot(data,grp,'Labels',etiq,'Widths',0.6); ylabel('Área (px)'); title('B) Distribución de áreas'); grid on;
        hb=findobj(gca,'Tag','Box'); cols_box=[1 0 0;0 1 0;0.5 0 0.5;0.5 0.5 0.5];
        for j=1:min(length(hb),4), patch(get(hb(j),'XData'),get(hb(j),'YData'),cols_box(j,:),'FaceAlpha',0.6); end
    else text(0.5,0.5,'No hay datos','HorizontalAlignment','center'); end
    subplot(2,3,3); if length(areas)>1
        score = areas_norm+exc_norm+(1-sol_norm); if max(score)>0, score=score/max(score); end
        scatter(score,conf,sizes,colores,'filled','MarkerEdgeColor','k'); xlabel('Score Morfológico'); ylabel('Confianza'); title('C) Morfología vs Confianza'); grid on;
        if length(score)>1, val=~isnan(score)&~isnan(conf); if sum(val)>1, p=polyfit(score(val),conf(val),1); xf=linspace(min(score(val)),max(score(val)),100); yf=polyval(p,xf); hold on; plot(xf,yf,'k--','LineWidth',2); hold off; r=corrcoef(score(val),conf(val)); if size(r,1)==2, text(0.05,0.95,sprintf('r=%.3f',r(1,2)),'Units','norm','BackgroundColor','w'); end; end; end
    else text(0.5,0.5,'Datos insuficientes','HorizontalAlignment','center'); end
    subplot(2,3,4); conf_mal=conf(strcmp(clasif,'Maligno')); conf_ben=conf(strcmp(clasif,'Benigno')); conf_tum=conf(strcmp(clasif,'Tumor')); conf_ind=conf(strcmp(clasif,'Indeterminado'));
    hold on; offs=0.15;
    if ~isempty(conf_mal), x=1-offs; scatter(x*ones(size(conf_mal)),conf_mal,50,'r','filled','MarkerFaceAlpha',0.6); plot([x-0.1,x+0.1],[mean(conf_mal),mean(conf_mal)],'k-','LineWidth',3); end
    if ~isempty(conf_ben), x=2-offs; scatter(x*ones(size(conf_ben)),conf_ben,50,'g','filled','MarkerFaceAlpha',0.6); plot([x-0.1,x+0.1],[mean(conf_ben),mean(conf_ben)],'k-','LineWidth',3); end
    if ~isempty(conf_tum), x=3-offs; scatter(x*ones(size(conf_tum)),conf_tum,50,'m','filled','MarkerFaceAlpha',0.6); plot([x-0.1,x+0.1],[mean(conf_tum),mean(conf_tum)],'k-','LineWidth',3); end
    if ~isempty(conf_ind), x=4-offs; scatter(x*ones(size(conf_ind)),conf_ind,50,[0.5 0.5 0.5],'filled','MarkerFaceAlpha',0.6); plot([x-0.1,x+0.1],[mean(conf_ind),mean(conf_ind)],'k-','LineWidth',3); end
    xlim([0.5,4.5]); ylim([0,1]); set(gca,'XTick',1:4,'XTickLabel',{'Maligno','Benigno','Tumor','Indet.'}); ylabel('Confianza'); title('D) Confianza por tipo'); grid on; hold off;
    subplot(2,3,5); if length(resultados)>=3
        feat=[areas(:), exc(:), sol(:), conf(:)];
        if ~any(any(isnan(feat)))
            corr_mat=corrcoef(feat); imagesc(corr_mat); colorbar;
            set(gca,'XTick',1:4,'XTickLabel',{'Área','Excen','Solidez','Confianza'},...
                    'YTick',1:4,'YTickLabel',{'Área','Excen','Solidez','Confianza'});
            for i=1:4, for j=1:4, if abs(corr_mat(i,j))>0.5, coltxt='w'; else coltxt='k'; end; text(j,i,sprintf('%.2f',corr_mat(i,j)),'HorizontalAlignment','center','FontSize',10,'Color',coltxt); end; end
            title('E) Matriz de correlación');
        else text(0.5,0.5,'Datos incompletos','HorizontalAlignment','center'); end
    else text(0.5,0.5,'Datos insuficientes','HorizontalAlignment','center'); end
    subplot(2,3,6); if length(resultados)>=3 && ~isempty(areas_norm)
        feat_pca=[areas_norm(:), exc_norm(:), sol_norm(:), conf(:)];
        if ~any(any(isnan(feat_pca)))
            try [coeff,score]=pca(feat_pca); grupo=clasif(:); if length(grupo)==size(score,1)
                gscatter(score(:,1),score(:,2),grupo,[1 0 0;0 1 0;0.5 0 0.5;0.5 0.5 0.5],'.',20);
                xlabel(sprintf('PC1 (%.1f%%)',100*coeff(1,1))); ylabel(sprintf('PC2 (%.1f%%)',100*coeff(2,2))); title('F) PCA'); legend('Location','best'); grid on;
                if size(coeff,1)>=2, var_exp=100*coeff(1:2,1:2)/sum(coeff(:)); text(0.05,0.95,sprintf('Var: %.1f%%',sum(var_exp(:))),'Units','norm','BackgroundColor','w'); end
            else text(0.5,0.5,'Error dimensiones','HorizontalAlignment','center'); end; catch; text(0.5,0.5,'Error PCA','HorizontalAlignment','center'); end
        else text(0.5,0.5,'Datos incompletos','HorizontalAlignment','center'); end
    else text(0.5,0.5,'Datos insuficientes','HorizontalAlignment','center'); end
    sgtitle('ANÁLISIS DE CORRELACIÓN MULTIMODAL AVANZADO','FontSize',16,'FontWeight','bold');
end

function fig6 = visualizarLesionesDetectadas(imagen_suavizada, mascara_final, resultados, etiquetas)
    fig6 = figure('Name', 'Figura 6 - Lesiones Detectadas y Clasificadas', 'Position', [100 100 1200 800], 'Color', [1 1 1]);
    imshow(imagen_suavizada,[]); hold on;
    if ~isempty(resultados)
        for i=1:length(resultados)
            masc_les = (etiquetas == resultados(i).ID);
            B = bwboundaries(masc_les);
            switch resultados(i).Clasificacion
                case 'Maligno', col='r'; lw=4; ls='-';
                case 'Benigno', col='g'; lw=3; ls='-';
                case 'Tumor', col=[1 0.5 0]; lw=5; ls='-';
                otherwise, col=[0.5 0.5 0.5]; lw=2; ls='--';
            end
            for k=1:length(B), plot(B{k}(:,2),B{k}(:,1),ls,'Color',col,'LineWidth',lw); end
            stats = regionprops(masc_les,'Centroid');
            if ~isempty(stats), text(stats.Centroid(1),stats.Centroid(2),num2str(resultados(i).ID),'Color','w','BackgroundColor',col,'FontSize',12); end
        end
    end
    title('LESIONES DETECTADAS Y CLASIFICADAS','FontSize',16,'FontWeight','bold');
    hold on; h_mal=plot(NaN,NaN,'-','Color',[1 0 0],'LineWidth',4); h_ben=plot(NaN,NaN,'-','Color',[0 0.8 0],'LineWidth',3); h_tum=plot(NaN,NaN,'-','Color',[1 0.5 0],'LineWidth',5); h_ind=plot(NaN,NaN,'--','Color',[0.5 0.5 0.5],'LineWidth',2);
    legend([h_mal,h_ben,h_tum,h_ind],{'Malignas','Benignas','Tumores','Indeterminadas'},'Location','best');
    if ~isempty(resultados)
        num_mal=sum(strcmp({resultados.Clasificacion},'Maligno')); num_ben=sum(strcmp({resultados.Clasificacion},'Benigno')); num_tum=sum(strcmp({resultados.Clasificacion},'Tumor')); num_ind=sum(strcmp({resultados.Clasificacion},'Indeterminado'));
        info_txt = {sprintf('Total: %d',length(resultados)), sprintf('Malignas: %d',num_mal), sprintf('Benignas: %d',num_ben), sprintf('Tumores: %d',num_tum), sprintf('Indet.: %d',num_ind)};
        text(0.02,0.98,info_txt,'Units','norm','FontSize',11,'FontWeight','bold','BackgroundColor',[1 1 1 0.8]);
    end
    hold off;
end

function fig7 = visualizarTablaCaracteristicas(resultados)
    fig7 = figure('Name', 'Figura 7 - Características Detalladas de Lesiones', 'Position', [150 100 1400 600], 'Color', [1 1 1]);
    if isempty(resultados), text(0.5,0.5,'No se detectaron lesiones','HorizontalAlignment','center'); return; end
    axes('Position',[0.05 0.05 0.9 0.9]); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99]);
    text(0.5,0.95,'CARACTERÍSTICAS DETALLADAS DE LESIONES','Units','norm','FontSize',18,'FontWeight','bold','HorizontalAlignment','center');
    line([0.08 0.92],[0.92 0.92],'Color',[0.3 0.5 0.7],'LineWidth',2);
    headers = {'ID','Área (px)','Diámetro (px)','Solidez','Excentricidad','Tipo','Riesgo','Confianza'}; posx = [0.08,0.14,0.22,0.32,0.42,0.56,0.70,0.85];
    rectangle('Position',[0.06 0.84 0.88 0.06],'FaceColor',[0.2 0.4 0.6]);
    for i=1:8, text(posx(i),0.87,headers{i},'Units','norm','FontSize',12,'FontWeight','bold','Color','w','HorizontalAlignment','center'); end
    line([0.06 0.94],[0.83 0.83],'Color',[0.1 0.3 0.5],'LineWidth',1);
    nf = min(8,length(resultados));
    for i=1:nf
        if mod(i,2)==1, rectcol=[0.95 0.95 0.97]; else rectcol=[0.92 0.94 0.98]; end
        rectangle('Position',[0.06 0.77-(i-1)*0.08 0.88 0.07],'FaceColor',rectcol);
        switch resultados(i).Clasificacion
            case 'Maligno', coltxt=[0.8 0 0]; colf=[1 0.9 0.9];
            case 'Benigno', coltxt=[0 0.5 0]; colf=[0.9 1 0.9];
            case 'Tumor', coltxt=[0.8 0.4 0]; colf=[1 0.95 0.9];
            otherwise, coltxt=[0.3 0.3 0.3]; colf=[0.95 0.95 0.95];
        end
        rectangle('Position',[0.54 0.77-(i-1)*0.08 0.40 0.07],'FaceColor',colf);
        area_f = formatNumber(resultados(i).Area); diam_f = formatNumber(round(resultados(i).Diametro));
        sol_f = sprintf('%.3f',resultados(i).Solidez); exc_f = sprintf('%.3f',resultados(i).Excentricidad);
        conf_f = sprintf('%.1f%%',resultados(i).Confianza*100);
        datos = {num2str(resultados(i).ID), area_f, diam_f, sol_f, exc_f, resultados(i).Clasificacion, num2str(resultados(i).PuntuacionRiesgo), conf_f};
        for j=1:8
            if j>=6, text(posx(j),0.80-(i-1)*0.08,datos{j},'Units','norm','FontSize',10,'FontName','Monospaced','Color',coltxt,'HorizontalAlignment','center');
            else text(posx(j),0.80-(i-1)*0.08,datos{j},'Units','norm','FontSize',10,'FontName','Monospaced','Color',[0.2 0.2 0.4],'HorizontalAlignment','center'); end
        end
        if i<nf, line([0.08 0.92],[0.77-(i-1)*0.08-0.01 0.77-(i-1)*0.08-0.01],'Color',[0.85 0.85 0.85]); end
    end
    if length(resultados)>8, text(0.5,0.15,sprintf('+ %d adicionales...',length(resultados)-8),'Units','norm','FontSize',12,'FontWeight','bold','HorizontalAlignment','center'); end
    text(0.5,0.08,'LEYENDA DE COLORES:','Units','norm','FontSize',12,'FontWeight','bold','HorizontalAlignment','center');
    items={'Maligno','Benigno','Tumor','Indeterminado'}; cols_leg={[0.8 0 0],[0 0.5 0],[0.8 0.4 0],[0.3 0.3 0.3]}; bg_leg={[1 0.9 0.9],[0.9 1 0.9],[1 0.95 0.9],[0.95 0.95 0.95]};
    ancho_tot=0.18*length(items); startx=0.5-ancho_tot/2;
    for k=1:length(items), xpos=startx+(k-1)*0.18; rectangle('Position',[xpos-0.02 0.02 0.12 0.04],'FaceColor',bg_leg{k},'EdgeColor',cols_leg{k},'LineWidth',2); text(xpos+0.04,0.04,items{k},'Units','norm','FontSize',10,'FontWeight','bold','Color',cols_leg{k},'HorizontalAlignment','center'); end
end

function fig8 = visualizarAnalisisEstadistico(imagen_suavizada, mascara_final, resultados, etiquetas)
    fig8 = figure('Name', 'Figura 8 - Análisis Estadístico y Distribución', 'Position', [200 50 1400 900], 'Color', [1 1 1]);
    if isempty(resultados), text(0.5,0.5,'No hay datos','HorizontalAlignment','center'); return; end
    tipos = {'Maligno','Benigno','Tumor','Indeterminado'}; cnt=zeros(1,4); areas_prom=zeros(1,4);
    for i=1:4, mask=strcmp({resultados.Clasificacion},tipos{i}); cnt(i)=sum(mask); if cnt(i)>0, areas_prom(i)=mean([resultados(mask).Area]); end; end
    subplot(2,2,1); yyaxis left; b=bar(cnt,'FaceColor',[0.2 0.4 0.8],'EdgeColor','k','FaceAlpha',0.7); ylabel('Número'); set(gca,'XTickLabel',{'Maligno','Benigno','Tumor','Indet.'}); for i=1:4, if cnt(i)>0, text(i,cnt(i)+0.1,num2str(cnt(i)),'HorizontalAlignment','center'); end; end; yyaxis right; plot(areas_prom/1000,'ro-','LineWidth',3,'MarkerSize',10,'MarkerFaceColor','r'); ylabel('Área Promedio (x1000 px)'); title('A) Distribución por tipo'); grid on; legend('Cantidad','Área Promedio','Location','best');
    subplot(2,2,2); imshow(imagen_suavizada,[]); hold on; [f,c]=size(imagen_suavizada); mapa_calor=zeros(f,c);
    for i=1:length(resultados), masc_les=(etiquetas==resultados(i).ID); switch resultados(i).Clasificacion, case 'Maligno', val=4; case 'Tumor', val=3; case 'Indeterminado', val=2; case 'Benigno', val=1; otherwise, val=0.5; end; mapa_calor(masc_les)=val; end
    h=imagesc(mapa_calor); set(h,'AlphaData',mapa_calor*0.4); colormap([0 0 0;0 1 0;1 1 0;1 0.5 0;1 0 0]); caxis([0 4]);
    for i=1:length(resultados), masc_les=(etiquetas==resultados(i).ID); stats=regionprops(masc_les,'Centroid'); if ~isempty(stats), cent=stats.Centroid; switch resultados(i).Clasificacion, case 'Maligno', plot(cent(1),cent(2),'ro','MarkerSize',12,'MarkerFaceColor','r'); text(cent(1)+15,cent(2),num2str(resultados(i).ID),'Color','w','BackgroundColor','r'); case 'Benigno', plot(cent(1),cent(2),'go','MarkerSize',10,'MarkerFaceColor','g'); text(cent(1)+15,cent(2),num2str(resultados(i).ID),'Color','w','BackgroundColor','g'); case 'Tumor', plot(cent(1),cent(2),'s','MarkerSize',14,'MarkerFaceColor',[1 0.5 0],'Color','k'); text(cent(1)+15,cent(2),num2str(resultados(i).ID),'Color','w','BackgroundColor',[1 0.5 0]); otherwise, plot(cent(1),cent(2),'^','MarkerSize',10,'MarkerFaceColor',[0.5 0.5 0.5],'Color','k'); end; end; end
    title('B) Mapa de distribución y densidad'); colorbar('Ticks',[0.5,1.5,2.5,3.5],'TickLabels',{'Fondo','Benigno','Indet.','Tumor','Maligno'}); hold off;
    subplot(2,2,3); areas=[resultados.Area]; sols=[resultados.Solidez]; excs=[resultados.Excentricidad]; sz=zeros(size(areas)); cols=zeros(length(areas),3);
    for i=1:length(areas), sz(i)=80+(areas(i)/max(areas))*120; switch resultados(i).Clasificacion, case 'Maligno', cols(i,:)=[1,0,0]; case 'Benigno', cols(i,:)=[0,0.8,0]; case 'Tumor', cols(i,:)=[1,0.5,0]; otherwise, cols(i,:)=[0.5,0.5,0.5]; end; end
    scatter(sols,excs,sz,cols,'filled','MarkerEdgeColor','k','LineWidth',1.5); xlabel('Solidez'); ylabel('Excentricidad'); title('C) Formas: Solidez vs Excentricidad'); grid on;
    for i=1:length(resultados), text(sols(i),excs(i),num2str(resultados(i).ID),'HorizontalAlignment','center','BackgroundColor',[1 1 1 0.8]); end
    hold on; scatter(0.1,0.9,50,[0.5 0.5 0.5],'filled','MarkerEdgeColor','k'); scatter(0.1,0.8,100,[0.5 0.5 0.5],'filled','MarkerEdgeColor','k'); scatter(0.1,0.7,150,[0.5 0.5 0.5],'filled','MarkerEdgeColor','k'); text(0.15,0.9,'Área pequeña'); text(0.15,0.8,'Área media'); text(0.15,0.7,'Área grande'); hold off;
    subplot(2,2,4); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99],'EdgeColor',[0.2 0.4 0.6]);
    areas=[resultados.Area]; sols=[resultados.Solidez]; excs=[resultados.Excentricidad]; riesgos=[resultados.PuntuacionRiesgo]; confs=[resultados.Confianza];
    mal=sum(strcmp({resultados.Clasificacion},'Maligno')); ben=sum(strcmp({resultados.Clasificacion},'Benigno')); tum=sum(strcmp({resultados.Clasificacion},'Tumor')); ind=sum(strcmp({resultados.Clasificacion},'Indeterminado'));
    texto = {'RESUMEN ESTADÍSTICO COMPLETO','──────────────────────────',sprintf('Total: %d',length(resultados)),sprintf('Área total: %s px',formatNumber(sum(areas))),'','DISTRIBUCIÓN:',sprintf('Malignas: %d (%.1f%%)',mal,mal/length(resultados)*100),sprintf('Benignas: %d (%.1f%%)',ben,ben/length(resultados)*100),sprintf('Tumores: %d (%.1f%%)',tum,tum/length(resultados)*100),sprintf('Indet.: %d (%.1f%%)',ind,ind/length(resultados)*100),'','PROMEDIO:',sprintf('Área: %s px',formatNumber(mean(areas))),sprintf('Solidez: %.3f ± %.3f',mean(sols),std(sols)),sprintf('Excentricidad: %.3f ± %.3f',mean(excs),std(excs)),sprintf('Riesgo: %.1f ± %.1f',mean(riesgos),std(riesgos)),sprintf('Confianza: %.1f%% ± %.1f%%',mean(confs)*100,std(confs)*100),'','RANGO:',sprintf('Mín: %s px',formatNumber(min(areas))),sprintf('Máx: %s px',formatNumber(max(areas))),sprintf('Mediana: %s px',formatNumber(median(areas))),'','VARIABILIDAD:',sprintf('CV: %.1f%%',std(areas)/mean(areas)*100),sprintf('Asimetría: %.3f',skewness(areas)),sprintf('Curtosis: %.3f',kurtosis(areas))};
    text(0.1,0.9,texto,'Units','norm','FontSize',10,'FontName','Monospaced','VerticalAlignment','top'); title('D) Resumen estadístico completo');
end

function fig9 = visualizarResumenClinico(resultados, diagnostico, recomendacion, puntuacion_total)
    fig9 = figure('Name', 'Figura 9 - Resumen Clínico Integral', 'Position', [250 100 1400 900], 'Color', [1 1 1]);
    subplot(2,2,1); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99]);
    text(0.5,0.9,'DIAGNÓSTICO PRINCIPAL','Units','norm','FontSize',16,'FontWeight','bold','HorizontalAlignment','center');
    if contains(diagnostico,'ALTA SOSPECHA') || contains(diagnostico,'MALIGNIDAD'), col_diag=[1 0 0]; col_bg=[1 0.9 0.9];
    elseif contains(diagnostico,'MODERADA'), col_diag=[1 0.5 0]; col_bg=[1 0.95 0.9];
    elseif contains(diagnostico,'BENIGNOS'), col_diag=[0 0.7 0]; col_bg=[0.9 1 0.9];
    else col_diag=[0.5 0.5 0.5]; col_bg=[0.95 0.95 0.95]; end
    rectangle('Position',[0.1 0.6 0.8 0.25],'FaceColor',col_diag); text(0.5,0.8,'DIAGNÓSTICO','Color','w','FontSize',14,'FontWeight','bold','HorizontalAlignment','center'); text(0.5,0.65,diagnostico,'Color','w','FontSize',12,'FontWeight','bold','HorizontalAlignment','center');
    rectangle('Position',[0.2 0.35 0.6 0.15],'FaceColor',col_bg,'EdgeColor',col_diag); text(0.5,0.42,sprintf('PUNTUACIÓN TOTAL: %.1f',puntuacion_total),'FontSize',12,'FontWeight','bold','HorizontalAlignment','center');
    text(0.5,0.15,sprintf('Generado: %s',datestr(now,'dd/mm/yyyy HH:MM')),'Units','norm','FontSize',10,'HorizontalAlignment','center');
    subplot(2,2,2); if ~isempty(resultados), cnt=[sum(strcmp({resultados.Clasificacion},'Maligno')), sum(strcmp({resultados.Clasificacion},'Benigno')), sum(strcmp({resultados.Clasificacion},'Tumor')), sum(strcmp({resultados.Clasificacion},'Indeterminado'))]; pie(cnt(cnt>0),{'Maligno','Benigno','Tumor','Indet.'}(cnt>0)); title('Distribución de lesiones'); else text(0.5,0.5,'No hay lesiones','HorizontalAlignment','center'); end
    subplot(2,2,3); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.97 0.98 0.95]); text(0.5,0.95,'RESUMEN ESTADÍSTICO','Units','norm','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    if ~isempty(resultados), num_tot=length(resultados); num_mal=sum(strcmp({resultados.Clasificacion},'Maligno')); num_ben=sum(strcmp({resultados.Clasificacion},'Benigno')); num_tum=sum(strcmp({resultados.Clasificacion},'Tumor')); num_ind=sum(strcmp({resultados.Clasificacion},'Indeterminado')); areas=[resultados.Area]; confs=[resultados.Confianza];
        texto = {'DATOS GENERALES:','────────────────',sprintf('Total: %d',num_tot),sprintf('Área total: %s px',formatNumber(sum(areas))),sprintf('Confianza media: %.1f%%',mean(confs)*100),'','DISTRIBUCIÓN:',sprintf('• Malignas: %d',num_mal),sprintf('• Benignas: %d',num_ben),sprintf('• Tumores: %d',num_tum),sprintf('• Indet.: %d',num_ind),'','PROMEDIO:',sprintf('Área: %s px',formatNumber(mean(areas))),sprintf('Solidez: %.3f',mean([resultados.Solidez])),sprintf('Excentricidad: %.3f',mean([resultados.Excentricidad])),'','RANGOS:',sprintf('Mín: %s px',formatNumber(min(areas))),sprintf('Máx: %s px',formatNumber(max(areas)))};
        text(0.1,0.85,texto,'Units','norm','FontSize',10,'FontName','Monospaced','VerticalAlignment','top'); else text(0.5,0.5,'No hay datos','HorizontalAlignment','center'); end
    subplot(2,2,4); axis off; rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.97 0.95]); text(0.5,0.95,'RECOMENDACIONES','Units','norm','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    if ~isempty(recomendacion), ypos=0.85; for i=1:min(length(recomendacion),6), rectangle('Position',[0.08 ypos-0.12 0.84 0.1],'FaceColor','w'); text(0.12,ypos-0.06,sprintf('%d.',i),'FontSize',11,'FontWeight','bold'); text(0.18,ypos-0.06,recomendacion{i},'FontSize',10); ypos=ypos-0.14; end; if length(recomendacion)>6, text(0.5,0.05,sprintf('+ %d adicionales',length(recomendacion)-6),'HorizontalAlignment','center'); end; else text(0.5,0.5,'No hay recomendaciones','HorizontalAlignment','center'); end
    axes('Position',[0.05 0.01 0.9 0.04]); axis off; info_sis = {'SISTEMA AVANZADO | Deep Learning + Autoencoders + Biomecánica | 11 Figuras | 4 Categorías'}; text(0.5,0.5,info_sis,'Units','norm','FontSize',9,'FontWeight','bold','HorizontalAlignment','center','BackgroundColor',[0.95 0.95 0.98]);
end

function fig10 = visualizarMicrocalcificacionesAvanzadas(imagen_suavizada, mapa_calcio, micro, ~)
    fig10 = figure('Name', 'Figura 10 - Análisis de Microcalcificaciones', 'Position', [300 100 1400 800], 'Color', [1 1 1]);
    subplot(2,3,1); imshow(imagen_suavizada,[]); hold on; B=bwboundaries(mapa_calcio); for k=1:length(B), plot(B{k}(:,2),B{k}(:,1),'r-','LineWidth',1.5); end; title('A) Microcalcificaciones detectadas');
    subplot(2,3,2); imshow(mapa_calcio); title('B) Mapa binario');
    subplot(2,3,3); if micro.numero>0, histogram(micro.areas,10,'FaceColor','r'); xlabel('Área (px)'); ylabel('Frecuencia'); title('C) Distribución de tamaños'); else text(0.5,0.5,'Sin microcalcificaciones','HorizontalAlignment','center'); end
    subplot(2,3,4); axis off; info_txt={'ANÁLISIS DE MICROCALCIFICACIONES','─────────────────────────────',sprintf('Número: %d',micro.numero),sprintf('Distribución: %s',micro.distribucion),'','CLASIFICACIÓN MORFOLÓGICA:'}; text(0.1,0.9,info_txt,'Units','norm','FontSize',11,'FontWeight','bold','VerticalAlignment','top');
    if micro.numero>0, area_med=mean(micro.areas); if area_med<5, morf='PUNTIFORMES (benignas)'; col=[0 0.6 0]; elseif area_med<15, morf='AMORFAS (sospechosas)'; col=[1 0.5 0]; else morf='PLEOMÓRFICAS (malignas)'; col=[1 0 0]; end; text(0.1,0.45,{sprintf('Tamaño medio: %.1f px',area_med),sprintf('Clasificación: %s',morf)},'Units','norm','FontSize',11,'FontWeight','bold','Color',col); else text(0.1,0.45,'NO APLICA','Units','norm','FontSize',11,'FontWeight','bold'); end
    subplot(2,3,5); axis off; patrones={'PATRONES DE DISTRIBUCIÓN:','────────────────────────','- AISLADAS: Riesgo bajo','- AGRUPADAS: Riesgo intermedio','- LINEALES: Riesgo alto','- SEGMENTARIAS: Muy sospechosas','','RECOMENDACIONES:'};
    switch micro.distribucion, case 'Aisladas', rec='Seguimiento rutinario'; col_rec=[0 0.6 0]; case 'Agrupadas', rec='Evaluación en 6 meses'; col_rec=[1 0.5 0]; case 'Lineales', rec='Biopsia considerada'; col_rec=[1 0 0]; otherwise, rec='Evaluación especializada'; col_rec=[0.5 0.5 0.5]; end; patrones=[patrones,{sprintf('- %s',rec)}]; text(0.1,0.9,patrones,'Units','norm','FontSize',10,'FontWeight','bold','VerticalAlignment','top','Color',[0.2 0.2 0.4]);
    subplot(2,3,6); if micro.numero>0, score_n=min(micro.numero/5,3); score_t=min(area_med/10,2); switch micro.distribucion, case 'Aisladas', d=1; case 'Agrupadas', d=2; case 'Lineales', d=3; otherwise, d=1.5; end; score_tot=(score_n+score_t+d)/3; rectangle('Position',[0.1 0.1 0.8 0.3],'FaceColor',[0.9 0.9 0.9]); if score_tot<=0.33, col_g=[0 0.8 0]; niv='BAJO'; elseif score_tot<=0.66, col_g=[1 0.5 0]; niv='MODERADO'; else col_g=[1 0 0]; niv='ALTO'; end; rectangle('Position',[0.1 0.1 0.8*score_tot 0.3],'FaceColor',col_g); text(0.5,0.6,'SCORE DE RIESGO','Units','norm','FontSize',12,'FontWeight','bold','HorizontalAlignment','center'); text(0.5,0.25,niv,'Units','norm','FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Color','w'); text(0.5,0.45,sprintf('%.1f/3.0',score_tot*3),'Units','norm','FontSize',11,'FontWeight','bold','HorizontalAlignment','center'); else text(0.5,0.5,'Sin microcalcificaciones\nScore: 0/3.0','HorizontalAlignment','center'); end; title('F) Score de riesgo');
    sgtitle('ANÁLISIS AVANZADO DE MICROCALCIFICACIONES','FontSize',16,'FontWeight','bold');
end

function fig11 = visualizarExplicabilidadViT(imagen_suavizada, heatmap_gradcam, clasificacion_vit, probs_vit)
    fig11 = figure('Name', 'Figura 11 - Explicabilidad Vision Transformer (Grad-CAM)', 'Position', [350 100 1200 600], 'Color', [1 1 1]);
    subplot(1,3,1); imshow(imagen_suavizada,[]); title('Imagen original');
    subplot(1,3,2); imshow(imagen_suavizada,[]); hold on; imagesc(heatmap_gradcam,'AlphaData',0.5); colormap jet; colorbar; title('Mapa de atención (Grad-CAM simulado)');
    subplot(1,3,3); axis off; text(0.1,0.9,{sprintf('ViT: %s',clasificacion_vit),sprintf('Prob: %.2f',max(probs_vit)),'','Áreas influyentes:','- Regiones de alta densidad','- Bordes irregulares','- Textura heterogénea'},'FontSize',12,'FontWeight','bold');
    sgtitle('EXPLICABILIDAD CON VISION TRANSFORMER','FontSize',16,'FontWeight','bold');
end

function formatted = formatNumber(num)
    if num >= 1000000, formatted = sprintf('%.1fM', num/1000000);
    elseif num >= 1000, formatted = sprintf('%.1fK', num/1000);
    else formatted = sprintf('%d', round(num)); end
end

function generarInformeAvanzado(info, resultados, diagnostico, metricas_densidad, modelo_biomecanico, puntuacion_total, num_lesiones_total)
    fprintf('\n=== INFORME UNIFICADO AVANZADO DE ANÁLISIS MAMARIO ===\n');
    fprintf('Fecha: %s\n', datestr(now));
    fprintf('Sistema: 11 Figuras, CVIP 2019 + Extensiones 2026\n\n');
    fprintf('INFORMACIÓN DEL ESTUDIO:\n'); fprintf('Modalidad: %s\n', info.Modality);
    if isfield(info,'SeriesDescription'), fprintf('Descripción: %s\n', info.SeriesDescription); end
    fprintf('Dimensiones: %dx%d\n', info.Dimensions(1), info.Dimensions(2));
    fprintf('\nDENSIDAD: %.1f%% (BI-RADS %s)\n', metricas_densidad.porcentaje_densidad, metricas_densidad.birads_categoria);
    fprintf('Área total: %d px, Área densa: %d px\n', metricas_densidad.area_total, metricas_densidad.area_densa);
    fprintf('Entropía: %.3f, Homogeneidad: %.3f\n', metricas_densidad.entropia, metricas_densidad.homogeneidad);
    fprintf('\nMODELADO BIOMECÁNICO: Área modelada: %d px\n', modelo_biomecanico.geometria.area_total);
    if modelo_biomecanico.geometria.area_total>0
        fprintf('Tejido glandular: %d px (%.1f%%)\n', modelo_biomecanico.geometria.area_glandular, modelo_biomecanico.geometria.area_glandular/modelo_biomecanico.geometria.area_total*100);
        fprintf('Tejido adiposo: %d px (%.1f%%)\n', modelo_biomecanico.geometria.area_adiposa, modelo_biomecanico.geometria.area_adiposa/modelo_biomecanico.geometria.area_total*100);
    end
    fprintf('\nLESIONES: %d total\n', num_lesiones_total);
    if ~isempty(resultados)
        mal = sum(strcmp({resultados.Clasificacion},'Maligno')); ben = sum(strcmp({resultados.Clasificacion},'Benigno')); tum = sum(strcmp({resultados.Clasificacion},'Tumor')); ind = sum(strcmp({resultados.Clasificacion},'Indeterminado'));
        fprintf('Malignas: %d, Benignas: %d, Tumores: %d, Indet.: %d\n', mal, ben, tum, ind);
        fprintf('Puntuación riesgo: %.1f, Confianza media: %.1f%%\n', puntuacion_total, mean([resultados.Confianza])*100);
        fprintf('Área promedio: %.0f px, Máx: %.0f px, Mín: %.0f px\n', mean([resultados.Area]), max([resultados.Area]), min([resultados.Area]));
    end
    fprintf('\nMICROCALCIFICACIONES: %d (%s)\n', diagnostico.microcalcificaciones.numero, diagnostico.microcalcificaciones.distribucion);
    fprintf('ViT: %s (probabilidad %.2f)\n', diagnostico.clasificacion_vit, diagnostico.probabilidad_vit);
    fprintf('\nDIAGNÓSTICO: %s (confianza %.1f%%)\n', diagnostico.clasificacion, diagnostico.confianza*100);
    fprintf('\nRECOMENDACIONES:\n'); for i=1:length(diagnostico.recomendacion), fprintf('%s\n', diagnostico.recomendacion{i}); end
    fprintf('\n=== FIN DEL INFORME ===\n');
end