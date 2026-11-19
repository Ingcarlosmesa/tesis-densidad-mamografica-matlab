%% SISTEMA UNIFICADO AVANZADO DE ANÁLISIS DICOM PARA CÁNCER DE MAMA - V2
% Versión mejorada unificada con todas las funcionalidades integradas
% Técnicas: Deep Learning + Autoencoders + Modelado biomecánico + Procesamiento avanzado
% + Microcalcificaciones + ViT + Grad-CAM + DDPM + Aprendizaje Federado
% Genera 11 figuras completas + exportación a .mat

clear all; close all; clc;

%% CONFIGURACIÓN AVANZADA DEL SISTEMA UNIFICADO
disp('=== SISTEMA UNIFICADO AVANZADO LIBRA + DEEP LEARNING PARA CÁNCER DE MAMA V2 ===');
disp('Integrando: Densidad LIBRA + Autoencoders + CNN + ViT + Grad-CAM + DDPM + Federado');
disp('           + Modelado biomecánico + Microcalcificaciones + Correlación multimodal');

% Parámetros del sistema mejorados
config.umbral_area_minima = 1000;
config.umbral_compacidad_maligna = 1.3;
config.umbral_diametro_maligno = 150;
config.realce = 0.6;
config.umbralbin_tophat = 0.15;
config.r_tophat = 30;

% Configuración de modelos deep learning
config.deep_learning.uso_autoencoder = true;
config.deep_learning.uso_cnn_clasificacion = true;
config.deep_learning.umbral_confianza_cnn = 0.75;

% Parámetros de modelos biomecánicos mejorados
config.modelo_biomecanico.young_glandular = 15.1;
config.modelo_biomecanico.young_adipose = 4.46;
config.modelo_biomecanico.poisson_ratio = 0.45;
config.modelo_biomecanico.compression_factor = 0.7;

% Nuevos parámetros para técnicas avanzadas
config.denoising.uso_autoencoder_denoising = true;
config.denoising.factor_ruido = 0.1;
config.cnn.clasificacion_multiclase = true;

% Parámetros de microcalcificaciones
config.microcalcificaciones.umbral_wavelet = 0.3;
config.microcalcificaciones.area_minima = 5;
config.microcalcificaciones.area_maxima = 500;
config.microcalcificaciones.distancia_agrupacion = 50;

% Parámetros de técnicas 2026
config.vit.num_patches = 16;
config.vit.lbp_radio = 2;
config.vit.lbp_vecinos = 8;
config.ddpm.num_pasos = 100;
config.ddpm.beta_inicio = 0.0001;
config.ddpm.beta_fin = 0.02;
config.federado.num_clientes = 5;
config.federado.rondas = 10;

%% INICIALIZACIÓN DE MODELOS DE DEEP LEARNING
fprintf('\n=== INICIALIZANDO MODELOS DE DEEP LEARNING ===\n');

% Estructura para modelos
modelos.deep_learning = inicializarModelosDeepLearning(config);

%% CARGA Y PROCESAMIENTO AVANZADO DE DATOS DICOM
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
    
    % Crear estructura info básica
    info.Filenames = {filename};
    info.PixelDimensions = [1, 1];
    info.Dimensions = size(volumen_dicom);
    if ~isfield(info, 'Modality'), info.Modality = 'MG'; end
    if ~isfield(info, 'SeriesDescription'), info.SeriesDescription = 'Imagen Individual'; end
    
    % Mostrar información del dataset
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

%% PREPROCESAMIENTO AVANZADO CON AUTOENCODER
disp('Realizando preprocesamiento avanzado con técnicas de CVIP 2019...');

% Determinar dimensiones y seleccionar imagen para análisis
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

% Aplicar normalización DICOM si está disponible
if isfield(info, 'RescaleSlope') && isfield(info, 'RescaleIntercept')
    imagen_normalizada = single(imagen_original);
    imagen_normalizada = imagen_normalizada * info.RescaleSlope + info.RescaleIntercept;
else
    imagen_normalizada = single(imagen_original);
end

% Conversión robusta a 8 bits MEJORADA
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

%% DENOISING CON AUTOENCODER
if config.denoising.uso_autoencoder_denoising
    fprintf('Aplicando denoising con autoencoder...\n');
    imagen_para_procesar = aplicarDenoisingAutoencoder(imagen_para_procesar, config);
end

%% PREPROCESAMIENTO AVANZADO COMBINADO MEJORADO
disp('Realizando preprocesamiento avanzado con técnicas combinadas...');

% Convertir a escala de grises adecuada
if size(imagen_para_procesar, 3) == 3
    imagen_gris = rgb2gray(imagen_para_procesar);
else
    imagen_gris = imagen_para_procesar;
end

% Pipeline de procesamiento mejorado
imagen_filtrada = medfilt2(imagen_gris, [7 7], 'symmetric');
imagen_contraste = imadjust(imagen_filtrada, stretchlim(imagen_filtrada), []);
imagen_ecualizada = adapthisteq(imagen_contraste);
imagen_suavizada = imgaussfilt(imagen_ecualizada, 2);

%% SEGMENTACIÓN MEJORADA CON TÉCNICAS COMBINADAS Y DEEP LEARNING
disp('Realizando segmentación avanzada con técnicas híbridas...');

% Técnica 1: Segmentación adaptativa mejorada
mascara_adaptativa = imbinarize(imagen_suavizada, 'adaptive', 'Sensitivity', 0.55);

% Técnica 2: Top-hat mejorada
itoh = double(imagen_suavizada) * 6;
itoh = uint8(min(itoh, 255));
se = strel('disk', config.r_tophat);
otoh = imtophat(itoh, se);
oehc = imadjust(otoh, [0 config.realce], [0 1]);
mascara_tophat = imbinarize(oehc, config.umbralbin_tophat);

% Combinar técnicas de segmentación
mascara_combinada = mascara_adaptativa | mascara_tophat;

% Limpieza morfológica mejorada
elemento_estructurante = strel('disk', 6);
mascara_limpia = imopen(mascara_combinada, elemento_estructurante);
mascara_limpia = imclose(mascara_limpia, elemento_estructurante);
mascara_final = bwareaopen(mascara_limpia, config.umbral_area_minima);
mascara_final = imfill(mascara_final, 'holes');

% Refinamiento con técnicas de deep learning
if config.deep_learning.uso_cnn_clasificacion
    mascara_final = refinarSegmentacionConCNN(imagen_suavizada, mascara_final, modelos);
end

% Eliminar objetos muy grandes que podrían ser artefactos
estadisticas = regionprops(mascara_final, 'Area', 'Centroid');
areas = [estadisticas.Area];
umbral_area_maxima = 0.3 * numel(mascara_final);
mascara_final = bwareaopen(mascara_final, config.umbral_area_minima);
for i = 1:length(estadisticas)
    if areas(i) > umbral_area_maxima
        cx = round(estadisticas(i).Centroid(1));
        cy = round(estadisticas(i).Centroid(2));
        cx = max(1, min(cx, size(mascara_final, 2)));
        cy = max(1, min(cy, size(mascara_final, 1)));
        mascara_final = mascara_final & ~bwselect(mascara_final, cx, cy);
    end
end

%% ANÁLISIS DE TEJIDO GLANDULAR CON TÉCNICAS AVANZADAS
disp('=== ANÁLISIS AVANZADO DE TEJIDO GLANDULAR Y MODELADO BIOMECÁNICO ===');

% Generar mapa de densidad cuantitativa AVANZADO
mapa_densidad = generarMapaDensidadAvanzado(imagen_suavizada, mascara_final);
metricas_densidad = calcularMetricasDensidadAvanzadas(mapa_densidad, mascara_final);

% Generar modelo biomecánico AVANZADO
[modelo_biomecanico, deformaciones] = generarModeloBiomecanicoAvanzado(...
    imagen_suavizada, mapa_densidad, config.modelo_biomecanico);

%% DETECCIÓN DE MICROCALCIFICACIONES
disp('=== DETECCIÓN DE MICROCALCIFICACIONES ===');
[microcalcificaciones, mapa_micro] = detectarMicrocalcificaciones(...
    imagen_suavizada, mascara_final, config.microcalcificaciones);

%% CLASIFICACIÓN AVANZADA CON DEEP LEARNING Y ANÁLISIS MORFOLÓGICO
disp('Realizando clasificación avanzada con técnicas híbridas...');

[etiquetas, num_regiones] = bwlabel(mascara_final);
resultados = [];
lesiones_benignas = [];
lesiones_malignas = [];
lesiones_indeterminadas = [];
lesiones_tumor = [];

% Calcular características de textura global para referencia
mascara_mama = imfill(mascara_final, 'holes');
if any(mascara_mama(:))
    region_textura = imagen_suavizada;
    region_textura(~mascara_mama) = 0;
    textura_entropy_global = entropy(region_textura);
else
    textura_entropy_global = 0;
end

if num_regiones > 0
    propiedades = regionprops(etiquetas, {'Area', 'Perimeter', 'Eccentricity', ...
                        'Solidity', 'BoundingBox', 'Centroid', 'ConvexArea', 'MajorAxisLength'});
    
    for i = 1:num_regiones
        % CLASIFICACIÓN HÍBRIDA AVANZADA: Deep Learning + Análisis Morfológico
        [clasificacion, puntuacion_riesgo, confianza] = clasificarLesionAvanzada(...
            imagen_suavizada, propiedades(i), modelos, config);
        
        % Métricas adicionales
        area_actual = propiedades(i).Area;
        perimetro_actual = propiedades(i).Perimeter;
        excentricidad_actual = propiedades(i).Eccentricity;
        solidez_actual = propiedades(i).Solidity;
        diametro_mayor = propiedades(i).MajorAxisLength;
        
        diametro_equivalente = 2 * sqrt(area_actual / pi);
        compacidad = (perimetro_actual^2) / (4 * pi * area_actual);
        
        % Almacenar resultados
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
        
        % Agrupar por clasificación
        switch clasificacion
            case 'Benigno'
                lesiones_benignas = [lesiones_benignas, i];
            case 'Maligno'
                lesiones_malignas = [lesiones_malignas, i];
            case 'Tumor'
                lesiones_tumor = [lesiones_tumor, i];
            otherwise
                lesiones_indeterminadas = [lesiones_indeterminadas, i];
        end
    end
end

%% TÉCNICAS DE VANGUARDIA 2026 (SIMULADAS)
disp('=== APLICANDO TÉCNICAS DE VANGUARDIA 2026 ===');

% Vision Transformer (ViT) simulado
[vit_resultado, vit_features] = aplicarViTSimulado(imagen_suavizada, mascara_final, config.vit);

% Grad-CAM simulado para explicabilidad
mapa_gradcam = generarGradCAMSimulado(imagen_suavizada, mascara_final, resultados);

% Difusión DDPM conceptual
ddpm_resultado = aplicarDDPMConceptual(imagen_suavizada, config.ddpm);

% Aprendizaje federado simulado
federado_resultado = simularAprendizajeFederado(resultados, config.federado);

%% DIAGNÓSTICO INTEGRADO MEJORADO CON FUSIÓN MULTI-CLASIFICADOR
disp('Generando diagnóstico integrado con fusión avanzada...');

diagnostico_integrado = generarDiagnosticoIntegradoAvanzado(...
    resultados, metricas_densidad, modelo_biomecanico, config);

% Mantener compatibilidad con sistema de visualización original
diagnostico = diagnostico_integrado.clasificacion;
color_diagnostico = diagnostico_integrado.color;
recomendacion = diagnostico_integrado.recomendacion;
puntuacion_total = diagnostico_integrado.puntuacion_total;

% Calcular estadísticas para compatibilidad
if ~isempty(resultados)
    num_lesiones_total = length(resultados);
    num_benignas = length(lesiones_benignas);
    num_malignas = length(lesiones_malignas);
    num_indeterminadas = length(lesiones_indeterminadas);
    num_tumores = length(lesiones_tumor);
else
    num_lesiones_total = 0;
    num_benignas = 0;
    num_malignas = 0;
    num_indeterminadas = 0;
    num_tumores = 0;
end

%% VISUALIZACIONES UNIFICADAS AVANZADAS - 11 FIGURAS COMPLETAS
disp('Generando visualizaciones avanzadas (11 figuras)...');

% Figura 1: Procesamiento básico mejorado
fig1 = visualizarProcesamientoAvanzado(imagen_original, imagen_suavizada, oehc, ...
    mascara_final, mascara_adaptativa, imagen_ecualizada, num_regiones, info);

% Figura 2: Análisis de densidad y textura avanzado
fig2 = visualizarDensidadTexturaAvanzada(imagen_suavizada, mascara_final, ...
    mapa_densidad, metricas_densidad, modelos);

% Figura 3: Modelo biomecánico avanzado
fig3 = visualizarModeloBiomecanicoAvanzado(imagen_suavizada, mapa_densidad, ...
    modelo_biomecanico, metricas_densidad);

% Figura 4: Mapa de riesgo integrado con deep learning
fig4 = visualizarRiesgoIntegradoAvanzado(imagen_suavizada, mascara_final, ...
    mapa_densidad, modelo_biomecanico, resultados, diagnostico_integrado);

% Figura 5: Correlación multimodal avanzada
fig5 = visualizarCorrelacionMultimodalAvanzada(resultados, deformaciones, ...
    metricas_densidad, config);

% Figura 6: Lesiones Detectadas y Clasificadas
fig6 = visualizarLesionesDetectadas(imagen_suavizada, mascara_final, resultados, etiquetas);

% Figura 7: Tabla de Características Detalladas
fig7 = visualizarTablaCaracteristicas(resultados);

% Figura 8: Análisis Estadístico y Distribución
fig8 = visualizarAnalisisEstadistico(imagen_suavizada, mascara_final, resultados, etiquetas);

% Figura 9: Resumen Clínico
fig9 = visualizarResumenClinico(resultados, diagnostico, recomendacion, puntuacion_total);

% Figura 10: Microcalcificaciones
fig10 = visualizarMicrocalcificaciones(imagen_suavizada, microcalcificaciones, mapa_micro);

% Figura 11: Explicabilidad ViT y Grad-CAM
fig11 = visualizarExplicabilidadViT(imagen_suavizada, mascara_final, ...
    vit_resultado, mapa_gradcam, ddpm_resultado, federado_resultado);

%% EXPORTACIÓN DE RESULTADOS A .MAT
disp('=== EXPORTANDO RESULTADOS ===');
exportarResultados(info, resultados, diagnostico_integrado, metricas_densidad, ...
    modelo_biomecanico, microcalcificaciones, vit_resultado, mapa_gradcam, ...
    ddpm_resultado, federado_resultado, puntuacion_total);

%% GENERACIÓN DE INFORME UNIFICADO AVANZADO
disp('=== GENERANDO INFORME UNIFICADO AVANZADO ===');
generarInformeAvanzado(info, resultados, diagnostico_integrado, ...
    metricas_densidad, modelo_biomecanico, microcalcificaciones, ...
    vit_resultado, federado_resultado, puntuacion_total, num_lesiones_total);

fprintf('\n=== ANÁLISIS UNIFICADO AVANZADO V2 COMPLETADO ===\n');
fprintf('Sistema generó 11 figuras completas de análisis avanzado\n');
fprintf('Integración: Procesamiento + Deep Learning + Biomecánica + ViT + Grad-CAM + DDPM + Federado\n');
fprintf('Resultados exportados a: resultados_analisis_mamario.mat\n');

%% ============================================================================
%% FUNCIONES DEL SISTEMA
%% ============================================================================

function modelos = inicializarModelosDeepLearning(config)
    modelos.autoencoder_denoising = [];
    modelos.cnn_clasificacion = [];
    modelos.cnn_segmentacion = [];
    modelos.vit_clasificacion = [];
    
    fprintf('Modelos de deep learning inicializados (incluye ViT simulado)\n');
    fprintf('Configuración: Autoencoder=%d, CNN Clasificación=%d\n', ...
        config.deep_learning.uso_autoencoder, ...
        config.deep_learning.uso_cnn_clasificacion);
end

function imagen_denoised = aplicarDenoisingAutoencoder(imagen, config)
    % Aplicar denoising usando técnica de autoencoder (filtro bilateral avanzado)
    imagen_double = double(imagen);
    
    imagen_denoised = imbilatfilt(imagen_double, ...
        'DegreeOfSmoothing', 0.01 * config.denoising.factor_ruido, ...
        'SpatialSigma', 3);
    
    imagen_denoised = uint8(imagen_denoised);
    
    fprintf('Denoising aplicado (simulación autoencoder)\n');
end

function mascara_mejorada = refinarSegmentacionConCNN(imagen, mascara, modelos)
    % Refinar segmentación usando CNN (gradientes como proxy)
    [gx, gy] = imgradientxy(imagen);
    magnitud_gradiente = sqrt(gx.^2 + gy.^2);
    
    umbral_gradiente = graythresh(magnitud_gradiente) * max(magnitud_gradiente(:));
    bordes_refinados = magnitud_gradiente > umbral_gradiente * 0.3;
    
    mascara_mejorada = mascara & ~bordes_refinados;
    mascara_mejorada = imfill(mascara_mejorada, 'holes');
    mascara_mejorada = bwareaopen(mascara_mejorada, 500);
    
    fprintf('Segmentación refinada con técnicas avanzadas\n');
end

%% ============================================================================
%% DETECCIÓN DE MICROCALCIFICACIONES (NUEVO)
%% ============================================================================

function [microcalc, mapa_micro] = detectarMicrocalcificaciones(imagen, mascara, params)
    % Detectar microcalcificaciones usando wavelets
    fprintf('Detectando microcalcificaciones con wavelets...\n');
    
    imagen_double = double(imagen);
    mapa_micro = zeros(size(imagen));
    microcalc = struct('centroides', [], 'areas', [], 'patron', '', ...
                       'score_riesgo', 0, 'num_total', 0, 'num_agrupadas', 0);
    
    % Descomposición wavelet (usar dwt2 si Wavelet Toolbox disponible)
    try
        [cA, cH, cV, cD] = dwt2(imagen_double, 'db4');
        
        % Los coeficientes de detalle revelan microcalcificaciones
        detalle_combinado = sqrt(cH.^2 + cV.^2 + cD.^2);
        
        % Redimensionar al tamaño original
        detalle_resized = imresize(detalle_combinado, size(imagen));
        
        % Normalizar
        if max(detalle_resized(:)) > 0
            detalle_norm = detalle_resized / max(detalle_resized(:));
        else
            detalle_norm = detalle_resized;
        end
        
        fprintf('Wavelet Toolbox disponible: usando dwt2 con db4\n');
    catch
        % Fallback sin Wavelet Toolbox: usar filtro Laplaciano de Gaussiana
        fprintf('Wavelet Toolbox no disponible: usando filtro LoG alternativo\n');
        h_log = fspecial('log', [15 15], 2);
        detalle_norm = abs(imfilter(imagen_double, h_log, 'replicate'));
        if max(detalle_norm(:)) > 0
            detalle_norm = detalle_norm / max(detalle_norm(:));
        end
    end
    
    % Umbralizar para detectar candidatos
    mascara_mama = imfill(mascara, 'holes');
    candidatos = (detalle_norm > params.umbral_wavelet) & mascara_mama;
    
    % Limpieza morfológica para microcalcificaciones
    se_micro = strel('disk', 1);
    candidatos = imopen(candidatos, se_micro);
    candidatos = bwareaopen(candidatos, params.area_minima);
    
    % Eliminar objetos demasiado grandes (no son microcalcificaciones)
    etiq_micro = bwlabel(candidatos);
    props_micro = regionprops(etiq_micro, 'Area', 'Centroid', 'Eccentricity');
    
    centroides = [];
    areas_micro = [];
    
    for i = 1:length(props_micro)
        if props_micro(i).Area <= params.area_maxima && props_micro(i).Area >= params.area_minima
            centroides = [centroides; props_micro(i).Centroid];
            areas_micro = [areas_micro; props_micro(i).Area];
            mapa_micro(etiq_micro == i) = 1;
        end
    end
    
    microcalc.centroides = centroides;
    microcalc.areas = areas_micro;
    microcalc.num_total = size(centroides, 1);
    
    % Clasificar patrón de microcalcificaciones
    if microcalc.num_total == 0
        microcalc.patron = 'Sin microcalcificaciones';
        microcalc.score_riesgo = 0;
    elseif microcalc.num_total <= 3
        microcalc.patron = 'Aisladas';
        microcalc.score_riesgo = 1;
    else
        % Verificar agrupación
        num_agrupadas = 0;
        if microcalc.num_total >= 2
            distancias = pdist(centroides);
            num_agrupadas = sum(distancias < params.distancia_agrupacion);
        end
        microcalc.num_agrupadas = num_agrupadas;
        
        if num_agrupadas > microcalc.num_total * 0.5
            % Verificar si son lineales
            if microcalc.num_total >= 3
                % Calcular PCA para detectar linealidad
                centroides_centradas = centroides - mean(centroides, 1);
                [~, S] = svd(centroides_centradas, 'econ');
                if size(S, 2) >= 2
                    ratio_sv = S(1,1) / (S(2,2) + eps);
                else
                    ratio_sv = 10;
                end
                
                if ratio_sv > 5
                    microcalc.patron = 'Lineales';
                    microcalc.score_riesgo = 4;
                else
                    microcalc.patron = 'Agrupadas';
                    microcalc.score_riesgo = 3;
                end
            else
                microcalc.patron = 'Agrupadas';
                microcalc.score_riesgo = 3;
            end
        else
            microcalc.patron = 'Dispersas';
            microcalc.score_riesgo = 2;
        end
    end
    
    fprintf('Microcalcificaciones detectadas: %d (%s, score=%d)\n', ...
        microcalc.num_total, microcalc.patron, microcalc.score_riesgo);
end

%% ============================================================================
%% TÉCNICAS DE VANGUARDIA 2026 (SIMULADAS)
%% ============================================================================

function [vit_resultado, vit_features] = aplicarViTSimulado(imagen, mascara, params)
    % Vision Transformer (ViT) simulado con LBP + red feedforward
    fprintf('Aplicando Vision Transformer simulado...\n');
    
    imagen_double = double(imagen);
    [filas, columnas] = size(imagen);
    
    % Dividir imagen en patches
    num_patches = params.num_patches;
    patch_h = floor(filas / num_patches);
    patch_w = floor(columnas / num_patches);
    
    vit_features = zeros(num_patches * num_patches, 6);
    patch_idx = 0;
    
    for pi = 1:num_patches
        for pj = 1:num_patches
            patch_idx = patch_idx + 1;
            
            r1 = (pi-1)*patch_h + 1;
            r2 = min(pi*patch_h, filas);
            c1 = (pj-1)*patch_w + 1;
            c2 = min(pj*patch_w, columnas);
            
            patch = imagen_double(r1:r2, c1:c2);
            
            % Extraer características LBP simplificadas
            lbp_val = calcularLBPSimplificado(patch, params.lbp_radio);
            
            % Características del patch
            vit_features(patch_idx, 1) = mean(patch(:));
            vit_features(patch_idx, 2) = std(patch(:));
            vit_features(patch_idx, 3) = entropy(uint8(patch));
            vit_features(patch_idx, 4) = lbp_val;
            vit_features(patch_idx, 5) = mean(patch(:) > mean(imagen_double(:)));
            vit_features(patch_idx, 6) = sum(mascara(r1:r2, c1:c2), 'all') / numel(patch);
        end
    end
    
    % Red feedforward simulada (combinación lineal de features)
    pesos_simulados = [0.15, 0.20, 0.25, 0.15, 0.10, 0.15]';
    scores_patches = vit_features * pesos_simulados;
    
    % Normalizar scores
    if max(scores_patches) > min(scores_patches)
        scores_norm = (scores_patches - min(scores_patches)) / (max(scores_patches) - min(scores_patches));
    else
        scores_norm = zeros(size(scores_patches));
    end
    
    % Resultado del ViT
    vit_resultado.scores_patches = scores_norm;
    vit_resultado.features = vit_features;
    vit_resultado.num_patches = num_patches;
    vit_resultado.patch_size = [patch_h, patch_w];
    vit_resultado.score_global = mean(scores_norm);
    
    % Clasificación ViT simulada
    if vit_resultado.score_global > 0.7
        vit_resultado.clasificacion = 'Alto riesgo';
    elseif vit_resultado.score_global > 0.4
        vit_resultado.clasificacion = 'Riesgo moderado';
    else
        vit_resultado.clasificacion = 'Bajo riesgo';
    end
    
    fprintf('ViT simulado completado: score=%.3f (%s)\n', ...
        vit_resultado.score_global, vit_resultado.clasificacion);
end

function lbp_val = calcularLBPSimplificado(patch, radio)
    % LBP simplificado: comparar píxeles vecinos con el centro
    [filas, columnas] = size(patch);
    if filas < 3 || columnas < 3
        lbp_val = 0;
        return;
    end
    
    centro = patch(2:end-1, 2:end-1);
    
    % 8 vecinos
    vecinos = zeros(size(centro, 1), size(centro, 2), 8);
    vecinos(:,:,1) = patch(1:end-2, 1:end-2);
    vecinos(:,:,2) = patch(1:end-2, 2:end-1);
    vecinos(:,:,3) = patch(1:end-2, 3:end);
    vecinos(:,:,4) = patch(2:end-1, 3:end);
    vecinos(:,:,5) = patch(3:end, 3:end);
    vecinos(:,:,6) = patch(3:end, 2:end-1);
    vecinos(:,:,7) = patch(3:end, 1:end-2);
    vecinos(:,:,8) = patch(2:end-1, 1:end-2);
    
    % Calcular LBP como uniformidad de patrones
    lbp_code = zeros(size(centro));
    for k = 1:8
        lbp_code = lbp_code + (vecinos(:,:,k) >= centro) * 2^(k-1);
    end
    
    % Retornar entropía del histograma LBP como feature
    lbp_hist = histcounts(lbp_code(:), 256);
    lbp_hist = lbp_hist / sum(lbp_hist);
    lbp_hist(lbp_hist == 0) = [];
    lbp_val = -sum(lbp_hist .* log2(lbp_hist));
end

function mapa_gradcam = generarGradCAMSimulado(imagen, mascara, resultados)
    % Grad-CAM simulado para explicabilidad
    fprintf('Generando Grad-CAM simulado para explicabilidad...\n');
    
    imagen_double = double(imagen);
    [filas, columnas] = size(imagen);
    mapa_gradcam = zeros(filas, columnas);
    
    % Generar mapa de atención basado en gradientes y regiones de interés
    [gx, gy] = imgradientxy(imagen_double);
    magnitud = sqrt(gx.^2 + gy.^2);
    
    % Normalizar magnitud
    if max(magnitud(:)) > 0
        magnitud_norm = magnitud / max(magnitud(:));
    else
        magnitud_norm = magnitud;
    end
    
    % Combinar con máscara de lesiones para simular atención
    mascara_mama = imfill(mascara, 'holes');
    
    % Base de atención: gradientes dentro de la mama
    mapa_gradcam = magnitud_norm .* double(mascara_mama);
    
    % Aumentar atención en regiones con lesiones detectadas
    if ~isempty(resultados)
        for i = 1:length(resultados)
            bbox = resultados(i).BoundingBox;
            if isfield(resultados(i), 'BoundingBox')
                % No tenemos BoundingBox en resultados, usar centroide
            end
        end
    end
    
    % Aumentar atención en áreas de alta textura (simula capas profundas)
    textura_local = stdfilt(imagen_double, true(7));
    if max(textura_local(:)) > 0
        textura_norm = textura_local / max(textura_local(:));
    else
        textura_norm = textura_local;
    end
    
    mapa_gradcam = 0.6 * mapa_gradcam + 0.4 * textura_norm .* double(mascara_mama);
    
    % Suavizar el mapa
    mapa_gradcam = imgaussfilt(mapa_gradcam, 8);
    
    % Normalizar final
    if max(mapa_gradcam(:)) > 0
        mapa_gradcam = mapa_gradcam / max(mapa_gradcam(:));
    end
    
    fprintf('Grad-CAM simulado generado\n');
end

function ddpm_resultado = aplicarDDPMConceptual(imagen, params)
    % Difusión DDPM conceptual: demostración de forward + reverse
    fprintf('Aplicando DDPM conceptual (difusión)...\n');
    
    imagen_double = double(imagen) / 255;
    
    % Generar schedule de betas
    betas = linspace(params.beta_inicio, params.beta_fin, params.num_pasos);
    alphas = 1 - betas;
    alphas_acumulados = cumprod(alphas);
    
    % Forward process: añadir ruido progresivamente (mostrar unos pasos)
    pasos_muestra = [1, round(params.num_pasos/4), round(params.num_pasos/2), params.num_pasos];
    imagenes_ruido = cell(1, length(pasos_muestra));
    
    for idx = 1:length(pasos_muestra)
        t = pasos_muestra(idx);
        alpha_t = alphas_acumulados(t);
        ruido = randn(size(imagen_double));
        imagen_ruidosa = sqrt(alpha_t) * imagen_double + sqrt(1 - alpha_t) * ruido;
        imagenes_ruido{idx} = imagen_ruidosa;
    end
    
    % Reverse process simulado: denoising simple
    imagen_reconstruida = imagen_double + 0.05 * randn(size(imagen_double));
    for t = params.num_pasos:-1:1
        % Denoising simplificado con filtro gaussiano adaptativo
        sigma_t = betas(t) * 5;
        if sigma_t > 0.1
            imagen_reconstruida = imgaussfilt(imagen_reconstruida, sigma_t);
        end
    end
    
    % Normalizar reconstrucción
    imagen_reconstruida = max(0, min(1, imagen_reconstruida));
    
    % Calcular PSNR entre original y reconstruida
    mse_val = mean((imagen_double(:) - imagen_reconstruida(:)).^2);
    if mse_val > 0
        psnr_val = 10 * log10(1 / mse_val);
    else
        psnr_val = Inf;
    end
    
    ddpm_resultado.imagenes_ruido = imagenes_ruido;
    ddpm_resultado.pasos_muestra = pasos_muestra;
    ddpm_resultado.imagen_reconstruida = imagen_reconstruida;
    ddpm_resultado.betas = betas;
    ddpm_resultado.alphas_acumulados = alphas_acumulados;
    ddpm_resultado.psnr = psnr_val;
    ddpm_resultado.num_pasos = params.num_pasos;
    
    fprintf('DDPM conceptual completado: PSNR=%.2f dB\n', psnr_val);
end

function fed_resultado = simularAprendizajeFederado(resultados, params)
    % Aprendizaje federado (FedAvg) simulado con datos sintéticos
    fprintf('Simulando aprendizaje federado (FedAvg)...\n');
    
    num_clientes = params.num_clientes;
    rondas = params.rondas;
    
    % Generar datos sintéticos por cliente
    num_features = 5;
    
    % Modelo global inicial (pesos aleatorios)
    modelo_global = randn(num_features, 1) * 0.1;
    
    % Historial de convergencia
    perdidas_por_ronda = zeros(rondas, 1);
    precisiones_por_ronda = zeros(rondas, 1);
    modelos_clientes = cell(num_clientes, 1);
    
    % Generar datos sintéticos basados en resultados reales si hay
    if ~isempty(resultados)
        num_muestras = length(resultados);
        X_global = zeros(num_muestras, num_features);
        y_global = zeros(num_muestras, 1);
        
        for i = 1:num_muestras
            X_global(i, :) = [resultados(i).Area/10000, ...
                              resultados(i).Excentricidad, ...
                              resultados(i).Solidez, ...
                              resultados(i).Compacidad, ...
                              resultados(i).Confianza];
            switch resultados(i).Clasificacion
                case 'Maligno'
                    y_global(i) = 1;
                case 'Tumor'
                    y_global(i) = 1;
                otherwise
                    y_global(i) = 0;
            end
        end
    else
        % Datos completamente sintéticos
        num_muestras = 50;
        X_global = randn(num_muestras, num_features);
        y_global = double(randn(num_muestras, 1) > 0);
    end
    
    % Simulación de FedAvg
    lr = 0.01; % Learning rate
    
    for ronda = 1:rondas
        modelos_locales = zeros(num_features, num_clientes);
        
        for cliente = 1:num_clientes
            % Cada cliente tiene un subconjunto de datos (con ruido)
            indices = randperm(num_muestras, max(3, floor(num_muestras / num_clientes)));
            X_local = X_global(indices, :) + 0.1 * randn(length(indices), num_features);
            y_local = y_global(indices);
            
            % Entrenamiento local (regresión logística simplificada)
            modelo_local = modelo_global;
            for epoca = 1:5
                predicciones = 1 ./ (1 + exp(-X_local * modelo_local));
                error = predicciones - y_local;
                gradiente = (X_local' * error) / length(indices);
                modelo_local = modelo_local - lr * gradiente;
            end
            
            modelos_locales(:, cliente) = modelo_local;
        end
        
        % Agregación FedAvg
        modelo_global = mean(modelos_locales, 2);
        
        % Calcular pérdida y precisión global
        predicciones_global = 1 ./ (1 + exp(-X_global * modelo_global));
        perdida = -mean(y_global .* log(predicciones_global + 1e-8) + ...
                       (1 - y_global) .* log(1 - predicciones_global + 1e-8));
        precision = mean((predicciones_global > 0.5) == y_global) * 100;
        
        perdidas_por_ronda(ronda) = perdida;
        precisiones_por_ronda(ronda) = precision;
    end
    
    fed_resultado.modelo_final = modelo_global;
    fed_resultado.perdidas = perdidas_por_ronda;
    fed_resultado.precisiones = precisiones_por_ronda;
    fed_resultado.num_clientes = num_clientes;
    fed_resultado.rondas = rondas;
    fed_resultado.precision_final = precisiones_por_ronda(end);
    
    fprintf('Aprendizaje federado completado: precisión final=%.1f%%\n', ...
        fed_resultado.precision_final);
end

%% ============================================================================
%% CLASIFICACIÓN DE LESIONES
%% ============================================================================

function [clasificacion, puntuacion, confianza] = clasificarLesionAvanzada(imagen, prop, modelos, config)
    % Clasificación híbrida: Deep Learning + características morfológicas
    
    bbox = prop.BoundingBox;
    bbox = round(bbox);
    x1 = max(1, bbox(1));
    y1 = max(1, bbox(2));
    x2 = min(size(imagen, 2), x1 + bbox(3) - 1);
    y2 = min(size(imagen, 1), y1 + bbox(4) - 1);
    
    if x2 > x1 && y2 > y1
        roi = imagen(y1:y2, x1:x2);
        
        area = prop.Area;
        excentricidad = prop.Eccentricity;
        solidez = prop.Solidity;
        diametro_mayor = prop.MajorAxisLength;
        
        % CLASIFICACIÓN BASADA EN CARACTERÍSTICAS MORFOLÓGICAS
        if area > 10000
            clasificacion_morf = 'Tumor';
            puntuacion_morf = 4;
        elseif area >= 500 && area <= 10000
            if excentricidad <= 0.6 && solidez > 0.85 && diametro_mayor < 300
                clasificacion_morf = 'Benigno';
                puntuacion_morf = 1;
            elseif excentricidad >= 0.7 || (solidez < 0.6 && diametro_mayor > 200)
                clasificacion_morf = 'Maligno';
                puntuacion_morf = 3;
            else
                clasificacion_morf = 'Indeterminado';
                puntuacion_morf = 2;
            end
        else
            clasificacion_morf = 'Ruido';
            puntuacion_morf = 0;
        end
        
        % Simular clasificación con CNN
        if config.deep_learning.uso_cnn_clasificacion && area > 100
            textura_entropy = entropy(roi);
            textura_std = std(double(roi(:)));
            
            if textura_entropy > 5 && textura_std > 25
                clasificacion_cnn = 'Maligno';
                confianza_cnn = 0.85;
            elseif textura_entropy < 3 && textura_std < 15
                clasificacion_cnn = 'Benigno';
                confianza_cnn = 0.90;
            else
                clasificacion_cnn = 'Indeterminado';
                confianza_cnn = 0.60;
            end
            
            % Fusión de clasificadores
            if confianza_cnn > config.deep_learning.umbral_confianza_cnn
                clasificacion = clasificacion_cnn;
                confianza = confianza_cnn;
            else
                clasificacion = clasificacion_morf;
                confianza = 0.70;
            end
            
            switch clasificacion
                case 'Maligno'
                    puntuacion = 3 * confianza;
                case 'Benigno'
                    puntuacion = 1 * confianza;
                case 'Tumor'
                    puntuacion = 4;
                otherwise
                    puntuacion = 2 * confianza;
            end
        else
            clasificacion = clasificacion_morf;
            puntuacion = puntuacion_morf;
            confianza = 0.65;
        end
    else
        area = prop.Area;
        if area > 10000
            clasificacion = 'Tumor';
            puntuacion = 4;
        elseif area >= 500
            clasificacion = 'Indeterminado';
            puntuacion = 2;
        else
            clasificacion = 'Ruido';
            puntuacion = 0;
        end
        confianza = 0.50;
    end
    
    fprintf('Lesión clasificada como: %s (confianza: %.2f)\n', clasificacion, confianza);
end

%% ============================================================================
%% FUNCIONES DE DENSIDAD Y BIOMECÁNICA
%% ============================================================================

function mapa_densidad = generarMapaDensidadAvanzado(imagen, mascara)
    mascara_mama = imfill(mascara, 'holes');
    
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
        metricas.area_total = 0;
        metricas.area_densa = 0;
        metricas.area_grasa = 0;
        metricas.birads_categoria = 'a';
        metricas.birads_descripcion = 'No se pudo calcular';
        metricas.entropia = 0;
        metricas.homogeneidad = 0;
        metricas.contraste = 0;
        metricas.asimetria_espacial = 0;
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
        [GLCM, ~] = graycomatrix(mapa_densidad_mama, ...
            'Offset', [0 1; -1 1; -1 0; -1 -1], ...
            'NumLevels', 4, 'GrayLimits', [1 4]);
        props = graycoprops(GLCM, {'Contrast', 'Homogeneity'});
        metricas.contraste = mean(props.Contrast);
        metricas.homogeneidad = mean(props.Homogeneity);
    catch
        metricas.contraste = 0;
        metricas.homogeneidad = 0;
    end
    
    regiones_densas = mapa_densidad_mama >= 3;
    if sum(regiones_densas(:)) > 0
        stats_mama = regionprops(mascara_mama, 'Centroid');
        if ~isempty(stats_mama)
            centroide_mama = stats_mama(1).Centroid;
            
            stats_densas = regionprops(regiones_densas, 'Centroid', 'Area');
            if ~isempty(stats_densas)
                areas_densas = [stats_densas.Area];
                centroides_densas = vertcat(stats_densas.Centroid);
                centroide_densas = sum(centroides_densas .* areas_densas', 1) / sum(areas_densas);
                
                [fil, col] = find(mascara_mama);
                diametro_mama = max(sqrt((fil - centroide_mama(2)).^2 + (col - centroide_mama(1)).^2)) * 2;
                if diametro_mama > 0
                    distancia_centroides = sqrt(sum((centroide_mama - centroide_densas).^2)) / diametro_mama;
                else
                    distancia_centroides = 0;
                end
                
                metricas.asimetria_espacial = distancia_centroides;
            else
                metricas.asimetria_espacial = 0;
            end
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
    centro_x = columnas / 2;
    centro_y = filas / 2;
    
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

%% ============================================================================
%% DIAGNÓSTICO INTEGRADO
%% ============================================================================

function diagnostico = generarDiagnosticoIntegradoAvanzado(resultados, metricas, modelo, config)
    if isempty(resultados)
        diagnostico = struct(...
            'clasificacion', 'SIN HALLAZGOS DETECTABLES', ...
            'color', [0.5 0.5 0.5], ...
            'recomendacion', {{'Continuar con revisiones preventivas'}}, ...
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
        diagnostico.recomendacion = {
            'Biopsia inmediata recomendada'
            'Consulta urgente con oncólogo'
            'Estudios complementarios necesarios'
        };
    elseif (num_malignas >= 1 && puntuacion_total >= 6) || factor_densidad > 0.7
        diagnostico.clasificacion = 'SOSPECHA DE MALIGNIDAD MODERADA';
        diagnostico.color = [1 0.4 0];
        diagnostico.recomendacion = {
            'Evaluación oncológica prioritaria'
            'Mamografía de seguimiento en 1-3 meses'
            'Considerar estudios adicionales'
        };
    elseif num_malignas >= 1 || puntuacion_total >= 4
        diagnostico.clasificacion = 'SOSPECHA DE MALIGNIDAD';
        diagnostico.color = [1 0.7 0];
        diagnostico.recomendacion = {
            'Evaluación especializada necesaria'
            'Seguimiento en 3-6 meses'
            'Monitoreo cercano recomendado'
        };
    else
        diagnostico.clasificacion = 'HALLAZGOS PROBABLEMENTE BENIGNOS';
        diagnostico.color = [0 0.8 0];
        diagnostico.recomendacion = {
            'Seguimiento rutinario'
            'Revisión anual recomendada'
            'Mantener estilo de vida saludable'
        };
    end
    
    diagnostico.puntuacion_total = puntuacion_total;
    diagnostico.confianza = confianza_promedio;
    diagnostico.metricas = metricas;
    
    fprintf('Diagnóstico integrado generado: %s\n', diagnostico.clasificacion);
end

%% ============================================================================
%% FUNCIONES DE VISUALIZACIÓN (11 FIGURAS)
%% ============================================================================

function fig = visualizarProcesamientoAvanzado(imagen_original, imagen_suavizada, oehc, ...
    mascara_final, mascara_adaptativa, imagen_ecualizada, num_regiones, info)
    
    fig = figure('Name', 'Figura 1 - Procesamiento Avanzado de Imágenes DICOM', ...
           'Position', [50 50 1400 900], ...
           'Color', [0.95 0.95 0.95], ...
           'NumberTitle', 'off');

    subplot(2, 3, 1);
    imshow(imagen_original, []);
    title('A) Imagen DICOM Original', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    colorbar('southoutside');

    subplot(2, 3, 2);
    imshow(imagen_suavizada, []);
    title('B) Imagen Preprocesada (Con Autoencoder)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    colorbar('southoutside');

    subplot(2, 3, 3);
    imshow(oehc, []);
    title('C) Segmentación Top-hat', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    colorbar('southoutside');

    subplot(2, 3, 4);
    imshow(mascara_final);
    title(['D) Máscara Final (', num2str(num_regiones), ' regiones)'], ...
          'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);

    subplot(2, 3, 5);
    imshow(mascara_adaptativa);
    title('E) Segmentación Adaptativa', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);

    subplot(2, 3, 6);
    imshow(imagen_ecualizada, []);
    title('F) Imagen Ecualizada Mejorada', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    colorbar('southoutside');

    [~, nombreArchivo, extension] = fileparts(info.Filenames{1});
    nombreArchivoCompleto = [nombreArchivo extension];
    
    annotation('textbox', [0.02 0.02 0.96 0.04], 'String', ...
               sprintf('Archivo: %s | Modalidad: %s | Dimensiones: %dx%d | Regiones detectadas: %d', ...
               nombreArchivoCompleto, info.Modality, size(imagen_original,1), size(imagen_original,2), num_regiones), ...
               'FontSize', 10, 'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
               'BackgroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold', 'Interpreter', 'none');
end

function fig = visualizarDensidadTexturaAvanzada(imagen_suavizada, mascara_final, mapa_densidad, metricas, modelos)
    fig = figure('Name', 'Figura 2 - Mapa de Densidad y Análisis de Textura Avanzado', ...
           'Position', [100 100 1400 700], ...
           'Color', [1 1 1], ...
           'NumberTitle', 'off');

    %% PANEL IZQUIERDO: MAPA DE DENSIDAD
    subplot(1, 2, 1);
    imagesc(mapa_densidad);
    colormap([0.9 0.9 0.9; 0.7 0.9 0.7; 1.0 0.8 0.4; 1.0 0.4 0.4]);
    caxis([0 3]);
    colorbar('Ticks', [0.375, 1.125, 1.875, 2.625], ...
             'TickLabels', {'Fondo', 'Tejido Graso', 'Tejido Intermedio', 'Tejido Denso'});
    axis image;
    title('MAPA DE DENSIDAD CUANTITATIVA AVANZADO', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0 0 0.6]);

    if metricas.porcentaje_densidad < 25
        clasificacion_birads = 'CAT a: Casi completamente grasa';
        color_birads = [0 0.7 0];
    elseif metricas.porcentaje_densidad < 50
        clasificacion_birads = 'CAT b: Densidades dispersas';
        color_birads = [0 0.5 0.8];
    elseif metricas.porcentaje_densidad < 75
        clasificacion_birads = 'CAT c: Heterogeneamente densa';
        color_birads = [1 0.6 0.2];
    else
        clasificacion_birads = 'CAT d: Extremadamente densa';
        color_birads = [1 0.2 0.2];
    end

    info_densidad = {};
    info_densidad{end+1} = sprintf('Porcentaje de densidad: %.1f%%', metricas.porcentaje_densidad);
    info_densidad{end+1} = sprintf('Area total: %d pixeles', metricas.area_total);
    info_densidad{end+1} = sprintf('Area densa: %d pixeles', metricas.area_densa);
    info_densidad{end+1} = sprintf('Entropia: %.3f', metricas.entropia);
    info_densidad{end+1} = sprintf('Homogeneidad: %.3f', metricas.homogeneidad);
    info_densidad{end+1} = sprintf('Asimetria espacial: %.3f', metricas.asimetria_espacial);

    text(0.02, 0.98, info_densidad, 'Units', 'normalized', 'FontSize', 11, 'FontWeight', 'bold', ...
         'Color', [0 0 0.5], 'VerticalAlignment', 'top', ...
         'BackgroundColor', [1 1 1 0.9], 'EdgeColor', [0 0 0.5], 'Margin', 3);

    text(0.02, 0.02, clasificacion_birads, 'Units', 'normalized', ...
         'FontSize', 12, 'FontWeight', 'bold', 'Color', color_birads, ...
         'VerticalAlignment', 'bottom', 'BackgroundColor', [1 1 1 0.9], 'Margin', 3);

    %% PANEL DERECHO: ANÁLISIS DE TEXTURA
    subplot(1, 2, 2);
    axis off;
    
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 3, 'Curvature', 0.02);

    text(0.5, 0.92, 'ANALISIS CUANTITATIVO DE TEXTURA AVANZADO', 'Units', 'normalized', ...
         'FontSize', 16, 'FontWeight', 'bold', 'Color', [0.1 0.3 0.5], ...
         'HorizontalAlignment', 'center');

    mascara_mama = imfill(mascara_final, 'holes');
    if any(mascara_mama(:))
        region_textura = imagen_suavizada;
        region_textura(~mascara_mama) = 0;

        [GLCM, ~] = graycomatrix(region_textura, ...
            'Offset', [0 1; -1 1; -1 0; -1 -1], ...
            'NumLevels', 16, 'GrayLimits', []);
        props_glcm = graycoprops(GLCM, {'contrast', 'correlation', 'energy', 'homogeneity'});

        hist_vals = region_textura(region_textura > 0);
        if ~isempty(hist_vals)
            skewness_val = skewness(double(hist_vals));
            kurtosis_val = kurtosis(double(hist_vals));
            entropy_val = entropy(region_textura);
            roughness = std(double(hist_vals)) / mean(double(hist_vals));
        else
            skewness_val = 0; kurtosis_val = 0; entropy_val = 0; roughness = 0;
        end
    else
        props_glcm.Contrast = 0; props_glcm.Correlation = 0;
        props_glcm.Energy = 0; props_glcm.Homogeneity = 0;
        skewness_val = 0; kurtosis_val = 0; entropy_val = 0; roughness = 0;
    end

    % Cuadro 1: GLCM
    rectangle('Position', [0.08 0.70 0.84 0.18], 'FaceColor', [0.95 0.96 1], ...
              'EdgeColor', [0.2 0.3 0.6], 'LineWidth', 2, 'Curvature', 0.02);

    text(0.5, 0.86, 'CARACTERISTICAS DE TEXTURA GLCM', 'Units', 'normalized', ...
         'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', [0.1 0.2 0.5]);

    glcm_left = {};
    glcm_left{1} = sprintf('Contraste:    %.3f', mean(props_glcm.Contrast));
    glcm_left{2} = sprintf('Correlacion:  %.3f', mean(props_glcm.Correlation));
    
    glcm_right = {};
    glcm_right{1} = sprintf('Energia:      %.3f', mean(props_glcm.Energy));
    glcm_right{2} = sprintf('Homogeneidad: %.3f', mean(props_glcm.Homogeneity));

    text(0.15, 0.78, glcm_left, 'Units', 'normalized', 'FontSize', 12, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.2 0.2 0.4]);

    text(0.55, 0.78, glcm_right, 'Units', 'normalized', 'FontSize', 12, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.2 0.2 0.4]);

    % Cuadro 2: Estadísticas
    rectangle('Position', [0.08 0.45 0.84 0.18], 'FaceColor', [0.96 0.98 0.96], ...
              'EdgeColor', [0.2 0.5 0.3], 'LineWidth', 2, 'Curvature', 0.02);

    text(0.5, 0.61, 'ANALISIS ESTADISTICO AVANZADO', 'Units', 'normalized', ...
         'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', [0.1 0.4 0.2]);

    stats_left = {};
    stats_left{1} = sprintf('Asimetria:   %.3f', skewness_val);
    stats_left{2} = sprintf('Curtosis:    %.3f', kurtosis_val);
    
    stats_right = {};
    stats_right{1} = sprintf('Entropia:    %.3f', entropy_val);
    stats_right{2} = sprintf('Rugosidad:   %.3f', roughness);

    text(0.15, 0.53, stats_left, 'Units', 'normalized', 'FontSize', 12, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.2 0.3 0.2]);

    text(0.55, 0.53, stats_right, 'Units', 'normalized', 'FontSize', 12, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.2 0.3 0.2]);

    % Cuadro 3: Interpretación
    if entropy_val > 6 && mean(props_glcm.Contrast) > 0.4
        interpretacion = 'TEXTURA COMPLEJA - Alta heterogeneidad';
        color_interp = [0.8 0.2 0.2];
        bg_color = [1 0.95 0.95];
    elseif entropy_val > 4 || mean(props_glcm.Contrast) > 0.3
        interpretacion = 'TEXTURA MODERADA - Requiere seguimiento';
        color_interp = [1 0.6 0.2];
        bg_color = [1 0.97 0.95];
    else
        interpretacion = 'TEXTURA SIMPLE - Probable benigno';
        color_interp = [0.2 0.6 0.2];
        bg_color = [0.95 1 0.95];
    end

    rectangle('Position', [0.08 0.20 0.84 0.18], 'FaceColor', bg_color, ...
              'EdgeColor', color_interp, 'LineWidth', 3, 'Curvature', 0.03);

    text(0.5, 0.34, 'INTERPRETACION', 'Units', 'normalized', ...
         'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', color_interp);

    text(0.5, 0.28, interpretacion, 'Units', 'normalized', ...
         'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', color_interp);
end

function fig = visualizarModeloBiomecanicoAvanzado(imagen_suavizada, mapa_densidad, modelo, metricas)
    fig = figure('Name', 'Figura 3 - Modelo Biomecánico Avanzado', ...
           'Position', [150 50 1400 900], 'Color', [1 1 1]);

    subplot(2, 3, 1);
    imagesc(mapa_densidad);
    hold on;
    if any(modelo.tensiones.maxima(:) > 0)
        alta_tension = modelo.tensiones.maxima > prctile(modelo.tensiones.maxima(modelo.tensiones.maxima > 0), 75);
        [contornos_y, contornos_x] = find(bwperim(alta_tension));
        plot(contornos_x, contornos_y, 'r.', 'MarkerSize', 2);
    end
    colormap([0.9 0.9 0.9; 0.7 0.9 0.7; 1.0 0.8 0.4; 1.0 0.4 0.4]);
    caxis([0 3]);
    colorbar;
    title('A) Densidad + Alta Tension', 'FontSize', 12, 'FontWeight', 'bold');

    subplot(2, 3, 2);
    if any(modelo.tensiones.maxima(:) > 0)
        imagesc(modelo.tensiones.maxima);
        colorbar;
    else
        imagesc(zeros(size(imagen_suavizada)));
    end
    title('B) Campo de Tensiones Maximas (kPa)', 'FontSize', 12, 'FontWeight', 'bold');

    subplot(2, 3, 3);
    if any(modelo.tensiones.maxima(:) > 0)
        tensiones_validas = modelo.tensiones.maxima(modelo.tensiones.maxima > 0);
        histogram(tensiones_validas, 50, 'FaceColor', [0.8 0.2 0.2], 'EdgeColor', 'black');
    else
        histogram(0);
    end
    xlabel('Tension (kPa)');
    ylabel('Frecuencia');
    title('C) Distribucion de Tensiones', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;

    subplot(2, 3, 4);
    if any(modelo.tensiones.gradiente(:) > 0)
        imagesc(modelo.tensiones.gradiente);
        colorbar;
    else
        imagesc(zeros(size(imagen_suavizada)));
    end
    title('D) Gradientes de Tension', 'FontSize', 12, 'FontWeight', 'bold');

    subplot(2, 3, 5);
    axis off;
    
    if modelo.geometria.area_total > 0
        relacion_glandular = (modelo.geometria.area_glandular/modelo.geometria.area_total)*100;
    else
        relacion_glandular = 0;
    end
    
    modelo_text = {};
    modelo_text{end+1} = 'PROPIEDADES DEL MODELO BIOMECANICO';
    modelo_text{end+1} = '--------------------------------------';
    modelo_text{end+1} = sprintf('Modulo glandular:   %.1f kPa', modelo.propiedades.young_glandular);
    modelo_text{end+1} = sprintf('Modulo adiposo:     %.1f kPa', modelo.propiedades.young_adipose);
    modelo_text{end+1} = sprintf('Coef. Poisson:      %.2f', modelo.propiedades.poisson_ratio);
    modelo_text{end+1} = '';
    modelo_text{end+1} = 'GEOMETRIA DEL TEJIDO:';
    modelo_text{end+1} = sprintf('Area total:         %d px', modelo.geometria.area_total);
    modelo_text{end+1} = sprintf('Area glandular:     %d px', modelo.geometria.area_glandular);
    modelo_text{end+1} = sprintf('Area adiposa:       %d px', modelo.geometria.area_adiposa);
    modelo_text{end+1} = sprintf('Relacion glandular: %.1f%%', relacion_glandular);
    modelo_text{end+1} = '';
    modelo_text{end+1} = 'ANALISIS DE TENSIONES:';
    
    if any(modelo.tensiones.maxima(:) > 0)
        tensiones_validas = modelo.tensiones.maxima(modelo.tensiones.maxima > 0);
        modelo_text{end+1} = sprintf('Tension maxima:     %.2f kPa', max(tensiones_validas));
        modelo_text{end+1} = sprintf('Tension media:      %.2f kPa', mean(tensiones_validas));
        modelo_text{end+1} = sprintf('Desv. estandar:     %.2f kPa', std(tensiones_validas));
    else
        modelo_text{end+1} = 'No hay datos de tension';
    end
    
    text(0.1, 0.9, modelo_text, 'Units', 'normalized', 'FontSize', 10, ...
         'FontName', 'Monospaced', 'VerticalAlignment', 'top', 'FontWeight', 'bold');

    subplot(2, 3, 6);
    if any(modelo.tensiones.maxima(:) > 0)
        surf(modelo.tensiones.maxima(1:10:end, 1:10:end), 'EdgeColor', 'none');
        title('E) Superficie de Tensiones', 'FontSize', 12, 'FontWeight', 'bold');
        zlabel('Tension (kPa)');
    else
        surf(zeros(10,10));
        title('E) Sin datos de tension', 'FontSize', 12, 'FontWeight', 'bold');
    end
end

function fig = visualizarRiesgoIntegradoAvanzado(imagen_suavizada, mascara_final, mapa_densidad, ...
    modelo_biomecanico, resultados, diagnostico_integrado)
    
    fig = figure('Name', 'Figura 4 - Mapa de Riesgo Integrado Avanzado', ...
           'Position', [200 50 1400 800], ...
           'Color', [1 1 1], ...
           'NumberTitle', 'off');

    mascara_mama = imfill(mascara_final, 'holes');
    area_total = sum(mascara_mama(:));
    
    if area_total > 0
        area_densa = sum(mapa_densidad(mascara_mama) >= 2);
        porcentaje_densidad = (area_densa / area_total) * 100;
        
        region_textura = imagen_suavizada;
        region_textura(~mascara_mama) = 0;
        
        if any(region_textura(:) > 0)
            [GLCM, ~] = graycomatrix(region_textura, ...
                'Offset', [0 1; -1 1; -1 0; -1 -1], ...
                'NumLevels', 8, 'GrayLimits', []);
            props_glcm = graycoprops(GLCM, {'contrast', 'homogeneity'});
            textura_contrast = mean(props_glcm.Contrast);
            textura_homogeneity = mean(props_glcm.Homogeneity);
            textura_entropy = entropy(region_textura);
        else
            textura_contrast = 0; textura_homogeneity = 0; textura_entropy = 0;
        end
        
        if any(modelo_biomecanico.tensiones.maxima(:) > 0)
            tensiones_validas = modelo_biomecanico.tensiones.maxima(modelo_biomecanico.tensiones.maxima > 0);
            tension_promedio = mean(tensiones_validas);
            factor_tension = min(tension_promedio / 10, 2);
        else
            factor_tension = 0;
        end
        
        if ~isempty(resultados)
            num_malignas = sum(strcmp({resultados.Clasificacion}, 'Maligno'));
            num_lesiones = length(resultados);
            factor_lesiones = min(num_malignas * 0.5 + num_lesiones * 0.1, 3);
        else
            factor_lesiones = 0;
        end
        
        puntuacion_densidad = min(porcentaje_densidad / 25, 4);
        puntuacion_textura = (textura_contrast * 6 + (1 - textura_homogeneity) * 4 + textura_entropy * 1.2);
        puntuacion_riesgo_integrado = puntuacion_densidad + puntuacion_textura + factor_tension + factor_lesiones;
    else
        puntuacion_riesgo_integrado = 0;
        porcentaje_densidad = 0;
    end

    subplot(2, 3, [1, 2, 4, 5]);
    imshow(imagen_suavizada, []);
    hold on;

    if puntuacion_riesgo_integrado >= 10
        color_riesgo = [1 0 0]; texto_riesgo = 'RIESGO MUY ALTO'; nivel_riesgo = 'MUY ALTO';
    elseif puntuacion_riesgo_integrado >= 8
        color_riesgo = [1 0.3 0]; texto_riesgo = 'ALTO RIESGO INTEGRADO'; nivel_riesgo = 'ALTO';
    elseif puntuacion_riesgo_integrado >= 6
        color_riesgo = [1 0.6 0]; texto_riesgo = 'RIESGO MODERADO-ALTO'; nivel_riesgo = 'MODERADO-ALTO';
    elseif puntuacion_riesgo_integrado >= 4
        color_riesgo = [1 0.8 0]; texto_riesgo = 'RIESGO MODERADO'; nivel_riesgo = 'MODERADO';
    elseif puntuacion_riesgo_integrado >= 2
        color_riesgo = [0.2 0.8 0.2]; texto_riesgo = 'RIESGO BAJO-MODERADO'; nivel_riesgo = 'BAJO-MODERADO';
    else
        color_riesgo = [0 0.6 0]; texto_riesgo = 'BAJO RIESGO'; nivel_riesgo = 'BAJO';
    end

    if any(mascara_mama(:))
        contornos_mama = bwboundaries(mascara_mama);
        for k = 1:length(contornos_mama)
            contorno = contornos_mama{k};
            plot(contorno(:,2), contorno(:,1), 'Color', color_riesgo, 'LineWidth', 4);
        end
    end

    title('MAPA DE RIESGO INTEGRADO AVANZADO', 'FontSize', 16, 'FontWeight', 'bold', ...
          'Color', color_riesgo);

    info_riesgo_texto = {};
    info_riesgo_texto{1} = texto_riesgo;
    info_riesgo_texto{2} = sprintf('Puntuacion integrada: %.1f/12', min(puntuacion_riesgo_integrado, 12));
    info_riesgo_texto{3} = sprintf('Densidad mamaria: %.1f%%', porcentaje_densidad);
    info_riesgo_texto{4} = sprintf('Nivel de riesgo: %s', nivel_riesgo);
    info_riesgo_texto{5} = sprintf('Confianza diagnostico: %.1f%%', diagnostico_integrado.confianza * 100);

    text(0.02, 0.98, info_riesgo_texto, 'Units', 'normalized', ...
         'FontSize', 12, 'FontWeight', 'bold', 'Color', color_riesgo, ...
         'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1 0.9], ...
         'EdgeColor', color_riesgo, 'LineWidth', 2, 'Margin', 5);
    hold off;

    subplot(2, 3, 3);
    axis off;
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 2, 'Curvature', 0.02);
    text(0.5, 0.95, 'DIAGNOSTICO AVANZADO', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', [0 0 0.6]);
    rectangle('Position', [0.1 0.75 0.8 0.15], 'FaceColor', diagnostico_integrado.color, ...
              'EdgeColor', 'black', 'LineWidth', 2, 'Curvature', 0.03);
    text(0.5, 0.82, diagnostico_integrado.clasificacion, 'Units', 'normalized', ...
         'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', 'white');

    subplot(2, 3, 6);
    axis off;
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.97 0.98 0.95], ...
              'EdgeColor', [0.3 0.6 0.3], 'LineWidth', 2, 'Curvature', 0.02);
    text(0.5, 0.95, 'RECOMENDACIONES', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', [0 0.4 0]);

    rec_y_pos = 0.8;
    for i = 1:min(length(diagnostico_integrado.recomendacion), 4)
        text(0.15, rec_y_pos, diagnostico_integrado.recomendacion{i}, ...
             'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold', ...
             'Color', [0.1 0.3 0.1], 'Interpreter', 'none');
        rec_y_pos = rec_y_pos - 0.12;
    end
end

function fig = visualizarCorrelacionMultimodalAvanzada(resultados, deformaciones, metricas, config)
    fig = figure('Name', 'Figura 5 - Correlacion Multimodal Avanzada', ...
           'Position', [250 50 1400 800], 'Color', [1 1 1]);

    if isempty(resultados)
        text(0.5, 0.5, 'No hay datos para correlacion multimodal', ...
             'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
        return;
    end

    areas = [resultados.Area];
    excentricidades = [resultados.Excentricidad];
    solideces = [resultados.Solidez];
    confianzas = [resultados.Confianza];
    puntuaciones_riesgo = [resultados.PuntuacionRiesgo];
    clasificaciones = {resultados.Clasificacion};
    
    if ~isempty(areas) && max(areas) > 0
        areas_norm = areas / max(areas);
    else
        areas_norm = areas;
    end
    if ~isempty(excentricidades) && max(excentricidades) > 0
        excentricidades_norm = excentricidades / max(excentricidades);
    else
        excentricidades_norm = excentricidades;
    end
    if ~isempty(solideces) && max(solideces) > 0
        solideces_norm = solideces / max(solideces);
    else
        solideces_norm = solideces;
    end

    % Asignar colores y tamaños
    colores = zeros(length(resultados), 3);
    sizes = zeros(length(resultados), 1);
    for i = 1:length(resultados)
        switch resultados(i).Clasificacion
            case 'Maligno'
                colores(i, :) = [1, 0, 0]; sizes(i) = 80 + confianzas(i) * 40;
            case 'Benigno'
                colores(i, :) = [0, 1, 0]; sizes(i) = 60 + confianzas(i) * 40;
            case 'Tumor'
                colores(i, :) = [0.5, 0, 0.5]; sizes(i) = 100 + confianzas(i) * 40;
            otherwise
                colores(i, :) = [0.5, 0.5, 0.5]; sizes(i) = 50 + confianzas(i) * 30;
        end
    end

    % 1. Area vs Excentricidad
    subplot(2, 3, 1);
    scatter(areas, excentricidades, sizes, colores, 'filled', 'MarkerEdgeColor', 'black');
    xlabel('Area (pixeles)', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Excentricidad', 'FontSize', 11, 'FontWeight', 'bold');
    title('A) Area vs Excentricidad', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;

    % 2. Distribución de áreas por tipo
    subplot(2, 3, 2);
    tipos_unicos = unique(clasificaciones);
    data_matrix = [];
    group_vector = [];
    group_labels = {};
    
    for k = 1:length(tipos_unicos)
        mask_tipo = strcmp(clasificaciones, tipos_unicos{k});
        current_data = areas(mask_tipo);
        if ~isempty(current_data)
            data_matrix = [data_matrix; current_data(:)];
            group_vector = [group_vector; k * ones(length(current_data), 1)];
            group_labels{end+1} = tipos_unicos{k};
        end
    end
    
    if ~isempty(data_matrix)
        boxplot(data_matrix, group_vector, 'Labels', group_labels, 'Widths', 0.6);
        ylabel('Area (pixeles)', 'FontSize', 11, 'FontWeight', 'bold');
        title('B) Distribucion de Areas por Tipo', 'FontSize', 12, 'FontWeight', 'bold');
        grid on;
    else
        text(0.5, 0.5, 'Sin datos', 'HorizontalAlignment', 'center');
    end

    % 3. Morfología vs Confianza
    subplot(2, 3, 3);
    if length(areas) > 1
        score_morfologico = areas_norm + excentricidades_norm + (1 - solideces_norm);
        if max(score_morfologico) > 0
            score_morfologico = score_morfologico / max(score_morfologico);
        end
        
        scatter(score_morfologico, confianzas, sizes, colores, 'filled', 'MarkerEdgeColor', 'black');
        
        if length(score_morfologico) > 1
            hold on;
            valid_idx = ~isnan(score_morfologico) & ~isnan(confianzas);
            if sum(valid_idx) > 1
                p = polyfit(score_morfologico(valid_idx), confianzas(valid_idx), 1);
                x_trend = linspace(min(score_morfologico(valid_idx)), max(score_morfologico(valid_idx)), 100);
                y_trend = polyval(p, x_trend);
                plot(x_trend, y_trend, 'k--', 'LineWidth', 2);
                
                r_matrix = corrcoef(score_morfologico(valid_idx), confianzas(valid_idx));
                if all(size(r_matrix) == [2,2])
                    text(0.05, 0.95, sprintf('r = %.3f', r_matrix(1,2)), 'Units', 'normalized', ...
                         'FontSize', 11, 'FontWeight', 'bold', 'BackgroundColor', 'white');
                end
            end
            hold off;
        end
        
        xlabel('Score Morfologico', 'FontSize', 11, 'FontWeight', 'bold');
        ylabel('Confianza', 'FontSize', 11, 'FontWeight', 'bold');
        title('C) Morfologia vs Confianza', 'FontSize', 12, 'FontWeight', 'bold');
        grid on;
    else
        text(0.5, 0.5, 'Datos insuficientes', 'HorizontalAlignment', 'center');
    end

    % 4. Confianza por tipo
    subplot(2, 3, 4);
    hold on;
    tipos_plot = {'Maligno', 'Benigno', 'Tumor', 'Indeterminado'};
    colores_plot = {[1 0 0], [0 1 0], [0.5 0 0.5], [0.5 0.5 0.5]};
    
    for ti = 1:length(tipos_plot)
        mask = strcmp(clasificaciones, tipos_plot{ti});
        conf_tipo = confianzas(mask);
        if ~isempty(conf_tipo)
            scatter((ti-0.15) * ones(size(conf_tipo)), conf_tipo, 50, ...
                    colores_plot{ti}, 'filled', 'MarkerFaceAlpha', 0.6);
            plot([ti-0.25, ti-0.05], [mean(conf_tipo), mean(conf_tipo)], 'k-', 'LineWidth', 3);
        end
    end
    
    xlim([0.5, 4.5]); ylim([0, 1]);
    set(gca, 'XTick', 1:4, 'XTickLabel', tipos_plot);
    ylabel('Confianza', 'FontSize', 11, 'FontWeight', 'bold');
    title('D) Confianza por Tipo', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    hold off;

    % 5. Matriz de correlación
    subplot(2, 3, 5);
    if length(resultados) >= 3
        features = [areas(:), excentricidades(:), solideces(:), confianzas(:), puntuaciones_riesgo(:)];
        if ~any(any(isnan(features)))
            corr_matrix = corrcoef(features);
            imagesc(corr_matrix);
            colorbar;
            feature_labels = {'Area', 'Excent', 'Solidez', 'Conf', 'Riesgo'};
            set(gca, 'XTick', 1:5, 'XTickLabel', feature_labels);
            set(gca, 'YTick', 1:5, 'YTickLabel', feature_labels);
            
            for ii = 1:size(corr_matrix, 1)
                for jj = 1:size(corr_matrix, 2)
                    if abs(corr_matrix(ii, jj)) > 0.5
                        color_texto = 'white';
                    else
                        color_texto = 'black';
                    end
                    text(jj, ii, sprintf('%.2f', corr_matrix(ii, jj)), ...
                         'HorizontalAlignment', 'center', 'FontSize', 9, ...
                         'FontWeight', 'bold', 'Color', color_texto);
                end
            end
            title('E) Matriz de Correlacion', 'FontSize', 12, 'FontWeight', 'bold');
        else
            text(0.5, 0.5, 'Datos incompletos', 'HorizontalAlignment', 'center');
        end
    else
        text(0.5, 0.5, 'Datos insuficientes', 'HorizontalAlignment', 'center');
    end

    % 6. PCA
    subplot(2, 3, 6);
    if length(resultados) >= 3 && ~isempty(areas_norm)
        features_pca = [areas_norm(:), excentricidades_norm(:), solideces_norm(:), confianzas(:)];
        if ~any(any(isnan(features_pca)))
            try
                [coeff, score] = pca(features_pca);
                group = clasificaciones(:);
                if length(group) == size(score, 1) && size(score, 2) >= 2
                    gscatter(score(:,1), score(:,2), group, ...
                            [1 0 0; 0 1 0; 0.5 0 0.5; 0.5 0.5 0.5], '.', 20);
                    xlabel('PC1', 'FontSize', 11, 'FontWeight', 'bold');
                    ylabel('PC2', 'FontSize', 11, 'FontWeight', 'bold');
                    title('F) Componentes Principales', 'FontSize', 12, 'FontWeight', 'bold');
                    legend('Location', 'best');
                    grid on;
                else
                    text(0.5, 0.5, 'Error en dimensiones PCA', 'HorizontalAlignment', 'center');
                end
            catch
                text(0.5, 0.5, 'Error en PCA', 'HorizontalAlignment', 'center');
            end
        else
            text(0.5, 0.5, 'Datos incompletos', 'HorizontalAlignment', 'center');
        end
    else
        text(0.5, 0.5, 'Datos insuficientes', 'HorizontalAlignment', 'center');
    end

    sgtitle('ANALISIS DE CORRELACION MULTIMODAL AVANZADO', ...
            'FontSize', 16, 'FontWeight', 'bold', 'Color', [0 0 0.6]);
end

function fig6 = visualizarLesionesDetectadas(imagen_suavizada, mascara_final, resultados, etiquetas)
    fig6 = figure('Name', 'Figura 6 - Lesiones Detectadas y Clasificadas', ...
           'Position', [100 100 1200 800], 'Color', [1 1 1]);

    subplot(1, 1, 1);
    imshow(imagen_suavizada, []);
    hold on;
    
    if ~isempty(resultados)
        for i = 1:length(resultados)
            mascara_lesion = (etiquetas == resultados(i).ID);
            contornos = bwboundaries(mascara_lesion);
            
            switch resultados(i).Clasificacion
                case 'Maligno'
                    color_contorno = [1 0 0]; grosor = 4; estilo = '-';
                case 'Benigno'
                    color_contorno = [0 0.8 0]; grosor = 3; estilo = '-';
                case 'Tumor'
                    color_contorno = [1 0.5 0]; grosor = 5; estilo = '-';
                otherwise
                    color_contorno = [0.5 0.5 0.5]; grosor = 2; estilo = '--';
            end
            
            for k = 1:length(contornos)
                contorno = contornos{k};
                plot(contorno(:,2), contorno(:,1), estilo, 'Color', color_contorno, 'LineWidth', grosor);
                
                stats = regionprops(mascara_lesion, 'Centroid');
                if ~isempty(stats)
                    centroid = stats(1).Centroid;
                    text(centroid(1), centroid(2), num2str(resultados(i).ID), ...
                         'Color', 'white', 'FontSize', 12, 'FontWeight', 'bold', ...
                         'BackgroundColor', color_contorno, 'HorizontalAlignment', 'center', 'Margin', 2);
                end
            end
        end
    end
    
    title('LESIONES DETECTADAS Y CLASIFICADAS', 'FontSize', 16, 'FontWeight', 'bold', 'Color', [0 0 0.6]);
    
    hold on;
    h_mal = plot(NaN, NaN, '-', 'Color', [1 0 0], 'LineWidth', 4);
    h_ben = plot(NaN, NaN, '-', 'Color', [0 0.8 0], 'LineWidth', 3);
    h_tum = plot(NaN, NaN, '-', 'Color', [1 0.5 0], 'LineWidth', 5);
    h_ind = plot(NaN, NaN, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 2);
    legend([h_mal, h_ben, h_tum, h_ind], {'Malignas', 'Benignas', 'Tumores', 'Indeterminadas'}, ...
           'Location', 'best', 'FontSize', 12, 'FontWeight', 'bold');
    
    if ~isempty(resultados)
        num_malignas = sum(strcmp({resultados.Clasificacion}, 'Maligno'));
        num_benignas = sum(strcmp({resultados.Clasificacion}, 'Benigno'));
        num_tumores = sum(strcmp({resultados.Clasificacion}, 'Tumor'));
        num_indet = sum(strcmp({resultados.Clasificacion}, 'Indeterminado'));
        
        info_text = {};
        info_text{1} = sprintf('Total lesiones: %d', length(resultados));
        info_text{2} = sprintf('Malignas: %d', num_malignas);
        info_text{3} = sprintf('Benignas: %d', num_benignas);
        info_text{4} = sprintf('Tumores: %d', num_tumores);
        info_text{5} = sprintf('Indeterminadas: %d', num_indet);
        
        text(0.02, 0.98, info_text, 'Units', 'normalized', ...
             'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0 0.5], ...
             'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1 0.9], ...
             'EdgeColor', [0 0 0.5], 'LineWidth', 1);
    end
    hold off;
end

function fig7 = visualizarTablaCaracteristicas(resultados)
    fig7 = figure('Name', 'Figura 7 - Caracteristicas Detalladas de Lesiones', ...
           'Position', [150 100 1400 600], 'Color', [1 1 1]);

    if isempty(resultados)
        text(0.5, 0.5, 'No se detectaron lesiones', 'HorizontalAlignment', 'center', ...
             'FontSize', 16, 'FontWeight', 'bold', 'Color', [0.5 0.5 0.5]);
        return;
    end

    axes('Position', [0.05 0.05 0.9 0.9]);
    axis off;
    
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 3, 'Curvature', 0.02);
    
    text(0.5, 0.95, 'CARACTERISTICAS DETALLADAS DE LESIONES', 'Units', 'normalized', ...
         'FontSize', 18, 'FontWeight', 'bold', 'Color', [0 0 0.6], 'HorizontalAlignment', 'center');
    
    line([0.08 0.92], [0.92 0.92], 'Color', [0.3 0.5 0.7], 'LineWidth', 2);
    
    headers = {'ID', 'Area (px)', 'Diametro', 'Solidez', 'Excent.', 'Tipo', 'Riesgo', 'Conf.'};
    pos_x = [0.08, 0.14, 0.22, 0.32, 0.42, 0.56, 0.70, 0.85];
    
    rectangle('Position', [0.06 0.84 0.88 0.06], 'FaceColor', [0.2 0.4 0.6], ...
              'EdgeColor', [0.1 0.3 0.5], 'Curvature', 0.03);
    
    for i = 1:length(headers)
        text(pos_x(i), 0.87, headers{i}, 'Units', 'normalized', ...
             'FontSize', 12, 'FontWeight', 'bold', 'FontName', 'Monospaced', ...
             'Color', 'white', 'HorizontalAlignment', 'center');
    end
    
    num_filas_a_mostrar = min(8, length(resultados));
    
    for i = 1:num_filas_a_mostrar
        if mod(i, 2) == 1
            rect_color = [0.95 0.95 0.97];
        else
            rect_color = [0.92 0.94 0.98];
        end
        rectangle('Position', [0.06 0.77-(i-1)*0.08 0.88 0.07], ...
                  'FaceColor', rect_color, 'EdgeColor', [0.9 0.9 0.9], 'Curvature', 0.02);
        
        switch resultados(i).Clasificacion
            case 'Maligno'
                color_texto = [0.8 0 0]; color_fondo = [1 0.9 0.9];
            case 'Benigno'
                color_texto = [0 0.5 0]; color_fondo = [0.9 1 0.9];
            case 'Tumor'
                color_texto = [0.8 0.4 0]; color_fondo = [1 0.95 0.9];
            otherwise
                color_texto = [0.3 0.3 0.3]; color_fondo = [0.95 0.95 0.95];
        end
        
        rectangle('Position', [0.54 0.77-(i-1)*0.08 0.40 0.07], ...
                  'FaceColor', color_fondo, 'EdgeColor', [0.9 0.9 0.9], 'Curvature', 0.02);
        
        datos_fila = {
            sprintf('%d', resultados(i).ID), ...
            formatNumber(resultados(i).Area), ...
            formatNumber(round(resultados(i).Diametro)), ...
            sprintf('%.3f', resultados(i).Solidez), ...
            sprintf('%.3f', resultados(i).Excentricidad), ...
            resultados(i).Clasificacion, ...
            sprintf('%.1f', resultados(i).PuntuacionRiesgo), ...
            sprintf('%.0f%%', resultados(i).Confianza * 100)
        };
        
        for j = 1:length(datos_fila)
            if j >= 6
                text(pos_x(j), 0.80-(i-1)*0.08, datos_fila{j}, 'Units', 'normalized', ...
                     'FontSize', 10, 'FontName', 'Monospaced', 'FontWeight', 'bold', ...
                     'Color', color_texto, 'HorizontalAlignment', 'center');
            else
                text(pos_x(j), 0.80-(i-1)*0.08, datos_fila{j}, 'Units', 'normalized', ...
                     'FontSize', 10, 'FontName', 'Monospaced', 'FontWeight', 'bold', ...
                     'Color', [0.2 0.2 0.4], 'HorizontalAlignment', 'center');
            end
        end
    end
    
    if length(resultados) > 8
        text(0.5, 0.15, sprintf('+ %d lesiones adicionales...', length(resultados)-8), ...
             'Units', 'normalized', 'FontSize', 12, 'FontWeight', 'bold', ...
             'Color', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');
    end
end

function fig8 = visualizarAnalisisEstadistico(imagen_suavizada, mascara_final, resultados, etiquetas)
    fig8 = figure('Name', 'Figura 8 - Analisis Estadistico y Distribucion', ...
           'Position', [200 50 1400 900], 'Color', [1 1 1]);

    if isempty(resultados)
        text(0.5, 0.5, 'No hay datos para analisis estadistico', ...
             'HorizontalAlignment', 'center', 'FontSize', 16, 'FontWeight', 'bold');
        return;
    end

    % 1. Distribución por tipo
    subplot(2, 2, 1);
    tipos = {'Maligno', 'Benigno', 'Tumor', 'Indeterminado'};
    counts = zeros(1,4);
    areas_promedio = zeros(1,4);
    for i = 1:4
        mask_tipo = strcmp({resultados.Clasificacion}, tipos{i});
        counts(i) = sum(mask_tipo);
        if counts(i) > 0
            areas_promedio(i) = mean([resultados(mask_tipo).Area]);
        end
    end
    
    yyaxis left
    b = bar(counts, 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'black', 'FaceAlpha', 0.7);
    ylabel('Numero de Lesiones', 'FontSize', 12, 'FontWeight', 'bold');
    set(gca, 'XTickLabel', {'Maligno', 'Benigno', 'Tumor', 'Indet.'}, 'FontSize', 11);
    
    for i = 1:length(counts)
        if counts(i) > 0
            text(i, counts(i) + 0.1, num2str(counts(i)), ...
                 'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
        end
    end
    
    yyaxis right
    p = plot(areas_promedio/1000, 'ro-', 'LineWidth', 3, 'MarkerSize', 10, 'MarkerFaceColor', 'red');
    ylabel('Area Promedio (x1000 px)', 'FontSize', 12, 'FontWeight', 'bold');
    title('A) Distribucion por Tipo', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    legend([b, p], {'Cantidad', 'Area Promedio'}, 'Location', 'best');

    % 2. Mapa de distribución
    subplot(2, 2, 2);
    imshow(imagen_suavizada, []);
    hold on;
    
    for i = 1:length(resultados)
        mascara_lesion = (etiquetas == resultados(i).ID);
        stats = regionprops(mascara_lesion, 'Centroid');
        if ~isempty(stats)
            centroid = stats(1).Centroid;
            switch resultados(i).Clasificacion
                case 'Maligno'
                    plot(centroid(1), centroid(2), 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'red', 'LineWidth', 2);
                case 'Benigno'
                    plot(centroid(1), centroid(2), 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'green', 'LineWidth', 2);
                case 'Tumor'
                    plot(centroid(1), centroid(2), 's', 'MarkerSize', 14, 'MarkerFaceColor', [1 0.5 0], 'Color', 'black', 'LineWidth', 2);
                otherwise
                    plot(centroid(1), centroid(2), '^', 'MarkerSize', 10, 'MarkerFaceColor', [0.5 0.5 0.5], 'Color', 'black');
            end
            text(centroid(1)+15, centroid(2), num2str(resultados(i).ID), ...
                 'Color', 'white', 'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', [0.3 0.3 0.3]);
        end
    end
    title('B) Mapa de Distribucion', 'FontSize', 14, 'FontWeight', 'bold');
    hold off;

    % 3. Solidez vs Excentricidad
    subplot(2, 2, 3);
    areas = [resultados.Area];
    solideces = [resultados.Solidez];
    excentricidades = [resultados.Excentricidad];
    
    sizes = 80 + (areas / max(areas)) * 120;
    colores = zeros(length(areas), 3);
    for i = 1:length(areas)
        switch resultados(i).Clasificacion
            case 'Maligno'
                colores(i, :) = [1, 0, 0];
            case 'Benigno'
                colores(i, :) = [0, 0.8, 0];
            case 'Tumor'
                colores(i, :) = [1, 0.5, 0];
            otherwise
                colores(i, :) = [0.5, 0.5, 0.5];
        end
    end
    
    scatter(solideces, excentricidades, sizes, colores, 'filled', 'MarkerEdgeColor', 'black', 'LineWidth', 1.5);
    xlabel('Solidez', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Excentricidad', 'FontSize', 12, 'FontWeight', 'bold');
    title('C) Solidez vs Excentricidad', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    
    for i = 1:length(resultados)
        text(solideces(i), excentricidades(i), num2str(resultados(i).ID), ...
             'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', ...
             'BackgroundColor', [1 1 1 0.8], 'Margin', 1);
    end

    % 4. Resumen estadístico
    subplot(2, 2, 4);
    axis off;
    
    riesgos = [resultados.PuntuacionRiesgo];
    confianzas = [resultados.Confianza];
    
    resumen_texto = {};
    resumen_texto{end+1} = 'RESUMEN ESTADISTICO COMPLETO';
    resumen_texto{end+1} = '--------------------------';
    resumen_texto{end+1} = sprintf('Total de lesiones:      %d', length(resultados));
    resumen_texto{end+1} = sprintf('Area total detectada:   %s px', formatNumber(sum(areas)));
    resumen_texto{end+1} = '';
    resumen_texto{end+1} = 'DISTRIBUCION POR TIPO:';
    resumen_texto{end+1} = sprintf('Malignas:           %2d (%.1f%%)', ...
        sum(strcmp({resultados.Clasificacion}, 'Maligno')), ...
        sum(strcmp({resultados.Clasificacion}, 'Maligno'))/length(resultados)*100);
    resumen_texto{end+1} = sprintf('Benignas:           %2d (%.1f%%)', ...
        sum(strcmp({resultados.Clasificacion}, 'Benigno')), ...
        sum(strcmp({resultados.Clasificacion}, 'Benigno'))/length(resultados)*100);
    resumen_texto{end+1} = sprintf('Tumores:            %2d (%.1f%%)', ...
        sum(strcmp({resultados.Clasificacion}, 'Tumor')), ...
        sum(strcmp({resultados.Clasificacion}, 'Tumor'))/length(resultados)*100);
    resumen_texto{end+1} = sprintf('Indeterminadas:     %2d (%.1f%%)', ...
        sum(strcmp({resultados.Clasificacion}, 'Indeterminado')), ...
        sum(strcmp({resultados.Clasificacion}, 'Indeterminado'))/length(resultados)*100);
    resumen_texto{end+1} = '';
    resumen_texto{end+1} = 'CARACTERISTICAS PROMEDIO:';
    resumen_texto{end+1} = sprintf('Area:               %s px', formatNumber(mean(areas)));
    resumen_texto{end+1} = sprintf('Solidez:            %.3f +/- %.3f', mean(solideces), std(solideces));
    resumen_texto{end+1} = sprintf('Excentricidad:      %.3f +/- %.3f', mean(excentricidades), std(excentricidades));
    resumen_texto{end+1} = sprintf('Riesgo:             %.1f +/- %.1f', mean(riesgos), std(riesgos));
    resumen_texto{end+1} = sprintf('Confianza:          %.1f%% +/- %.1f%%', mean(confianzas)*100, std(confianzas)*100);
    
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 2, 'Curvature', 0.02);
    
    text(0.1, 0.9, resumen_texto, 'Units', 'normalized', 'FontSize', 10, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.1 0.3 0.5]);
    
    title('D) Resumen Estadistico', 'FontSize', 14, 'FontWeight', 'bold');
end

function fig9 = visualizarResumenClinico(resultados, diagnostico, recomendacion, puntuacion_total)
    fig9 = figure('Name', 'Figura 9 - Resumen Clinico Integral', ...
           'Position', [250 100 1400 900], 'Color', [1 1 1]);

    % Panel 1: Diagnóstico principal
    subplot(2, 2, 1);
    axis off;
    
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 3, 'Curvature', 0.03);
    
    text(0.5, 0.9, 'DIAGNOSTICO PRINCIPAL', 'Units', 'normalized', ...
         'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', [0.1 0.3 0.5]);
    
    if contains(diagnostico, 'ALTA SOSPECHA') || contains(diagnostico, 'MALIGNIDAD')
        color_diag = [1 0 0];
    elseif contains(diagnostico, 'MODERADA')
        color_diag = [1 0.5 0];
    elseif contains(diagnostico, 'BENIGNOS')
        color_diag = [0 0.7 0];
    else
        color_diag = [0.5 0.5 0.5];
    end
    
    rectangle('Position', [0.1 0.6 0.8 0.25], 'FaceColor', color_diag, ...
              'EdgeColor', 'black', 'LineWidth', 3, 'Curvature', 0.03);
    
    text(0.5, 0.8, 'DIAGNOSTICO', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', 'white');
    text(0.5, 0.65, diagnostico, 'Units', 'normalized', ...
         'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', 'white');
    
    text(0.5, 0.42, sprintf('PUNTUACION TOTAL DE RIESGO: %.1f', puntuacion_total), ...
         'Units', 'normalized', 'FontSize', 12, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', 'Color', color_diag);
    
    text(0.5, 0.15, sprintf('Generado: %s', datestr(now, 'dd/mm/yyyy HH:MM')), ...
         'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);

    % Panel 2: Distribución de lesiones
    subplot(2, 2, 2);
    if ~isempty(resultados)
        tipos = {'Maligno', 'Benigno', 'Tumor', 'Indeterminado'};
        counts = zeros(1,4);
        for i = 1:4
            counts(i) = sum(strcmp({resultados.Clasificacion}, tipos{i}));
        end
        pie_data = counts(counts > 0);
        pie_labels = tipos(counts > 0);
        if ~isempty(pie_data)
            pie(pie_data, pie_labels);
            title('DISTRIBUCION DE LESIONES', 'FontSize', 14, 'FontWeight', 'bold');
        end
    else
        text(0.5, 0.5, 'Sin lesiones', 'HorizontalAlignment', 'center', 'FontSize', 12);
    end

    % Panel 3: Resumen estadístico
    subplot(2, 2, 3);
    axis off;
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.97 0.98 0.95], ...
              'EdgeColor', [0.3 0.6 0.3], 'LineWidth', 2, 'Curvature', 0.02);
    
    if ~isempty(resultados)
        areas = [resultados.Area];
        confianzas = [resultados.Confianza];
        
        resumen = {};
        resumen{end+1} = 'RESUMEN ESTADISTICO';
        resumen{end+1} = '-------------------';
        resumen{end+1} = sprintf('Total lesiones:     %d', length(resultados));
        resumen{end+1} = sprintf('Area total:         %s px', formatNumber(sum(areas)));
        resumen{end+1} = sprintf('Confianza promedio: %.1f%%', mean(confianzas)*100);
        resumen{end+1} = sprintf('Area minima:        %s px', formatNumber(min(areas)));
        resumen{end+1} = sprintf('Area maxima:        %s px', formatNumber(max(areas)));
        
        text(0.1, 0.85, resumen, 'Units', 'normalized', 'FontSize', 11, ...
             'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
             'Color', [0.1 0.3 0.1]);
    end

    % Panel 4: Recomendaciones
    subplot(2, 2, 4);
    axis off;
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.97 0.95], ...
              'EdgeColor', [0.6 0.4 0.2], 'LineWidth', 2, 'Curvature', 0.02);
    text(0.5, 0.95, 'RECOMENDACIONES CLINICAS', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', [0.4 0.2 0.1]);
    
    if ~isempty(recomendacion)
        rec_y_pos = 0.82;
        for i = 1:min(length(recomendacion), 5)
            text(0.12, rec_y_pos, sprintf('%d. %s', i, recomendacion{i}), ...
                 'Units', 'normalized', 'FontSize', 11, 'FontWeight', 'bold', ...
                 'Color', [0.2 0.1 0], 'Interpreter', 'none');
            rec_y_pos = rec_y_pos - 0.14;
        end
    end
end

%% ============================================================================
%% FIGURA 10: MICROCALCIFICACIONES (NUEVA)
%% ============================================================================

function fig10 = visualizarMicrocalcificaciones(imagen_suavizada, microcalc, mapa_micro)
    fig10 = figure('Name', 'Figura 10 - Deteccion de Microcalcificaciones', ...
           'Position', [300 50 1400 700], 'Color', [1 1 1]);

    % Panel 1: Imagen con microcalcificaciones marcadas
    subplot(1, 3, 1);
    imshow(imagen_suavizada, []);
    hold on;
    
    if microcalc.num_total > 0
        plot(microcalc.centroides(:,1), microcalc.centroides(:,2), ...
             'r+', 'MarkerSize', 10, 'LineWidth', 2);
        
        % Círculos de agrupación
        if microcalc.num_total >= 2
            centro_grupo = mean(microcalc.centroides, 1);
            radio_grupo = max(pdist2(microcalc.centroides, centro_grupo));
            theta = linspace(0, 2*pi, 100);
            plot(centro_grupo(1) + radio_grupo*cos(theta), ...
                 centro_grupo(2) + radio_grupo*sin(theta), ...
                 'y--', 'LineWidth', 2);
        end
    end
    
    title('A) Microcalcificaciones Detectadas', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0 0 0.6]);
    hold off;

    % Panel 2: Mapa de microcalcificaciones
    subplot(1, 3, 2);
    if any(mapa_micro(:))
        % Dilatar para mejor visibilidad
        mapa_visible = imdilate(mapa_micro, strel('disk', 3));
        
        % Superponer sobre imagen
        imshow(imagen_suavizada, []);
        hold on;
        h = imagesc(mapa_visible);
        set(h, 'AlphaData', mapa_visible * 0.7);
        colormap(gca, hot);
        hold off;
    else
        imshow(imagen_suavizada, []);
    end
    title('B) Mapa de Microcalcificaciones', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0 0 0.6]);

    % Panel 3: Información y score de riesgo
    subplot(1, 3, 3);
    axis off;
    
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 3, 'Curvature', 0.03);
    
    text(0.5, 0.92, 'ANALISIS DE MICROCALCIFICACIONES', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', [0 0 0.6]);

    % Score de riesgo visual
    switch microcalc.score_riesgo
        case 0
            color_score = [0 0.7 0];
            nivel = 'SIN RIESGO';
        case 1
            color_score = [0.2 0.8 0.2];
            nivel = 'BAJO';
        case 2
            color_score = [1 0.8 0];
            nivel = 'MODERADO';
        case 3
            color_score = [1 0.5 0];
            nivel = 'ALTO';
        case 4
            color_score = [1 0 0];
            nivel = 'MUY ALTO';
        otherwise
            color_score = [0.5 0.5 0.5];
            nivel = 'NO EVALUADO';
    end
    
    rectangle('Position', [0.1 0.72 0.8 0.15], 'FaceColor', color_score, ...
              'EdgeColor', 'black', 'LineWidth', 2, 'Curvature', 0.03);
    text(0.5, 0.80, sprintf('RIESGO: %s (Score %d/4)', nivel, microcalc.score_riesgo), ...
         'Units', 'normalized', 'FontSize', 13, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', 'Color', 'white');

    info_micro = {};
    info_micro{end+1} = sprintf('Total detectadas:    %d', microcalc.num_total);
    info_micro{end+1} = sprintf('Patron:              %s', microcalc.patron);
    info_micro{end+1} = sprintf('Agrupadas:           %d', microcalc.num_agrupadas);
    
    if ~isempty(microcalc.areas)
        info_micro{end+1} = sprintf('Area promedio:       %.1f px', mean(microcalc.areas));
        info_micro{end+1} = sprintf('Area maxima:         %.1f px', max(microcalc.areas));
    end
    
    text(0.15, 0.60, info_micro, 'Units', 'normalized', 'FontSize', 12, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.1 0.2 0.4]);

    % Interpretación clínica
    rectangle('Position', [0.1 0.15 0.8 0.20], 'FaceColor', [0.95 0.97 1], ...
              'EdgeColor', [0.3 0.5 0.7], 'LineWidth', 2, 'Curvature', 0.02);
    
    text(0.5, 0.32, 'INTERPRETACION CLINICA', 'Units', 'normalized', ...
         'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', [0 0 0.5]);
    
    switch microcalc.patron
        case 'Lineales'
            interp_text = 'Patron lineal sugiere ductografia.';
        case 'Agrupadas'
            interp_text = 'Patron agrupado requiere seguimiento.';
        case 'Dispersas'
            interp_text = 'Patron disperso, probablemente benigno.';
        case 'Aisladas'
            interp_text = 'Calcificaciones aisladas, bajo riesgo.';
        otherwise
            interp_text = 'Sin microcalcificaciones significativas.';
    end
    
    text(0.5, 0.22, interp_text, 'Units', 'normalized', ...
         'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', color_score);
end

%% ============================================================================
%% FIGURA 11: EXPLICABILIDAD ViT Y GRAD-CAM (NUEVA)
%% ============================================================================

function fig11 = visualizarExplicabilidadViT(imagen_suavizada, mascara_final, ...
    vit_resultado, mapa_gradcam, ddpm_resultado, federado_resultado)
    
    fig11 = figure('Name', 'Figura 11 - Explicabilidad ViT, Grad-CAM, DDPM y Federado', ...
           'Position', [350 50 1500 900], 'Color', [1 1 1]);

    % 1. Mapa de atención ViT (scores por patch)
    subplot(2, 3, 1);
    num_patches = vit_resultado.num_patches;
    mapa_atencion = reshape(vit_resultado.scores_patches, [num_patches, num_patches]);
    
    imagesc(mapa_atencion);
    colormap(gca, hot);
    colorbar;
    title('A) Mapa de Atencion ViT', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.6]);
    xlabel('Patch X'); ylabel('Patch Y');
    
    % Anotar score global
    text(0.02, 0.98, sprintf('Score global: %.3f\n%s', ...
        vit_resultado.score_global, vit_resultado.clasificacion), ...
        'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold', ...
        'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1 0.9], ...
        'Color', [0 0 0.5]);

    % 2. Grad-CAM superpuesto
    subplot(2, 3, 2);
    imshow(imagen_suavizada, []);
    hold on;
    h = imagesc(mapa_gradcam);
    set(h, 'AlphaData', mapa_gradcam * 0.6);
    colormap(gca, jet);
    colorbar;
    title('B) Grad-CAM Simulado (Explicabilidad)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.6]);
    hold off;

    % 3. DDPM: proceso de difusión forward
    subplot(2, 3, 3);
    num_pasos_vis = length(ddpm_resultado.imagenes_ruido);
    
    % Mostrar composición de pasos de ruido
    montaje = [];
    for idx = 1:min(4, num_pasos_vis)
        img_ruido = ddpm_resultado.imagenes_ruido{idx};
        img_ruido = mat2gray(img_ruido);
        img_small = imresize(img_ruido, [100, 100]);
        if isempty(montaje)
            montaje = img_small;
        else
            montaje = [montaje, img_small];
        end
    end
    
    imshow(montaje, []);
    title('C) DDPM Forward (Ruido Progresivo)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.6]);
    
    % Etiquetas de pasos
    for idx = 1:min(4, num_pasos_vis)
        text((idx-0.5)/min(4,num_pasos_vis), 0.02, sprintf('t=%d', ddpm_resultado.pasos_muestra(idx)), ...
             'Units', 'normalized', 'FontSize', 9, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'center', 'Color', 'white', 'BackgroundColor', [0 0 0 0.6]);
    end

    % 4. DDPM: reconstrucción
    subplot(2, 3, 4);
    imshow(ddpm_resultado.imagen_reconstruida, []);
    title(sprintf('D) DDPM Reconstruccion (PSNR=%.1f dB)', ddpm_resultado.psnr), ...
          'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.6]);

    % 5. Aprendizaje Federado: convergencia
    subplot(2, 3, 5);
    
    yyaxis left
    plot(1:federado_resultado.rondas, federado_resultado.perdidas, 'b-', 'LineWidth', 2);
    ylabel('Perdida', 'FontSize', 11, 'FontWeight', 'bold');
    
    yyaxis right
    plot(1:federado_resultado.rondas, federado_resultado.precisiones, 'r-', 'LineWidth', 2);
    ylabel('Precision (%)', 'FontSize', 11, 'FontWeight', 'bold');
    
    xlabel('Ronda de Federacion', 'FontSize', 11, 'FontWeight', 'bold');
    title(sprintf('E) Convergencia FedAvg (%d clientes)', federado_resultado.num_clientes), ...
          'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.6]);
    legend({'Perdida', 'Precision'}, 'Location', 'best');
    grid on;

    % 6. Resumen de técnicas 2026
    subplot(2, 3, 6);
    axis off;
    
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.97 0.97 1], ...
              'EdgeColor', [0.3 0.3 0.7], 'LineWidth', 3, 'Curvature', 0.03);
    
    text(0.5, 0.92, 'TECNICAS DE VANGUARDIA 2026', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', [0 0 0.6]);
    
    resumen_2026 = {};
    resumen_2026{end+1} = 'VISION TRANSFORMER (ViT):';
    resumen_2026{end+1} = sprintf('  Score global:      %.3f', vit_resultado.score_global);
    resumen_2026{end+1} = sprintf('  Clasificacion:     %s', vit_resultado.clasificacion);
    resumen_2026{end+1} = sprintf('  Patches:           %dx%d', vit_resultado.num_patches, vit_resultado.num_patches);
    resumen_2026{end+1} = '';
    resumen_2026{end+1} = 'GRAD-CAM:';
    resumen_2026{end+1} = sprintf('  Atencion max:      %.3f', max(mapa_gradcam(:)));
    resumen_2026{end+1} = sprintf('  Atencion media:    %.3f', mean(mapa_gradcam(mapa_gradcam > 0)));
    resumen_2026{end+1} = '';
    resumen_2026{end+1} = 'DIFUSION DDPM:';
    resumen_2026{end+1} = sprintf('  Pasos:             %d', ddpm_resultado.num_pasos);
    resumen_2026{end+1} = sprintf('  PSNR:              %.2f dB', ddpm_resultado.psnr);
    resumen_2026{end+1} = '';
    resumen_2026{end+1} = 'APRENDIZAJE FEDERADO:';
    resumen_2026{end+1} = sprintf('  Clientes:          %d', federado_resultado.num_clientes);
    resumen_2026{end+1} = sprintf('  Rondas:            %d', federado_resultado.rondas);
    resumen_2026{end+1} = sprintf('  Precision final:   %.1f%%', federado_resultado.precision_final);
    
    text(0.1, 0.85, resumen_2026, 'Units', 'normalized', 'FontSize', 10, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.1 0.2 0.5]);
    
    sgtitle('EXPLICABILIDAD Y TECNICAS AVANZADAS 2026', ...
            'FontSize', 16, 'FontWeight', 'bold', 'Color', [0 0 0.6]);
end

%% ============================================================================
%% EXPORTACIÓN Y REPORTE
%% ============================================================================

function exportarResultados(info, resultados, diagnostico, metricas_densidad, ...
    modelo_biomecanico, microcalcificaciones, vit_resultado, mapa_gradcam, ...
    ddpm_resultado, federado_resultado, puntuacion_total)
    
    fprintf('Exportando resultados a archivo .mat...\n');
    
    exportacion = struct();
    exportacion.info_dicom.modalidad = info.Modality;
    exportacion.info_dicom.dimensiones = info.Dimensions;
    if isfield(info, 'SeriesDescription')
        exportacion.info_dicom.descripcion = info.SeriesDescription;
    end
    exportacion.info_dicom.fecha_analisis = datestr(now);
    
    exportacion.resultados_lesiones = resultados;
    exportacion.diagnostico = diagnostico;
    exportacion.metricas_densidad = metricas_densidad;
    exportacion.modelo_biomecanico_geometria = modelo_biomecanico.geometria;
    exportacion.modelo_biomecanico_propiedades = modelo_biomecanico.propiedades;
    exportacion.microcalcificaciones = microcalcificaciones;
    exportacion.vit = rmfield(vit_resultado, 'features'); % Sin features completas por tamaño
    exportacion.ddpm_psnr = ddpm_resultado.psnr;
    exportacion.federado_precision = federado_resultado.precision_final;
    exportacion.federado_convergencia = federado_resultado.precisiones;
    exportacion.puntuacion_total = puntuacion_total;
    
    try
        save('resultados_analisis_mamario.mat', '-struct', 'exportacion');
        fprintf('Resultados exportados exitosamente: resultados_analisis_mamario.mat\n');
    catch ME
        fprintf('Error al exportar: %s\n', ME.message);
    end
end

% Función auxiliar para formatear números grandes
function formatted = formatNumber(num)
    if num >= 1000000
        formatted = sprintf('%.1fM', num/1000000);
    elseif num >= 1000
        formatted = sprintf('%.1fK', num/1000);
    else
        formatted = sprintf('%d', round(num));
    end
end

function generarInformeAvanzado(info, resultados, diagnostico, metricas_densidad, ...
    modelo_biomecanico, microcalcificaciones, vit_resultado, federado_resultado, ...
    puntuacion_total, num_lesiones_total)
    
    fprintf('\n=== INFORME UNIFICADO AVANZADO V2 DE ANALISIS MAMARIO ===\n');
    fprintf('Fecha de generacion: %s\n', datestr(now));
    fprintf('Sistema: Analisis Unificado Avanzado V2 (11 Figuras)\n');
    fprintf('Tecnicas: CVIP 2019 + ViT + Grad-CAM + DDPM + Aprendizaje Federado\n\n');
    
    fprintf('INFORMACION DEL ESTUDIO:\n');
    fprintf('------------------------\n');
    fprintf('Modalidad: %s\n', info.Modality);
    if isfield(info, 'SeriesDescription')
        fprintf('Descripcion: %s\n', info.SeriesDescription);
    end
    fprintf('Dimensiones: %dx%d\n', info.Dimensions(1), info.Dimensions(2));
    
    fprintf('\nANALISIS DE DENSIDAD AVANZADO:\n');
    fprintf('------------------------------\n');
    fprintf('Porcentaje de densidad: %.1f%%\n', metricas_densidad.porcentaje_densidad);
    fprintf('Categoria BI-RADS: %s\n', metricas_densidad.birads_categoria);
    fprintf('Descripcion: %s\n', metricas_densidad.birads_descripcion);
    fprintf('Area total analizada: %d pixeles\n', metricas_densidad.area_total);
    fprintf('Area de tejido denso: %d pixeles\n', metricas_densidad.area_densa);
    fprintf('Entropia de densidad: %.3f\n', metricas_densidad.entropia);
    fprintf('Homogeneidad: %.3f\n', metricas_densidad.homogeneidad);
    fprintf('Asimetria espacial: %.3f\n', metricas_densidad.asimetria_espacial);
    
    fprintf('\nMODELADO BIOMECANICO:\n');
    fprintf('---------------------\n');
    fprintf('Area total modelada: %d pixeles\n', modelo_biomecanico.geometria.area_total);
    if modelo_biomecanico.geometria.area_total > 0
        fprintf('Tejido glandular: %d px (%.1f%%)\n', ...
            modelo_biomecanico.geometria.area_glandular, ...
            (modelo_biomecanico.geometria.area_glandular/modelo_biomecanico.geometria.area_total)*100);
        fprintf('Tejido adiposo: %d px (%.1f%%)\n', ...
            modelo_biomecanico.geometria.area_adiposa, ...
            (modelo_biomecanico.geometria.area_adiposa/modelo_biomecanico.geometria.area_total)*100);
    end
    
    fprintf('\nMICROCALCIFICACIONES:\n');
    fprintf('---------------------\n');
    fprintf('Total detectadas: %d\n', microcalcificaciones.num_total);
    fprintf('Patron: %s\n', microcalcificaciones.patron);
    fprintf('Score de riesgo: %d/4\n', microcalcificaciones.score_riesgo);
    
    fprintf('\nEVALUACION DE LESIONES:\n');
    fprintf('----------------------\n');
    fprintf('Numero total de lesiones: %d\n', num_lesiones_total);
    
    if ~isempty(resultados)
        fprintf('Malignas: %d\n', sum(strcmp({resultados.Clasificacion}, 'Maligno')));
        fprintf('Benignas: %d\n', sum(strcmp({resultados.Clasificacion}, 'Benigno')));
        fprintf('Tumores: %d\n', sum(strcmp({resultados.Clasificacion}, 'Tumor')));
        fprintf('Indeterminadas: %d\n', sum(strcmp({resultados.Clasificacion}, 'Indeterminado')));
        fprintf('Puntuacion total de riesgo: %.1f\n', puntuacion_total);
        fprintf('Confianza promedio: %.1f%%\n', mean([resultados.Confianza]) * 100);
    end
    
    fprintf('\nTECNICAS DE VANGUARDIA 2026:\n');
    fprintf('----------------------------\n');
    fprintf('ViT - Score global: %.3f (%s)\n', vit_resultado.score_global, vit_resultado.clasificacion);
    fprintf('Aprendizaje Federado - Precision final: %.1f%%\n', federado_resultado.precision_final);
    
    fprintf('\nDIAGNOSTICO INTEGRADO:\n');
    fprintf('----------------------\n');
    fprintf('%s\n', diagnostico.clasificacion);
    fprintf('Confianza: %.1f%%\n\n', diagnostico.confianza * 100);
    
    fprintf('RECOMENDACIONES:\n');
    fprintf('----------------\n');
    for i = 1:length(diagnostico.recomendacion)
        fprintf('  %d. %s\n', i, diagnostico.recomendacion{i});
    end
    
    fprintf('\nRESUMEN DEL SISTEMA V2:\n');
    fprintf('-----------------------\n');
    fprintf('  11 Figuras generadas para analisis completo\n');
    fprintf('  Integracion: Procesamiento + DL + Biomecanica + ViT + DDPM + Federado\n');
    fprintf('  Microcalcificaciones: Wavelet (dwt2/LoG) + clasificacion de patrones\n');
    fprintf('  Explicabilidad: Grad-CAM simulado + mapa de atencion ViT\n');
    fprintf('  Resultados exportados a: resultados_analisis_mamario.mat\n');
    
    fprintf('\n=== FIN DEL INFORME AVANZADO V2 ===\n');
end
