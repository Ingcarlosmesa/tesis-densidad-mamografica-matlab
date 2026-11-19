%% SISTEMA UNIFICADO DE ANÁLISIS DICOM PARA CÁNCER DE MAMA
% Versión mejorada con 9 figuras completas y procesamiento optimizado

clear all; close all; clc;

%% CONFIGURACIÓN DEL SISTEMA UNIFICADO
disp('=== SISTEMA UNIFICADO LIBRA + ANÁLISIS AVANZADO PARA CÁNCER DE MAMA ===');
disp('Integrando: Densidad LIBRA + Modelado biomecánico + Correlación multimodal');

% Parámetros del sistema mejorados
config.umbral_area_minima = 1000; % Aumentado para mejor filtrado
config.umbral_compacidad_maligna = 1.3;
config.umbral_diametro_maligno = 150;
config.realce = 0.6;
config.umbralbin_tophat = 0.15; % Ajustado
config.r_tophat = 30; % Aumentado

% Parámetros de modelos biomecánicos (basados en Wellman 1999)
config.modelo_biomecanico.young_glandular = 15.1; % kPa
config.modelo_biomecanico.young_adipose = 4.46;   % kPa
config.modelo_biomecanico.poisson_ratio = 0.45;
config.modelo_biomecanico.compression_factor = 0.7;

%% CARGA Y PROCESAMIENTO DE DATOS DICOM
try
    fprintf('\n=== CARGA DE DATOS DICOM ===\n');
    
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

%% PROCESAMIENTO UNIFICADO DE IMÁGENES MEJORADO
disp('Realizando procesamiento unificado de imágenes...');

% Determinar dimensiones y seleccionar imagen para análisis
if ndims(volumen_dicom) > 2
    if size(volumen_dicom, 3) > 1
        slice_idx = round(size(volumen_dicom, 3) / 2);
        imagen_actual = volumen_dicom(:, :, slice_idx);
        fprintf('Analizando slice %d de %d\n', slice_idx, size(volumen_dicom, 3));
    else
        imagen_actual = volumen_dicom;
    end
else
    imagen_actual = volumen_dicom;
end

% Aplicar normalización DICOM si está disponible
if isfield(info, 'RescaleSlope') && isfield(info, 'RescaleIntercept')
    imagen_normalizada = single(imagen_actual);
    imagen_normalizada = imagen_normalizada * info.RescaleSlope + info.RescaleIntercept;
else
    imagen_normalizada = single(imagen_actual);
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
        % Usar percentiles para mejor contraste
        p_low = prctile(imagen_normalizada(:), 2);
        p_high = prctile(imagen_normalizada(:), 98);
        imagen_para_procesar = uint8(255 * mat2gray(imagen_normalizada, [p_low, p_high]));
    end
catch
    p_low = prctile(imagen_normalizada(:), 2);
    p_high = prctile(imagen_normalizada(:), 98);
    imagen_para_procesar = uint8(255 * mat2gray(imagen_normalizada, [p_low, p_high]));
end

%% PREPROCESAMIENTO AVANZADO COMBINADO MEJORADO
disp('Realizando preprocesamiento avanzado...');

% Convertir a escala de grises adecuada
if size(imagen_para_procesar, 3) == 3
    imagen_gris = rgb2gray(imagen_para_procesar);
else
    imagen_gris = imagen_para_procesar;
end

% Procesamiento en cadena mejorado
imagen_filtrada = medfilt2(imagen_gris, [7 7], 'symmetric'); % Tamaño aumentado
imagen_contraste = imadjust(imagen_filtrada, stretchlim(imagen_filtrada), []);
imagen_ecualizada = adapthisteq(imagen_contraste); % CLAHE mejorado
imagen_suavizada = imgaussfilt(imagen_ecualizada, 2); % Suavizado aumentado

%% SEGMENTACIÓN MEJORADA CON TÉCNICAS COMBINADAS
disp('Realizando segmentación avanzada...');

% Técnica 1: Segmentación adaptativa mejorada
mascara_adaptativa = imbinarize(imagen_suavizada, 'adaptive', 'Sensitivity', 0.55);

% Técnica 2: Top-hat mejorada
itoh = double(imagen_suavizada) * 6; % Factor reducido
itoh = uint8(min(itoh, 255));
se = strel('disk', config.r_tophat);
otoh = imtophat(itoh, se);
oehc = imadjust(otoh, [0 config.realce], [0 1]);
mascara_tophat = imbinarize(oehc, config.umbralbin_tophat);

% Combinar técnicas de segmentación
mascara_combinada = mascara_adaptativa | mascara_tophat;

% Limpieza morfológica mejorada
elemento_estructurante = strel('disk', 6); % Aumentado
mascara_limpia = imopen(mascara_combinada, elemento_estructurante);
mascara_limpia = imclose(mascara_limpia, elemento_estructurante);
mascara_final = bwareaopen(mascara_limpia, config.umbral_area_minima);
mascara_final = imfill(mascara_final, 'holes');

% Eliminar objetos muy grandes que podrían ser artefactos
estadisticas = regionprops(mascara_final, 'Area');
areas = [estadisticas.Area];
umbral_area_maxima = 0.3 * numel(mascara_final); % 30% del área total
mascara_final = bwareaopen(mascara_final, config.umbral_area_minima);
for i = 1:length(estadisticas)
    if areas(i) > umbral_area_maxima
        mascara_final = mascara_final & ~bwselect(mascara_final, round(estadisticas(i).Centroid(1)), round(estadisticas(i).Centroid(2)));
    end
end

%% ANÁLISIS DE TEJIDO GLANDULAR Y MODELADO BIOMECÁNICO MEJORADO
disp('=== ANÁLISIS AVANZADO DE TEJIDO GLANDULAR Y MODELADO BIOMECÁNICO ===');

% Generar mapa de densidad cuantitativa MEJORADO
mapa_densidad = generarMapaDensidadMejorado(imagen_suavizada, mascara_final);
metricas_densidad = calcularMetricasDensidad(mapa_densidad, mascara_final);

% Generar modelo biomecánico
[modelo_biomecanico, deformaciones] = generarModeloBiomecanico(...
    imagen_suavizada, mapa_densidad, config.modelo_biomecanico);

%% ANÁLISIS DE REGIONES Y CLASIFICACIÓN MEJORADA
disp('Analizando regiones y clasificando...');

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
        area_actual = propiedades(i).Area;
        perimetro_actual = propiedades(i).Perimeter;
        excentricidad_actual = propiedades(i).Eccentricity;
        solidez_actual = propiedades(i).Solidity;
        diametro_mayor = propiedades(i).MajorAxisLength;
        
        % CLASIFICACIÓN MEJORADA CON CRITERIOS MÁS ESPECÍFICOS
        if area_actual > 10000  % Umbral aumentado para tumores reales
            clasificacion = 'Tumor';
            puntuacion_riesgo = 4;
            lesiones_tumor = [lesiones_tumor, i];
        elseif area_actual >= 500 && area_actual <= 10000
            % Criterios mejorados para benignos
            if excentricidad_actual <= 0.6 && solidez_actual > 0.85 && diametro_mayor < 300
                clasificacion = 'Benigno';
                puntuacion_riesgo = 1;
                lesiones_benignas = [lesiones_benignas, i];
            % Criterios mejorados para malignos
            elseif excentricidad_actual >= 0.7 || (solidez_actual < 0.6 && diametro_mayor > 200)
                clasificacion = 'Maligno';
                puntuacion_riesgo = 3;
                lesiones_malignas = [lesiones_malignas, i];
            else
                clasificacion = 'Indeterminado';
                puntuacion_riesgo = 2;
                lesiones_indeterminadas = [lesiones_indeterminadas, i];
            end
        else
            clasificacion = 'Ruido';
            puntuacion_riesgo = 0;
        end
        
        % Calcular métricas adicionales
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
            'PuntuacionRiesgo', puntuacion_riesgo);
        
        resultados = [resultados, resultado_region];
    end
end

%% DIAGNÓSTICO INTEGRADO MEJORADO
disp('Generando diagnóstico integrado...');

% Calcular puntuación general mejorada
if ~isempty(resultados)
    puntuacion_total = sum([resultados.PuntuacionRiesgo]);
    num_lesiones_total = length(resultados);
    num_benignas = length(lesiones_benignas);
    num_malignas = length(lesiones_malignas);
    num_indeterminadas = length(lesiones_indeterminadas);
    num_tumores = length(lesiones_tumor);
    
    % DETERMINAR DIAGNÓSTICO GENERAL MEJORADO CON CRITERIOS MÁS CONSERVADORES
    if num_tumores >= 1 || (num_malignas >= 3 && puntuacion_total >= 8)
        diagnostico = 'ALTA SOSPECHA DE MALIGNIDAD';
        color_diagnostico = [1 0 0]; % Rojo
        recomendacion = {'• Biopsia inmediata recomendada'; 
                        '• Consulta urgente con especialista oncólogo';
                        '• Realizar estudios complementarios (ecografía, resonancia)';
                        '• No posponer la evaluación'};
    elseif (num_malignas >= 2 && puntuacion_total >= 6) || (num_tumores >= 1 && num_malignas >= 1)
        diagnostico = 'SOSPECHA DE MALIGNIDAD MODERADA-ALTA';
        color_diagnostico = [1 0.4 0]; % Naranja-rojo
        recomendacion = {'• Evaluación oncológica prioritaria';
                        '• Mamografía de seguimiento en 1-3 meses';
                        '• Considerar biopsia según evaluación clínica';
                        '• Monitoreo estrecho requerido'};
    elseif num_malignas >= 1 || puntuacion_total >= 5
        diagnostico = 'SOSPECHA DE MALIGNIDAD';
        color_diagnostico = [1 0.5 0]; % Naranja
        recomendacion = {'• Evaluación oncológica necesaria';
                        '• Mamografía de seguimiento en 3-6 meses';
                        '• Considerar estudios complementarios';
                        '• Monitoreo cercano recomendado'};
    elseif num_benignas > 2 && num_malignas == 0 && num_tumores == 0
        diagnostico = 'HALLAZGOS PROBABLEMENTE BENIGNOS';
        color_diagnostico = [0 0.8 0]; % Verde
        recomendacion = {'• Seguimiento rutinario según protocolo';
                        '• Revisión anual recomendada';
                        '• Monitorear cambios en próximos controles';
                        '• Mantener estilo de vida saludable'};
    elseif num_indeterminadas > num_lesiones_total * 0.7
        diagnostico = 'HALLAZGOS INDETERMINADOS - REQUIERE REVISIÓN';
        color_diagnostico = [1 1 0]; % Amarillo
        recomendacion = {'• Requiere evaluación adicional por especialista';
                        '• Repetir estudio en 3-6 meses';
                        '• Considerar evaluación con experto en imagen mamaria';
                        '• No ignorar los hallazgos'};
    else
        diagnostico = 'HALLAZGOS NORMALES';
        color_diagnostico = [0 0 1]; % Azul
        recomendacion = {'• Continuar con screening rutinario';
                        '• No se detectaron anomalías significativas';
                        '• Próximo control según edad y factores';
                        '• Mantener hábitos de prevención'};
    end
else
    diagnostico = 'SIN HALLAZGOS DETECTABLES';
    color_diagnostico = [0.5 0.5 0.5]; % Gris
    recomendacion = {'• No se detectaron lesiones significativas';
                    '• Continuar con revisiones preventivas';
                    '• Seguir protocolo establecido de screening'};
    puntuacion_total = 0;
    num_lesiones_total = 0;
    num_benignas = 0;
    num_malignas = 0;
    num_indeterminadas = 0;
    num_tumores = 0;
end

%% VISUALIZACIONES UNIFICADAS - 9 FIGURAS COMPLETAS

% Figura 1: Procesamiento básico de imágenes
fig1 = visualizarProcesamientoBasico(imagen_actual, imagen_suavizada, oehc, ...
    mascara_final, mascara_adaptativa, imagen_ecualizada, num_regiones, info);

% Figura 2: Análisis de densidad y textura
fig2 = visualizarDensidadTextura(imagen_suavizada, mascara_final, mapa_densidad, metricas_densidad);

% Figura 3: Modelo biomecánico
fig3 = visualizarModeloBiomecanico(imagen_suavizada, mapa_densidad, modelo_biomecanico, metricas_densidad);

% Figura 4: Mapa de riesgo integrado
fig4 = visualizarRiesgoIntegrado(imagen_suavizada, mascara_final, mapa_densidad, ...
    modelo_biomecanico, resultados, diagnostico, color_diagnostico, recomendacion);

% Figura 5: Correlación multimodal
fig5 = visualizarCorrelacionMultimodal(resultados, deformaciones, metricas_densidad, config);

% Figura 6: Lesiones Detectadas y Clasificadas
fig6 = visualizarLesionesDetectadas(imagen_suavizada, mascara_final, resultados, etiquetas);

% Figura 7: Tabla de Características Detalladas
fig7 = visualizarTablaCaracteristicas(resultados);

% Figura 8: Análisis Estadístico y Distribución
fig8 = visualizarAnalisisEstadistico(imagen_suavizada, mascara_final, resultados, etiquetas);

% Figura 9: Resumen Clínico
fig9 = visualizarResumenClinico(resultados, diagnostico, recomendacion, puntuacion_total);

%% GENERACIÓN DE INFORME UNIFICADO MEJORADO
disp('=== GENERANDO INFORME UNIFICADO ===');
generarInformeUnificado(info, resultados, diagnostico, recomendacion, ...
    metricas_densidad, modelo_biomecanico, puntuacion_total, num_lesiones_total);

fprintf('\n=== ANÁLISIS UNIFICADO COMPLETADO ===\n');
fprintf('Sistema generó 9 figuras completas de análisis\n');
fprintf('Integración: Procesamiento avanzado + Modelado biomecánico + Correlación multimodal\n');

%% FUNCIONES AUXILIARES MEJORADAS

function mapa_densidad = generarMapaDensidadMejorado(imagen, mascara)
    % Generar mapa de densidad cuantitativa MEJORADO
    mascara_mama = imfill(mascara, 'holes');
    
    % Usar múltiples umbrales adaptativos para mejor segmentación
    nivel1 = graythresh(imagen(mascara_mama)) * 0.7;
    nivel2 = graythresh(imagen(mascara_mama)) * 1.3;
    
    mapa_densidad = zeros(size(imagen));
    
    % Tejido graso (baja densidad)
    mapa_densidad(mascara_mama & imagen < nivel1 * max(imagen(:))) = 1;
    
    % Tejido intermedio
    mapa_densidad(mascara_mama & imagen >= nivel1 * max(imagen(:)) & ...
                  imagen < nivel2 * max(imagen(:))) = 2;
    
    % Tejido denso (alta densidad)
    mapa_densidad(mascara_mama & imagen >= nivel2 * max(imagen(:))) = 3;
    
    % Aplicar suavizado para transiciones realistas
    mapa_densidad = imgaussfilt(mapa_densidad, 1.5);
end

function metricas = calcularMetricasDensidad(mapa_densidad, mascara)
    % Calcular métricas cuantitativas de densidad
    mascara_mama = imfill(mascara, 'holes');
    area_total = sum(mascara_mama(:));
    
    if area_total == 0
        metricas.porcentaje_densidad = 0;
        metricas.area_total = 0;
        metricas.area_densa = 0;
        metricas.area_grasa = 0;
        metricas.birads_categoria = 'a';
        metricas.birads_descripcion = 'No se pudo calcular';
        return;
    end
    
    % Áreas de tejido específico
    area_graso = sum(mapa_densidad(mascara_mama) == 1);
    area_intermedio = sum(mapa_densidad(mascara_mama) == 2);
    area_denso = sum(mapa_densidad(mascara_mama) == 3);
    
    % Porcentaje considerando tejido intermedio como parcialmente denso
    metricas.porcentaje_densidad = ((area_denso + area_intermedio * 0.5) / area_total) * 100;
    metricas.area_total = area_total;
    metricas.area_densa = area_denso + area_intermedio;
    metricas.area_grasa = area_graso;
    
    % Clasificación BI-RADS de densidad MEJORADA
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
end

function [modelo, deformaciones] = generarModeloBiomecanico(imagen, mapa_densidad, config)
    % Generar modelo biomecánico simplificado del tejido mamario
    
    fprintf('Generando modelo biomecánico...\n');
    
    modelo = struct();
    
    % Segmentación de tejidos para el modelo
    mascara_mama = mapa_densidad > 0;
    mascara_glandular = mapa_densidad >= 2; % Incluye intermedio y denso
    mascara_adiposo = mapa_densidad == 1;
    
    % Propiedades del material basadas en la tesis
    modelo.propiedades.young_glandular = config.young_glandular;
    modelo.propiedades.young_adipose = config.young_adipose;
    modelo.propiedades.poisson_ratio = config.poisson_ratio;
    
    % Geometría del modelo
    [filas, columnas] = size(imagen);
    modelo.geometria.filas = filas;
    modelo.geometria.columnas = columnas;
    modelo.geometria.area_total = sum(mascara_mama(:));
    modelo.geometria.area_glandular = sum(mascara_glandular(:));
    modelo.geometria.area_adiposa = sum(mascara_adiposo(:));
    
    % Simular deformación por compresión
    deformaciones = simularDeformacionCompresion(mapa_densidad, config.compression_factor);
    
    % Calcular tensiones biomecánicas
    modelo.tensiones = calcularTensionesBiomecanicas(mapa_densidad, deformaciones, config);
    
    fprintf('Modelo biomecánico generado: %d elementos\n', modelo.geometria.area_total);
end

function deformaciones = simularDeformacionCompresion(mapa_densidad, factor_compresion)
    % Simular deformación por compresión mamográfica
    [filas, columnas] = size(mapa_densidad);
    
    % Crear campo de desplazamiento simulado
    [X, Y] = meshgrid(1:columnas, 1:filas);
    centro_x = columnas / 2;
    centro_y = filas / 2;
    
    % Deformación radial (compresión desde los bordes)
    distancia_centro = sqrt((X - centro_x).^2 + (Y - centro_y).^2);
    max_distancia = sqrt(centro_x^2 + centro_y^2);
    
    % Factor de compresión dependiente de la distancia al centro
    factor_radial = 1 - factor_compresion * (distancia_centro / max_distancia);
    
    % Aplicar deformación (simplificado)
    deformaciones.desp_x = (X - centro_x) .* (1 - factor_radial) * 0.1;
    deformaciones.desp_y = (Y - centro_y) .* (1 - factor_radial) * 0.1;
    deformaciones.factor_compresion = factor_radial;
end

function tensiones = calcularTensionesBiomecanicas(mapa_densidad, deformaciones, config)
    % Calcular tensiones biomecánicas simplificadas
    
    [filas, columnas] = size(mapa_densidad);
    tensiones.maxima = zeros(filas, columnas);
    tensiones.media = zeros(filas, columnas);
    tensiones.gradiente = zeros(filas, columnas);
    
    % Calcular gradientes de deformación
    [grad_x, grad_y] = gradient(deformaciones.factor_compresion);
    
    for i = 1:filas
        for j = 1:columnas
            if mapa_densidad(i, j) > 0
                % Tensión dependiente del tipo de tejido y deformación
                if mapa_densidad(i, j) >= 2 % Tejido glandular e intermedio
                    E = config.young_glandular;
                else % Tejido adiposo
                    E = config.young_adipose;
                end
                
                % Tensión simplificada (Ley de Hooke)
                deformacion_local = 1 - deformaciones.factor_compresion(i, j);
                tensiones.maxima(i, j) = E * deformacion_local;
                
                % Considerar gradientes de deformación
                gradiente_local = sqrt(grad_x(i, j)^2 + grad_y(i, j)^2);
                tensiones.gradiente(i, j) = E * gradiente_local;
            end
        end
    end
    
    tensiones.media = tensiones.maxima / 2;
end

function fig = visualizarProcesamientoBasico(imagen_actual, imagen_suavizada, oehc, ...
    mascara_final, mascara_adaptativa, imagen_ecualizada, num_regiones, info)
    
    fig = figure('Name', 'Figura 1 - Procesamiento de Imágenes DICOM', ...
           'Position', [50 50 1400 900], ...
           'Color', [0.95 0.95 0.95], ...
           'NumberTitle', 'off');

    % 1. Imagen DICOM original
    subplot(2, 3, 1);
    imshow(imagen_actual, []);
    title('A) Imagen DICOM Original', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    colorbar('southoutside');

    % 2. Imagen preprocesada
    subplot(2, 3, 2);
    imshow(imagen_suavizada, []);
    title('B) Imagen Preprocesada', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    colorbar('southoutside');

    % 3. Segmentación Top-hat
    subplot(2, 3, 3);
    imshow(oehc, []);
    title('C) Segmentación Top-hat', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    colorbar('southoutside');

    % 4. Máscara binaria
    subplot(2, 3, 4);
    imshow(mascara_final);
    title(['D) Máscara Final (', num2str(num_regiones), ' regiones)'], ...
          'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);

    % 5. Segmentación adaptativa
    subplot(2, 3, 5);
    imshow(mascara_adaptativa);
    title('E) Segmentación Adaptativa', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);

    % 6. Imagen mejorada para análisis
    subplot(2, 3, 6);
    imshow(imagen_ecualizada, []);
    title('F) Imagen Ecualizada Mejorada', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    colorbar('southoutside');

    % Añadir texto informativo - CORREGIDO
    [~, nombreArchivo, extension] = fileparts(info.Filenames{1});
    nombreArchivoCompleto = [nombreArchivo extension];
    
    annotation('textbox', [0.02 0.02 0.96 0.04], 'String', ...
               sprintf('Archivo: %s | Modalidad: %s | Dimensiones: %dx%d | Regiones detectadas: %d', ...
               nombreArchivoCompleto, info.Modality, size(imagen_actual,1), size(imagen_actual,2), num_regiones), ...
               'FontSize', 10, 'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
               'BackgroundColor', [0.9 0.9 0.9], 'FontWeight', 'bold', 'Interpreter', 'none');
end

function fig = visualizarDensidadTextura(imagen_suavizada, mascara_final, mapa_densidad, metricas)
    fig = figure('Name', 'Figura 2 - Mapa de Densidad y Análisis de Textura', ...
           'Position', [100 100 1400 700], ...
           'Color', [1 1 1], ...
           'NumberTitle', 'off');

    %% PANEL IZQUIERDO: MAPA DE DENSIDAD CUANTITATIVA MEJORADO
    subplot(1, 2, 1);

    imagesc(mapa_densidad);
    colormap([0.9 0.9 0.9; 0.7 0.9 0.7; 1.0 0.8 0.4; 1.0 0.4 0.4]); % 4 colores
    caxis([0 3]);
    colorbar('Ticks', [0.375, 1.125, 1.875, 2.625], ...
             'TickLabels', {'Fondo', 'Tejido Graso', 'Tejido Intermedio', 'Tejido Denso'});
    axis image;
    title('MAPA DE DENSIDAD CUANTITATIVA MEJORADO', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0 0 0.6]);

    % Clasificación BI-RADS
    if metricas.porcentaje_densidad < 25
        clasificacion_birads = 'CATEGORÍA a: Casi completamente grasa';
        color_birads = [0 0.7 0];
    elseif metricas.porcentaje_densidad < 50
        clasificacion_birads = 'CATEGORÍA b: Densidades dispersas';
        color_birads = [0 0.5 0.8];
    elseif metricas.porcentaje_densidad < 75
        clasificacion_birads = 'CATEGORÍA c: Heterogéneamente densa';
        color_birads = [1 0.6 0.2];
    else
        clasificacion_birads = 'CATEGORÍA d: Extremadamente densa';
        color_birads = [1 0.2 0.2];
    end

    % Información de densidad MEJORADA - POSICIÓN CORREGIDA
    info_densidad = {
        sprintf('Porcentaje de densidad: %.1f%%', metricas.porcentaje_densidad)
        sprintf('Área total: %d píxeles', metricas.area_total)
        sprintf('Área densa: %d píxeles', metricas.area_densa)
        sprintf('Área grasa: %d píxeles', metricas.area_grasa)
    };

    % Texto reposicionado para mejor visibilidad
    text(0.02, 0.98, info_densidad, 'Units', 'normalized', 'FontSize', 11, 'FontWeight', 'bold', ...
         'Color', [0 0 0.5], 'VerticalAlignment', 'top', ...
         'BackgroundColor', [1 1 1 0.9], 'EdgeColor', [0 0 0.5], 'Margin', 3);

    text(0.02, 0.02, clasificacion_birads, 'Units', 'normalized', ...
         'FontSize', 12, 'FontWeight', 'bold', 'Color', color_birads, ...
         'VerticalAlignment', 'bottom', 'BackgroundColor', [1 1 1 0.9], 'Margin', 3);

    %% PANEL DERECHO: ANÁLISIS DE TEXTURA PARENQUIMATOSA MEJORADO - REORGANIZADO
    subplot(1, 2, 2);
    axis off;

    % Fondo con diseño profesional MEJORADO
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 3, 'Curvature', 0.02);

    % Título MEJORADO
    text(0.5, 0.92, 'ANÁLISIS CUANTITATIVO DE TEXTURA', 'Units', 'normalized', ...
         'FontSize', 16, 'FontWeight', 'bold', 'Color', [0.1 0.3 0.5], ...
         'HorizontalAlignment', 'center');

    % Extraer características de textura MEJORADO
    mascara_mama = imfill(mascara_final, 'holes');
    if any(mascara_mama(:))
        region_textura = imagen_suavizada;
        region_textura(~mascara_mama) = 0;

        [GLCM, ~] = graycomatrix(region_textura, 'Offset', [0 1; -1 1; -1 0; -1 -1], ...
                                 'NumLevels', 16, 'GrayLimits', []);
        props_glcm = graycoprops(GLCM, {'contrast', 'correlation', 'energy', 'homogeneity'});

        hist_vals = region_textura(region_textura > 0);
        if ~isempty(hist_vals)
            skewness_val = skewness(double(hist_vals));
            kurtosis_val = kurtosis(double(hist_vals));
            entropy_val = entropy(region_textura);
            roughness = std(double(hist_vals)) / mean(double(hist_vals));
        else
            skewness_val = 0;
            kurtosis_val = 0;
            entropy_val = 0;
            roughness = 0;
        end
    else
        % Valores por defecto si no hay máscara
        props_glcm.Contrast = 0;
        props_glcm.Correlation = 0;
        props_glcm.Energy = 0;
        props_glcm.Homogeneity = 0;
        skewness_val = 0;
        kurtosis_val = 0;
        entropy_val = 0;
        roughness = 0;
    end

    %% CUADRO 1: CARACTERÍSTICAS DE TEXTURA GLCM - POSICIÓN CORREGIDA
    rectangle('Position', [0.08 0.70 0.84 0.18], 'FaceColor', [0.95 0.96 1], ...
              'EdgeColor', [0.2 0.3 0.6], 'LineWidth', 2, 'Curvature', 0.02);

    text(0.5, 0.86, 'CARACTERÍSTICAS DE TEXTURA', 'Units', 'normalized', ...
         'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', [0.1 0.2 0.5]);

    % Métricas GLCM organizadas en dos columnas
    glcm_left = {
        sprintf('Contraste:    %.3f', mean(props_glcm.Contrast))
        sprintf('Correlación:  %.3f', mean(props_glcm.Correlation))
    };
    
    glcm_right = {
        sprintf('Energía:      %.3f', mean(props_glcm.Energy))
        sprintf('Homogeneidad: %.3f', mean(props_glcm.Homogeneity))
    };

    text(0.15, 0.78, glcm_left, 'Units', 'normalized', 'FontSize', 12, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.2 0.2 0.4]);

    text(0.55, 0.78, glcm_right, 'Units', 'normalized', 'FontSize', 12, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.2 0.2 0.4]);

    %% CUADRO 2: ANÁLISIS ESTADÍSTICO - POSICIÓN CORREGIDA
    rectangle('Position', [0.08 0.45 0.84 0.18], 'FaceColor', [0.96 0.98 0.96], ...
              'EdgeColor', [0.2 0.5 0.3], 'LineWidth', 2, 'Curvature', 0.02);

    text(0.5, 0.61, 'ANÁLISIS ESTADÍSTICO', 'Units', 'normalized', ...
         'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', [0.1 0.4 0.2]);

    % Métricas estadísticas organizadas
    stats_left = {
        sprintf('Asimetría:   %.3f', skewness_val)
        sprintf('Curtosis:    %.3f', kurtosis_val)
    };
    
    stats_right = {
        sprintf('Entropía:    %.3f', entropy_val)
        sprintf('Rugosidad:   %.3f', roughness)
    };

    text(0.15, 0.53, stats_left, 'Units', 'normalized', 'FontSize', 12, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.2 0.3 0.2]);

    text(0.55, 0.53, stats_right, 'Units', 'normalized', 'FontSize', 12, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.2 0.3 0.2]);

    %% CUADRO 3: INTERPRETACIÓN - POSICIÓN CORREGIDA
    % Determinar interpretación basada en entropía
    if entropy_val > 6
        interpretacion = 'TEXTURA COMPLEJA - Mayor heterogeneidad parenquimatosa';
        color_interp = [0.8 0.2 0.2];
        bg_color = [1 0.95 0.95];
    elseif entropy_val > 4
        interpretacion = 'TEXTURA MODERADA - Heterogeneidad media';
        color_interp = [1 0.6 0.2];
        bg_color = [1 0.97 0.95];
    else
        interpretacion = 'TEXTURA SIMPLE - Baja heterogeneidad';
        color_interp = [0.2 0.6 0.2];
        bg_color = [0.95 1 0.95];
    end

    rectangle('Position', [0.08 0.20 0.84 0.18], 'FaceColor', bg_color, ...
              'EdgeColor', color_interp, 'LineWidth', 3, 'Curvature', 0.03);

    text(0.5, 0.34, 'INTERPRETACIÓN', 'Units', 'normalized', ...
         'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', color_interp);

    text(0.5, 0.28, interpretacion, 'Units', 'normalized', ...
         'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', color_interp);

    %% INFORMACIÓN ADICIONAL MEJORADA
    info_adicional = {
        'Nota: La entropía mide la complejidad de la textura.'
        'Valores altos sugieren mayor heterogeneidad del tejido.'
    };

    text(0.5, 0.12, info_adicional, 'Units', 'normalized', ...
         'FontSize', 10, 'FontWeight', 'normal', 'HorizontalAlignment', 'center', ...
         'Color', [0.4 0.4 0.4], 'BackgroundColor', [1 1 1 0.8]);
end

function fig = visualizarModeloBiomecanico(imagen, mapa_densidad, modelo, metricas)
    fig = figure('Name', 'Figura 3 - Modelo Biomecánico y Análisis de Tensión', ...
           'Position', [150 50 1400 900], 'Color', [1 1 1]);

    % 1. Mapa de densidad con superposición de tensiones MEJORADO
    subplot(2, 3, 1);
    imagesc(mapa_densidad);
    hold on;
    % Mostrar áreas de alta tensión
    if any(modelo.tensiones.maxima(:) > 0)
        alta_tension = modelo.tensiones.maxima > prctile(modelo.tensiones.maxima(modelo.tensiones.maxima > 0), 75);
        [contornos_y, contornos_x] = find(bwperim(alta_tension));
        plot(contornos_x, contornos_y, 'r.', 'MarkerSize', 2);
    end
    colormap([0.9 0.9 0.9; 0.7 0.9 0.7; 1.0 0.8 0.4; 1.0 0.4 0.4]);
    caxis([0 3]);
    colorbar;
    title('A) Mapa de Densidad + Áreas de Alta Tensión', 'FontSize', 12, 'FontWeight', 'bold');

    % 2. Campo de tensiones
    subplot(2, 3, 2);
    if any(modelo.tensiones.maxima(:) > 0)
        imagesc(modelo.tensiones.maxima);
        colorbar;
    else
        imagesc(zeros(size(imagen)));
    end
    title('B) Campo de Tensiones Máximas (kPa)', 'FontSize', 12, 'FontWeight', 'bold');

    % 3. Distribución de tensiones
    subplot(2, 3, 3);
    if any(modelo.tensiones.maxima(:) > 0)
        tensiones_validas = modelo.tensiones.maxima(modelo.tensiones.maxima > 0);
        histogram(tensiones_validas, 50, 'FaceColor', [0.8 0.2 0.2], 'EdgeColor', 'black');
    else
        histogram(0);
    end
    xlabel('Tensión (kPa)');
    ylabel('Frecuencia');
    title('C) Distribución de Tensiones', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;

    % 4. Gradientes de tensión
    subplot(2, 3, 4);
    if any(modelo.tensiones.gradiente(:) > 0)
        imagesc(modelo.tensiones.gradiente);
        colorbar;
    else
        imagesc(zeros(size(imagen)));
    end
    title('D) Gradientes de Tensión', 'FontSize', 12, 'FontWeight', 'bold');

    % 5. Información del modelo MEJORADA
    subplot(2, 3, 5);
    axis off;
    
    if modelo.geometria.area_total > 0
        relacion_glandular = (modelo.geometria.area_glandular/modelo.geometria.area_total)*100;
    else
        relacion_glandular = 0;
    end
    
    modelo_text = {
        'PROPIEDADES DEL MODELO BIOMECÁNICO'
        '─────────────────────────────────'
        sprintf('Módulo glandular:   %.1f kPa', modelo.propiedades.young_glandular)
        sprintf('Módulo adiposo:     %.1f kPa', modelo.propiedades.young_adipose)
        sprintf('Coef. Poisson:      %.2f', modelo.propiedades.poisson_ratio)
        ''
        'GEOMETRÍA DEL TEJIDO:'
        sprintf('Área total:         %d px', modelo.geometria.area_total)
        sprintf('Área glandular:     %d px', modelo.geometria.area_glandular)
        sprintf('Área adiposa:       %d px', modelo.geometria.area_adiposa)
        sprintf('Relación glandular: %.1f%%', relacion_glandular)
        ''
        'ANÁLISIS DE TENSIONES:'
    };
    
    if any(modelo.tensiones.maxima(:) > 0)
        tensiones_validas = modelo.tensiones.maxima(modelo.tensiones.maxima > 0);
        modelo_text = [modelo_text; {
            sprintf('Tensión máxima:     %.2f kPa', max(tensiones_validas))
            sprintf('Tensión media:      %.2f kPa', mean(tensiones_validas))
            sprintf('Desv. estándar:     %.2f kPa', std(tensiones_validas))
        }];
    else
        modelo_text = [modelo_text; {
            'No hay datos de tensión'
        }];
    end
    
    text(0.1, 0.9, modelo_text, 'Units', 'normalized', 'FontSize', 10, ...
         'FontName', 'Monospaced', 'VerticalAlignment', 'top', 'FontWeight', 'bold');

    % 6. Visualización 3D simplificada de tensiones
    subplot(2, 3, 6);
    if any(modelo.tensiones.maxima(:) > 0)
        surf(modelo.tensiones.maxima(1:10:end, 1:10:end), 'EdgeColor', 'none');
        title('E) Superficie de Tensiones (submuestreado)', 'FontSize', 12, 'FontWeight', 'bold');
        zlabel('Tensión (kPa)');
    else
        surf(zeros(10,10));
        title('E) Sin datos de tensión', 'FontSize', 12, 'FontWeight', 'bold');
    end
end

function fig = visualizarRiesgoIntegrado(imagen_suavizada, mascara_final, mapa_densidad, ...
    modelo_biomecanico, resultados, diagnostico, color_diagnostico, recomendacion)
    
    fig = figure('Name', 'Figura 4 - Mapa de Riesgo Integrado', ...
           'Position', [200 50 1400 800], ...
           'Color', [1 1 1], ...
           'NumberTitle', 'off');

    % Calcular puntuación de riesgo integrada MEJORADA
    mascara_mama = imfill(mascara_final, 'holes');
    area_total = sum(mascara_mama(:));
    
    if area_total > 0
        % Usar el mapa de densidad para cálculo de riesgo
        area_densa = sum(mapa_densidad(mascara_mama) >= 2);
        porcentaje_densidad = (area_densa / area_total) * 100;
        
        % Extraer características de textura para cálculo de riesgo
        region_textura = imagen_suavizada;
        region_textura(~mascara_mama) = 0;
        
        if any(region_textura(:) > 0)
            [GLCM, ~] = graycomatrix(region_textura, 'Offset', [0 1; -1 1; -1 0; -1 -1], ...
                                     'NumLevels', 8, 'GrayLimits', []);
            props_glcm = graycoprops(GLCM, {'contrast', 'homogeneity'});
            textura_contrast = mean(props_glcm.Contrast);
            textura_homogeneity = mean(props_glcm.Homogeneity);
            textura_entropy = entropy(region_textura);
        else
            textura_contrast = 0;
            textura_homogeneity = 0;
            textura_entropy = 0;
        end
        
        % Considerar tensiones biomecánicas en el riesgo
        if any(modelo_biomecanico.tensiones.maxima(:) > 0)
            tensiones_validas = modelo_biomecanico.tensiones.maxima(modelo_biomecanico.tensiones.maxima > 0);
            tension_promedio = mean(tensiones_validas);
            factor_tension = min(tension_promedio / 10, 2); % Normalizado
        else
            factor_tension = 0;
        end
        
        puntuacion_densidad = min(porcentaje_densidad / 25, 4);
        puntuacion_textura = (textura_contrast * 8 + (1 - textura_homogeneity) * 6 + textura_entropy * 1.5);
        puntuacion_riesgo_integrado = puntuacion_densidad + puntuacion_textura + factor_tension;
    else
        puntuacion_riesgo_integrado = 0;
        porcentaje_densidad = 0;
    end

    %% LAYOUT HORIZONTAL MEJORADO - 3 COLUMNAS
    % Columna 1: Imagen con mapa de riesgo
    subplot(2, 3, [1, 2, 4, 5]); % Ocupa 2/3 del ancho en ambas filas
    imshow(imagen_suavizada, []);
    hold on;

    % Definir nivel de riesgo MEJORADO - CAMBIO AMARILLO POR VERDE
    if puntuacion_riesgo_integrado >= 8
        color_riesgo = [1 0 0]; % Rojo
        texto_riesgo = 'ALTO RIESGO INTEGRADO';
        nivel_riesgo = 'ALTO';
    elseif puntuacion_riesgo_integrado >= 6
        color_riesgo = [1 0.4 0]; % Naranja-rojo
        texto_riesgo = 'RIESGO MODERADO-ALTO';
        nivel_riesgo = 'MODERADO-ALTO';
    elseif puntuacion_riesgo_integrado >= 4
        color_riesgo = [1 0.7 0]; % Naranja
        texto_riesgo = 'RIESGO MODERADO';
        nivel_riesgo = 'MODERADO';
    elseif puntuacion_riesgo_integrado >= 2
        color_riesgo = [0.2 0.8 0.2]; % VERDE en lugar de amarillo
        texto_riesgo = 'RIESGO BAJO-MODERADO';
        nivel_riesgo = 'BAJO-MODERADO';
    else
        color_riesgo = [0 0.6 0]; % Verde oscuro
        texto_riesgo = 'BAJO RIESGO';
        nivel_riesgo = 'BAJO';
    end

    % Dibujar contorno de riesgo si hay máscara
    if any(mascara_mama(:))
        contornos_mama = bwboundaries(mascara_mama);
        for k = 1:length(contornos_mama)
            contorno = contornos_mama{k};
            plot(contorno(:,2), contorno(:,1), 'Color', color_riesgo, ...
                 'LineWidth', 4, 'LineStyle', '-');
        end
    end

    title('MAPA DE RIESGO INTEGRADO MEJORADO', 'FontSize', 16, 'FontWeight', 'bold', ...
          'Color', color_riesgo);

    % Información de riesgo MEJORADA - POSICIÓN CORREGIDA
    info_riesgo_texto = {
        texto_riesgo
        sprintf('Puntuación integrada: %.1f/10', min(puntuacion_riesgo_integrado, 10))
        sprintf('Densidad mamaria: %.1f%%', porcentaje_densidad)
        sprintf('Nivel de riesgo: %s', nivel_riesgo)
    };

    text(0.02, 0.98, info_riesgo_texto, 'Units', 'normalized', ...
         'FontSize', 12, 'FontWeight', 'bold', 'Color', color_riesgo, ...
         'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1 0.9], ...
         'EdgeColor', color_riesgo, 'LineWidth', 2, 'Margin', 5);

    hold off;

    %% COLUMNA 2: PANEL DE INFORMACIÓN CLÍNICA (1/3 del ancho)
    subplot(2, 3, 3); % Primera fila, tercera columna
    axis off;
    
    % Fondo del panel
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 2, 'Curvature', 0.02);

    % Título del panel
    text(0.5, 0.95, 'DIAGNÓSTICO CLÍNICO', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', [0 0 0.6]);

    % Cuadro de diagnóstico
    rectangle('Position', [0.1 0.75 0.8 0.15], 'FaceColor', color_diagnostico, ...
              'EdgeColor', 'black', 'LineWidth', 2, 'Curvature', 0.03);

    text(0.5, 0.85, 'DIAGNÓSTICO', 'Units', 'normalized', ...
         'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', 'white');

    text(0.5, 0.75, diagnostico, 'Units', 'normalized', ...
         'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', 'white');

    % Información detallada MEJORADA
    if ~isempty(resultados)
        num_lesiones_total = length(resultados);
        num_malignas = sum(strcmp({resultados.Clasificacion}, 'Maligno'));
        num_benignas = sum(strcmp({resultados.Clasificacion}, 'Benigno'));
        num_tumores = sum(strcmp({resultados.Clasificacion}, 'Tumor'));
        num_indeterminadas = sum(strcmp({resultados.Clasificacion}, 'Indeterminado'));
    else
        num_lesiones_total = 0;
        num_malignas = 0;
        num_benignas = 0;
        num_tumores = 0;
        num_indeterminadas = 0;
    end

    % Resumen de hallazgos - FORMATEADO CORREGIDO
    info_hallazgos = {
        'RESUMEN DE HALLAZGOS:'
        '────────────────────'
        sprintf('Total lesiones:    %d', num_lesiones_total)
        sprintf('Lesiones malignas: %d', num_malignas)
        sprintf('Lesiones benignas: %d', num_benignas)
        sprintf('Tumores:           %d', num_tumores)
        sprintf('Indeterminadas:    %d', num_indeterminadas)
        ''
        sprintf('Puntuación riesgo: %.1f/10', min(puntuacion_riesgo_integrado, 10))
    };

    text(0.1, 0.55, info_hallazgos, 'Units', 'normalized', 'FontSize', 10, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.2 0.2 0.4], 'BackgroundColor', [1 1 1 0.8], 'Margin', 2);

    %% FILA 2: RECOMENDACIONES (ocupando todo el ancho inferior)
    subplot(2, 3, 6); % Segunda fila, tercera columna
    axis off;
    
    % Fondo del panel de recomendaciones
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.97 0.98 0.95], ...
              'EdgeColor', [0.3 0.6 0.3], 'LineWidth', 2, 'Curvature', 0.02);

    text(0.5, 0.95, 'RECOMENDACIONES CLÍNICAS', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', [0 0.4 0]);

    % Mostrar recomendaciones en formato de lista MEJORADO
    rec_y_pos = 0.8;
    for i = 1:length(recomendacion)
        % Fondo para cada recomendación
        rectangle('Position', [0.1 rec_y_pos-0.08 0.8 0.07], ...
                  'FaceColor', [1 1 1], 'EdgeColor', [0.8 0.9 0.8], ...
                  'LineWidth', 1, 'Curvature', 0.02);
        
        % Texto de la recomendación
        text(0.15, rec_y_pos-0.04, ['• ' recomendacion{i}], ...
             'Units', 'normalized', 'FontSize', 10, 'VerticalAlignment', 'middle', ...
             'FontWeight', 'bold', 'Color', [0.1 0.3 0.1], 'Interpreter', 'none');
        
        rec_y_pos = rec_y_pos - 0.1;
        
        % Ajustar si hay muchas recomendaciones
        if i >= 4 && rec_y_pos < 0.2
            break; % Limitar a 4 recomendaciones visibles
        end
    end

    % Información adicional si hay más recomendaciones
    if length(recomendacion) > 4
        text(0.5, 0.05, sprintf('+ %d recomendaciones adicionales...', length(recomendacion)-4), ...
             'Units', 'normalized', 'FontSize', 9, 'FontWeight', 'bold', ...
             'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);
    end
end

function fig = visualizarCorrelacionMultimodal(resultados, deformaciones, metricas, config)
    fig = figure('Name', 'Figura 5 - Correlación Multimodal y Análisis Estadístico', ...
           'Position', [250 50 1400 800], 'Color', [1 1 1]);

    if isempty(resultados)
        text(0.5, 0.5, 'No hay datos para correlación multimodal', ...
             'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
        return;
    end

    % 1. Correlación entre características morfológicas MEJORADA
    subplot(2, 3, 1);
    
    areas = [resultados.Area];
    excentricidades = [resultados.Excentricidad];
    solideces = [resultados.Solidez];
    
    % Colorear por tipo de lesión
    colores = zeros(length(resultados), 3);
    sizes = zeros(length(resultados), 1);
    for i = 1:length(resultados)
        switch resultados(i).Clasificacion
            case 'Maligno'
                colores(i, :) = [1, 0, 0]; % Rojo
                sizes(i) = 100;
            case 'Benigno'
                colores(i, :) = [0, 1, 0]; % Verde
                sizes(i) = 80;
            case 'Tumor'
                colores(i, :) = [0.5, 0, 0.5]; % Morado
                sizes(i) = 120;
            otherwise
                colores(i, :) = [0.5, 0.5, 0.5]; % Gris
                sizes(i) = 60;
        end
    end
    
    scatter(areas, excentricidades, sizes, colores, 'filled', 'MarkerEdgeColor', 'black');
    xlabel('Área (píxeles)');
    ylabel('Excentricidad');
    title('A) Correlación: Área vs Excentricidad', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    % Leyenda MEJORADA - CORREGIDA
    hold on;
    legend_handles = [];
    legend_labels = {};
    
    tipos_unicos = unique({resultados.Clasificacion});
    color_map = containers.Map();
    color_map('Maligno') = [1, 0, 0];
    color_map('Benigno') = [0, 1, 0];
    color_map('Tumor') = [0.5, 0, 0.5];
    color_map('Indeterminado') = [0.5, 0.5, 0.5];
    
    for i = 1:length(tipos_unicos)
        tipo = tipos_unicos{i};
        if any(strcmp({resultados.Clasificacion}, tipo))
            h = scatter(NaN, NaN, 80, color_map(tipo), 'filled', 'MarkerEdgeColor', 'black');
            legend_handles(end+1) = h;
            legend_labels{end+1} = tipo;
        end
    end
    
    if ~isempty(legend_handles)
        legend(legend_handles, legend_labels, 'Location', 'best');
    end
    hold off;

    % 2. Distribución de áreas por tipo de lesión
    subplot(2, 3, 2);
    
    % Agrupar áreas por tipo
    areas_malignas = [resultados(strcmp({resultados.Clasificacion}, 'Maligno')).Area];
    areas_benignas = [resultados(strcmp({resultados.Clasificacion}, 'Benigno')).Area];
    areas_tumores = [resultados(strcmp({resultados.Clasificacion}, 'Tumor')).Area];
    areas_indet = [resultados(strcmp({resultados.Clasificacion}, 'Indeterminado')).Area];
    
    datos_grafico = [];
    grupos = {};
    
    if ~isempty(areas_malignas)
        datos_grafico = [datos_grafico, mean(areas_malignas)];
        grupos{end+1} = 'Maligno';
    end
    if ~isempty(areas_benignas)
        datos_grafico = [datos_grafico, mean(areas_benignas)];
        grupos{end+1} = 'Benigno';
    end
    if ~isempty(areas_tumores)
        datos_grafico = [datos_grafico, mean(areas_tumores)];
        grupos{end+1} = 'Tumor';
    end
    if ~isempty(areas_indet)
        datos_grafico = [datos_grafico, mean(areas_indet)];
        grupos{end+1} = 'Indet.';
    end
    
    if ~isempty(datos_grafico)
        bar(datos_grafico, 'FaceColor', [0.2 0.4 0.8]);
        set(gca, 'XTickLabel', grupos);
        ylabel('Área Promedio (píxeles)');
        title('B) Área Promedio por Tipo', 'FontSize', 12, 'FontWeight', 'bold');
        grid on;
    else
        text(0.5, 0.5, 'No hay datos de área', 'HorizontalAlignment', 'center');
    end

    % 3. Distribución de solidez por tipo de lesión - VERSIÓN SEGURA
    subplot(2, 3, 3);
    
    solideces_malignas = [resultados(strcmp({resultados.Clasificacion}, 'Maligno')).Solidez];
    solideces_benignas = [resultados(strcmp({resultados.Clasificacion}, 'Benigno')).Solidez];
    solideces_tumores = [resultados(strcmp({resultados.Clasificacion}, 'Tumor')).Solidez];
    solideces_indet = [resultados(strcmp({resultados.Clasificacion}, 'Indeterminado')).Solidez];
    
    % Crear gráfico de violín simple en lugar de boxplot
    hold on;
    offset = 0.2;
    
    if ~isempty(solideces_malignas)
        scatter(ones(size(solideces_malignas)) - offset, solideces_malignas, 40, 'r', 'filled');
        plot([1-offset-0.1, 1-offset+0.1], [median(solideces_malignas), median(solideces_malignas)], 'k-', 'LineWidth', 2);
    end
    
    if ~isempty(solideces_benignas)
        scatter(2*ones(size(solideces_benignas)) - offset, solideces_benignas, 40, 'g', 'filled');
        plot([2-offset-0.1, 2-offset+0.1], [median(solideces_benignas), median(solideces_benignas)], 'k-', 'LineWidth', 2);
    end
    
    if ~isempty(solideces_tumores)
        scatter(3*ones(size(solideces_tumores)) - offset, solideces_tumores, 40, 'm', 'filled');
        plot([3-offset-0.1, 3-offset+0.1], [median(solideces_tumores), median(solideces_tumores)], 'k-', 'LineWidth', 2);
    end
    
    if ~isempty(solideces_indet)
        scatter(4*ones(size(solideces_indet)) - offset, solideces_indet, 40, [0.5 0.5 0.5], 'filled');
        plot([4-offset-0.1, 4-offset+0.1], [median(solideces_indet), median(solideces_indet)], 'k-', 'LineWidth', 2);
    end
    
    xlim([0.5, 4.5]);
    set(gca, 'XTick', [1, 2, 3, 4], 'XTickLabel', {'Maligno', 'Benigno', 'Tumor', 'Indet.'});
    ylabel('Solidez');
    title('C) Distribución de Solidez por Tipo', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    hold off;

    % 4. Histograma de áreas total
    subplot(2, 3, 4);
    if ~isempty(resultados)
        histogram([resultados.Area], 20, 'FaceColor', [0.8 0.4 0.2], 'EdgeColor', 'black');
        xlabel('Área (píxeles)');
        ylabel('Frecuencia');
        title('D) Distribución de Áreas de Lesiones', 'FontSize', 12, 'FontWeight', 'bold');
        grid on;
    else
        text(0.5, 0.5, 'No hay datos de áreas', 'HorizontalAlignment', 'center');
    end

    % 5. Pie chart de distribución de tipos
    subplot(2, 3, 5);
    if ~isempty(resultados)
        counts = [sum(strcmp({resultados.Clasificacion}, 'Maligno')), ...
                 sum(strcmp({resultados.Clasificacion}, 'Benigno')), ...
                 sum(strcmp({resultados.Clasificacion}, 'Tumor')), ...
                 sum(strcmp({resultados.Clasificacion}, 'Indeterminado'))];
        
        % Solo mostrar categorías con datos
        labels = {};
        colors_pie = [];
        valid_counts = [];
        
        if counts(1) > 0
            labels{end+1} = 'Malignas';
            colors_pie = [colors_pie; 1 0 0];
            valid_counts(end+1) = counts(1);
        end
        if counts(2) > 0
            labels{end+1} = 'Benignas';
            colors_pie = [colors_pie; 0 1 0];
            valid_counts(end+1) = counts(2);
        end
        if counts(3) > 0
            labels{end+1} = 'Tumores';
            colors_pie = [colors_pie; 0.5 0 0.5];
            valid_counts(end+1) = counts(3);
        end
        if counts(4) > 0
            labels{end+1} = 'Indet.';
            colors_pie = [colors_pie; 0.5 0.5 0.5];
            valid_counts(end+1) = counts(4);
        end
        
        if ~isempty(valid_counts)
            pie(valid_counts, labels);
            colormap(colors_pie);
            title('E) Distribución de Tipos de Lesiones', 'FontSize', 12, 'FontWeight', 'bold');
        else
            text(0.5, 0.5, 'No hay datos', 'HorizontalAlignment', 'center');
        end
    else
        text(0.5, 0.5, 'No hay datos', 'HorizontalAlignment', 'center');
    end

    % 6. Correlación solidez vs compacidad
    subplot(2, 3, 6);
    if ~isempty(resultados)
        solideces = [resultados.Solidez];
        compacidades = [resultados.Compacidad];
        
        scatter(solideces, compacidades, sizes, colores, 'filled', 'MarkerEdgeColor', 'black');
        xlabel('Solidez');
        ylabel('Compacidad');
        title('F) Correlación: Solidez vs Compacidad', 'FontSize', 12, 'FontWeight', 'bold');
        grid on;
    else
        text(0.5, 0.5, 'No hay datos', 'HorizontalAlignment', 'center');
    end
end

function fig6 = visualizarLesionesDetectadas(imagen_suavizada, mascara_final, resultados, etiquetas)
    % FIGURA 6 - Lesiones Detectadas y Clasificadas
    fig6 = figure('Name', 'Figura 6 - Lesiones Detectadas y Clasificadas', ...
           'Position', [100 100 1200 800], 'Color', [1 1 1]);

    % Panel principal con la imagen y lesiones marcadas
    subplot(1, 1, 1);
    imshow(imagen_suavizada, []);
    hold on;
    
    if ~isempty(resultados)
        % Colores mejorados para mejor contraste
        for i = 1:length(resultados)
            mascara_lesion = (etiquetas == resultados(i).ID);
            contornos = bwboundaries(mascara_lesion);
            
            switch resultados(i).Clasificacion
                case 'Maligno'
                    color_contorno = [1 0 0]; % Rojo intenso
                    grosor = 4;
                    estilo = '-';
                case 'Benigno'
                    color_contorno = [0 0.8 0]; % Verde
                    grosor = 3;
                    estilo = '-';
                case 'Tumor'
                    color_contorno = [1 0.5 0]; % Naranja
                    grosor = 5;
                    estilo = '-';
                otherwise
                    color_contorno = [0.5 0.5 0.5]; % Gris
                    grosor = 2;
                    estilo = '--';
            end
            
            for k = 1:length(contornos)
                contorno = contornos{k};
                plot(contorno(:,2), contorno(:,1), estilo, 'Color', color_contorno, ...
                     'LineWidth', grosor);
                
                % Añadir número de identificación
                stats = regionprops(mascara_lesion, 'Centroid');
                if ~isempty(stats)
                    centroid = stats.Centroid;
                    text(centroid(1), centroid(2), num2str(resultados(i).ID), ...
                         'Color', 'white', 'FontSize', 12, 'FontWeight', 'bold', ...
                         'BackgroundColor', color_contorno, 'HorizontalAlignment', 'center', ...
                         'Margin', 2);
                end
            end
        end
    end
    
    title('LESIONES DETECTADAS Y CLASIFICADAS', 'FontSize', 16, 'FontWeight', 'bold', ...
          'Color', [0 0 0.6]);
    
    % Crear leyenda manualmente
    hold on;
    h_mal = plot(NaN, NaN, '-', 'Color', [1 0 0], 'LineWidth', 4);
    h_ben = plot(NaN, NaN, '-', 'Color', [0 0.8 0], 'LineWidth', 3);
    h_tum = plot(NaN, NaN, '-', 'Color', [1 0.5 0], 'LineWidth', 5);
    h_ind = plot(NaN, NaN, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 2);
    legend([h_mal, h_ben, h_tum, h_ind], {'Malignas', 'Benignas', 'Tumores', 'Indeterminadas'}, ...
           'Location', 'best', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Información resumen en la esquina
    if ~isempty(resultados)
        num_malignas = sum(strcmp({resultados.Clasificacion}, 'Maligno'));
        num_benignas = sum(strcmp({resultados.Clasificacion}, 'Benigno'));
        num_tumores = sum(strcmp({resultados.Clasificacion}, 'Tumor'));
        num_indet = sum(strcmp({resultados.Clasificacion}, 'Indeterminado'));
        
        info_text = {
            sprintf('Total lesiones: %d', length(resultados))
            sprintf('Malignas: %d', num_malignas)
            sprintf('Benignas: %d', num_benignas)
            sprintf('Tumores: %d', num_tumores)
            sprintf('Indeterminadas: %d', num_indet)
        };
        
        text(0.02, 0.98, info_text, 'Units', 'normalized', ...
             'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0 0.5], ...
             'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1 0.9], ...
             'EdgeColor', [0 0 0.5], 'LineWidth', 1);
    end
    
    hold off;
end

function fig7 = visualizarTablaCaracteristicas(resultados)
    % FIGURA 7 - Tabla Detallada de Características - CORREGIDA
    fig7 = figure('Name', 'Figura 7 - Características Detalladas de Lesiones', ...
           'Position', [150 100 1400 600], 'Color', [1 1 1]);

    if isempty(resultados)
        text(0.5, 0.5, 'No se detectaron lesiones', 'HorizontalAlignment', 'center', ...
             'FontSize', 16, 'FontWeight', 'bold', 'Color', [0.5 0.5 0.5]);
        return;
    end

    % Fondo profesional para la tabla
    axes('Position', [0.05 0.05 0.9 0.9]);
    axis off;
    
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 3, 'Curvature', 0.02);
    
    % Título de la tabla - CENTRADO CORREGIDO
    text(0.5, 0.95, 'CARACTERÍSTICAS DETALLADAS DE LESIONES', 'Units', 'normalized', ...
         'FontSize', 18, 'FontWeight', 'bold', 'Color', [0 0 0.6], ...
         'HorizontalAlignment', 'center');
    
    % Línea separadora del título
    line([0.08 0.92], [0.92 0.92], 'Color', [0.3 0.5 0.7], 'LineWidth', 2);
    
    % Encabezados de columnas MEJORADOS
    headers = {'ID', 'Área (px)', 'Diámetro (px)', 'Solidez', 'Excentricidad', 'Tipo', 'Riesgo'};
    pos_x = [0.10, 0.18, 0.28, 0.40, 0.52, 0.68, 0.85];
    
    % Dibujar fondo para encabezados
    rectangle('Position', [0.08 0.84 0.84 0.06], 'FaceColor', [0.2 0.4 0.6], ...
              'EdgeColor', [0.1 0.3 0.5], 'Curvature', 0.03);
    
    for i = 1:length(headers)
        text(pos_x(i), 0.87, headers{i}, 'Units', 'normalized', ...
             'FontSize', 13, 'FontWeight', 'bold', 'FontName', 'Monospaced', ...
             'Color', 'white', 'HorizontalAlignment', 'center');
    end
    
    % Línea separadora de encabezados
    line([0.08 0.92], [0.83 0.83], 'Color', [0.1 0.3 0.5], 'LineWidth', 1);
    
    % Datos de lesiones - MÁXIMO 8 filas para mejor visualización
    num_filas_a_mostrar = min(8, length(resultados));
    
    for i = 1:num_filas_a_mostrar
        % Fondo alternado para filas para mejor legibilidad
        if mod(i, 2) == 1
            rect_color = [0.95 0.95 0.97];
        else
            rect_color = [0.92 0.94 0.98];
        end
        rectangle('Position', [0.08 0.77-(i-1)*0.08 0.84 0.07], ...
                  'FaceColor', rect_color, 'EdgeColor', [0.9 0.9 0.9], ...
                  'Curvature', 0.02);
        
        % Determinar color según clasificación
        switch resultados(i).Clasificacion
            case 'Maligno'
                color_texto = [0.8 0 0];
                color_fondo = [1 0.9 0.9];
            case 'Benigno'
                color_texto = [0 0.5 0];
                color_fondo = [0.9 1 0.9];
            case 'Tumor'
                color_texto = [0.8 0.4 0];
                color_fondo = [1 0.95 0.9];
            otherwise
                color_texto = [0.3 0.3 0.3];
                color_fondo = [0.95 0.95 0.95];
        end
        
        % Fondo de color para la columna de tipo
        rectangle('Position', [0.66 0.77-(i-1)*0.08 0.14 0.07], ...
                  'FaceColor', color_fondo, 'EdgeColor', [0.9 0.9 0.9], ...
                  'Curvature', 0.02);
        
        % Fondo de color para la columna de riesgo
        rectangle('Position', [0.82 0.77-(i-1)*0.08 0.10 0.07], ...
                  'FaceColor', color_fondo, 'EdgeColor', [0.9 0.9 0.9], ...
                  'Curvature', 0.02);
        
        % Formatear datos con mejor presentación
        area_formateada = formatNumber(resultados(i).Area);
        diametro_formateado = formatNumber(round(resultados(i).Diametro));
        solidez_formateada = sprintf('%.3f', resultados(i).Solidez);
        excentricidad_formateada = sprintf('%.3f', resultados(i).Excentricidad);
        
        datos_fila = {
            sprintf('%d', resultados(i).ID),
            area_formateada,
            diametro_formateado,
            solidez_formateada,
            excentricidad_formateada,
            resultados(i).Clasificacion,
            sprintf('%d', resultados(i).PuntuacionRiesgo)
        };
        
        for j = 1:length(datos_fila)
            if j >= 6 % Columnas de tipo y riesgo
                text(pos_x(j), 0.80 - (i-1)*0.08, datos_fila{j}, 'Units', 'normalized', ...
                     'FontSize', 11, 'FontName', 'Monospaced', 'FontWeight', 'bold', ...
                     'Color', color_texto, 'HorizontalAlignment', 'center');
            else
                text(pos_x(j), 0.80 - (i-1)*0.08, datos_fila{j}, 'Units', 'normalized', ...
                     'FontSize', 11, 'FontName', 'Monospaced', 'FontWeight', 'bold', ...
                     'Color', [0.2 0.2 0.4], 'HorizontalAlignment', 'center');
            end
        end
        
        % Línea separadora entre filas
        if i < num_filas_a_mostrar
            line([0.10 0.90], [0.77-(i-1)*0.08-0.01 0.77-(i-1)*0.08-0.01], ...
                 'Color', [0.85 0.85 0.85], 'LineWidth', 0.5);
        end
    end
    
    % Información de resumen si hay más de 8 lesiones
    if length(resultados) > 8
        text(0.5, 0.15, sprintf('+ %d lesiones adicionales...', length(resultados)-8), ...
             'Units', 'normalized', 'FontSize', 12, 'FontWeight', 'bold', ...
             'Color', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');
    end
    
    % LEYENDA DE COLORES - CENTRADA Y MEJOR ORGANIZADA
    text(0.5, 0.08, 'LEYENDA DE COLORES:', 'Units', 'normalized', ...
         'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.2 0.2 0.4], ...
         'HorizontalAlignment', 'center');
    
    % Cuadros de colores para la leyenda - CENTRADOS
    legend_items = {'Maligno', 'Benigno', 'Tumor', 'Indeterminado'};
    legend_colors = {[0.8 0 0], [0 0.5 0], [0.8 0.4 0], [0.3 0.3 0.3]};
    legend_bg = {[1 0.9 0.9], [0.9 1 0.9], [1 0.95 0.9], [0.95 0.95 0.95]};
    
    % Calcular posición centrada para la leyenda
    total_legend_width = 0.18 * length(legend_items); % Ancho total de todos los items
    start_x = 0.5 - (total_legend_width / 2); % Empezar desde el centro
    
    for k = 1:length(legend_items)
        x_pos = start_x + (k-1)*0.18;
        
        % Fondo del ítem de leyenda
        rectangle('Position', [x_pos-0.02 0.02 0.12 0.04], ...
                  'FaceColor', legend_bg{k}, 'EdgeColor', legend_colors{k}, ...
                  'LineWidth', 2, 'Curvature', 0.1);
        
        % Texto del ítem de leyenda
        text(x_pos+0.04, 0.04, legend_items{k}, 'Units', 'normalized', ...
             'FontSize', 11, 'FontWeight', 'bold', 'Color', legend_colors{k}, ...
             'HorizontalAlignment', 'center');
    end
end

function fig8 = visualizarAnalisisEstadistico(imagen_suavizada, mascara_final, resultados, etiquetas)
    % FIGURA 8 - Análisis Estadístico y Distribución
    fig8 = figure('Name', 'Figura 8 - Análisis Estadístico y Distribución', ...
           'Position', [200 50 1400 900], 'Color', [1 1 1]);

    if isempty(resultados)
        % Si no hay resultados, mostrar mensaje
        text(0.5, 0.5, 'No hay datos para análisis estadístico', ...
             'HorizontalAlignment', 'center', 'FontSize', 16, 'FontWeight', 'bold', ...
             'Color', [0.5 0.5 0.5]);
        return;
    end

    % 1. Distribución por tipo
    subplot(2, 2, 1);
    
    % Contar por tipo
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
    
    % Gráfico de barras doble
    yyaxis left
    b = bar(counts, 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'black', 'FaceAlpha', 0.7);
    ylabel('Número de Lesiones', 'FontSize', 12, 'FontWeight', 'bold');
    set(gca, 'XTickLabel', {'Maligno', 'Benigno', 'Tumor', 'Indet.'}, ...
             'FontSize', 11, 'FontWeight', 'bold');
    
    % Añadir valores en las barras
    for i = 1:length(counts)
        if counts(i) > 0
            text(i, counts(i) + 0.1, num2str(counts(i)), ...
                 'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
        end
    end
    
    yyaxis right
    p = plot(areas_promedio/1000, 'ro-', 'LineWidth', 3, 'MarkerSize', 10, ...
             'MarkerFaceColor', 'red');
    ylabel('Área Promedio (x1000 px)', 'FontSize', 12, 'FontWeight', 'bold');
    
    title('A) Distribución por Tipo de Lesión', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    legend([b, p], {'Cantidad', 'Área Promedio'}, 'Location', 'best', ...
           'FontSize', 11, 'FontWeight', 'bold');

    % 2. Mapa de distribución y densidad
    subplot(2, 2, 2);
    imshow(imagen_suavizada, []);
    hold on;
    
    % Crear mapa de densidad de lesiones
    [filas, columnas] = size(imagen_suavizada);
    mapa_calor = zeros(filas, columnas);
    
    for i = 1:length(resultados)
        mascara_lesion = (etiquetas == resultados(i).ID);
        
        % Asignar valor según tipo y riesgo
        switch resultados(i).Clasificacion
            case 'Maligno'
                valor = 4;
            case 'Tumor'
                valor = 3;
            case 'Indeterminado'
                valor = 2;
            case 'Benigno'
                valor = 1;
            otherwise
                valor = 0.5;
        end
        
        mapa_calor(mascara_lesion) = valor;
    end
    
    % Mostrar mapa de calor semitransparente
    himage = imagesc(mapa_calor);
    set(himage, 'AlphaData', mapa_calor * 0.4);
    colormap([0 0 0; 0 1 0; 1 1 0; 1 0.5 0; 1 0 0]);
    caxis([0 4]);
    
    % Marcar centroides con símbolos diferentes
    for i = 1:length(resultados)
        mascara_lesion = (etiquetas == resultados(i).ID);
        stats = regionprops(mascara_lesion, 'Centroid');
        if ~isempty(stats)
            centroid = stats.Centroid;
            
            switch resultados(i).Clasificacion
                case 'Maligno'
                    plot(centroid(1), centroid(2), 'ro', 'MarkerSize', 12, ...
                         'MarkerFaceColor', 'red', 'LineWidth', 2);
                    text(centroid(1)+15, centroid(2), num2str(resultados(i).ID), ...
                         'Color', 'white', 'FontSize', 10, 'FontWeight', 'bold', ...
                         'BackgroundColor', 'red');
                case 'Benigno'
                    plot(centroid(1), centroid(2), 'go', 'MarkerSize', 10, ...
                         'MarkerFaceColor', 'green', 'LineWidth', 2);
                    text(centroid(1)+15, centroid(2), num2str(resultados(i).ID), ...
                         'Color', 'white', 'FontSize', 10, 'FontWeight', 'bold', ...
                         'BackgroundColor', 'green');
                case 'Tumor'
                    plot(centroid(1), centroid(2), 's', 'MarkerSize', 14, ...
                         'MarkerFaceColor', [1 0.5 0], 'Color', 'black', 'LineWidth', 2);
                    text(centroid(1)+15, centroid(2), num2str(resultados(i).ID), ...
                         'Color', 'white', 'FontSize', 10, 'FontWeight', 'bold', ...
                         'BackgroundColor', [1 0.5 0]);
                otherwise
                    plot(centroid(1), centroid(2), '^', 'MarkerSize', 10, ...
                         'MarkerFaceColor', [0.5 0.5 0.5], 'Color', 'black');
            end
        end
    end
    
    title('B) Mapa de Distribución y Densidad', 'FontSize', 14, 'FontWeight', 'bold');
    colorbar('Ticks', [0.5, 1.5, 2.5, 3.5], ...
             'TickLabels', {'Fondo', 'Benigno', 'Indet.', 'Tumor', 'Maligno'}, ...
             'FontSize', 10);
    hold off;

    % 3. Análisis de formas
    subplot(2, 2, 3);
    
    % Scatter plot de características de forma
    areas = [resultados.Area];
    solideces = [resultados.Solidez];
    excentricidades = [resultados.Excentricidad];
    
    % Tamaños y colores según tipo
    sizes = zeros(size(areas));
    colores = zeros(length(areas), 3);
    
    for i = 1:length(areas)
        sizes(i) = 80 + (areas(i) / max(areas)) * 120;
        
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
    
    scatter(solideces, excentricidades, sizes, colores, 'filled', ...
            'MarkerEdgeColor', 'black', 'LineWidth', 1.5);
    
    xlabel('Solidez', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Excentricidad', 'FontSize', 12, 'FontWeight', 'bold');
    title('C) Análisis de Formas: Solidez vs Excentricidad', ...
          'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    
    % Añadir etiquetas para todos los puntos
    for i = 1:length(resultados)
        text(solideces(i), excentricidades(i), num2str(resultados(i).ID), ...
             'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold', ...
             'BackgroundColor', [1 1 1 0.8], 'Margin', 1);
    end
    
    % Leyenda de tamaños
    hold on;
    scatter(0.1, 0.9, 50, [0.5 0.5 0.5], 'filled', 'MarkerEdgeColor', 'black');
    scatter(0.1, 0.8, 100, [0.5 0.5 0.5], 'filled', 'MarkerEdgeColor', 'black');
    scatter(0.1, 0.7, 150, [0.5 0.5 0.5], 'filled', 'MarkerEdgeColor', 'black');
    text(0.15, 0.9, 'Área pequeña', 'FontSize', 9, 'FontWeight', 'bold');
    text(0.15, 0.8, 'Área media', 'FontSize', 9, 'FontWeight', 'bold');
    text(0.15, 0.7, 'Área grande', 'FontSize', 9, 'FontWeight', 'bold');
    hold off;

    % 4. Resumen estadístico completo
    subplot(2, 2, 4);
    axis off;
    
    % Calcular estadísticas MEJORADAS
    areas = [resultados.Area];
    solideces = [resultados.Solidez];
    excentricidades = [resultados.Excentricidad];
    riesgos = [resultados.PuntuacionRiesgo];
    
    % Estadísticas por tipo
    malignas_mask = strcmp({resultados.Clasificacion}, 'Maligno');
    benignas_mask = strcmp({resultados.Clasificacion}, 'Benigno');
    tumores_mask = strcmp({resultados.Clasificacion}, 'Tumor');
    indet_mask = strcmp({resultados.Clasificacion}, 'Indeterminado');
    
    % Texto del resumen MEJORADO
    resumen_texto = {
        'RESUMEN ESTADÍSTICO COMPLETO'
        '──────────────────────────'
        sprintf('Total de lesiones:      %d', length(resultados))
        sprintf('Área total detectada:   %s px', formatNumber(sum(areas)))
        ''
        'DISTRIBUCIÓN POR TIPO:'
        sprintf('Malignas:           %2d (%.1f%%)', sum(malignas_mask), (sum(malignas_mask)/length(resultados))*100)
        sprintf('Benignas:           %2d (%.1f%%)', sum(benignas_mask), (sum(benignas_mask)/length(resultados))*100)
        sprintf('Tumores:            %2d (%.1f%%)', sum(tumores_mask), (sum(tumores_mask)/length(resultados))*100)
        sprintf('Indeterminadas:     %2d (%.1f%%)', sum(indet_mask), (sum(indet_mask)/length(resultados))*100)
        ''
        'CARACTERÍSTICAS PROMEDIO:'
        sprintf('Área:               %s px', formatNumber(mean(areas)))
        sprintf('Solidez:            %.3f ± %.3f', mean(solideces), std(solideces))
        sprintf('Excentricidad:      %.3f ± %.3f', mean(excentricidades), std(excentricidades))
        sprintf('Puntuación riesgo:  %.1f ± %.1f', mean(riesgos), std(riesgos))
        ''
        'RANGO DE ÁREAS:'
        sprintf('Mínima:             %s px', formatNumber(min(areas)))
        sprintf('Máxima:             %s px', formatNumber(max(areas)))
        sprintf('Mediana:            %s px', formatNumber(median(areas)))
        ''
        'VARIABILIDAD:'
        sprintf('Coef. variación área: %.1f%%', (std(areas)/mean(areas))*100)
        sprintf('Asimetría:           %.3f', skewness(areas))
        sprintf('Curtosis:            %.3f', kurtosis(areas))
    };
    
    % Fondo para mejor legibilidad
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 2, 'Curvature', 0.02);
    
    text(0.1, 0.9, resumen_texto, 'Units', 'normalized', 'FontSize', 10, ...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
         'Color', [0.1 0.3 0.5]);
    
    title('D) Resumen Estadístico Completo', 'FontSize', 14, 'FontWeight', 'bold');
end
function fig9 = visualizarResumenClinico(resultados, diagnostico, recomendacion, puntuacion_total)
    % FIGURA 9 - Resumen Clínico - DISEÑO MEJORADO
    fig9 = figure('Name', 'Figura 9 - Resumen Clínico Integral', ...
           'Position', [250 100 1400 900], 'Color', [1 1 1]);

    % Layout de 2x2 para mejor organización
    subplot(2, 2, 1);
    axis off;
    
    %% PANEL 1: DIAGNÓSTICO PRINCIPAL
    % Fondo del panel
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99], ...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 3, 'Curvature', 0.03);
    
    % Título del panel
    text(0.5, 0.9, 'DIAGNÓSTICO PRINCIPAL', 'Units', 'normalized', ...
         'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', [0.1 0.3 0.5]);
    
    % Determinar color del diagnóstico
    if contains(diagnostico, 'ALTA SOSPECHA') || contains(diagnostico, 'MALIGNIDAD')
        color_diag = [1 0 0];
        color_bg = [1 0.9 0.9];
    elseif contains(diagnostico, 'MODERADA')
        color_diag = [1 0.5 0];
        color_bg = [1 0.95 0.9];
    elseif contains(diagnostico, 'BENIGNOS')
        color_diag = [0 0.7 0];
        color_bg = [0.9 1 0.9];
    elseif contains(diagnostico, 'NORMALES')
        color_diag = [0 0 1];
        color_bg = [0.9 0.9 1];
    else
        color_diag = [0.5 0.5 0.5];
        color_bg = [0.95 0.95 0.95];
    end
    
    % Cuadro de diagnóstico
    rectangle('Position', [0.1 0.6 0.8 0.25], 'FaceColor', color_diag, ...
              'EdgeColor', 'black', 'LineWidth', 3, 'Curvature', 0.03);
    
    text(0.5, 0.8, 'DIAGNÓSTICO', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', 'white');
    
    text(0.5, 0.65, diagnostico, 'Units', 'normalized', ...
         'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', 'white');
    
    % Puntuación de riesgo
    rectangle('Position', [0.2 0.35 0.6 0.15], 'FaceColor', color_bg, ...
              'EdgeColor', color_diag, 'LineWidth', 2, 'Curvature', 0.02);
    
    text(0.5, 0.42, sprintf('PUNTUACIÓN TOTAL DE RIESGO: %.1f', puntuacion_total), ...
         'Units', 'normalized', 'FontSize', 12, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', 'Color', color_diag);
    
    % Fecha de generación
    text(0.5, 0.15, sprintf('Generado: %s', datestr(now, 'dd/mm/yyyy HH:MM')), ...
         'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);

    %% PANEL 2: DISTRIBUCIÓN DE LESIONES
    subplot(2, 2, 2);
    
    if ~isempty(resultados)
        % Contar por tipo
        tipos = {'Maligno', 'Benigno', 'Tumor', 'Indeterminado'};
        counts = zeros(1,4);
        for i = 1:4
            counts(i) = sum(strcmp({resultados.Clasificacion}, tipos{i}));
        end
        
        % Solo mostrar categorías con datos
        pie_data = counts(counts > 0);
        pie_labels = tipos(counts > 0);
        colors_pie = [1 0 0; 0 0.8 0; 1 0.5 0; 0.5 0.5 0.5];
        
        if ~isempty(pie_data)
            pie(pie_data, pie_labels);
            colormap(colors_pie(1:length(pie_data),:));
            title('DISTRIBUCIÓN DE LESIONES', 'FontSize', 14, 'FontWeight', 'bold');
        else
            text(0.5, 0.5, 'No hay datos', 'HorizontalAlignment', 'center', ...
                 'FontSize', 12, 'FontWeight', 'bold');
        end
    else
        text(0.5, 0.5, 'No se detectaron lesiones', 'HorizontalAlignment', 'center', ...
             'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.5 0.5 0.5]);
    end

    %% PANEL 3: RESUMEN ESTADÍSTICO
    subplot(2, 2, 3);
    axis off;
    
    % Fondo del panel
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.97 0.98 0.95], ...
              'EdgeColor', [0.3 0.6 0.3], 'LineWidth', 2, 'Curvature', 0.02);
    
    text(0.5, 0.95, 'RESUMEN ESTADÍSTICO', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', [0.1 0.4 0.1]);
    
    if ~isempty(resultados)
        num_total = length(resultados);
        num_malignas = sum(strcmp({resultados.Clasificacion}, 'Maligno'));
        num_benignas = sum(strcmp({resultados.Clasificacion}, 'Benigno'));
        num_tumores = sum(strcmp({resultados.Clasificacion}, 'Tumor'));
        num_indet = sum(strcmp({resultados.Clasificacion}, 'Indeterminado'));
        
        areas = [resultados.Area];
        solideces = [resultados.Solidez];
        excentricidades = [resultados.Excentricidad];
        
        resumen_texto = {
            'DATOS GENERALES:'
            '────────────────'
            sprintf('Total de lesiones:      %d', num_total)
            sprintf('Área total detectada:   %s px', formatNumber(sum(areas)))
            ''
            'DISTRIBUCIÓN POR TIPO:'
            sprintf('• Malignas:           %2d', num_malignas)
            sprintf('• Benignas:           %2d', num_benignas)
            sprintf('• Tumores:            %2d', num_tumores)
            sprintf('• Indeterminadas:     %2d', num_indet)
            ''
            'CARACTERÍSTICAS PROMEDIO:'
            sprintf('• Área:               %s px', formatNumber(mean(areas)))
            sprintf('• Solidez:            %.3f', mean(solideces))
            sprintf('• Excentricidad:      %.3f', mean(excentricidades))
            ''
            'RANGOS:'
            sprintf('• Área mínima:        %s px', formatNumber(min(areas)))
            sprintf('• Área máxima:        %s px', formatNumber(max(areas)))
        };
        
        text(0.1, 0.85, resumen_texto, 'Units', 'normalized', 'FontSize', 10, ...
             'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
             'Color', [0.1 0.3 0.1]);
    else
        text(0.5, 0.5, 'No hay datos estadísticos', 'HorizontalAlignment', 'center', ...
             'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.5 0.5 0.5]);
    end

    %% PANEL 4: RECOMENDACIONES CLÍNICAS
    subplot(2, 2, 4);
    axis off;
    
    % Fondo del panel
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.97 0.95], ...
              'EdgeColor', [0.6 0.4 0.2], 'LineWidth', 2, 'Curvature', 0.02);
    
    text(0.5, 0.95, 'RECOMENDACIONES CLÍNICAS', 'Units', 'normalized', ...
         'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', [0.4 0.2 0.1]);
    
    % Mostrar recomendaciones en lista ordenada
    if ~isempty(recomendacion)
        rec_y_pos = 0.85;
        for i = 1:min(length(recomendacion), 6) % Máximo 6 recomendaciones
            % Fondo para cada recomendación
            rectangle('Position', [0.08 rec_y_pos-0.12 0.84 0.1], ...
                      'FaceColor', [1 1 1], 'EdgeColor', [0.9 0.8 0.7], ...
                      'LineWidth', 1, 'Curvature', 0.02);
            
            % Número y texto de la recomendación
            text(0.12, rec_y_pos-0.06, sprintf('%d.', i), 'Units', 'normalized', ...
                 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.6 0.3 0]);
            
            text(0.18, rec_y_pos-0.06, recomendacion{i}, 'Units', 'normalized', ...
                 'FontSize', 10, 'FontWeight', 'bold', 'VerticalAlignment', 'middle', ...
                 'Color', [0.2 0.1 0], 'Interpreter', 'none');
            
            rec_y_pos = rec_y_pos - 0.14;
        end
        
        % Indicar si hay más recomendaciones
        if length(recomendacion) > 6
            text(0.5, 0.05, sprintf('+ %d recomendaciones adicionales', length(recomendacion)-6), ...
                 'Units', 'normalized', 'FontSize', 9, 'FontWeight', 'bold', ...
                 'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);
        end
    else
        text(0.5, 0.5, 'No hay recomendaciones específicas', 'HorizontalAlignment', 'center', ...
             'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.5 0.5 0.5]);
    end
    
    %% INFORMACIÓN DEL SISTEMA (en la parte inferior de todos los paneles)
    % Crear un axes separado para el footer
    axes('Position', [0.05 0.01 0.9 0.04]);
    axis off;
    
    info_sistema = {
        'SISTEMA DE ANÁLISIS UNIFICADO AVANZADO | '
        'MÉTODOS: Segmentación + Modelado Biomecánico + Análisis Estadístico | '
        'FIGURAS: 9 Análisis Completos | '
        'CLASIFICACIÓN: 4 Categorías de Riesgo'
    };
    
    text(0.5, 0.5, info_sistema, 'Units', 'normalized', ...
         'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'Color', [0.3 0.3 0.5], 'BackgroundColor', [0.95 0.95 0.98]);
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

function generarInformeUnificado(info, resultados, diagnostico, recomendacion, ...
    metricas, modelo_biomecanico, puntuacion_total, num_lesiones_total)
    
    fprintf('\n=== INFORME UNIFICADO DE ANÁLISIS MAMARIO ===\n');
    fprintf('Fecha de generación: %s\n', datestr(now));
    fprintf('Sistema: Análisis Unificado Avanzado (9 Figuras)\n\n');
    
    fprintf('INFORMACIÓN DEL ESTUDIO:\n');
    fprintf('───────────────────────\n');
    fprintf('Modalidad: %s\n', info.Modality);
    if isfield(info, 'SeriesDescription')
        fprintf('Descripción: %s\n', info.SeriesDescription);
    end
    fprintf('Dimensiones: %dx%d\n', info.Dimensions(1), info.Dimensions(2));
    
    fprintf('\nANÁLISIS DE DENSIDAD:\n');
    fprintf('────────────────────\n');
    fprintf('Porcentaje de densidad: %.1f%%\n', metricas.porcentaje_densidad);
    fprintf('Categoría BI-RADS: %s\n', metricas.birads_categoria);
    fprintf('Descripción: %s\n', metricas.birads_descripcion);
    fprintf('Área total analizada: %d píxeles\n', metricas.area_total);
    fprintf('Área de tejido denso: %d píxeles\n', metricas.area_densa);
    
    fprintf('\nMODELADO BIOMECÁNICO:\n');
    fprintf('────────────────────\n');
    fprintf('Área total modelada: %d píxeles\n', modelo_biomecanico.geometria.area_total);
    if modelo_biomecanico.geometria.area_total > 0
        fprintf('Tejido glandular: %d píxeles (%.1f%%)\n', ...
            modelo_biomecanico.geometria.area_glandular, ...
            (modelo_biomecanico.geometria.area_glandular/modelo_biomecanico.geometria.area_total)*100);
        fprintf('Tejido adiposo: %d píxeles (%.1f%%)\n', ...
            modelo_biomecanico.geometria.area_adiposa, ...
            (modelo_biomecanico.geometria.area_adiposa/modelo_biomecanico.geometria.area_total)*100);
    else
        fprintf('Tejido glandular: 0 píxeles (0.0%%)\n');
        fprintf('Tejido adiposo: 0 píxeles (0.0%%)\n');
    end
    
    fprintf('\nEVALUACIÓN DE LESIONES:\n');
    fprintf('─────────────────────\n');
    fprintf('Número total de lesiones: %d\n', num_lesiones_total);
    
    if ~isempty(resultados)
        malignos = sum(strcmp({resultados.Clasificacion}, 'Maligno'));
        benignos = sum(strcmp({resultados.Clasificacion}, 'Benigno'));
        tumores = sum(strcmp({resultados.Clasificacion}, 'Tumor'));
        indeterminados = sum(strcmp({resultados.Clasificacion}, 'Indeterminado'));
        
        fprintf('• Lesiones malignas: %d\n', malignos);
        fprintf('• Lesiones benignas: %d\n', benignos);
        fprintf('• Tumores: %d\n', tumores);
        fprintf('• Indeterminadas: %d\n', indeterminados);
        fprintf('Puntuación total de riesgo: %.1f\n', puntuacion_total);
        
        % Estadísticas adicionales
        if ~isempty(resultados)
            areas = [resultados.Area];
            fprintf('Área promedio de lesiones: %.0f píxeles\n', mean(areas));
            fprintf('Área máxima: %.0f píxeles\n', max(areas));
            fprintf('Área mínima: %.0f píxeles\n', min(areas));
        end
    else
        fprintf('• No se detectaron lesiones\n');
    end
    
    fprintf('\nDIAGNÓSTICO:\n');
    fprintf('────────────\n');
    fprintf('%s\n\n', diagnostico);
    
    fprintf('RECOMENDACIONES:\n');
    fprintf('────────────────\n');
    for i = 1:length(recomendacion)
        fprintf('%s\n', recomendacion{i});
    end
    
    fprintf('\nRESUMEN DEL SISTEMA:\n');
    fprintf('───────────────────\n');
    fprintf('• 9 Figuras generadas para análisis completo\n');
    fprintf('• Integración: Procesamiento + Biomecánica + Estadística\n');
    fprintf('• Métodos: Segmentación adaptativa + Top-hat + Modelado físico\n');
    fprintf('• Clasificación: 4 categorías con criterios múltiples\n');
    
    fprintf('\n=== FIN DEL INFORME ===\n');
end