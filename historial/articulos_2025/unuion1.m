%% SISTEMA COMPLETO DE ANÁLISIS DICOM PARA CÁNCER DE MAMA
% Usando las funciones DICOM disponibles

clear all; close all; clc;

%% CONFIGURACIÓN INICIAL
disp('=== SISTEMA DICOM DE DETECCIÓN DE CÁNCER DE MAMA ===');
disp('Inicializando sistema...');

% Parámetros del sistema
umbral_area_minima = 1000;
umbral_compacidad_maligna = 1.3;
umbral_diametro_maligno = 150;

%% CARGA Y PROCESAMIENTO DE DATOS DICOM
try
    % Seleccionar archivo o carpeta DICOM
    [filename, pathname] = uigetfile({'*.dcm;*.dicom', 'Archivos DICOM'; '*.*', 'Todos los archivos'}, ...
                                    'Seleccione archivo DICOM o carpeta');
    
    if isequal(filename, 0)
        error('No se seleccionó ningún archivo.');
    end
    
    fullpath = fullfile(pathname, filename);
    fprintf('Procesando: %s\n', fullpath);
    
    % Intentar carga directa
    fprintf('Cargando archivo DICOM directamente...\n');
    info = dicominfo(fullpath);
    volumen_dicom = dicomread(fullpath);
    info.Filenames = {fullpath};
    info.PixelDimensions = [1, 1];
    info.Dimensions = size(volumen_dicom);
    if ~isfield(info, 'Modality'), info.Modality = 'MR'; end
    if ~isfield(info, 'SeriesDescription'), info.SeriesDescription = 'Imagen Individual'; end
    
    fprintf('Carga directa exitosa\n');
    
    % Mostrar información del dataset
    fprintf('\n=== INFORMACIÓN DICOM ===\n');
    fprintf('Modalidad: %s\n', info.Modality);
    fprintf('Descripción: %s\n', info.SeriesDescription);
    fprintf('Dimensiones: %dx%d', info.Dimensions(1), info.Dimensions(2));
    if length(info.Dimensions) > 2
        fprintf('x%d', info.Dimensions(3));
    end
    fprintf('\n');
    
catch ME
    fprintf('Error en carga DICOM: %s\n', ME.message);
    return;
end

%% NORMALIZACIÓN Y PREPROCESAMIENTO
disp('Realizando normalización DICOM...');

% Aplicar normalización si hay información de rescale
if isfield(info, 'RescaleSlope') && isfield(info, 'RescaleIntercept')
    volumen_normalizado = single(volumen_dicom);
    volumen_normalizado = volumen_normalizado * info.RescaleSlope + info.RescaleIntercept;
    fprintf('Aplicada normalización DICOM: Slope=%.2f, Intercept=%.2f\n', ...
            info.RescaleSlope, info.RescaleIntercept);
else
    volumen_normalizado = single(volumen_dicom);
    fprintf('No se encontraron parámetros de normalización DICOM\n');
end

% Determinar dimensiones y seleccionar imagen para análisis
if ndims(volumen_normalizado) > 2
    % Es un volumen - seleccionar slice central
    if size(volumen_normalizado, 3) > 1
        slice_idx = round(size(volumen_normalizado, 3) / 2);
        imagen_actual = volumen_normalizado(:, :, slice_idx);
        fprintf('Analizando slice %d de %d\n', slice_idx, size(volumen_normalizado, 3));
    else
        imagen_actual = volumen_normalizado;
    end
else
    % Imagen 2D
    imagen_actual = volumen_normalizado;
end

% Convertir a escala 0-1 para procesamiento
imagen_actual = mat2gray(imagen_actual);

% Preprocesamiento de la imagen
disp('Realizando preprocesamiento...');
imagen_contraste = imadjust(imagen_actual);
imagen_filtrada = medfilt2(imagen_contraste, [3 3]);
imagen_ecualizada = histeq(imagen_filtrada);
imagen_suavizada = imgaussfilt(imagen_ecualizada, 1);

%% SEGMENTACIÓN Y ANÁLISIS
disp('Realizando segmentación...');

% Segmentación combinada
mascara_adaptativa = imbinarize(imagen_suavizada, 'adaptive');
mascara_otsu = imbinarize(imagen_suavizada);

% Intentar Active Contour, si falla usar máscara simple
try
    mascara_contorno = activecontour(imagen_suavizada, mascara_otsu, 50, 'edge');
    mascara_combinada = mascara_adaptativa | mascara_contorno;
catch
    fprintf('Active Contour falló, usando segmentación adaptativa\n');
    mascara_combinada = mascara_adaptativa;
end

% Limpieza morfológica
elemento_estructurante = strel('disk', 3);
mascara_limpia = imopen(mascara_combinada, elemento_estructurante);
mascara_limpia = imclose(mascara_limpia, elemento_estructurante);
mascara_final = bwareaopen(mascara_limpia, umbral_area_minima);

%% EXTRACCIÓN DE CARACTERÍSTICAS
disp('Extrayendo características...');

% Análisis de regiones
[etiquetas, num_regiones] = bwlabel(mascara_final);

if num_regiones > 0
    propiedades = regionprops(etiquetas, {'Area', 'Perimeter', 'BoundingBox', 'Centroid'});
    
    % Encontrar región principal
    areas = [propiedades.Area];
    [area_max, idx_principal] = max(areas);
    lesion_principal = propiedades(idx_principal);
    
    % Calcular métricas
    diametro_equivalente = 2 * sqrt(area_max / pi);
    compacidad = (lesion_principal.Perimeter^2) / (4 * pi * area_max);
    
    % Características de intensidad
    mascara_lesion = (etiquetas == idx_principal);
    intensidad_promedio = mean(imagen_suavizada(mascara_lesion));
    
    % Características de textura (GLCM)
    try
        glcm = graycomatrix(imagen_suavizada, 'Offset', [0 1], 'NumLevels', 8);
        stats = graycoprops(glcm, {'Contrast', 'Correlation', 'Energy', 'Homogeneity'});
        contraste_promedio = stats.Contrast;
    catch
        contraste_promedio = 0;
    end
    
    resultados = struct(...
        'Area', area_max, ...
        'Diametro', diametro_equivalente, ...
        'Compacidad', compacidad, ...
        'Intensidad', intensidad_promedio, ...
        'Contraste', contraste_promedio, ...
        'NumRegiones', num_regiones);
else
    resultados = [];
    lesion_principal = [];
    fprintf('No se detectaron regiones significativas\n');
end

%% CLASIFICACIÓN
disp('Realizando clasificación...');

if ~isempty(resultados)
    % Sistema de puntuación
    puntuacion = 0;
    
    % Evaluar tamaño
    if resultados.Diametro > umbral_diametro_maligno
        puntuacion = puntuacion + 3;
        fprintf('- Diámetro grande: +3 puntos\n');
    elseif resultados.Diametro > umbral_diametro_maligno/2
        puntuacion = puntuacion + 1;
        fprintf('- Diámetro moderado: +1 punto\n');
    end
    
    % Evaluar forma
    if resultados.Compacidad > umbral_compacidad_maligna
        puntuacion = puntuacion + 2;
        fprintf('- Forma irregular: +2 puntos\n');
    end
    
    % Evaluar textura
    if resultados.Contraste > 0.3
        puntuacion = puntuacion + 1;
        fprintf('- Textura heterogénea: +1 punto\n');
    end
    
    fprintf('Puntuación total: %d/6\n', puntuacion);
    
    % Diagnóstico final
    if puntuacion >= 4
        diagnostico = 'SOSPECHA DE MALIGNIDAD';
        color_diagnostico = [1 0 0];
        recomendacion = 'Biopsia inmediata recomendada. Consultar con especialista.';
    elseif puntuacion >= 2
        diagnostico = 'LESIÓN BENIGNA SOSPECHOSA';
        color_diagnostico = [1 1 0];
        recomendacion = 'Seguimiento en 6 meses recomendado. Evaluación adicional necesaria.';
    else
        diagnostico = 'HALLAZGOS NORMALES';
        color_diagnostico = [0 1 0];
        recomendacion = 'Continuar con revisiones anuales según protocolo.';
    end
else
    diagnostico = 'SIN HALLAZGOS SIGNIFICATIVOS';
    color_diagnostico = [0 0 1];
    recomendacion = 'No se detectaron lesiones. Continuar con screening rutinario.';
    puntuacion = 0;
end

%% VISUALIZACIÓN COMPLETA
disp('Generando visualizaciones...');

figure('Name', 'Análisis DICOM - Cáncer de Mama', ...
       'Position', [50 50 1400 800], ...
       'Color', [0.98 0.98 0.98]);

% 1. Imagen DICOM original
subplot(2, 3, 1);
imshow(imagen_actual, []);
title('Imagen DICOM Original', 'FontSize', 12, 'FontWeight', 'bold');
colorbar;

% 2. Imagen preprocesada
subplot(2, 3, 2);
imshow(imagen_suavizada, []);
title('Imagen Preprocesada', 'FontSize', 12, 'FontWeight', 'bold');
colorbar;

% 3. Máscara segmentada
subplot(2, 3, 3);
imshow(mascara_final);
title(sprintf('Segmentación (%d regiones)', num_regiones), 'FontSize', 12, 'FontWeight', 'bold');

% 4. Superposición
subplot(2, 3, 4);
imshow(imagen_actual, []);
hold on;

if ~isempty(lesion_principal)
    % Dibujar contornos de todas las regiones
    for i = 1:num_regiones
        mascara_region = (etiquetas == i);
        contornos = bwboundaries(mascara_region);
        for k = 1:length(contornos)
            contorno = contornos{k};
            if i == idx_principal
                plot(contorno(:,2), contorno(:,1), 'r-', 'LineWidth', 3);
            else
                plot(contorno(:,2), contorno(:,1), 'y-', 'LineWidth', 1.5);
            end
        end
    end
    
    % Dibujar bounding box de la lesión principal
    bbox = lesion_principal.BoundingBox;
    rectangle('Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2, 'LineStyle', '--');
    
    % Marcar centroide
    centroid = lesion_principal.Centroid;
    plot(centroid(1), centroid(2), 'ro', 'MarkerSize', 10, 'LineWidth', 3);
end

title('Lesiones Detectadas', 'FontSize', 12, 'FontWeight', 'bold');
hold off;

% 5. Métricas y diagnóstico
subplot(2, 3, 5);
axis off;

if ~isempty(resultados)
    texto_metricas = {
        'MÉTRICAS DE LA LESION:';
        '────────────────────';
        sprintf('Área: %.0f píxeles', resultados.Area);
        sprintf('Diámetro: %.1f píxeles', resultados.Diametro);
        sprintf('Compacidad: %.3f', resultados.Compacidad);
        sprintf('Intensidad: %.3f', resultados.Intensidad);
        sprintf('Contraste: %.3f', resultados.Contraste);
        '';
        sprintf('Número de regiones: %d', resultados.NumRegiones);
        sprintf('Puntuación: %d/6', puntuacion);
    };
else
    texto_metricas = {
        'MÉTRICAS:';
        '────────';
        'No se detectaron';
        'lesiones significativas';
    };
end

text(0.1, 0.8, texto_metricas, 'FontSize', 11, 'FontName', 'Courier', ...
     'VerticalAlignment', 'top', 'Units', 'normalized', 'FontWeight', 'bold');

% 6. Diagnóstico y recomendación - CORREGIDO
subplot(2, 3, 6);
axis off;

% Crear el texto diagnóstico de manera más robusta
texto_base = {
    'DIAGNÓSTICO:';
    '───────────';
    '';
    diagnostico;
    '';
    'RECOMENDACIÓN:';
    '─────────────';
    ''
};

% Dividir la recomendación en líneas más cortas de manera segura
palabras = strsplit(recomendacion, ' ');
linea_actual = '';
lineas_recomendacion = {};

for i = 1:length(palabras)
    if isempty(linea_actual)
        linea_actual = palabras{i};
    else
        prueba_linea = [linea_actual ' ' palabras{i}];
        if length(prueba_linea) <= 35
            linea_actual = prueba_linea;
        else
            lineas_recomendacion{end+1} = linea_actual;
            linea_actual = palabras{i};
        end
    end
end

% Añadir la última línea si no está vacía
if ~isempty(linea_actual)
    lineas_recomendacion{end+1} = linea_actual;
end

% Combinar todo el texto
texto_final = [texto_base; lineas_recomendacion'];

text(0.1, 0.7, texto_final, 'FontSize', 11, 'FontName', 'Arial', ...
     'VerticalAlignment', 'top', 'Units', 'normalized', ...
     'Color', color_diagnostico, 'FontWeight', 'bold');

%% REPORTE FINAL EN CONSOLA
fprintf('\n=== REPORTE DE ANÁLISIS DICOM ===\n');
fprintf('Archivo: %s\n', fullpath);
fprintf('Fecha de análisis: %s\n', datestr(now));
fprintf('Modalidad: %s\n', info.Modality);
fprintf('Descripción: %s\n', info.SeriesDescription);

if ~isempty(resultados)
    fprintf('\n--- HALLAZGOS ---\n');
    fprintf('Lesión principal detectada:\n');
    fprintf('  • Área: %.0f píxeles\n', resultados.Area);
    fprintf('  • Diámetro equivalente: %.1f píxeles\n', resultados.Diametro);
    fprintf('  • Compacidad: %.3f\n', resultados.Compacidad);
    fprintf('  • Intensidad promedio: %.3f\n', resultados.Intensidad);
    fprintf('  • Contraste textural: %.3f\n', resultados.Contraste);
    fprintf('  • Número de regiones: %d\n', resultados.NumRegiones);
    fprintf('  • Puntuación de riesgo: %d/6\n', puntuacion);
end

fprintf('\n--- DIAGNÓSTICO ---\n');
fprintf('%s\n', diagnostico);
fprintf('\n--- RECOMENDACIÓN ---\n');
fprintf('%s\n', recomendacion);

fprintf('\n=== ANÁLISIS COMPLETADO ===\n');

%% OPCIÓN DE EXPORTACIÓN SIMPLIFICADA
try
    respuesta = input('\n¿Exportar imagen de resultados? (s/n): ', 's');
    if lower(respuesta) == 's'
        nombre_export = sprintf('Resultado_DICOM_%s_%s.png', ...
                              info.Modality, datestr(now, 'yyyy-mm-dd_HH-MM'));
        saveas(gcf, nombre_export);
        fprintf('Resultados guardados como: %s\n', nombre_export);
    end
catch
    fprintf('Exportación cancelada\n');
end

fprintf('\nSistema DICOM finalizado.\n');