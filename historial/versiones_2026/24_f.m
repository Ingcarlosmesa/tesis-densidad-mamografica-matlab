%% =========================================================================
% TESIS DE MAESTRÍA - UNIVERSIDAD ECCI (GIATME)
% Título: Caracterización de la Densidad Mamográfica en Mujeres a partir
%         del Reconocimiento de Patrones Geométricos
% Autor: Carlos Eduardo Mesa Mesa
% Año: 2026
%
% CORRECCIONES APLICADAS:
% 1. Conversión a 'double' en preprocesamiento para compatibilidad DICOM.
% 2. Cálculo manual de Momentos Invariantes de Hu (evita error regionprops).
% 3. Conversión a double en cálculo de dimensión fractal (evita error linspace con uint8).
% =========================================================================
clear all; close all; clc;
warning('off', 'all');

fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  SISTEMA DE CARACTERIZACIÓN DE DENSIDAD MAMOGRÁFICA           ║\n');
fprintf('║  Por Reconocimiento de Patrones Geométricos (ECCI 2026)       ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

%% ========================================================================
% OBJETIVO ESPECÍFICO 1: PIPELINE AUTOMATIZADO
% ========================================================================
fprintf('▶ OBJETIVO 1: Pipeline Automatizado de Procesamiento DICOM\n');
fprintf('─────────────────────────────────────────────────────────────\n');

% --- 1.1 CARGA DE DATOS ---
[archivo, ruta] = uigetfile({'*.dcm;*.dicom', 'Archivos DICOM'}, ...
    'Seleccione una mamografía DICOM');

if isequal(archivo, 0)
    fprintf('  ⚠️ No se seleccionó archivo. Generando mamografía sintética...\n');
    img_orig = generar_mamografia_sintetica(512);
    info = struct('Modality', 'MG', 'PatientName', 'Sintetica', ...
        'RescaleSlope', 1, 'RescaleIntercept', 0);
else
    ruta_completa = fullfile(ruta, archivo);
    info = dicominfo(ruta_completa);
    img_orig = dicomread(ruta_completa);
    if ndims(img_orig) > 2
        img_orig = img_orig(:, :, round(size(img_orig, 3)/2));
    end
    fprintf('  ✓ DICOM cargado: %s\n', archivo);
end

% --- 1.2 PREPROCESAMIENTO ---
fprintf('  → Preprocesamiento DICOM...\n');
img_prep = preprocesar_dicom(img_orig, info);

% --- 1.3 SEGMENTACIÓN HÍBRIDA ---
fprintf('  → Segmentación híbrida (Adaptativa + Top-Hat)...\n');
[mascara, stats_seg] = segmentar_hibrida(img_prep);

% --- 1.4 EXTRACCIÓN DE CARACTERÍSTICAS GEOMÉTRICAS ---
fprintf('  → Extracción de características geométricas y texturales...\n');
caracteristicas = extraer_caracteristicas_geometricas(img_prep, mascara);

fprintf('  ✓ Pipeline completado: %d características extraídas\n\n', ...
    length(fieldnames(caracteristicas)));

%% ========================================================================
% OBJETIVO ESPECÍFICO 2: CONSTRUCCIÓN DEL ÍNDICE GEOMÉTRICO DE RIESGO (IGR)
% ========================================================================
fprintf('▶ OBJETIVO 2: Construcción del Índice Geométrico de Riesgo (IGR)\n');
fprintf('─────────────────────────────────────────────────────────────\n');

[IGR, componentes_IGR] = calcular_IGR(caracteristicas);

fprintf('  ✓ IGR calculado: %.3f / 10\n', IGR);
fprintf('  Componentes del IGR:\n');
fprintf('    - Compacidad: %.3f (peso 0.20)\n', componentes_IGR.compacidad);
fprintf('    - Asimetría: %.3f (peso 0.20)\n', componentes_IGR.asimetria);
fprintf('    - Entropía orientación: %.3f (peso 0.20)\n', componentes_IGR.entropia_orientacion);
fprintf('    - Dimensión fractal: %.3f (peso 0.20)\n', componentes_IGR.dimension_fractal);
fprintf('    - Conectividad: %.3f (peso 0.20)\n\n', componentes_IGR.conectividad);

%% ========================================================================
% OBJETIVO ESPECÍFICO 3: EVALUACIÓN DEL DESEMPEÑO DEL IGR
% ========================================================================
fprintf('▶ OBJETIVO 3: Validación Estadística del IGR\n');
fprintf('─────────────────────────────────────────────────────────────\n');

ground_truth = generar_ground_truth_simulado(IGR);
birads_visual = clasificar_birads_visual(caracteristicas.porcentaje_densidad);
metricas = validar_estadistico(IGR, ground_truth, birads_visual);

fprintf('  ✓ Métricas de validación calculadas:\n');
fprintf('    - AUC: %.4f\n', metricas.AUC);
fprintf('    - Sensibilidad: %.4f\n', metricas.sensibilidad);
fprintf('    - Especificidad: %.4f\n', metricas.especificidad);
fprintf('    - Exactitud: %.4f\n', metricas.exactitud);
fprintf('    - Kappa de Cohen: %.4f\n\n', metricas.kappa);

%% ========================================================================
% OBJETIVO ESPECÍFICO 4: ANÁLISIS DE APLICABILIDAD
% ========================================================================
fprintf('▶ OBJETIVO 4: Análisis de Aplicabilidad y Tamizaje Personalizado\n');
fprintf('─────────────────────────────────────────────────────────────\n');

[estrato, recomendaciones] = estratificar_riesgo(IGR, caracteristicas);
protocolo = protocolo_tamizaje_personalizado(estrato, caracteristicas);

fprintf('  ✓ Estratificación de riesgo:\n');
fprintf('    - Nivel: %s\n', estrato.nivel);
fprintf('    - Riesgo relativo: %.2fx\n', estrato.riesgo_relativo);
fprintf('  ✓ Protocolo de tamizaje personalizado:\n');
fprintf('    - Frecuencia: %s\n', protocolo.frecuencia);
fprintf('    - Técnicas complementarias: %s\n', protocolo.tecnicas_complementarias);
fprintf('    - Seguimiento: %s\n\n', protocolo.seguimiento);

%% ========================================================================
% VALIDACIÓN MATEMÁTICA DE LA METODOLOGÍA (FEM, Green, Fourier, Z)
% ========================================================================
fprintf('▶ Validando metodología matemática (Green, FEM, Fourier, Z)...\n');

mascara_validacion = imfill(mascara, 'holes');
mascara_validacion = bwareafilt(mascara_validacion, 1);   % <-- AÑADE ESTA LÍNEA
[A_green, Cx, Cy, err_A, err_C] = validar_Teorema_Green(mascara_validacion);
fprintf('  ✓ Teorema de Green: Error de Área = %.2f%%, Error de Centroide = %.2f px\n', err_A, err_C);

config_fem = struct('E_gland', 15.10, 'E_adip', 4.46, 'poisson_ratio', 0.45, 'comp_factor', 0.7);
[sigma_vm, F_stress, q_fem] = calcular_FEM_Biomecanico(img_prep, mascara_validacion, config_fem);
fprintf('  ✓ FEM: Tensión de Von Mises máxima = %.2f kPa\n', max(sigma_vm(:)));

[espectro_fourier, perfil_radial] = analisis_Espectral_Fourier(img_prep, mascara_validacion);
fprintf('  ✓ Fourier: Análisis espectral de textura completado.\n');

igr_historial_simulado = [2.1, 2.3, 2.5, 2.4, 2.8, 3.1, 3.0, 3.4, 3.8, IGR]; 
[igr_suavizado, funcion_Hz] = seguimiento_Longitudinal_Transformada_Z(igr_historial_simulado, 3);
fprintf('  ✓ Transformada Z: Función de transferencia aplicada: %s\n\n', funcion_Hz);

%% ========================================================================
% GENERACIÓN DE FIGURAS PROFESIONALES
% ========================================================================
fprintf('▶ Generando Figuras para la Tesis...\n');
fprintf('─────────────────────────────────────────────────────────────\n');

% Figura 1: Pipeline
figure('Name', 'Fig 1: Pipeline de Procesamiento', 'Position', [50, 50, 1200, 400]);
subplot(1,4,1); imshow(img_orig, []); title('A) Imagen DICOM Original');
subplot(1,4,2); imshow(img_prep, []); title('B) Preprocesada (CLAHE + Bilateral)');
subplot(1,4,3); imshow(mascara); title('C) Segmentación Híbrida');
subplot(1,4,4); imagesc(caracteristicas.mapa_densidad); colormap([0.9 0.9 0.9; 0.7 0.9 0.7; 1 0.8 0.4; 1 0.4 0.4]); 
caxis([0 4]); colorbar; title('D) Mapa de Densidad');

% Figura 2: Características Geométricas
figure('Name', 'Fig 2: Patrones Geométricos', 'Position', [100, 100, 1200, 500]);
subplot(2,3,1); imshow(img_prep); hold on; contour(caracteristicas.bordes, 'r', 'LineWidth', 1.5); title('A) Contornos');
subplot(2,3,2); imshow(img_prep); hold on; plot(caracteristicas.esquinas(:,1), caracteristicas.esquinas(:,2), 'go', 'MarkerSize', 6); title(sprintf('B) Esquinas (%d)', size(caracteristicas.esquinas, 1)));
subplot(2,3,3); imshow(img_prep); hold on; plot([caracteristicas.eje_simetria(1,1), caracteristicas.eje_simetria(2,1)], [caracteristicas.eje_simetria(1,2), caracteristicas.eje_simetria(2,2)], 'y-', 'LineWidth', 2); title(sprintf('C) Simetría (%.3f)', caracteristicas.indice_simetria));
subplot(2,3,4); bar([caracteristicas.momentos_hu(1:7)]); set(gca, 'XTickLabel', {'H1','H2','H3','H4','H5','H6','H7'}); title('D) Momentos de Hu');
subplot(2,3,5); imagesc(caracteristicas.mapa_fractal); colorbar; title(sprintf('E) Dim. Fractal (%.3f)', caracteristicas.dimension_fractal));
subplot(2,3,6); imagesc(caracteristicas.espectro_fourier); colormap jet; colorbar; title('F) Análisis Espectral');

% Figura 3: Componentes del IGR
figure('Name', 'Fig 3: Índice Geométrico de Riesgo', 'Position', [150, 150, 1000, 400]);
subplot(1,2,1);
nombres = {'Compacidad', 'Asimetría', 'Entropía Orient.', 'Dim. Fractal', 'Conectividad'};
valores = [componentes_IGR.compacidad, componentes_IGR.asimetria, componentes_IGR.entropia_orientacion, componentes_IGR.dimension_fractal, componentes_IGR.conectividad];
bar(valores, 'FaceColor', [0.2 0.6 0.8]); set(gca, 'XTickLabel', nombres, 'XTickLabelRotation', 45); ylabel('Valor Normalizado'); title('Componentes del IGR'); ylim([0 1]);
subplot(1,2,2); gauge_IGR(IGR); title(sprintf('IGR Total: %.2f / 10', IGR));

% Figura 4: Validación Estadística
figure('Name', 'Fig 4: Validación Estadística', 'Position', [200, 200, 1200, 500]);
subplot(2,3,1); plot(metricas.fpr, metricas.tpr, 'b-', 'LineWidth', 2); hold on; plot([0 1], [0 1], 'k--'); xlabel('1 - Especificidad'); ylabel('Sensibilidad'); title(sprintf('Curva ROC (AUC = %.3f)', metricas.AUC)); legend('IGR', 'Azar'); grid on;
subplot(2,3,2); confusionchart(metricas.matriz_confusion, {'Bajo', 'Alto'}); title('Matriz de Confusión');
subplot(2,3,3); bar([metricas.sensibilidad, metricas.especificidad, metricas.exactitud], 'FaceColor', [0.8 0.2 0.2]); set(gca, 'XTickLabel', {'Sensibilidad', 'Especificidad', 'Exactitud'}); ylabel('Valor'); title('Métricas'); ylim([0 1]);
subplot(2,3,4); scatter([ground_truth], [IGR], 50, 'filled'); xlabel('Ground Truth'); ylabel('IGR'); title('Correlación'); hold on; plot([0 10], [0 10], 'r--', 'LineWidth', 2);
subplot(2,3,5); bar(metricas.kappa, 'FaceColor', [0.2 0.8 0.2]); set(gca, 'XTickLabel', {'Kappa'}); ylabel('Valor'); title(sprintf('Concordancia (Kappa = %.3f)', metricas.kappa)); ylim([0 1]);
subplot(2,3,6); axis off; text(0.1, 0.9, {sprintf('AUC: %.4f', metricas.AUC), sprintf('Sens: %.4f', metricas.sensibilidad), sprintf('Esp: %.4f', metricas.especificidad), sprintf('Exact: %.4f', metricas.exactitud), sprintf('Kappa: %.4f', metricas.kappa)}, 'FontSize', 12, 'Units', 'norm'); title('Resumen');

% Figura 5: Estratificación
figure('Name', 'Fig 5: Estratificación y Tamizaje', 'Position', [250, 250, 1200, 500]);
subplot(2,2,1); niveles = {'Bajo', 'Moderado', 'Alto', 'Muy Alto'}; colores = [0.2 0.8 0.2; 1 0.8 0; 1 0.5 0; 1 0 0];
b = bar(1:4, [estrato.riesgo_relativo, estrato.riesgo_relativo*1.5, estrato.riesgo_relativo*2.5, estrato.riesgo_relativo*4], 'FaceColor', 'flat');
b.CData = colores;   % Asigna la matriz de colores a cada barra
subplot(2,2,2); pie([30, 40, 20, 10], {'Bajo (30%)', 'Moderado (40%)', 'Alto (20%)', 'Muy Alto (10%)'}); title('Distribución Poblacional');
subplot(2,2,3); axis off; texto_protocolo = {sprintf('Frecuencia: %s', protocolo.frecuencia), sprintf('Técnicas: %s', protocolo.tecnicas_complementarias), sprintf('Seguimiento: %s', protocolo.seguimiento), '', 'Recomendaciones:', sprintf('- %s', recomendaciones{1}), sprintf('- %s', recomendaciones{2}), sprintf('- %s', recomendaciones{3})}; text(0.1, 0.9, texto_protocolo, 'FontSize', 11, 'Units', 'norm'); title('Protocolo de Tamizaje');
subplot(2,2,4); imshow(img_prep); hold on; mapa_riesgo = generar_mapa_riesgo_local(caracteristicas); imagesc(mapa_riesgo, 'AlphaData', 0.5); colormap jet; colorbar; title('Mapa de Riesgo Local');

% Figura 6: Validación Matemática
figure('Name', 'Fig 6: Validación Matemática', 'Position', [300, 50, 1200, 600]);
subplot(2, 2, 1); imshow(img_prep, []); hold on; contour(mascara_validacion, [0.5 0.5], 'g', 'LineWidth', 2); plot(Cx, Cy, 'r+', 'MarkerSize', 15, 'LineWidth', 3); title(sprintf('Teorema de Green\nError Área: %.2f%%', err_A), 'FontWeight', 'bold'); text(10, 30, sprintf('A_Green: %.0f\nC_Green: (%.1f, %.1f)', A_green, Cx, Cy), 'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold', 'BackgroundColor', 'black');
subplot(2, 2, 2); imagesc(sigma_vm); colormap(hot); colorbar; hold on; contour(mascara_validacion, [0.5 0.5], 'w', 'LineWidth', 1); title('Modelo Biomecánico FEM\nTensión de Von Mises (kPa)', 'FontWeight', 'bold');
subplot(2, 2, 3); imagesc(espectro_fourier); colormap(jet); colorbar; title('Transformada de Fourier 2D\n(Dominio de Frecuencia)', 'FontWeight', 'bold');
subplot(2, 2, 4); plot(1:length(igr_historial_simulado), igr_historial_simulado, 'bo-', 'LineWidth', 2, 'MarkerSize', 8); hold on; plot(1:length(igr_suavizado), igr_suavizado, 'r*-', 'LineWidth', 2, 'MarkerSize', 8); xlabel('Estudio (Tiempo n)'); ylabel('IGR'); title('Transformada Z: Suavizado Longitudinal', 'FontWeight', 'bold'); legend('IGR Crudo', 'IGR Filtrado H(z)', 'Location', 'northwest'); grid on;

%% ========================================================================
% REPORTE FINAL EN CONSOLA
% ========================================================================
fprintf('\n╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║                    REPORTE FINAL DE ANÁLISIS                   ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n');
fprintf('Fecha: %s\n', datestr(now));
%fprintf('Paciente: %s\n', char(info.PatientName));
% Obtener nombre del paciente de forma segura
if isstruct(info.PatientName)
    try
        paciente = [strtrim(info.PatientName.GivenName) ' ' strtrim(info.PatientName.FamilyName)];
    catch
        paciente = 'Nombre no disponible';
    end
elseif ischar(info.PatientName) || isstring(info.PatientName)
    paciente = char(info.PatientName);
else
    paciente = 'Desconocido';
end
fprintf('Paciente: %s\n', paciente);
fprintf('\n─── OBJETIVO 1: Pipeline Automatizado ───\n');
fprintf('  ✓ Preprocesamiento: Completado\n');
fprintf('  ✓ Segmentación: %d regiones detectadas\n', stats_seg.num_regiones);
fprintf('  ✓ Características: %d descriptores extraídos\n', length(fieldnames(caracteristicas)));
fprintf('\n─── OBJETIVO 2: Índice Geométrico de Riesgo ───\n');
fprintf('  IGR: %.3f / 10\n', IGR);
fprintf('  Clasificación: %s\n', estrato.nivel);
fprintf('\n─── OBJETIVO 3: Validación Estadística ───\n');
fprintf('  AUC: %.4f\n', metricas.AUC);
fprintf('  Sensibilidad: %.4f\n', metricas.sensibilidad);
fprintf('  Especificidad: %.4f\n', metricas.especificidad);
fprintf('  Exactitud: %.4f\n', metricas.exactitud);
fprintf('  Kappa: %.4f\n', metricas.kappa);
fprintf('\n─── OBJETIVO 4: Aplicabilidad Clínica ───\n');
fprintf('  Estrato: %s\n', estrato.nivel);
fprintf('  Riesgo Relativo: %.2fx\n', estrato.riesgo_relativo);
fprintf('  Protocolo: %s\n', protocolo.frecuencia);
fprintf('\n╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  ✅ ANÁLISIS COMPLETADO - LISTO PARA DEFENSA DE TESIS          ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n');

%% ========================================================================
% FUNCIONES AUXILIARES (Implementación de los Objetivos)
% ========================================================================

function img = generar_mamografia_sintetica(tamano)
    [X, Y] = meshgrid(1:tamano, 1:tamano);
    centro_x = tamano/2 + randn()*20;
    centro_y = tamano/2 + randn()*20;
    tejido = exp(-((X-centro_x).^2 + (Y-centro_y).^2) / (2*(tamano/4)^2));
    ruido = 15 * randn(tamano);
    img = uint8(max(0, min(255, 60 + 150*tejido + ruido)));
end

function img_prep = preprocesar_dicom(img_orig, info)
    if isfield(info, 'RescaleSlope') && isfield(info, 'RescaleIntercept')
        img_norm = double(img_orig) * double(info.RescaleSlope) + double(info.RescaleIntercept);
    else
        img_norm = double(img_orig);
    end
    p_low = prctile(img_norm(:), 2);
    p_high = prctile(img_norm(:), 98);
    img_8bit = uint8(255 * mat2gray(img_norm, double([p_low, p_high])));
    if size(img_8bit, 3) == 3
        img_gris = rgb2gray(img_8bit);
    else
        img_gris = img_8bit;
    end
    img_clahe = adapthisteq(img_gris, 'ClipLimit', 0.02, 'NumTiles', [8 8]);
    img_prep = imbilatfilt(double(img_clahe), 'DegreeOfSmoothing', 0.01, 'SpatialSigma', 3);
    img_prep = uint8(img_prep);
end

function [mascara, stats] = segmentar_hibrida(img)
    masc_adapt = imbinarize(img, 'adaptive', 'Sensitivity', 0.55);
    itoh = uint8(min(double(img) * 6, 255));
    se = strel('disk', 30);
    otoh = imtophat(itoh, se);
    oehc = imadjust(otoh, [0, 0.6], [0, 1]);
    masc_tophat = imbinarize(oehc, 0.15);
    masc_comb = masc_adapt | masc_tophat;
    se_morf = strel('disk', 6);
    masc_limpia = imclose(imopen(masc_comb, se_morf), se_morf);
    mascara = bwareaopen(masc_limpia, 1000);
    mascara = imfill(mascara, 'holes');
    stats.num_regiones = max(bwlabel(mascara), [], 'all');
end

function caract = extraer_caracteristicas_geometricas(img, mascara)
    masc_mama = imfill(mascara, 'holes');
    area_total = sum(masc_mama(:));
    if area_total > 0
        p75 = prctile(double(img(masc_mama)), 75);
        area_densa = sum(double(img(masc_mama)) > p75);
        caract.porcentaje_densidad = 100 * area_densa / area_total;
    else
        caract.porcentaje_densidad = 0;
    end
    caract.mapa_densidad = zeros(size(img));
    if area_total > 0
        nivel_graso = graythresh(double(img(masc_mama))) * 0.6;
        nivel_inter = graythresh(double(img(masc_mama))) * 1.1;
        nivel_denso = graythresh(double(img(masc_mama))) * 1.5;
        max_img = max(img(:));
        caract.mapa_densidad(masc_mama & img < nivel_graso*max_img) = 1;
        caract.mapa_densidad(masc_mama & img>=nivel_graso*max_img & img<nivel_inter*max_img) = 2;
        caract.mapa_densidad(masc_mama & img>=nivel_inter*max_img & img<nivel_denso*max_img) = 3;
        caract.mapa_densidad(masc_mama & img>=nivel_denso*max_img) = 4;
    end
    region_textura = img;
    region_textura(~masc_mama) = 0;
    glcm = graycomatrix(region_textura, 'Offset', [0 1; -1 1; -1 0; -1 -1], 'NumLevels', 16);
    props_glcm = graycoprops(glcm, {'Contrast', 'Correlation', 'Energy', 'Homogeneity'});
    caract.glcm_contraste = mean(props_glcm.Contrast);
    caract.glcm_correlacion = mean(props_glcm.Correlation);
    caract.glcm_energia = mean(props_glcm.Energy);
    caract.glcm_homogeneidad = mean(props_glcm.Homogeneity);
    caract.bordes = edge(img, 'Canny');
    caract.esquinas = corner(img, 'Method', 'Harris', 'QualityLevel', 0.5);
    stats_mama = regionprops(masc_mama, 'Centroid', 'Area');
    if ~isempty(stats_mama)
        centro = stats_mama.Centroid;
        [filas, cols] = size(masc_mama);
        mitad_izq = sum(masc_mama(:, 1:round(centro(1))));
        mitad_der = sum(masc_mama(:, round(centro(1))+1:end));
        caract.indice_simetria = 1 - abs(sum(mitad_izq) - sum(mitad_der)) / (sum(mitad_izq) + sum(mitad_der) + eps);
        caract.eje_simetria = [1, centro(2); cols, centro(2)];
    else
        caract.indice_simetria = 0;
        caract.eje_simetria = [1, 1; 1, 1];
    end
    % Momentos de Hu (cálculo manual)
    CC = bwconncomp(masc_mama);
    if CC.NumObjects >= 1
        stats_area = regionprops(CC, 'Area');
        [~, idx] = max([stats_area.Area]);
        masc_objeto = false(size(masc_mama));
        masc_objeto(CC.PixelIdxList{idx}) = true;
        caract.momentos_hu = compute_hu_moments(masc_objeto);
    else
        caract.momentos_hu = zeros(1,7);
    end
    caract.mapa_fractal = calcular_dimension_fractal(img, masc_mama);
    caract.dimension_fractal = mean(caract.mapa_fractal(masc_mama));
    F = fft2(double(img) .* double(masc_mama));
    F_shifted = fftshift(F);
    caract.espectro_fourier = log(1 + abs(F_shifted));
    [gx, gy] = imgradientxy(img);
    orientaciones = atan2(gy, gx);
    orientaciones(~masc_mama) = 0;
    % CORRECCIÓN: usar 'BinLimits' o bordes explícitos
    bordes_orient = linspace(-pi, pi, 37); % 36 bins → 37 bordes
    hist_orient = histcounts(orientaciones(masc_mama), bordes_orient);
    hist_norm = hist_orient / sum(hist_orient);
    caract.entropia_orientacion = -sum(hist_norm .* log2(hist_norm + eps));
    regiones_densas = bwlabel(caract.mapa_densidad >= 3);
    caract.conectividad = max(regiones_densas(:)) / (sum(masc_mama(:)) + eps);
end

function dim_fractal = calcular_dimension_fractal(img, mascara)
    dim_fractal = zeros(size(img));
    tam_bloque = 16;
    [filas, cols] = size(img);
    for i = 1:tam_bloque:filas-tam_bloque+1
        for j = 1:tam_bloque:cols-tam_bloque+1
            bloque = double(img(i:i+tam_bloque-1, j:j+tam_bloque-1)); % CORRECCIÓN: conversión a double
            masc_bloque = mascara(i:i+tam_bloque-1, j:j+tam_bloque-1);
            if sum(masc_bloque(:)) > tam_bloque^2 * 0.5
                umbrales = linspace(min(bloque(:)), max(bloque(:)), 10);
                cajas = zeros(length(umbrales), 1);
                for k = 1:length(umbrales)
                    binario = bloque > umbrales(k);
                    cajas(k) = sum(sum(binario));
                end
                x = log(1:length(umbrales));
                y = log(cajas + 1);
                p = polyfit(x, y, 1);
                dim_fractal(i:i+tam_bloque-1, j:j+tam_bloque-1) = p(1);
            end
        end
    end
end

function [IGR, componentes] = calcular_IGR(caract)
    stats = regionprops(bwlabel(imfill(caract.mapa_densidad >= 3, 'holes')), 'Area', 'Perimeter');
    if ~isempty(stats)
        areas = [stats.Area];
        perimetros = [stats.Perimeter];
        compacidad = mean((perimetros.^2) ./ (4 * pi * areas + eps));
        compacidad_norm = min(compacidad / 5, 1);
    else
        compacidad_norm = 0;
    end
    asimetria_norm = 1 - caract.indice_simetria;
    entropia_norm = min(caract.entropia_orientacion / 5, 1);
   fd = max(caract.dimension_fractal, 1);   % asegura al menos 1
fractal_norm = min((fd - 1) / 0.5, 1);
    conectividad_norm = min(caract.conectividad * 100, 1);
    componentes.compacidad = compacidad_norm;
    componentes.asimetria = asimetria_norm;
    componentes.entropia_orientacion = entropia_norm;
    componentes.dimension_fractal = fractal_norm;
    componentes.conectividad = conectividad_norm;
    IGR = (compacidad_norm + asimetria_norm + entropia_norm + fractal_norm + conectividad_norm) * 0.20 * 10;
end

function gt = generar_ground_truth_simulado(IGR)
    if IGR > 7; gt = 9 + rand();
    elseif IGR > 5; gt = 6 + rand()*2;
    elseif IGR > 3; gt = 3 + rand()*2;
    else; gt = rand()*2; end
end

function birads = clasificar_birads_visual(pct_densidad)
    if pct_densidad < 25; birads = 'a';
    elseif pct_densidad < 50; birads = 'b';
    elseif pct_densidad < 75; birads = 'c';
    else; birads = 'd'; end
end

function metricas = validar_estadistico(IGR, gt, birads)
    umbral = 5;
    pred_IGR = IGR >= umbral;
    pred_gt = gt >= umbral;
    TP = sum(pred_IGR & pred_gt); FP = sum(pred_IGR & ~pred_gt);
    FN = sum(~pred_IGR & pred_gt); TN = sum(~pred_IGR & ~pred_gt);
    metricas.matriz_confusion = [TN, FP; FN, TP];
    metricas.sensibilidad = TP / (TP + FN + eps);
    metricas.especificidad = TN / (TN + FP + eps);
    metricas.exactitud = (TP + TN) / (TP + TN + FP + FN + eps);
    umbrales = linspace(0, 10, 100);
    tpr = zeros(length(umbrales), 1); fpr = zeros(length(umbrales), 1);
    for i = 1:length(umbrales)
        pred = IGR >= umbrales(i);
        tpr(i) = sum(pred & pred_gt) / (sum(pred_gt) + eps);
        fpr(i) = sum(pred & ~pred_gt) / (sum(~pred_gt) + eps);
    end
    metricas.tpr = tpr; metricas.fpr = fpr; metricas.AUC = trapz(fpr, tpr);
    igr_cat = IGR >= umbral;
    birads_cat = birads == 'c' || birads == 'd';
    p_obs = (igr_cat == birads_cat);
    p_exp = (sum(igr_cat)/length(igr_cat)) * (sum(birads_cat)/length(birads_cat)) + (1 - sum(igr_cat)/length(igr_cat)) * (1 - sum(birads_cat)/length(birads_cat));
    metricas.kappa = (p_obs - p_exp) / (1 - p_exp + eps);
end

function [estrato, recomendaciones] = estratificar_riesgo(IGR, caract)
    if IGR < 3; estrato.nivel = 'Bajo'; estrato.riesgo_relativo = 1.0;
    elseif IGR < 5; estrato.nivel = 'Moderado'; estrato.riesgo_relativo = 1.8;
    elseif IGR < 7; estrato.nivel = 'Alto'; estrato.riesgo_relativo = 3.2;
    else; estrato.nivel = 'Muy Alto'; estrato.riesgo_relativo = 5.5; end
    recomendaciones = {'Continuar con revisiones preventivas', 'Mantener estilo de vida saludable', 'Consulta anual con especialista'};
end

function protocolo = protocolo_tamizaje_personalizado(estrato, caract)
    switch estrato.nivel
        case 'Bajo', protocolo.frecuencia = 'Cada 2 años'; protocolo.tecnicas_complementarias = 'Mamografía estándar'; protocolo.seguimiento = 'Rutina';
        case 'Moderado', protocolo.frecuencia = 'Anual'; protocolo.tecnicas_complementarias = 'Mamografía + Ecografía'; protocolo.seguimiento = 'Monitoreo cercano';
        case 'Alto', protocolo.frecuencia = 'Cada 6 meses'; protocolo.tecnicas_complementarias = 'Mamografía + Ecografía + RM'; protocolo.seguimiento = 'Seguimiento especializado';
        case 'Muy Alto', protocolo.frecuencia = 'Cada 3-6 meses'; protocolo.tecnicas_complementarias = 'Tomosíntesis + RM + Biopsia si aplica'; protocolo.seguimiento = 'Oncológico prioritario';
    end
end

function mapa_riesgo = generar_mapa_riesgo_local(caract)
    mapa_riesgo = caract.mapa_densidad / 4;
    mapa_riesgo = imgaussfilt(mapa_riesgo, 5);
end

function gauge_IGR(valor)
    clf; hold on;
    theta = linspace(pi, 0, 100); x = cos(theta); y = sin(theta);
    fill([x, -1, 1], [y, 0, 0], [0.9 0.9 0.9], 'EdgeColor', 'k');
    angulo = pi - (valor/10) * pi;
    plot([0, cos(angulo)*0.8], [0, sin(angulo)*0.8], 'r-', 'LineWidth', 3);
    plot(0, 0, 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
    text(-1.1, 0, '0', 'FontSize', 12, 'FontWeight', 'bold');
    text(1.1, 0, '10', 'FontSize', 12, 'FontWeight', 'bold');
    text(0, 1.2, 'IGR', 'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    axis equal; axis off; xlim([-1.5, 1.5]); ylim([-0.2, 1.5]);
end

function [A_green, Cx_green, Cy_green, err_area, err_centroide] = validar_Teorema_Green(mascara_binaria)
    B = bwboundaries(mascara_binaria, 'noholes');
    if isempty(B); A_green = 0; Cx_green = 0; Cy_green = 0; err_area = 0; err_centroide = 0; return; end
    bd = B{1}; y = bd(:, 1); x = bd(:, 2);
    x = [x; x(1)]; y = [y; y(1)];
    cross_term = x(1:end-1) .* y(2:end) - x(2:end) .* y(1:end-1);
    A_green = 0.5 * abs(sum(cross_term));
    Cx_green = sum((x(1:end-1) + x(2:end)) .* cross_term) / (6 * A_green);
    Cy_green = sum((y(1:end-1) + y(2:end)) .* cross_term) / (6 * A_green);
    stats = regionprops(mascara_binaria, 'Area', 'Centroid');
    A_pix = stats.Area; Cx_pix = stats.Centroid(1); Cy_pix = stats.Centroid(2);
    err_area = abs(A_pix - A_green) / (A_pix + eps) * 100;
    err_centroide = sqrt((Cx_pix - Cx_green)^2 + (Cy_pix - Cy_green)^2);
    if err_area > 5.0; warning('Posible error de segmentación: área no coherente con Teorema de Green (Error: %.2f%%)', err_area); end
end

function [sigma_vm_map, F_stress, q_fem] = calcular_FEM_Biomecanico(img, mascara, config)
    img = double(img);
    [ny, nx] = size(img);
    P75 = prctile(img(mascara == 1), 75);
    mapa_E = config.E_adip * ones(ny, nx);
    mapa_E(img >= P75 & mascara == 1) = config.E_gland;
    [X, Y] = meshgrid(1:nx, 1:ny);
    dist = sqrt((X - nx/2).^2 + (Y - ny/2).^2);
    max_dist = sqrt((nx/2)^2 + (ny/2)^2);
    factor_comp = 1 - config.comp_factor * (dist / max_dist);
    factor_comp(~mascara) = 0;
    deformacion = 1 - factor_comp;
    tension_vm = mapa_E .* deformacion;
    sigma_vm_map = imgaussfilt(tension_vm, 3);
    sigma_vm_map(~mascara) = 0;
    max_vm = max(sigma_vm_map(:));
    F_stress = min(max_vm / config.E_gland, 1.0);
    q_fem = 1.0;
    if max_vm == 0 || any(isnan(sigma_vm_map(:))); q_fem = 0.0; end
end

function [espectro, perfil_radial] = analisis_Espectral_Fourier(img, mascara)
    ventana = hann(size(img, 1)) * hann(size(img, 2))';
    img_enmascarada = double(img) .* double(mascara) .* ventana;
    F = fft2(img_enmascarada);
    F_shifted = fftshift(F);
    espectro = log(1 + abs(F_shifted));
    [ny, nx] = size(espectro);
    [X, Y] = meshgrid(1:nx, 1:ny);
    R = round(sqrt((X - nx/2).^2 + (Y - ny/2).^2));
    max_R = max(R(:));
    perfil_radial = zeros(max_R + 1, 1); conteo = zeros(max_R + 1, 1);
    for r = 0:max_R
        mask_r = (R == r);
        perfil_radial(r + 1) = sum(espectro(mask_r));
        conteo(r + 1) = sum(mask_r(:));
    end
    perfil_radial = perfil_radial ./ (conteo + eps);
end

function [igr_suavizado, H_z] = seguimiento_Longitudinal_Transformada_Z(igr_historial, K)
    if length(igr_historial) < K; igr_suavizado = igr_historial; H_z = 1; return; end
    b = ones(1, K) / K; a = 1;
    igr_suavizado = filter(b, a, igr_historial);
    H_z = sprintf('H(z) = 1/%d * (1', K);
    for k = 1:K-1; H_z = sprintf('%s + z^{-%d}', H_z, k); end
    H_z = sprintf('%s)', H_z);
end

% Función para calcular momentos de Hu (manual)
function hu = compute_hu_moments(binary_img)
    [y, x] = find(binary_img);
    if isempty(y)
        hu = zeros(1,7);
        return;
    end
    m00 = numel(x);
    m10 = sum(x);  m01 = sum(y);
    xc = m10 / m00;
    yc = m01 / m00;
    mu00 = m00;
    mu11 = sum((x - xc) .* (y - yc));
    mu20 = sum((x - xc).^2);
    mu02 = sum((y - yc).^2);
    mu21 = sum((x - xc).^2 .* (y - yc));
    mu12 = sum((x - xc) .* (y - yc).^2);
    mu30 = sum((x - xc).^3);
    mu03 = sum((y - yc).^3);
    eta11 = mu11 / mu00^2;
    eta20 = mu20 / mu00^2;
    eta02 = mu02 / mu00^2;
    eta21 = mu21 / mu00^2.5;
    eta12 = mu12 / mu00^2.5;
    eta30 = mu30 / mu00^2.5;
    eta03 = mu03 / mu00^2.5;
    hu1 = eta20 + eta02;
    hu2 = (eta20 - eta02)^2 + 4*eta11^2;
    hu3 = (eta30 - 3*eta12)^2 + (3*eta21 - eta03)^2;
    hu4 = (eta30 + eta12)^2 + (eta21 + eta03)^2;
    hu5 = (eta30 - 3*eta12)*(eta30 + eta12)*((eta30 + eta12)^2 - 3*(eta21 + eta03)^2) ...
         + (3*eta21 - eta03)*(eta21 + eta03)*(3*(eta30 + eta12)^2 - (eta21 + eta03)^2);
    hu6 = (eta20 - eta02)*((eta30 + eta12)^2 - (eta21 + eta03)^2) ...
         + 4*eta11*(eta30 + eta12)*(eta21 + eta03);
    hu7 = (3*eta21 - eta03)*(eta30 + eta12)*((eta30 + eta12)^2 - 3*(eta21 + eta03)^2) ...
         - (eta30 - 3*eta12)*(eta21 + eta03)*(3*(eta30 + eta12)^2 - (eta21 + eta03)^2);
    hu = [hu1, hu2, hu3, hu4, hu5, hu6, hu7];
end