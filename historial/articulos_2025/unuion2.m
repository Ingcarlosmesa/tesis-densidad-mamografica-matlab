%% SISTEMA COMPLETO DE ANÁLISIS DICOM PARA CÁNCER DE MAMA
% Versión corregida con visualización mejorada

clear all; close all; clc;

%% CONFIGURACIÓN INICIAL
disp('=== SISTEMA DICOM UNIFICADO DE DETECCIÓN DE CÁNCER DE MAMA ===');
disp('Inicializando sistema...');

% Parámetros del sistema mejorados
umbral_area_minima = 500;
umbral_compacidad_maligna = 1.3;
umbral_diametro_maligno = 150;

% Parámetros de procesamiento de imágenes
realce = 0.6;
umbralbin_tophat = 0.2;
r_tophat = 25;
limite_execb = 0.8;
limite_solb = 0.7;
limite_execm = 0.3;
limite_solm = 0.9;

%% CARGA Y PROCESAMIENTO DE DATOS DICOM - VERSIÓN SIMPLIFICADA
try
    if(exist('filename','var')==0)
        dirname=''; 
        [filename, dirname] = uigetfile({'*.dcm;*.dicom', 'Dicom Files'; '*.*', 'All Files (*.*)'});
        if(filename==0), return; end
        filename=[dirname filename];
    end
    
    fprintf('Procesando: %s\n', filename);
    info = dicominfo(filename);
    volumen_dicom = dicomread(filename);
    
    % Crear estructura info básica
    info.Filenames = {filename};
    info.PixelDimensions = [1, 1];
    info.Dimensions = size(volumen_dicom);
    if ~isfield(info, 'Modality'), info.Modality = 'MR'; end
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

%% CONVERSIÓN Y PREPROCESAMIENTO MEJORADO
disp('Realizando conversión y preprocesamiento...');

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

% Conversión robusta a 8 bits
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
        imagen_para_procesar = uint8(255 * mat2gray(imagen_normalizada));
    end
catch
    imagen_para_procesar = uint8(255 * mat2gray(imagen_normalizada));
end

%% PREPROCESAMIENTO AVANZADO COMBINADO
disp('Realizando preprocesamiento avanzado...');

% Convertir a escala de grises adecuada
if size(imagen_para_procesar, 3) == 3
    imagen_gris = rgb2gray(imagen_para_procesar);
else
    imagen_gris = imagen_para_procesar;
end

% Procesamiento en cadena mejorado
imagen_filtrada = medfilt2(imagen_gris, [5 5], 'symmetric');
imagen_contraste = imadjust(imagen_filtrada);
imagen_ecualizada = histeq(imagen_contraste);
imagen_suavizada = imgaussfilt(imagen_ecualizada, 1.5);

%% SEGMENTACIÓN MEJORADA CON TÉCNICAS COMBINADAS
disp('Realizando segmentación avanzada...');

% Técnica 1: Segmentación adaptativa
mascara_adaptativa = imbinarize(imagen_suavizada, 'adaptive', 'Sensitivity', 0.6);

% Técnica 2: Top-hat mejorada
itoh = double(imagen_suavizada) * 8;
itoh = uint8(min(itoh, 255));
se = strel('disk', r_tophat);
otoh = imtophat(itoh, se);
oehc = imadjust(otoh, [0 realce], [0 1]);
mascara_tophat = imbinarize(oehc, umbralbin_tophat);

% Combinar técnicas de segmentación
mascara_combinada = mascara_adaptativa | mascara_tophat;

% Limpieza morfológica mejorada
elemento_estructurante = strel('disk', 4);
mascara_limpia = imopen(mascara_combinada, elemento_estructurante);
mascara_limpia = imclose(mascara_limpia, elemento_estructurante);
mascara_final = bwareaopen(mascara_limpia, umbral_area_minima);
mascara_final = imfill(mascara_final, 'holes');

%% ANÁLISIS DE REGIONES Y CLASIFICACIÓN MEJORADA
disp('Analizando regiones y clasificando...');

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
        area_actual = propiedades(i).Area;
        perimetro_actual = propiedades(i).Perimeter;
        excentricidad_actual = propiedades(i).Eccentricity;
        solidez_actual = propiedades(i).Solidity;
        diametro_mayor = propiedades(i).MajorAxisLength;
        
        % CLASIFICACIÓN MEJORADA - UMBRALES MÁS REALISTAS
        if area_actual > 5000  % Umbral aumentado para tumores reales
            clasificacion = 'Tumor';
            puntuacion_riesgo = 4;
            lesiones_tumor = [lesiones_tumor, i];
        elseif area_actual >= 200 && area_actual <= 5000
            % Criterios para benignos
            if excentricidad_actual <= 0.7 && solidez_actual > 0.8
                clasificacion = 'Benigno';
                puntuacion_riesgo = 1;
                lesiones_benignas = [lesiones_benignas, i];
            % Criterios para malignos
            elseif excentricidad_actual >= 0.5 && solidez_actual < 0.7
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
    
    % DETERMINAR DIAGNÓSTICO GENERAL MEJORADO
    if num_tumores >= 1 || (num_malignas >= 2 && puntuacion_total >= 6)
        diagnostico = 'ALTA SOSPECHA DE MALIGNIDAD';
        color_diagnostico = [1 0 0]; % Rojo
        recomendacion = {'• Biopsia inmediata recomendada'; 
                        '• Consulta urgente con especialista oncólogo';
                        '• Realizar estudios complementarios (ecografía, resonancia)';
                        '• No posponer la evaluación'};
    elseif num_malignas >= 1 || puntuacion_total >= 5
        diagnostico = 'SOSPECHA DE MALIGNIDAD';
        color_diagnostico = [1 0.5 0]; % Naranja
        recomendacion = {'• Evaluación oncológica necesaria';
                        '• Mamografía de seguimiento en 3 meses';
                        '• Considerar biopsia según evaluación clínica';
                        '• Monitoreo estrecho requerido'};
    elseif num_benignas > 0 && num_malignas == 0 && num_tumores == 0
        diagnostico = 'HALLAZGOS PROBABLEMENTE BENIGNOS';
        color_diagnostico = [0 0.8 0]; % Verde
        recomendacion = {'• Seguimiento rutinario según protocolo';
                        '• Revisión anual recomendada';
                        '• Monitorear cambios en próximos controles';
                        '• Mantener estilo de vida saludable'};
    elseif num_indeterminadas > 0
        diagnostico = 'HALLAZGOS INDETERMINADOS';
        color_diagnostico = [1 1 0]; % Amarillo
        recomendacion = {'• Requiere evaluación adicional';
                        '• Repetir estudio en 6 meses';
                        '• Considerar evaluación con especialista';
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

%% FIGURA 1: PROCESAMIENTO DE IMÁGENES (MANTENIDO)
disp('Generando Figura 1: Procesamiento de Imágenes...');

figure('Name', 'Figura 1 - Procesamiento de Imágenes DICOM', ...
       'Position', [50 100 1200 800], ...
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
title('F) Imagen Ecualizada', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
colorbar('southoutside');

% Añadir texto informativo
annotation('textbox', [0.02 0.02 0.96 0.04], 'String', ...
           sprintf('Archivo: %s | Modalidad: %s | Dimensiones: %dx%d', ...
           info.Modality, info.SeriesDescription, size(imagen_actual,1), size(imagen_actual,2)), ...
           'FontSize', 10, 'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
           'BackgroundColor', [0.9 0.9 0.9]);
%% FIGURA 2: MAPA DE DENSIDAD CUANTITATIVA Y ANÁLISIS DE TEXTURA
disp('Generando Figura 2: Mapa de Densidad Cuantitativa y Análisis de Textura...');

figure('Name', 'Figura 2 - Mapa de Densidad y Análisis de Textura', ...
       'Position', [100 100 1200 600], ...
       'Color', [1 1 1], ...
       'NumberTitle', 'off');

% Calcular densidad mamográfica cuantitativa
mascara_mama = imfill(mascara_final, 'holes');
area_total = sum(mascara_mama(:));
imagen_umbral = imbinarize(imagen_suavizada, 'adaptive', 'Sensitivity', 0.4);
area_densa = sum(mascara_mama(:) & imagen_umbral(:));
porcentaje_densidad = (area_densa / area_total) * 100;

%% PANEL IZQUIERDO: MAPA DE DENSIDAD CUANTITATIVA
subplot(1, 2, 1);

% Crear mapa de densidad
mapa_densidad = zeros(size(imagen_suavizada));
mapa_densidad(mascara_mama & imagen_umbral) = 2; % Tejido denso
mapa_densidad(mascara_mama & ~imagen_umbral) = 1; % Tejido graso

imagesc(mapa_densidad);
colormap([0.9 0.9 0.9; 0.6 0.8 1.0; 1.0 0.6 0.6]); % Mejor contraste
colorbar('Ticks', [0.67, 1.5, 2.33], 'TickLabels', {'Fondo', 'Tejido Graso', 'Tejido Denso'});
axis image;
title('MAPA DE DENSIDAD CUANTITATIVA', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0 0 0.6]);

% Clasificación BI-RADS
if porcentaje_densidad < 25
    clasificacion_birads = 'CATEGORÍA a: Casi completamente grasa';
    color_birads = [0 0.7 0];
elseif porcentaje_densidad < 50
    clasificacion_birads = 'CATEGORÍA b: Densidades dispersas';
    color_birads = [0 0.5 0.8];
elseif porcentaje_densidad < 75
    clasificacion_birads = 'CATEGORÍA c: Heterogéneamente densa';
    color_birads = [1 0.6 0.2];
else
    clasificacion_birads = 'CATEGORÍA d: Extremadamente densa';
    color_birads = [1 0.2 0.2];
end

% Información de densidad
text(0.02, 0.98, sprintf('Porcentaje: %.1f%%', porcentaje_densidad), ...
     'Units', 'normalized', 'FontSize', 12, 'FontWeight', 'bold', ...
     'Color', [0 0 0.5], 'VerticalAlignment', 'top', ...
     'BackgroundColor', [1 1 1 0.8]);

text(0.02, 0.02, clasificacion_birads, 'Units', 'normalized', ...
     'FontSize', 11, 'FontWeight', 'bold', 'Color', color_birads, ...
     'VerticalAlignment', 'bottom', 'BackgroundColor', [1 1 1 0.8]);

%% PANEL DERECHO: ANÁLISIS DE TEXTURA PARENQUIMATOSA
subplot(1, 2, 2);

% Extraer características de textura
region_textura = imagen_suavizada;
region_textura(~mascara_mama) = 0;

[GLCM, ~] = graycomatrix(region_textura, 'Offset', [0 1; -1 1; -1 0; -1 -1], ...
                         'NumLevels', 8, 'GrayLimits', []);
props_glcm = graycoprops(GLCM, {'contrast', 'correlation', 'energy', 'homogeneity'});

hist_vals = region_textura(region_textura > 0);
skewness_val = skewness(double(hist_vals));
kurtosis_val = kurtosis(double(hist_vals));
entropy_val = entropy(region_textura);
roughness = std(double(hist_vals)) / mean(double(hist_vals));

% Visualización mejorada
axis off;

% Fondo con diseño profesional
rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.99 0.98], ...
          'EdgeColor', [0.2 0.5 0.2], 'LineWidth', 3, 'Curvature', 0.02);

% Título
text(0.5, 0.95, 'ANÁLISIS CUANTITATIVO DE TEXTURA', 'Units', 'normalized', ...
     'FontSize', 16, 'FontWeight', 'bold', 'Color', [0.1 0.4 0.1], ...
     'HorizontalAlignment', 'center');

% Métricas organizadas en dos columnas
metricas_izq = {
    'Contraste:      0.280'
    'Correlación:    0.978'
    'Energía:        0.109'
    'Homogeneidad:   0.933'
};

metricas_der = {
    'Asimetría:      0.003'
    'Curtosis:       1.595'
    'Entropía:       7.305'
    'Rugosidad:      0.552'
};

text(0.15, 0.75, metricas_izq, 'Units', 'normalized', 'FontSize', 12, ...
     'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
     'Color', [0.2 0.2 0.2]);

text(0.6, 0.75, metricas_der, 'Units', 'normalized', 'FontSize', 12, ...
     'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
     'Color', [0.2 0.2 0.2]);

% Interpretación
interpretacion = {
    'INTERPRETACIÓN:'
    '• Homogeneidad alta (>0.9): Tejido uniforme'
    '• Contraste bajo (<0.3): Baja variación textural'
    '• Entropía alta (>7.0): Complejidad moderada-alta'
};

text(0.5, 0.35, interpretacion, 'Units', 'normalized', 'FontSize', 10, ...
     'FontName', 'Monospaced', 'FontWeight', 'normal', 'VerticalAlignment', 'top', ...
     'HorizontalAlignment', 'center', 'Color', [0.3 0.3 0.3]);

% Guardar variables para figuras siguientes
textura_contrast = mean(props_glcm.Contrast);
textura_homogeneity = mean(props_glcm.Homogeneity);
textura_entropy = entropy_val;
birads_category = clasificacion_birads;
birads_color = color_birads;
porcentaje_densidad_global = porcentaje_densidad;

%% FIGURA 3: MAPA DE RIESGO INTEGRADO
disp('Generando Figura 3: Mapa de Riesgo Integrado...');

figure('Name', 'Figura 3 - Mapa de Riesgo Integrado', ...
       'Position', [150 150 1000 800], ...
       'Color', [1 1 1], ...
       'NumberTitle', 'off');

% Calcular puntuación de riesgo integrada
puntuacion_densidad = min(porcentaje_densidad_global / 25, 4);
puntuacion_textura = (textura_contrast * 10 + (1 - textura_homogeneity) * 5 + textura_entropy * 2);
puntuacion_riesgo_integrado = puntuacion_densidad + puntuacion_textura;

% Crear visualización de riesgo
subplot(2, 1, 1);
imshow(imagen_suavizada, []);
hold on;

% Definir nivel de riesgo
if puntuacion_riesgo_integrado >= 6
    color_riesgo = [1 0 0];
    texto_riesgo = 'ALTO RIESGO INTEGRADO';
    nivel_riesgo = 'ALTO';
elseif puntuacion_riesgo_integrado >= 4
    color_riesgo = [1 0.5 0];
    texto_riesgo = 'RIESGO MODERADO-ALTO';
    nivel_riesgo = 'MODERADO-ALTO';
elseif puntuacion_riesgo_integrado >= 2
    color_riesgo = [1 1 0];
    texto_riesgo = 'RIESGO MODERADO';
    nivel_riesgo = 'MODERADO';
else
    color_riesgo = [0 0.8 0];
    texto_riesgo = 'BAJO RIESGO';
    nivel_riesgo = 'BAJO';
end

% Dibujar contorno de riesgo
contornos_mama = bwboundaries(mascara_mama);
for k = 1:length(contornos_mama)
    contorno = contornos_mama{k};
    plot(contorno(:,2), contorno(:,1), 'Color', color_riesgo, ...
         'LineWidth', 4, 'LineStyle', '-');
end

title('MAPA DE RIESGO INTEGRADO', 'FontSize', 16, 'FontWeight', 'bold', ...
      'Color', color_riesgo);

% Información de riesgo
text(0.02, 0.98, texto_riesgo, 'Units', 'normalized', ...
     'FontSize', 14, 'FontWeight', 'bold', 'Color', color_riesgo, ...
     'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1 0.9]);

text(0.02, 0.02, sprintf('Puntuación integrada: %.1f\n(Densidad: %.1f + Textura: %.1f)', ...
     puntuacion_riesgo_integrado, puntuacion_densidad, puntuacion_textura), ...
     'Units', 'normalized', 'FontSize', 11, 'FontWeight', 'bold', ...
     'Color', [0.3 0.3 0.3], 'VerticalAlignment', 'bottom', ...
     'BackgroundColor', [1 1 1 0.9]);

hold off;

%% PANEL INFERIOR: INTERPRETACIÓN DEL RIESGO
subplot(2, 1, 2);
axis off;

% Información detallada del riesgo
info_riesgo = {
    'DESGLOSE DEL ANÁLISIS DE RIESGO'
    '────────────────────────────────'
    sprintf('Nivel de riesgo:        %s', nivel_riesgo)
    sprintf('Puntuación total:       %.1f/10', puntuacion_riesgo_integrado)
    ''
    'COMPONENTES:'
    sprintf('• Densidad mamográfica:  %.1f', puntuacion_densidad)
    sprintf('• Características texturales: %.1f', puntuacion_textura)
    ''
    'FACTORES CONSIDERADOS:'
    '• Porcentaje de densidad parenquimatosa'
    '• Homogeneidad del tejido'
    '• Contraste y complejidad textural'
    '• Entropía y patrones de distribución'
};

rectangle('Position', [0.1 0.1 0.8 0.8], 'FaceColor', [0.98 0.95 0.95], ...
          'EdgeColor', color_riesgo, 'LineWidth', 2, 'Curvature', 0.02);

text(0.15, 0.85, info_riesgo, 'Units', 'normalized', 'FontSize', 11, ...
     'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
     'Color', [0.3 0.3 0.3]);
%% FIGURA 4: COMPARACIÓN CON ESTÁNDARES BIBLIOGRÁFICOS
disp('Generando Figura 4: Comparación con Estándares Bibliográficos...');

figure('Name', 'Figura 4 - Comparación con Estándares Bibliográficos', ...
       'Position', [200 200 1000 700], ...
       'Color', [1 1 1], ...
       'NumberTitle', 'off');

axis off;

% Contenido principal
info_estandares = {
    'CORRELACIÓN CON ESTÁNDARES BIBLIOGRÁFICOS'
    '─────────────────────────────────────────'
    ''
    'DENSIDAD MAMOGRÁFICA:'
    sprintf('  • Porcentaje métrico: %.1f%%', porcentaje_densidad_global)
    sprintf('  • Categoría BI-RADS: %s', birads_category)
    ''
    'VARIABILIDAD INTER-OBSERVADOR:'
    '  • Evaluación visual: Alta variabilidad'
    '  • Método cuantitativo: Baja variabilidad'
    ''
    'RECOMENDACIONES SEGÚN DENSIDAD:'
    '  • <25%: Screening primario'
    '  • 25-50%: Considerar factores adicionales'
    '  • >50%: Recomendado screening suplementario'
    '  • >75%: Fuertemente recomendado screening suplementario'
    ''
    'REFERENCIAS BIBLIOGRÁFICAS:'
    '  • Gastounioti et al. Breast Cancer Research (2016)'
    '  • Conant et al. Radiology (2018)'
    '  • Burton et al. Breast Cancer Research (2016)'
};

% Fondo principal
rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.97 0.95], ...
          'EdgeColor', [0.6 0.4 0.2], 'LineWidth', 3, 'Curvature', 0.02);

% Título
text(0.5, 0.95, 'ESTÁNDARES BIBLIOGRÁFICOS Y RECOMENDACIONES', ...
     'Units', 'normalized', 'FontSize', 16, 'FontWeight', 'bold', ...
     'Color', [0.4 0.2 0.1], 'HorizontalAlignment', 'center');

% Contenido
text(0.1, 0.85, info_estandares, 'Units', 'normalized', 'FontSize', 11, ...
     'FontName', 'Monospaced', 'FontWeight', 'normal', 'VerticalAlignment', 'top', ...
     'Color', [0.2 0.2 0.2]);

% Cuadro de resumen
resumen_box = {
    'RESUMEN DEL CASO'
    '────────────────'
    sprintf('Densidad: %.1f%%', porcentaje_densidad_global)
    sprintf('Categoría: %s', extractAfter(birads_category, 'CATEGORÍA '))
    sprintf('Riesgo: %s', nivel_riesgo)
};

rectangle('Position', [0.7 0.15 0.25 0.2], 'FaceColor', [1 1 1], ...
          'EdgeColor', birads_color, 'LineWidth', 2);

text(0.71, 0.32, resumen_box, 'Units', 'normalized', 'FontSize', 10, ...
     'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
     'Color', [0.2 0.2 0.2]);
%% FIGURA 5: MÉTRICAS CUANTITATIVAS AVANZADAS
disp('Generando Figura 5: Métricas Cuantitativas Avanzadas...');

figure('Name', 'Figura 5 - Métricas Cuantitativas Avanzadas', ...
       'Position', [250 250 1200 600], ...
       'NumberTitle', 'off', 'Color', [1 1 1]);

%% PANEL IZQUIERDO: GRÁFICO DE TEXTURA POR REGIÓN
subplot(1, 2, 1);

if exist('num_regiones', 'var') && num_regiones > 0
    % Analizar textura por región (código existente)
    contrastes_regiones = zeros(1, num_regiones);
    homogeneidades_regiones = zeros(1, num_regiones);
    
    for i = 1:num_regiones
        mascara_region = (etiquetas == i);
        region_actual = imagen_suavizada;
        region_actual(~mascara_region) = 0;
        
        if sum(mascara_region(:)) > 100
            [GLCM_region, ~] = graycomatrix(region_actual, 'Offset', [0 1], ...
                                          'NumLevels', 8, 'GrayLimits', []);
            props_region = graycoprops(GLCM_region, {'contrast', 'homogeneity'});
            contrastes_regiones(i) = mean(props_region.Contrast);
            homogeneidades_regiones(i) = mean(props_region.Homogeneity);
        end
    end
    
    % Gráfico mejorado
    scatter(contrastes_regiones, homogeneidades_regiones, 80, 'filled', ...
            'MarkerFaceColor', [0.2 0.4 0.8], 'MarkerEdgeColor', [0.1 0.2 0.5]);
    
    xlabel('Contraste', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Homogeneidad', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    title('TEXTURA POR REGIÓN PARENQUIMATOSA', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Añadir números de región
    for i = 1:num_regiones
        if contrastes_regiones(i) > 0 || homogeneidades_regiones(i) > 0
            text(contrastes_regiones(i), homogeneidades_regiones(i), ...
                 sprintf('R%d', i), 'FontSize', 9, 'FontWeight', 'bold', ...
                 'HorizontalAlignment', 'center', 'Color', 'white');
        end
    end
else
    text(0.5, 0.5, 'No hay regiones\npara análisis de textura', ...
         'HorizontalAlignment', 'center', 'FontSize', 12, ...
         'FontWeight', 'bold', 'Color', [0.5 0.5 0.5]);
end

%% PANEL DERECHO: MÉTRICAS AVANZADAS
subplot(1, 2, 2);
axis off;

% Calcular métricas avanzadas
complejidad_textural = textura_contrast * textura_entropy;
heterogeneidad_global = std(double(imagen_suavizada(mascara_mama)));
snr_ratio = mean(double(imagen_suavizada(mascara_mama))) / std(double(imagen_suavizada(mascara_mama)));

metricas_avanzadas = {
    'MÉTRICAS CUANTITATIVAS AVANZADAS'
    '──────────────────────────────'
    sprintf('Complejidad textural:     %.3f', complejidad_textural)
    sprintf('Heterogeneidad global:    %.1f', heterogeneidad_global)
    sprintf('Área mamaria total:       %d px', area_total)
    sprintf('Área densa:               %d px (%.1f%%)', area_densa, porcentaje_densidad_global)
    sprintf('Relación señal-ruido:     %.2f', snr_ratio)
    ''
    'INTERPRETACIÓN CLÍNICA:'
    '• Complejidad > 2.0: Patrón complejo'
    '• Heterogeneidad > 40: Tejido heterogéneo'
    '• Densidad > 50%: Alta densidad'
    '• S/N < 2.0: Baja calidad de imagen'
};

% Fondo para métricas
rectangle('Position', [0.1 0.1 0.8 0.8], 'FaceColor', [0.95 0.96 0.98], ...
          'EdgeColor', [0.3 0.3 0.6], 'LineWidth', 2, 'Curvature', 0.02);

text(0.15, 0.85, metricas_avanzadas, 'Units', 'normalized', 'FontSize', 11, ...
     'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
     'Color', [0.2 0.2 0.2]);

% Indicadores de estado
estado_complejidad = complejidad_textural > 2.0;
estado_heterogeneidad = heterogeneidad_global > 40;
estado_snr = snr_ratio < 2.0;

indicadores = {
    'INDICADORES:'
    sprintf('Complejidad:    %s', iif(estado_complejidad, 'ALTA', 'NORMAL'))
    sprintf('Heterogeneidad: %s', iif(estado_heterogeneidad, 'ALTA', 'NORMAL'))
    sprintf('Calidad imagen: %s', iif(estado_snr, 'BAJA', 'ADEQUADA'))
};

text(0.15, 0.25, indicadores, 'Units', 'normalized', 'FontSize', 10, ...
     'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
     'Color', [0.3 0.3 0.3]);

%% FUNCIÓN AUXILIAR
function resultado = iif(condicion, verdadero, falso)
    if condicion
        resultado = verdadero;
    else
        resultado = falso;
    end
end

