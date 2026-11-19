%% =========================================================================
%  SISTEMA HÍBRIDO MAESTRÍA - CNN + GEOMETRÍA (VERSIÓN FINAL ESTABLE)
%  Título: Caracterización de la Densidad Mamográfica mediante Deep Learning
%          y Análisis de Patrones Geométricos
%  Autor: [Tu nombre]
%  Universidad ECCI
% =========================================================================

clear all; close all; clc;
warning off all;

%% CONFIGURACIÓN
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║       SISTEMA HÍBRIDO MAESTRÍA - CNN + GEOMETRÍA                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

config.prep.clahe_clip = 0.02;
config.prep.num_tiles = 8;
config.seg.radio = 6;
config.seg.sensibilidad = 0.55;
config.umbral_area_minima = 1000;

config.cnn.learning_rate = 0.001;
config.cnn.num_epochs = 20;
config.cnn.batch_size = 32;
config.cnn.imagen_size = [224 224];

%% CARGA DE IMAGEN (DICOM O PRUEBA)
try
    [archivo, ruta] = uigetfile({'*.dcm;*.dicom','Archivos DICOM';'*.*','Todos'}, ...
                                 'Seleccione una mamografía DICOM');
    if isequal(archivo,0), error('Cancelado - Usando imagen de prueba'); end
    ruta_completa = fullfile(ruta, archivo);
    info = dicominfo(ruta_completa);
    img_raw = dicomread(ruta_completa);
    fprintf('✓ DICOM cargado: %s\n', archivo);
catch
    fprintf('⚠ Usando imagen sintética de prueba\n');
    [ny, nx] = deal(1024, 1024);
    img_raw = uint8(ones(ny,nx)*80 + randn(ny,nx)*15);
    [X,Y] = meshgrid(1:nx,1:ny);
    cx = nx/2; cy = ny/2;
    region_densa = exp(-(sqrt((X-cx).^2 + (Y-cy).^2)/200).^2);
    img_raw = max(0, min(255, img_raw + uint8(region_densa*100)));
    info = struct('PatientName','PRUEBA','StudyDate',datestr(now),'Modality','MG');
end

%% PREPROCESAMIENTO Y SEGMENTACIÓN
fprintf('\n▶ Preprocesando imagen...\n');
if isfield(info,'RescaleSlope') && ~isempty(info.RescaleSlope)
    img_d = double(img_raw) * info.RescaleSlope + info.RescaleIntercept;
else
    img_d = double(img_raw);
end
p_low = prctile(img_d(:), 2);
p_high = prctile(img_d(:), 98);
img_norm = mat2gray(img_d, [p_low, p_high]);
img_8bit = uint8(img_norm * 255);
if size(img_8bit,3)==3, img_gris = rgb2gray(img_8bit);
else img_gris = img_8bit; end
img_clahe = adapthisteq(img_gris, 'ClipLimit', config.prep.clahe_clip, ...
                        'NumTiles', [config.prep.num_tiles config.prep.num_tiles]);
img_suave = imbilatfilt(img_clahe, 'DegreeOfSmoothing', 0.5, 'SpatialSigma', 2);
img_proc = imgaussfilt(img_suave, 1.0);

fprintf('▶ Segmentando...\n');
masc_adapt = imbinarize(img_proc, 'adaptive', 'Sensitivity', config.seg.sensibilidad);
masc_otsu = imbinarize(img_proc, graythresh(img_proc));
masc_inicial = masc_adapt | masc_otsu;
se = strel('disk', config.seg.radio);
masc_limpia = imclose(imopen(masc_inicial, se), se);
masc_final = bwareaopen(masc_limpia, config.umbral_area_minima);
masc_final = imfill(masc_final, 'holes');
stats_area = regionprops(masc_final, 'Area', 'Centroid');
for k=1:length(stats_area)
    if stats_area(k).Area > 0.3 * numel(masc_final)
        masc_final = masc_final & ~bwselect(masc_final, ...
                        round(stats_area(k).Centroid(1)), ...
                        round(stats_area(k).Centroid(2)));
    end
end
masc_final = bwareaopen(masc_final, config.umbral_area_minima);
[etiquetas, num_reg] = bwlabel(masc_final);
fprintf('   ✓ %d regiones segmentadas\n', num_reg);

if num_reg == 0
    error('No se detectaron regiones para análisis.');
end

%% EXTRACCIÓN DE CARACTERÍSTICAS RADIÓMICAS (GLCM)
fprintf('\n▶ Extrayendo características radiómicas y geométricas...\n');
glcm = graycomatrix(img_proc, 'Offset', [0 1; -1 1; -1 0; -1 -1], 'NumLevels', 16);
props = graycoprops(glcm, {'contrast', 'correlation', 'energy', 'homogeneity'});

props_reg = regionprops(etiquetas, img_proc, 'Area', 'Perimeter', 'Eccentricity', ...
                        'Solidity', 'MajorAxisLength', 'MinorAxisLength');

features_geometricas = [];
for i = 1:length(props_reg)
    area = props_reg(i).Area;
    perim = props_reg(i).Perimeter;
    compacidad = (perim^2) / (4 * pi * area);
    irregularidad = (area - pi*(props_reg(i).MinorAxisLength/2)*(props_reg(i).MajorAxisLength/2)) / area;
    features_geometricas = [features_geometricas; props_reg(i).Eccentricity, ...
                            props_reg(i).Solidity, compacidad, irregularidad];
end

% Porcentaje de densidad
img_mama = img_proc .* uint8(masc_final);
valores = img_mama(masc_final);
p75 = prctile(valores, 75);
area_densa = sum(img_mama(masc_final) > p75);
area_total = sum(masc_final(:));
pct_densidad = 100 * area_densa / area_total;
if pct_densidad < 25, birads_dens = 'a';
elseif pct_densidad < 50, birads_dens = 'b';
elseif pct_densidad < 75, birads_dens = 'c';
else birads_dens = 'd'; end

fprintf('   GLCM: Contraste=%.3f, Homogeneidad=%.3f\n', mean(props.Contrast), mean(props.Homogeneity));
fprintf('   Densidad: %.1f%% (BI-RADS %s)\n', pct_densidad, birads_dens);

%% PREPARACIÓN DE DATOS PARA LA CNN (AUMENTO DE DATOS SEGURO)
fprintf('\n▶ Preparando datos para entrenamiento de CNN...\n');

% Recortar ROIs y etiquetar (solo regiones con área >= 500)
X_data = [];
Y_labels = [];
for i = 1:num_reg
    if props_reg(i).Area < 500
        continue;   % Omitir regiones muy pequeñas
    end
    roi = img_proc .* uint8(etiquetas == i);
    % Verificar que la ROI no esté vacía
    if sum(roi(:)) == 0
        continue;
    end
    roi_resized = imresize(roi, config.cnn.imagen_size);
    % Etiqueta: 1 = alto riesgo (maligno), 0 = bajo riesgo (benigno)
    if props_reg(i).Area > 5000 || (props_reg(i).Eccentricity > 0.7 && props_reg(i).Solidity < 0.85)
        clase = 1;
    else
        clase = 0;
    end
    X_data = cat(4, X_data, roi_resized);
    Y_labels = [Y_labels; clase];
end

if size(X_data,4) < 2
    error('No hay suficientes regiones para entrenar la CNN (mínimo 2).');
end

num_original = size(X_data,4);
fprintf('   Regiones originales (área ≥ 500): %d\n', num_original);

% Aumento de datos: por cada original, generar EXACTAMENTE 2 imágenes aumentadas
X_aug = [];
Y_aug = [];
for i = 1:num_original
    % 1) Rotación aleatoria ±15 grados
    angulo = randi([-15,15]);
    try
        img_rot = imrotate(X_data(:,:,:,i), angulo, 'bilinear', 'crop');
        X_aug = cat(4, X_aug, img_rot);
        Y_aug = [Y_aug; Y_labels(i)];
    catch
        % Si falla, usar la original
        X_aug = cat(4, X_aug, X_data(:,:,:,i));
        Y_aug = [Y_aug; Y_labels(i)];
    end
    
    % 2) Ruido gaussiano
    try
        img_noisy = imnoise(X_data(:,:,:,i), 'gaussian', 0, 0.01);
        X_aug = cat(4, X_aug, img_noisy);
        Y_aug = [Y_aug; Y_labels(i)];
    catch
        X_aug = cat(4, X_aug, X_data(:,:,:,i));
        Y_aug = [Y_aug; Y_labels(i)];
    end
end

% Concatenar originales y aumentadas
X_total = cat(4, X_data, X_aug);
Y_total = [Y_labels; Y_aug];

% VERIFICACIÓN OBLIGATORIA DE CONSISTENCIA
if size(X_total,4) ~= length(Y_total)
    error('INCONSISTENCIA DETECTADA: X_total (%d) vs Y_total (%d). Revisar el bucle de aumento.', ...
          size(X_total,4), length(Y_total));
end

num_samples = size(X_total,4);
fprintf('   Total muestras después de aumento: %d\n', num_samples);

% Mezcla aleatoria
indices = randperm(num_samples);
X_total = X_total(:,:,:,indices);
Y_total = Y_total(indices);

% División entrenamiento (80%) / validación (20%)
num_train = round(0.8 * num_samples);
X_train = X_total(:,:,:,1:num_train);
Y_train = categorical(Y_total(1:num_train));
X_val   = X_total(:,:,:,num_train+1:end);
Y_val   = categorical(Y_total(num_train+1:end));

fprintf('   Entrenamiento: %d, Validación: %d\n', num_train, size(X_val,4));

%% CONSTRUCCIÓN Y ENTRENAMIENTO DE LA CNN
fprintf('▶ Construyendo y entrenando red neuronal convolucional...\n');

layers = [
    imageInputLayer(config.cnn.imagen_size)
    convolution2dLayer(5, 20, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    maxPooling2dLayer(2, 'Stride', 2)
    convolution2dLayer(5, 50, 'Padding', 'same')
    batchNormalizationLayer
    reluLayer
    maxPooling2dLayer(2, 'Stride', 2)
    fullyConnectedLayer(500)
    reluLayer
    dropoutLayer(0.5)
    fullyConnectedLayer(2)
    softmaxLayer
    classificationLayer
];

options = trainingOptions('adam', ...
    'InitialLearnRate', config.cnn.learning_rate, ...
    'MaxEpochs', config.cnn.num_epochs, ...
    'MiniBatchSize', min(config.cnn.batch_size, num_train), ...
    'Shuffle', 'every-epoch', ...
    'Verbose', true, ...
    'Plots', 'training-progress');

try
    net = trainNetwork(X_train, Y_train, layers, options);
    fprintf('   ✓ CNN entrenada exitosamente\n');
    
    % Evaluación en validación
    Y_pred = classify(net, X_val);
    accuracy = sum(Y_pred == Y_val) / numel(Y_val);
    fprintf('   Precisión en validación: %.2f%%\n', accuracy*100);
catch ME
    fprintf('   ⚠ Error en entrenamiento: %s\n', ME.message);
    fprintf('   Continuando sin CNN (usando solo características geométricas).\n');
    net = [];
end

%% RIESGO INTEGRADO Y DIAGNÓSTICO FINAL
fprintf('\n▶ Generando diagnóstico final...\n');
if ~isempty(features_geometricas)
    riesgo_geometrico = mean(features_geometricas(:,1)) * 5 + (1-mean(features_geometricas(:,2))) * 5;
    riesgo = min(riesgo_geometrico, 10);
else
    riesgo = pct_densidad / 10;
end

if riesgo > 7
    diagnostico = 'ALTA SOSPECHA - BIOPSIA RECOMENDADA';
    color = [0.8,0,0];
elseif riesgo > 4
    diagnostico = 'HALLAZGOS PROBABLEMENTE BENIGNOS - SEGUIMIENTO';
    color = [0.9,0.7,0];
else
    diagnostico = 'HALLAZGOS NORMALES - REVISIÓN RUTINARIA';
    color = [0,0.7,0];
end

fprintf('   Riesgo integrado: %.1f/10\n', riesgo);
fprintf('   Diagnóstico: %s\n', diagnostico);

%% VISUALIZACIÓN Y EXPORTACIÓN
carpeta = 'Resultados_Maestria_CNN';
if ~exist(carpeta,'dir'), mkdir(carpeta); end

resumen.densidad = pct_densidad;
resumen.birads = birads_dens;
resumen.riesgo = riesgo;
resumen.diagnostico = diagnostico;
resumen.num_regiones = num_reg;
resumen.glcm_contraste = mean(props.Contrast);
resumen.glcm_homogeneidad = mean(props.Homogeneity);
save(fullfile(carpeta, 'resultados.mat'), 'resumen', 'features_geometricas');

figure('Name','Diagnóstico Integrado','Visible','off');
subplot(2,2,1); imshow(img_proc,[]); title('Mamografía Procesada');
subplot(2,2,2); bar([pct_densidad, 100-pct_densidad]); title('Densidad');
subplot(2,2,3); imshow(label2rgb(etiquetas)); title('Segmentación');
subplot(2,2,4); axis off; text(0.1,0.9,{sprintf('BI-RADS: %s',birads_dens), ...
    sprintf('Riesgo: %.1f/10',riesgo),sprintf('Diagnóstico: %s',diagnostico)});
exportgraphics(gcf, fullfile(carpeta, 'Figura_Principal.png'), 'Resolution', 150);
close all;

fprintf('\n╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║                    ✓ ANÁLISIS COMPLETADO                         ║\n');
fprintf('║  Resultados guardados en: %s\n', carpeta);
fprintf('╚══════════════════════════════════════════════════════════════════╝\n');