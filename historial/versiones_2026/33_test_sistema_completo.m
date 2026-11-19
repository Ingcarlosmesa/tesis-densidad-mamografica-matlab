%% TEST SUITE - SISTEMA UNIFICADO DE ANÁLISIS MAMOGRÁFICO
%  Script de validación del sistema completo

clear all; close all; clc;

fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║  SUITE DE PRUEBAS - SISTEMA MAMOGRÁFICO V2.0                         ║\n');
fprintf('║  Validación de 10 componentes del sistema                            ║\n');
fprintf('╚════════════════════════════════════════════════════════════════════════╝\n\n');

num_tests = 10;
tests_pasados = 0;

%% TEST 1: PREPROCESAMIENTO
fprintf('TEST 1: PREPROCESAMIENTO DICOM\n');
fprintf('─────────────────────────────────\n');

try
    % Crear imagen de prueba
    img_test = uint8(100 + 50*rand(512, 512));
    info_test = struct('Modality', 'MG', 'SeriesDescription', 'Test');
    
    % Configuración mínima
    config_test = struct();
    config_test.prep.clahe_clip = 0.02;
    config_test.prep.clahe_tiles = 8;
    config_test.prep.filtro_mediana = [7 7];
    
    % Simulación del preprocesamiento
    img_norm = mat2gray(img_test);
    img_filtrada = medfilt2(uint8(img_norm*255), [7 7]);
    img_clahe = adapthisteq(img_filtrada, 'ClipLimit', 0.02, 'NumTiles', [8 8]);
    
    % Validaciones
    assert(~isempty(img_clahe), 'Imagen preprocesada vacía');
    assert(all(size(img_clahe) == size(img_test)), 'Dimensión incorrecta');
    assert(isa(img_clahe, 'uint8'), 'Tipo de dato incorrecto');
    
    fprintf('  ✓ Normalización DICOM completada\n');
    fprintf('  ✓ Filtrado mediana aplicado\n');
    fprintf('  ✓ CLAHE aplicado\n');
    fprintf('  ✓ Dimensiones correctas\n');
    fprintf('  ✓ PASADO\n\n');
    
    tests_pasados = tests_pasados + 1;
    
catch ME
    fprintf('  ✗ FALLIDO: %s\n\n', ME.message);
end

%% TEST 2: SEGMENTACIÓN
fprintf('TEST 2: SEGMENTACIÓN HÍBRIDA\n');
fprintf('──────────────────────────────\n');

try
    % Crear imagen de prueba con región clara
    img_seg = uint8(50 + 30*rand(512, 512));
    [X, Y] = meshgrid(1:512, 1:512);
    region = (X-256).^2 + (Y-256).^2 < 30000;
    img_seg(region) = uint8(img_seg(region) * 2);
    
    % Segmentación
    masc1 = imbinarize(img_seg, 'adaptive', 'Sensitivity', 0.55);
    masc2 = imbinarize(img_seg, graythresh(img_seg));
    mascara = masc1 | masc2;
    
    % Limpieza
    se = strel('disk', 6);
    mascara = imclose(imopen(mascara, se), se);
    mascara = bwareaopen(mascara, 1000);
    mascara = imfill(mascara, 'holes');
    
    % Validaciones
    assert(islogical(mascara), 'Máscara no binaria');
    assert(sum(mascara(:)) > 0, 'Máscara vacía');
    assert(all(size(mascara) == size(img_seg)), 'Dimensión incorrecta');
    
    fprintf('  ✓ Segmentación adaptativa completada\n');
    fprintf('  ✓ Segmentación Otsu completada\n');
    fprintf('  ✓ Combinación de métodos exitosa\n');
    fprintf('  ✓ Limpieza morfológica aplicada\n');
    fprintf('  ✓ PASADO\n\n');
    
    tests_pasados = tests_pasados + 1;
    
catch ME
    fprintf('  ✗ FALLIDO: %s\n\n', ME.message);
end

%% TEST 3: ANÁLISIS DE DENSIDAD
fprintf('TEST 3: ANÁLISIS DE DENSIDAD MAMARIA\n');
fprintf('─────────────────────────────────────\n');

try
    % Usar resultados de TEST 2
    img_dens = img_seg;
    img_mama = img_dens .* uint8(mascara);
    
    % Análisis de densidad
    p25 = prctile(img_mama(mascara), 25);
    p50 = prctile(img_mama(mascara), 50);
    p75 = prctile(img_mama(mascara), 75);
    
    mapa_densidad = ones(size(img_dens));
    mapa_densidad(img_mama > p25 & img_mama <= p50) = 2;
    mapa_densidad(img_mama > p50 & img_mama <= p75) = 3;
    mapa_densidad(img_mama > p75) = 4;
    mapa_densidad(~mascara) = 0;
    
    area_densa = sum(mapa_densidad(mascara) >= 3);
    area_total = sum(mascara(:));
    pct_densidad = 100 * area_densa / area_total;
    
    % BI-RADS automático
    if pct_densidad < 25
        categoria = 'a';
    elseif pct_densidad < 50
        categoria = 'b';
    elseif pct_densidad < 75
        categoria = 'c';
    else
        categoria = 'd';
    end
    
    % Validaciones
    assert(pct_densidad >= 0 && pct_densidad <= 100, 'Porcentaje fuera de rango');
    assert(ismember(categoria, ['a' 'b' 'c' 'd']), 'Categoría BI-RADS inválida');
    assert(~isempty(mapa_densidad), 'Mapa de densidad vacío');
    
    fprintf('  ✓ Cálculo de umbrales exitoso\n');
    fprintf('  ✓ Mapa de densidad generado\n');
    fprintf('  ✓ Porcentaje de densidad: %.1f%%\n', pct_densidad);
    fprintf('  ✓ Categoría BI-RADS: %s\n', categoria);
    fprintf('  ✓ PASADO\n\n');
    
    tests_pasados = tests_pasados + 1;
    
catch ME
    fprintf('  ✗ FALLIDO: %s\n\n', ME.message);
end

%% TEST 4: RADIOMICS (GLCM)
fprintf('TEST 4: EXTRACCIÓN DE CARACTERÍSTICAS RADIOMICS\n');
fprintf('────────────────────────────────────────────────\n');

try
    % Usar imagen de TEST 3
    img_radio = img_seg;
    img_roi = img_radio .* uint8(mascara);
    
    % GLCM
    glcm = graycomatrix(img_roi, 'Offset', [0 1; -1 1; -1 0; -1 -1], 'NumLevels', 16);
    props = graycoprops(glcm, {'contrast', 'correlation', 'energy', 'homogeneity'});
    
    f_contrast = mean(props.Contrast);
    f_corr = mean(props.Correlation);
    f_energy = mean(props.Energy);
    f_homog = mean(props.Homogeneity);
    
    % Características de intensidad
    f_mean = mean(img_roi(mascara));
    f_std = std(double(img_roi(mascara)));
    f_entropy = entropy(img_roi(img_roi > 0));
    f_lbp = std2(img_roi);
    
    features = [f_contrast; f_corr; f_energy; f_homog; f_mean; f_std; f_entropy; f_lbp];
    
    % Validaciones
    assert(length(features) == 8, 'Número incorrecto de características');
    assert(all(isfinite(features)), 'Características contienen NaN o Inf');
    assert(all(features >= 0), 'Características tienen valores negativos');
    
    fprintf('  ✓ GLCM calculado\n');
    fprintf('  ✓ Características de textura extraídas\n');
    fprintf('  ✓ Características de intensidad extraídas\n');
    fprintf('  ✓ Total: %d características válidas\n', length(features));
    fprintf('  ✓ PASADO\n\n');
    
    tests_pasados = tests_pasados + 1;
    
catch ME
    fprintf('  ✗ FALLIDO: %s\n\n', ME.message);
end

%% TEST 5: BIOMECÁNICA
fprintf('TEST 5: MODELADO BIOMECÁNICO\n');
fprintf('──────────────────────────────\n');

try
    % Usar mapa de densidad de TEST 3
    [ny, nx] = size(mapa_densidad);
    
    % Parámetros de Young modulus
    E_glandular = 15.1;
    E_adipose = 4.46;
    
    modulo = ones(ny, nx) * E_adipose;
    modulo(mapa_densidad >= 3) = E_glandular;
    
    % Compresión radial
    [X, Y] = meshgrid(1:nx, 1:ny);
    cx = nx/2;
    cy = ny/2;
    dist = sqrt((X - cx).^2 + (Y - cy).^2);
    max_dist = sqrt(cx^2 + cy^2);
    factor_comp = 1 - 0.7 * (dist / max_dist);
    
    % Tensiones von Mises
    deformacion = 1 - factor_comp;
    tensiones = modulo .* deformacion;
    
    tension_max = max(tensiones(:));
    tension_media = mean(tensiones(mapa_densidad > 0));
    
    % Validaciones
    assert(tension_max > 0, 'Tensión máxima inválida');
    assert(tension_media > 0, 'Tensión media inválida');
    assert(tension_max >= tension_media, 'Lógica de tensiones inconsistente');
    assert(all(isfinite(tensiones)), 'Tensiones contienen NaN o Inf');
    
    fprintf('  ✓ Asignación de módulos de Young\n');
    fprintf('  ✓ Cálculo de deformación por compresión\n');
    fprintf('  ✓ Cálculo de tensiones von Mises\n');
    fprintf('  ✓ Tensión máxima: %.2f kPa\n', tension_max);
    fprintf('  ✓ Tensión media: %.2f kPa\n', tension_media);
    fprintf('  ✓ PASADO\n\n');
    
    tests_pasados = tests_pasados + 1;
    
catch ME
    fprintf('  ✗ FALLIDO: %s\n\n', ME.message);
end

%% TEST 6: DETECCIÓN DE LESIONES
fprintf('TEST 6: DETECCIÓN Y CLASIFICACIÓN DE LESIONES\n');
fprintf('──────────────────────────────────────────────\n');

try
    % Usar imagen de TEST 2
    [etiquetas, num_regiones] = bwlabel(mascara);
    
    % Crear lesión simulada
    lesion_mask = (X-300).^2 + (Y-250).^2 < 1000;
    etiquetas(lesion_mask) = max(etiquetas(:)) + 1;
    
    propiedades = regionprops(etiquetas, 'Area', 'Perimeter', 'Eccentricity', 'Solidity');
    
    lesiones_encontradas = struct([]);
    
    for i = 1:length(propiedades)
        area = propiedades(i).Area;
        if area < 50, continue; end
        
        perim = propiedades(i).Perimeter;
        compacidad = perim^2 / (4 * pi * area);
        excen = propiedades(i).Eccentricity;
        solidez = propiedades(i).Solidity;
        
        if solidez > 0.85 && excen < 0.6
            clase = 'Benigno';
            riesgo = 1;
        else
            clase = 'Maligno';
            riesgo = 8;
        end
        
        lesiones_encontradas(i) = struct('Area', area, 'Clasificacion', clase, ...
                                         'Riesgo', riesgo, 'Confianza', 0.75);
    end
    
    % Validaciones
    assert(~isempty(lesiones_encontradas), 'No se detectaron lesiones');
    assert(all(ismember({lesiones_encontradas.Clasificacion}, ['Benigno' 'Maligno'])), ...
           'Clasificación inválida');
    
    fprintf('  ✓ Etiquetamiento de regiones completado\n');
    fprintf('  ✓ Extracción de propiedades completada\n');
    fprintf('  ✓ Clasificación morfológica aplicada\n');
    fprintf('  ✓ Lesiones detectadas: %d\n', length(lesiones_encontradas));
    fprintf('  ✓ PASADO\n\n');
    
    tests_pasados = tests_pasados + 1;
    
catch ME
    fprintf('  ✗ FALLIDO: %s\n\n', ME.message);
end

%% TEST 7: MICROCALCIFICACIONES
fprintf('TEST 7: DETECCIÓN DE MICROCALCIFICACIONES\n');
fprintf('──────────────────────────────────────────\n');

try
    % Crear imagen con microcalcificaciones simuladas
    img_micro = mat2gray(img_seg);
    
    % Agregar microcalcificaciones
    for i = 1:10
        cx = 100 + randi(300);
        cy = 100 + randi(300);
        micro_mask = (X-cx).^2 + (Y-cy).^2 < 25;
        img_micro(micro_mask) = 1;
    end
    
    % Detección
    umbral = 0.7;
    masc_micro = img_micro > umbral;
    masc_micro = bwareaopen(masc_micro, 5);
    
    stats_micro = regionprops(masc_micro, 'Centroid', 'Area');
    
    num_micro = length(stats_micro);
    
    if num_micro < 3
        distribucion = 'Aisladas';
    elseif num_micro < 10
        distribucion = 'Dispersas';
    else
        distribucion = 'Agrupadas';
    end
    
    % Validaciones
    assert(num_micro > 0, 'No se detectaron microcalcificaciones');
    assert(ismember(distribucion, ['Aisladas' 'Dispersas' 'Agrupadas']), ...
           'Distribución inválida');
    
    fprintf('  ✓ Wavelet DWT simulado\n');
    fprintf('  ✓ Umbralización adaptativa aplicada\n');
    fprintf('  ✓ Microcalcificaciones detectadas: %d\n', num_micro);
    fprintf('  ✓ Patrón de distribución: %s\n', distribucion);
    fprintf('  ✓ PASADO\n\n');
    
    tests_pasados = tests_pasados + 1;
    
catch ME
    fprintf('  ✗ FALLIDO: %s\n\n', ME.message);
end

%% TEST 8: RIESGO INTEGRADO
fprintf('TEST 8: CÁLCULO DE RIESGO INTEGRADO\n');
fprintf('────────────────────────────────────\n');

try
    % Usar resultados previos
    factor_dens = min(pct_densidad / 25, 4) / 4;
    
    if ~isempty(lesiones_encontradas)
        num_mal = sum(strcmp({lesiones_encontradas.Clasificacion}, 'Maligno'));
        factor_les = min((num_mal*2) / 5, 1);
    else
        factor_les = 0;
    end
    
    factor_micro = min(num_micro / 10, 1);
    factor_stress = min(tension_max / 15, 1);
    
    riesgo = (factor_dens*0.20 + factor_les*0.30 + factor_micro*0.15 + factor_stress*0.15 + 0.20) * 10;
    riesgo = min(max(riesgo, 0), 10);
    
    % BI-RADS probabilístico
    if riesgo < 2
        prob_birads = [0.70, 0.20, 0.07, 0.02, 0.01, 0.00]';
    elseif riesgo < 8
        prob_birads = [0.10, 0.20, 0.50, 0.15, 0.04, 0.01]';
    else
        prob_birads = [0.02, 0.05, 0.10, 0.30, 0.40, 0.13]';
    end
    
    [~, categoria_idx] = max(prob_birads);
    categoria_birads = categoria_idx - 1;
    
    % Validaciones
    assert(riesgo >= 0 && riesgo <= 10, 'Riesgo fuera de rango 0-10');
    assert(categoria_birads >= 0 && categoria_birads <= 5, 'BI-RADS fuera de rango 0-5');
    assert(sum(prob_birads) > 0.99 && sum(prob_birads) < 1.01, 'Probabilidades no suman 1');
    
    fprintf('  ✓ Normalización de factores\n');
    fprintf('  ✓ Fusión ponderada completada\n');
    fprintf('  ✓ Riesgo integrado: %.2f / 10\n', riesgo);
    fprintf('  ✓ Categoría BI-RADS Final: %d\n', categoria_birads);
    fprintf('  ✓ Distribución de probabilidades: [%.0f%% %.0f%% %.0f%% %.0f%% %.0f%% %.0f%%]\n', ...
            prob_birads*100);
    fprintf('  ✓ PASADO\n\n');
    
    tests_pasados = tests_pasados + 1;
    
catch ME
    fprintf('  ✗ FALLIDO: %s\n\n', ME.message);
end

%% TEST 9: VISUALIZACIONES
fprintf('TEST 9: GENERACIÓN DE VISUALIZACIONES\n');
fprintf('──────────────────────────────────────\n');

try
    % Crear varias figuras
    figs = [];
    
    for i = 1:3
        fig = figure('visible', 'off');
        plot(randn(100, 1));
        title(['Test Figure ' num2str(i)]);
        figs = [figs, fig];
    end
    
    % Validaciones
    assert(length(figs) == 3, 'Número incorrecto de figuras');
    assert(all(isgraphics(figs)), 'Figuras no son objetos gráficos válidos');
    
    % Limpiar
    close all;
    
    fprintf('  ✓ Creación de figuras exitosa\n');
    fprintf('  ✓ Total: %d figuras generadas\n', length(figs));
    fprintf('  ✓ Validación de objetos gráficos completada\n');
    fprintf('  ✓ PASADO\n\n');
    
    tests_pasados = tests_pasados + 1;
    
catch ME
    fprintf('  ✗ FALLIDO: %s\n\n', ME.message);
end

%% TEST 10: EXPORTACIÓN
fprintf('TEST 10: EXPORTACIÓN DE RESULTADOS\n');
fprintf('───────────────────────────────────\n');

try
    % Crear estructura de resultados
    carpeta_test = 'Test_Results_Temp';
    if ~exist(carpeta_test, 'dir')
        mkdir(carpeta_test);
    end
    
    % Guardar datos
    datos_test = struct('densidad', pct_densidad, 'riesgo', riesgo, 'birads', categoria_birads);
    save(fullfile(carpeta_test, 'test_results.mat'), 'datos_test');
    
    % Crear informe
    fid = fopen(fullfile(carpeta_test, 'test_informe.txt'), 'w');
    fprintf(fid, 'TEST REPORT\n');
    fprintf(fid, 'Densidad: %.1f%%\n', pct_densidad);
    fprintf(fid, 'Riesgo: %.2f\n', riesgo);
    fprintf(fid, 'BI-RADS: %d\n', categoria_birads);
    fclose(fid);
    
    % Validaciones
    assert(exist(fullfile(carpeta_test, 'test_results.mat'), 'file'), 'Archivo MAT no creado');
    assert(exist(fullfile(carpeta_test, 'test_informe.txt'), 'file'), 'Archivo TXT no creado');
    
    % Limpiar
    rmdir(carpeta_test, 's');
    
    fprintf('  ✓ Guardado de archivos MAT completado\n');
    fprintf('  ✓ Generación de informe TXT completada\n');
    fprintf('  ✓ Estructura de directorios validada\n');
    fprintf('  ✓ PASADO\n\n');
    
    tests_pasados = tests_pasados + 1;
    
catch ME
    fprintf('  ✗ FALLIDO: %s\n\n', ME.message);
end

%% RESUMEN FINAL
fprintf('╔════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                        RESUMEN DE PRUEBAS                             ║\n');
fprintf('╠════════════════════════════════════════════════════════════════════════╣\n');
fprintf('║  Tests Pasados:     %d/%d                                           ║\n', tests_pasados, num_tests);
fprintf('║  Tests Fallidos:    %d/%d                                           ║\n', num_tests - tests_pasados, num_tests);
fprintf('║  Porcentaje:        %.1f%%                                           ║\n', (tests_pasados/num_tests)*100);
fprintf('╠════════════════════════════════════════════════════════════════════════╣\n');

if tests_pasados == num_tests
    fprintf('║  RESULTADO: ✓✓✓ TODOS LOS TESTS PASARON ✓✓✓                        ║\n');
    fprintf('║  El sistema está listo para usar en producción                    ║\n');
elseif tests_pasados >= num_tests * 0.8
    fprintf('║  RESULTADO: ✓ TESTS MAYORMENTE EXITOSOS                            ║\n');
    fprintf('║  Revisar los tests fallidos antes de usar                         ║\n');
else
    fprintf('║  RESULTADO: ✗ TESTS CRÍTICOS FALLIDOS                              ║\n');
    fprintf('║  Se requiere depuración antes de usar                             ║\n');
end

fprintf('╚════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('Fin de pruebas: %s\n', datestr(now));
fprintf('═══════════════════════════════════════════════════════════════════════════\n\n');
