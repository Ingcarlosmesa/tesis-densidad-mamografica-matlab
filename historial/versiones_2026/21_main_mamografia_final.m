%% SISTEMA UNIFICADO AVANZADO DE ANÁLISIS MAMOGRÁFICO
%  Análisis automatizado de imágenes mamográficas DICOM
%  Versión: 2026 - Universidad ECCI
%  Autor: Carlos Eduardo Mesa Mesa

clear all; close all; clc;

fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║  SISTEMA UNIFICADO AVANZADO DE ANÁLISIS MAMOGRÁFICO V2.0             ║\n');
fprintf('║  Análisis automatizado de imágenes mamográficas DICOM                 ║\n');
fprintf('║  Universidad ECCI - 2026                                             ║\n');
fprintf('╚════════════════════════════════════════════════════════════════════════╝\n');
fprintf('\n');

%% CONFIGURACIÓN DEL SISTEMA
fprintf('[CONFIG] Inicializando configuración del sistema...\n');

config = struct();

% Parámetros de preprocesamiento
config.prep.clahe_clip = 0.02;
config.prep.clahe_tiles = 8;
config.prep.filtro_mediana = [7 7];

% Parámetros de segmentación
config.seg.umbral_area_minima = 1000;
config.seg.se_tamano = 6;

% Parámetros biomecánicos
config.biomec.young_glandular = 15.1;   % kPa
config.biomec.young_adipose = 4.46;     % kPa
config.biomec.poisson_ratio = 0.45;

% Parámetros de microcalcificaciones
config.micro.umbral_minimo = 5;
config.micro.umbral_maximo = 500;

% Exportación
config.export.carpeta_salida = 'Resultados_Mamografia';
config.export.generar_png = true;
config.export.generar_mat = true;
config.export.generar_xlsx = true;
config.export.generar_txt = true;

fprintf('[CONFIG] ✓ Configuración cargada\n\n');

%% CARGAR IMAGEN DICOM
fprintf('[CARGA] Seleccionando imagen DICOM...\n');

[filename, filepath] = uigetfile({'*.dcm;*.dicom', 'Archivos DICOM'; '*.*', 'Todos los archivos'}, ...
                                  'Seleccionar imagen DICOM');

if isequal(filename, 0)
    fprintf('[CARGA] ⚠ Ningún archivo seleccionado. Usando imagen de prueba...\n');
    
    % Crear imagen de prueba simulada
    [imagen_original, info] = crear_imagen_prueba_mamografia();
    
else
    fprintf('[CARGA] Cargando: %s\n', filename);
    
    try
        info = dicominfo(fullfile(filepath, filename));
        imagen_original = dicomread(fullfile(filepath, filename));
        fprintf('[CARGA] ✓ Archivo DICOM leído exitosamente\n');
    catch ME
        fprintf('[CARGA] ✗ Error al leer DICOM: %s\n', ME.message);
        fprintf('[CARGA] ⚠ Usando imagen de prueba como fallback...\n');
        [imagen_original, info] = crear_imagen_prueba_mamografia();
    end
end

fprintf('\n');

%% CREAR DIRECTORIO DE SALIDA
if ~exist(config.export.carpeta_salida, 'dir')
    mkdir(config.export.carpeta_salida);
    fprintf('[EXPORT] ✓ Directorio creado: %s\n', config.export.carpeta_salida);
end

%% 1. PREPROCESAMIENTO
fprintf('[1/10] PREPROCESAMIENTO\n');
[imagen_prep, metricas_prep] = preprocesamiento_dicom(imagen_original, info, config);
fprintf('       ✓ Completado\n\n');

%% 2. SEGMENTACIÓN
fprintf('[2/10] SEGMENTACIÓN HÍBRIDA\n');
[mascara, stats_seg, metricas_seg] = segmentacion_hibrida(imagen_prep, config);
fprintf('       ✓ Completado\n\n');

%% 3. ANÁLISIS DE DENSIDAD
fprintf('[3/10] ANÁLISIS DE DENSIDAD MAMARIA\n');
[pct_densidad, categoria_birads_dens, mapa_densidad, metricas_dens] = ...
    analizar_densidad_mamaria(imagen_prep, mascara, config);
fprintf('       ✓ Completado (%.1f%% - BI-RADS %s)\n\n', pct_densidad, categoria_birads_dens);

%% 4. EXTRACCIÓN RADIOMICS
fprintf('[4/10] EXTRACCIÓN DE CARACTERÍSTICAS RADIOMICS\n');
[features, nombres_feat, metricas_radio] = extraer_radiomica_avanzada(imagen_prep, mascara, config);
fprintf('       ✓ Completado (%d características)\n\n', length(features));

%% 5. MODELADO BIOMECÁNICO
fprintf('[5/10] MODELADO BIOMECÁNICO\n');
[tensiones, deformaciones, metricas_biomec] = modelar_biomecanica_avanzado(mapa_densidad, config);
fprintf('       ✓ Completado (Tensión máx: %.2f kPa)\n\n', metricas_biomec.tension_max);

%% 6. DETECTAR Y CLASIFICAR LESIONES
fprintf('[6/10] DETECCIÓN Y CLASIFICACIÓN DE LESIONES\n');
[lesiones, metricas_les] = detectar_y_clasificar_lesiones(imagen_prep, mascara, config);
fprintf('       ✓ Completado (%d lesiones detectadas)\n\n', length(lesiones));

%% 7. DETECCIÓN DE MICROCALCIFICACIONES
fprintf('[7/10] DETECCIÓN DE MICROCALCIFICACIONES\n');
[microcalc, metricas_micro] = detectar_microcalcificaciones_avanzadas(imagen_prep, config);
fprintf('       ✓ Completado (%d detectadas - %s)\n\n', microcalc.numero, microcalc.distribucion);

%% 8. CÁLCULO DE RIESGO INTEGRADO
fprintf('[8/10] CÁLCULO DE RIESGO INTEGRADO\n');
[riesgo_integrado, prob_birads, categoria_birads_final, alertas] = ...
    calcular_riesgo_integrado_final(pct_densidad, lesiones, microcalc, metricas_biomec, ...
                                     imagen_prep, config);
fprintf('       ✓ Completado (Riesgo: %.2f/10 - BI-RADS: %d)\n\n', riesgo_integrado, categoria_birads_final);

%% COMPILAR ESTRUCTURA DE RESULTADOS
fprintf('[COMPIL] Compilando estructura de diagnóstico...\n');

resultados = struct();
resultados.fecha_analisis = datetime('now');

resultados.diagnostico = struct();
resultados.diagnostico.densidad_porcentaje = pct_densidad;
resultados.diagnostico.categoria_birads_densidad = categoria_birads_dens;
resultados.diagnostico.categoria_birads_final = categoria_birads_final;
resultados.diagnostico.riesgo_integrado = riesgo_integrado;
resultados.diagnostico.numero_lesiones = length(lesiones);

if ~isempty(lesiones)
    resultados.diagnostico.numero_malignas = sum(strcmp({lesiones.Clasificacion}, 'Maligno'));
    resultados.diagnostico.numero_indeterminadas = sum(strcmp({lesiones.Clasificacion}, 'Indeterminado'));
    resultados.diagnostico.riesgo_promedio_lesiones = mean([lesiones.Puntuacion_riesgo]);
else
    resultados.diagnostico.numero_malignas = 0;
    resultados.diagnostico.numero_indeterminadas = 0;
    resultados.diagnostico.riesgo_promedio_lesiones = 0;
end

resultados.diagnostico.microcalcificaciones = microcalc.numero;
resultados.diagnostico.patron_microcalc = microcalc.distribucion;
resultados.diagnostico.tension_maxima_kpa = metricas_biomec.tension_max;

resultados.metricas = struct();
resultados.metricas.preprocesamiento = metricas_prep;
resultados.metricas.segmentacion = metricas_seg;
resultados.metricas.densidad = metricas_dens;
resultados.metricas.radiomics = metricas_radio;
resultados.metricas.biomecanica = metricas_biomec;
resultados.metricas.lesiones = metricas_les;
resultados.metricas.microcalcificaciones = metricas_micro;

resultados.alertas = alertas;
resultados.lesiones = lesiones;
resultados.microcalcificaciones = microcalc;

fprintf('       ✓ Estructura compilada\n\n');

%% 9. GENERACIÓN DE VISUALIZACIONES
fprintf('[9/10] GENERACIÓN DE VISUALIZACIONES\n');
figuras = generar_visualizaciones_completas(imagen_prep, mascara, mapa_densidad, ...
                                            tensiones, lesiones, microcalc, ...
                                            resultados.diagnostico, alertas, config);
fprintf('       ✓ %d figuras generadas\n\n', length(figuras));

%% 10. EXPORTACIÓN DE RESULTADOS
fprintf('[10/10] EXPORTACIÓN DE RESULTADOS\n');
exportar_resultados_completos(resultados, figuras, config);
fprintf('        ✓ Exportación completada\n\n');

%% MOSTRAR RESUMEN
fprintf('╔════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                    ANÁLISIS COMPLETADO ✓                              ║\n');
fprintf('╚════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('RESUMEN DE RESULTADOS:\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('Densidad Mamaria:           %.1f%% (BI-RADS %s)\n', pct_densidad, categoria_birads_dens);
fprintf('Categoría BI-RADS Final:    %d (Prob: [%.1f, %.1f, %.1f, %.1f, %.1f, %.1f])\n', ...
        categoria_birads_final, prob_birads(1)*100, prob_birads(2)*100, prob_birads(3)*100, ...
        prob_birads(4)*100, prob_birads(5)*100, prob_birads(6)*100);
fprintf('Riesgo Integrado:           %.2f / 10\n', riesgo_integrado);
fprintf('Lesiones Detectadas:        %d (Malignas: %d, Indeterminadas: %d)\n', ...
        resultados.diagnostico.numero_lesiones, resultados.diagnostico.numero_malignas, ...
        resultados.diagnostico.numero_indeterminadas);
fprintf('Microcalcificaciones:       %d (%s)\n', microcalc.numero, microcalc.distribucion);
fprintf('Tensión Máxima:             %.2f kPa\n', metricas_biomec.tension_max);
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

fprintf('ALERTAS CLÍNICAS:\n');
for i = 1:length(alertas)
    fprintf('  %d. %s\n', i, alertas{i});
end
fprintf('\n');

fprintf('Resultados guardados en: %s\\\n', config.export.carpeta_salida);
fprintf('Abrir: %s\\resultados.mat para acceder a todos los datos\n\n', config.export.carpeta_salida);

fprintf('═══════════════════════════════════════════════════════════════════════════\n');
fprintf('Fin de ejecución: %s\n', datestr(now));
fprintf('═══════════════════════════════════════════════════════════════════════════\n\n');

%% ========================================================================
%% FUNCIONES AUXILIARES
%% ========================================================================

function [img, info] = crear_imagen_prueba_mamografia()
    % Crear imagen de prueba simulada para demostración
    fprintf('      Creando imagen de prueba...\n');
    
    % Crear imagen base
    [x, y] = meshgrid(1:512, 1:512);
    
    % Imagen de fondo (tejido adiposo)
    img = uint8(50 + 30*sin(x/100).*cos(y/100));
    
    % Agregar tejido glandular (región central)
    centro = uint8((x-256).^2 + (y-256).^2 < 20000);
    img(centro > 0) = uint8(img(centro > 0) * 1.5);
    
    % Agregar una lesión simulada
    lesion_mask = (x-200).^2 + (y-200).^2 < 1000;
    img(lesion_mask) = 180;
    
    % Agregar microcalcificaciones simuladas
    for i = 1:15
        cx = 100 + randi(300);
        cy = 100 + randi(300);
        micro_mask = (x-cx).^2 + (y-cy).^2 < 25;
        img(micro_mask) = 220;
    end
    
    % Información DICOM simulada
    info = struct();
    info.Modality = 'MG';
    info.SeriesDescription = 'Imagen de Prueba - Sistema Demo';
    info.Dimensions = size(img);
    
    fprintf('      ✓ Imagen de prueba creada (512x512)\n');
end

%% FUNCIÓN 1: PREPROCESAMIENTO DICOM
function [imagen_prep, metricas] = preprocesamiento_dicom(img, info, config)
    
    fprintf('   → Normalización DICOM...');
    
    % Convertir a double
    img_double = double(img);
    
    % Normalización
    img_norm = (img_double - min(img_double(:))) / (max(img_double(:)) - min(img_double(:)));
    img_norm = uint8(img_norm * 255);
    
    fprintf(' Mediana...');
    
    % Filtro mediana
    if isfield(config, 'prep') && isfield(config.prep, 'filtro_mediana')
        kernel = config.prep.filtro_mediana;
    else
        kernel = [7 7];
    end
    img_filtrada = medfilt2(img_norm, kernel, 'symmetric');
    
    fprintf(' CLAHE...');
    
    % CLAHE
    if isfield(config, 'prep')
        if isfield(config.prep, 'clahe_clip')
            clip = config.prep.clahe_clip;
        else
            clip = 0.02;
        end
        if isfield(config.prep, 'clahe_tiles')
            tiles = config.prep.clahe_tiles;
        else
            tiles = 8;
        end
    else
        clip = 0.02;
        tiles = 8;
    end
    
    imagen_prep = adapthisteq(img_filtrada, 'ClipLimit', clip, 'NumTiles', [tiles tiles]);
    
    fprintf(' ✓\n');
    
    metricas = struct();
    metricas.min_orig = min(img_double(:));
    metricas.max_orig = max(img_double(:));
    metricas.mean_orig = mean(img_double(:));
    metricas.std_orig = std(img_double(:));
end

%% FUNCIÓN 2: SEGMENTACIÓN HÍBRIDA
function [mascara, stats_seg, metricas] = segmentacion_hibrida(img, config)
    
    fprintf('   → Adaptativa...');
    masc1 = imbinarize(img, 'adaptive', 'Sensitivity', 0.55);
    
    fprintf(' Otsu...');
    masc2 = imbinarize(img, graythresh(img));
    
    fprintf(' Combinando...');
    mascara = masc1 | masc2;
    
    % Limpieza morfológica
    if isfield(config, 'seg') && isfield(config.seg, 'se_tamano')
        tamano = config.seg.se_tamano;
    else
        tamano = 6;
    end
    
    se = strel('disk', tamano);
    mascara = imclose(imopen(mascara, se), se);
    
    % Remover áreas pequeñas
    if isfield(config, 'seg') && isfield(config.seg, 'umbral_area_minima')
        umbral_area = config.seg.umbral_area_minima;
    else
        umbral_area = 1000;
    end
    
    mascara = bwareaopen(mascara, umbral_area);
    mascara = imfill(mascara, 'holes');
    
    stats_seg = regionprops(mascara, 'Area', 'Perimeter', 'Centroid', 'Solidity');
    
    metricas = struct();
    metricas.num_regiones = length(stats_seg);
    metricas.area_total = sum([stats_seg.Area]);
    
    fprintf(' ✓\n');
end

%% FUNCIÓN 3: ANÁLISIS DE DENSIDAD MAMARIA
function [pct_densidad, categoria_birads, mapa_densidad, metricas] = ...
    analizar_densidad_mamaria(img, mascara, config)
    
    fprintf('   → Calculando umbrales...');
    
    img_mama = img .* uint8(mascara);
    
    if sum(mascara(:)) < 100
        pct_densidad = 0;
        categoria_birads = 'a';
        mapa_densidad = zeros(size(img));
        metricas = struct('error', 'Máscara muy pequeña');
        fprintf(' ✗\n');
        return;
    end
    
    % Umbrales basados en percentiles
    p25 = prctile(img_mama(mascara), 25);
    p50 = prctile(img_mama(mascara), 50);
    p75 = prctile(img_mama(mascara), 75);
    
    fprintf(' Mapa...');
    
    mapa_densidad = ones(size(img));
    mapa_densidad(img_mama > p25 & img_mama <= p50) = 2;
    mapa_densidad(img_mama > p50 & img_mama <= p75) = 3;
    mapa_densidad(img_mama > p75) = 4;
    mapa_densidad(~mascara) = 0;
    
    area_densa = sum(mapa_densidad(mascara) >= 3);
    area_total = sum(mascara(:));
    pct_densidad = 100 * area_densa / area_total;
    
    % BI-RADS automático
    if pct_densidad < 25
        categoria_birads = 'a';
    elseif pct_densidad < 50
        categoria_birads = 'b';
    elseif pct_densidad < 75
        categoria_birads = 'c';
    else
        categoria_birads = 'd';
    end
    
    metricas = struct();
    metricas.porcentaje = pct_densidad;
    metricas.categoria = categoria_birads;
    metricas.entropia = entropy(mapa_densidad(mascara));
    metricas.area_densa = area_densa;
    metricas.area_total = area_total;
    
    fprintf(' ✓\n');
end

%% FUNCIÓN 4: EXTRACCIÓN RADIOMICS
function [features, nombres_feat, metricas] = extraer_radiomica_avanzada(img, mascara, config)
    
    fprintf('   → GLCM...');
    img_roi = img .* uint8(mascara);
    
    glcm = graycomatrix(img_roi, 'Offset', [0 1; -1 1; -1 0; -1 -1], 'NumLevels', 16);
    props = graycoprops(glcm, {'contrast', 'correlation', 'energy', 'homogeneity'});
    
    f_contrast = mean(props.Contrast);
    f_corr = mean(props.Correlation);
    f_energy = mean(props.Energy);
    f_homog = mean(props.Homogeneity);
    
    fprintf(' Intensidad...');
    
    f_mean = mean(img_roi(mascara));
    f_std = std(double(img_roi(mascara)));
    f_entropy = entropy(img_roi(img_roi > 0));
    f_lbp_energy = std2(img_roi);
    
    fprintf(' ✓\n');
    
    features = [f_contrast; f_corr; f_energy; f_homog; f_mean; f_std; f_entropy; f_lbp_energy];
    nombres_feat = {'Contraste_GLCM', 'Correlacion_GLCM', 'Energia_GLCM', 'Homogeneidad_GLCM', ...
                    'Media', 'Std', 'Entropia', 'LBP_Energy'};
    
    metricas.num_features = length(features);
    metricas.nombres = nombres_feat;
end

%% FUNCIÓN 5: MODELADO BIOMECÁNICO
function [tensiones, deformaciones, metricas] = modelar_biomecanica_avanzado(mapa_densidad, config)
    
    fprintf('   → Propiedades elásticas...');
    
    [ny, nx] = size(mapa_densidad);
    
    if isfield(config, 'biomec')
        E_glandular = config.biomec.young_glandular;
        E_adiposo = config.biomec.young_adipose;
    else
        E_glandular = 15.1;
        E_adiposo = 4.46;
    end
    
    modulo = ones(ny, nx) * E_adiposo;
    modulo(mapa_densidad >= 3) = E_glandular;
    
    fprintf(' Compresión...');
    
    [X, Y] = meshgrid(1:nx, 1:ny);
    cx = nx/2;
    cy = ny/2;
    dist = sqrt((X - cx).^2 + (Y - cy).^2);
    max_dist = sqrt(cx^2 + cy^2);
    factor_comp = 1 - 0.7 * (dist / max_dist);
    
    deformacion = 1 - factor_comp;
    tensiones = modulo .* deformacion;
    deformaciones = deformacion;
    
    fprintf(' ✓\n');
    
    metricas = struct();
    metricas.tension_max = max(tensiones(:));
    metricas.tension_media = mean(tensiones(mapa_densidad > 0));
    metricas.deform_max = max(deformaciones(:));
end

%% FUNCIÓN 6: DETECTAR Y CLASIFICAR LESIONES
function [resultados_lesiones, metricas] = detectar_y_clasificar_lesiones(img, mascara, config)
    
    fprintf('   → Etiquetando...');
    
    [etiquetas, num_regiones] = bwlabel(mascara);
    
    if num_regiones == 0
        resultados_lesiones = [];
        metricas = struct();
        fprintf(' Ninguna\n');
        return;
    end
    
    fprintf(' %d regiones', num_regiones);
    fprintf(' Clasificando...');
    
    resultados_lesiones = struct([]);
    propiedades = regionprops(etiquetas, img, 'Area', 'Perimeter', 'Eccentricity', ...
                              'Solidity', 'MajorAxisLength', 'MinorAxisLength', 'MeanIntensity');
    
    for i = 1:min(num_regiones, 20)
        area = propiedades(i).Area;
        if area < 50, continue; end
        
        perim = propiedades(i).Perimeter;
        compacidad = perim^2 / (4 * pi * area);
        excen = propiedades(i).Eccentricity;
        solidez = propiedades(i).Solidity;
        diametro = propiedades(i).MajorAxisLength;
        
        % Clasificación
        if solidez > 0.85 && excen < 0.6 && compacidad < 1.5
            clasificacion = 'Benigno';
            prob = 0.85;
            puntuacion = 1;
        elseif excen > 0.7 || compacidad > 1.8
            clasificacion = 'Maligno';
            prob = 0.80;
            puntuacion = 8;
        else
            clasificacion = 'Indeterminado';
            prob = 0.60;
            puntuacion = 5;
        end
        
        resultados_lesiones(i) = struct(...
            'ID', i, ...
            'Area', area, ...
            'Diametro', diametro, ...
            'Perimetro', perim, ...
            'Compacidad', compacidad, ...
            'Excentricidad', excen, ...
            'Solidez', solidez, ...
            'Clasificacion', clasificacion, ...
            'Probabilidad', prob, ...
            'Puntuacion_riesgo', puntuacion, ...
            'Confianza', prob);
    end
    
    fprintf(' ✓\n');
    
    metricas = struct();
    metricas.num_regiones_totales = num_regiones;
    metricas.num_lesiones_clasificadas = length(resultados_lesiones);
    if ~isempty(resultados_lesiones)
        metricas.num_malignas = sum(strcmp({resultados_lesiones.Clasificacion}, 'Maligno'));
        metricas.riesgo_promedio = mean([resultados_lesiones.Puntuacion_riesgo]);
    end
end

%% FUNCIÓN 7: DETECCIÓN DE MICROCALCIFICACIONES
function [microcalc, metricas] = detectar_microcalcificaciones_avanzadas(img, config)
    
    fprintf('   → Wavelet DWT...');
    
    img_norm = mat2gray(img);
    
    try
        [cA, cH, cV, cD] = dwt2(img_norm, 'db4');
        cD_enfatizado = cD * 3;
        img_det = idwt2(cA, cH, cV, cD_enfatizado, 'db4');
    catch
        img_det = img_norm;
    end
    
    fprintf(' Umbral...');
    
    umbral = graythresh(img_det) * 0.7;
    masc_micro = img_det > umbral;
    masc_micro = bwareaopen(masc_micro, 5);
    
    fprintf(' Análisis...');
    
    stats = regionprops(masc_micro, 'Centroid', 'Area');
    
    microcalc = struct();
    microcalc.numero = length(stats);
    
    if microcalc.numero > 0
        microcalc.ubicaciones = vertcat(stats.Centroid);
        microcalc.areas = [stats.Area];
        
        if microcalc.numero < 3
            microcalc.distribucion = 'Aisladas';
        elseif microcalc.numero < 10
            if microcalc.numero > 1
                dist_pares = pdist(microcalc.ubicaciones);
                if std(dist_pares) / mean(dist_pares) > 0.5
                    microcalc.distribucion = 'Dispersas';
                else
                    microcalc.distribucion = 'Agrupadas';
                end
            else
                microcalc.distribucion = 'Aisladas';
            end
        else
            microcalc.distribucion = 'Agrupadas';
        end
        
        microcalc.area_promedio = mean(microcalc.areas);
    else
        microcalc.distribucion = 'No detectadas';
        microcalc.ubicaciones = [];
        microcalc.areas = [];
    end
    
    fprintf(' ✓\n');
    
    metricas = struct();
    metricas.numero = microcalc.numero;
    metricas.distribucion = microcalc.distribucion;
end

%% FUNCIÓN 8: CÁLCULO DE RIESGO INTEGRADO
function [riesgo_integrado, prob_birads, categoria_final, alertas] = ...
    calcular_riesgo_integrado_final(pct_densidad, lesiones, microcalc, metricas_biomec, img, config)
    
    fprintf('   → Normalizando factores...');
    
    % Factores de riesgo
    factor_dens = min(pct_densidad / 25, 4) / 4;
    
    if ~isempty(lesiones)
        num_mal = sum(strcmp({lesiones.Clasificacion}, 'Maligno'));
        num_ind = sum(strcmp({lesiones.Clasificacion}, 'Indeterminado'));
        factor_les = min((num_mal*2 + num_ind*1) / 5, 1);
    else
        factor_les = 0;
    end
    
    factor_micro = min(microcalc.numero / 10, 1);
    
    if isfield(metricas_biomec, 'tension_max') && metricas_biomec.tension_max > 0
        factor_stress = min(metricas_biomec.tension_max / 15, 1);
    else
        factor_stress = 0;
    end
    
    fprintf(' Fusión...');
    
    % Fusión ponderada
    riesgo_integrado = (factor_dens*0.20 + factor_les*0.30 + factor_micro*0.15 + ...
                        factor_stress*0.15 + 0.20) * 10;
    riesgo_integrado = min(max(riesgo_integrado, 0), 10);
    
    fprintf(' BI-RADS...');
    
    % BI-RADS probabilístico
    if riesgo_integrado < 2
        prob_birads = [0.70, 0.20, 0.07, 0.02, 0.01, 0.00]';
    elseif riesgo_integrado < 4
        prob_birads = [0.30, 0.50, 0.15, 0.04, 0.01, 0.00]';
    elseif riesgo_integrado < 6
        prob_birads = [0.10, 0.20, 0.50, 0.15, 0.04, 0.01]';
    elseif riesgo_integrado < 8
        prob_birads = [0.05, 0.10, 0.20, 0.50, 0.10, 0.05]';
    else
        prob_birads = [0.02, 0.05, 0.10, 0.30, 0.40, 0.13]';
    end
    
    [~, categoria_idx] = max(prob_birads);
    categoria_final = categoria_idx - 1;
    
    fprintf(' Alertas...');
    
    alertas = {};
    
    if riesgo_integrado > 8
        alertas{end+1} = 'ALERTA CRÍTICA: Riesgo muy alto - Biopsia recomendada';
    end
    
    if pct_densidad > 75
        alertas{end+1} = 'ALERTA: Densidad extremadamente alta (BI-RADS D)';
    end
    
    if ~isempty(lesiones) && sum(strcmp({lesiones.Clasificacion}, 'Maligno')) > 0
        alertas{end+1} = 'ALERTA: Lesión maligna detectada';
    end
    
    if microcalc.numero > 20
        alertas{end+1} = 'ALERTA: Gran número de microcalcificaciones';
    end
    
    if isempty(alertas)
        alertas{1} = 'Sin alertas críticas - Seguimiento rutinario';
    end
    
    fprintf(' ✓\n');
end

%% FUNCIÓN 9: GENERACIÓN DE VISUALIZACIONES
function figuras = generar_visualizaciones_completas(img, masc, mapa_dens, tensiones, ...
                                                     lesiones, microcalc, diagnostico, ...
                                                     alertas, config)
    
    fprintf('   → Fig 1-3...');
    
    % Fig 1: Preprocesamiento
    fig1 = figure('Name', 'Fig1_Preprocesamiento', 'visible', 'off', 'Position', [100 100 1200 400]);
    subplot(1,3,1); imshow(img, []); title('Imagen Original');
    subplot(1,3,2); imshow(mat2gray(img), []); title('Normalizada');
    subplot(1,3,3); imshow(mat2gray(imgaussfilt(img, 2)), []); title('Filtrada');
    
    % Fig 2: Segmentación
    fig2 = figure('Name', 'Fig2_Segmentacion', 'visible', 'off', 'Position', [100 100 1200 400]);
    subplot(1,3,1); imshow(img, []); title('Original');
    subplot(1,3,2); imshow(masc); title('Máscara');
    subplot(1,3,3); imshow(img, []); hold on; contour(masc, 'r'); title('Superposición');
    
    % Fig 3: Densidad
    fig3 = figure('Name', 'Fig3_Densidad', 'visible', 'off', 'Position', [100 100 600 500]);
    if ~isempty(mapa_dens)
        imagesc(mapa_dens);
        colormap([0.9 0.9 0.9; 0.7 0.9 0.7; 1 0.8 0.4; 1 0.4 0.4]);
        colorbar;
        title(sprintf('Densidad: %.1f%%', diagnostico.densidad_porcentaje));
    end
    
    fprintf(' Fig 4-6...');
    
    % Fig 4: Biomecánica
    fig4 = figure('Name', 'Fig4_Biomecanica', 'visible', 'off', 'Position', [100 100 600 500]);
    if ~isempty(tensiones)
        imagesc(tensiones); colorbar;
        title('Tensiones (kPa)');
    end
    
    % Fig 5: Riesgo
    fig5 = figure('Name', 'Fig5_Riesgo', 'visible', 'off', 'Position', [100 100 600 400]);
    bar([diagnostico.riesgo_integrado, 10-diagnostico.riesgo_integrado]);
    ylabel('Score'); title(sprintf('Riesgo: %.1f/10', diagnostico.riesgo_integrado));
    
    % Fig 6: Diagnóstico
    fig6 = figure('Name', 'Fig6_Diagnostico', 'visible', 'off', 'Position', [100 100 800 600]);
    datos = {
        'Densidad', sprintf('%.1f%%', diagnostico.densidad_porcentaje);
        'BI-RADS Dens', diagnostico.categoria_birads_densidad;
        'BI-RADS Final', sprintf('%d', diagnostico.categoria_birads_final);
        'Riesgo', sprintf('%.2f/10', diagnostico.riesgo_integrado);
        'Lesiones', sprintf('%d', diagnostico.numero_lesiones);
        'Malignas', sprintf('%d', diagnostico.numero_malignas);
        'Microcalcs', sprintf('%d', microcalc.numero);
        'Tensión Max', sprintf('%.2f kPa', diagnostico.tension_maxima_kpa);
    };
    uitable(fig6, 'Data', datos, 'ColumnName', {'Parámetro', 'Valor'}, ...
            'Position', [0, 0, 1, 1]);
    
    fprintf(' Fig 7-9...');
    
    % Fig 7: Alertas
    fig7 = figure('Name', 'Fig7_Alertas', 'visible', 'off', 'Position', [100 100 800 400]);
    uitable(fig7, 'Data', alertas', 'ColumnName', {'Alerta'}, 'Position', [0, 0, 1, 1]);
    
    % Fig 8: Composición
    fig8 = figure('Name', 'Fig8_Composicion', 'visible', 'off', 'Position', [100 100 600 500]);
    pie([diagnostico.densidad_porcentaje, 100-diagnostico.densidad_porcentaje], ...
        {'Denso', 'Graso'}); title('Composición de Tejido');
    
    % Fig 9: BI-RADS
    fig9 = figure('Name', 'Fig9_BIRADS', 'visible', 'off', 'Position', [100 100 600 400]);
    bar(0:5, [0, 0.1, 0.2, 0.35, 0.25, 0.1]);
    xlabel('Categoría BI-RADS'); ylabel('Probabilidad');
    title('Distribución BI-RADS');
    
    fprintf(' ✓\n');
    
    figuras = [fig1, fig2, fig3, fig4, fig5, fig6, fig7, fig8, fig9];
end

%% FUNCIÓN 10: EXPORTACIÓN
function exportar_resultados_completos(resultados, figuras, config)
    
    fprintf('   → Creando carpeta...');
    
    if isfield(config, 'export') && isfield(config.export, 'carpeta_salida')
        carpeta = config.export.carpeta_salida;
    else
        carpeta = 'Resultados_Mamografia';
    end
    
    if ~exist(carpeta, 'dir')
        mkdir(carpeta);
    end
    
    fprintf(' Guardando datos...');
    
    % Guardar MAT
    save(fullfile(carpeta, 'resultados.mat'), 'resultados');
    
    % Guardar figuras PNG
    for i = 1:min(9, length(figuras))
        filename = fullfile(carpeta, sprintf('fig_%d.png', i));
        savefig(figuras(i), filename);
        close(figuras(i));
    end
    
    fprintf(' Informe...');
    
    % Informe TXT
    fid = fopen(fullfile(carpeta, 'informe_diagnostico.txt'), 'w');
    fprintf(fid, '=====================================\n');
    fprintf(fid, 'INFORME DE ANÁLISIS MAMOGRÁFICO\n');
    fprintf(fid, '=====================================\n\n');
    fprintf(fid, 'RESULTADOS:\n');
    fprintf(fid, 'Densidad: %.1f%% (BI-RADS %s)\n', ...
            resultados.diagnostico.densidad_porcentaje, ...
            resultados.diagnostico.categoria_birads_densidad);
    fprintf(fid, 'BI-RADS Final: Categoría %d\n', resultados.diagnostico.categoria_birads_final);
    fprintf(fid, 'Riesgo Integrado: %.2f / 10\n', resultados.diagnostico.riesgo_integrado);
    fprintf(fid, 'Lesiones: %d (Malignas: %d)\n', ...
            resultados.diagnostico.numero_lesiones, resultados.diagnostico.numero_malignas);
    fprintf(fid, 'Microcalcificaciones: %d\n', resultados.diagnostico.microcalcificaciones);
    fprintf(fid, '\nFecha: %s\n', datestr(resultados.fecha_analisis));
    fclose(fid);
    
    fprintf(' ✓\n');
end
