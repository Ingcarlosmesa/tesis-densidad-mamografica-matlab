%% SISTEMA UNIFICADO COMPLETO DE ANÁLISIS MAMARIO
% Versión final corregida – 9 figuras + exportación funcional
% Incluye: densidad BI-RADS, segmentación, clasificación de lesiones,
%          modelo biomecánico, diagnóstico integrado, exportación
% Uso:
%   Modo 1 (Interactivo): selecciona un DICOM, muestra 9 figuras,
%          pregunta si desea exportar y luego cierra las figuras.
%   Modo 2 (Batch): selecciona carpeta con DICOMs, procesa en lote,
%          exporta resultados sin mostrar figuras.

clear all; close all; clc;

%% CONFIGURACIÓN INICIAL
fprintf('=========================================\n');
fprintf(' SISTEMA UNIFICADO DE ANÁLISIS MAMARIO\n');
fprintf('=========================================\n');
modo = input('Seleccione modo (1 = Interactivo, 2 = Batch): ');

if modo == 2
    carpeta = uigetdir(pwd, 'Carpeta con archivos DICOM');
    if carpeta == 0, disp('Cancelado.'); return; end
    archivos = dir(fullfile(carpeta, '*.dcm'));
    if isempty(archivos)
        archivos = dir(fullfile(carpeta, '*.dicom'));
    end
    if isempty(archivos)
        disp('No se encontraron DICOM.');
        return;
    end
    listaArchivos = fullfile(carpeta, {archivos.name});
else
    listaArchivos = {};
end

%% PARÁMETROS DEL SISTEMA
config.umbral_area_minima = 1000;
config.umbral_compacidad_maligna = 1.3;
config.umbral_diametro_maligno = 150;
config.realce = 0.6;
config.umbralbin_tophat = 0.15;
config.r_tophat = 30;

config.deep_learning.uso_autoencoder = true;
config.deep_learning.uso_cnn_clasificacion = true;
config.deep_learning.umbral_confianza_cnn = 0.75;

config.modelo_biomecanico.young_glandular = 15.1;
config.modelo_biomecanico.young_adipose = 4.46;
config.modelo_biomecanico.poisson_ratio = 0.45;
config.modelo_biomecanico.compression_factor = 0.7;

config.denoising.uso_autoencoder_denoising = true;
config.denoising.factor_ruido = 0.1;

%% INICIALIZACIÓN DE MODELOS DE DEEP LEARNING (simulados)
modelos = inicializarModelosDeepLearning(config);

%% EJECUCIÓN SEGÚN MODO
if modo == 1
    % ---------- MODO INTERACTIVO ----------
    [archivo, dirname] = uigetfile({'*.dcm;*.dicom','DICOM Files'; '*.*','All Files'});
    if isequal(archivo,0), disp('Cancelado.'); return; end
    archivo = fullfile(dirname, archivo);
    
    % Procesar mostrando figuras
    [resultados, diagnostico, metricas, modelo, figHandles] = procesarMamografia(archivo, config, modelos, true);
    
    % Preguntar exportación MIENTRAS las figuras están abiertas
    opcion = questdlg('¿Desea exportar los resultados (figuras, informe, datos)?', ...
                      'Exportar', 'Sí','No','Sí');
    if strcmp(opcion, 'Sí')
        exportarResultados(archivo, resultados, diagnostico, metricas, modelo, figHandles);
    end
    
    % Cerrar todas las figuras después de exportar
    for h = figHandles
        if ishandle(h), close(h); end
    end
    disp('Análisis interactivo finalizado.');
    
elseif modo == 2
    % ---------- MODO BATCH ----------
    fprintf('Procesando %d archivos en modo batch...\n', length(listaArchivos));
    for i = 1:length(listaArchivos)
        archivo = listaArchivos{i};
        fprintf('[%d/%d] %s\n', i, length(listaArchivos), archivo);
        try
            [resultados, diagnostico, metricas, modelo, ~] = procesarMamografia(archivo, config, modelos, false);
            exportarResultados(archivo, resultados, diagnostico, metricas, modelo, []);
            fprintf('   -> Exportado correctamente.\n');
        catch ME
            fprintf('   -> ERROR: %s\n', ME.message);
        end
    end
    disp('Procesamiento batch finalizado.');
end

%% ============================================================================
%% FUNCIÓN PRINCIPAL DE ANÁLISIS (NÚCLEO UNIFICADO)
%% ============================================================================
function [resultados, diagnostico, metricas_densidad, modelo_biomecanico, figHandles] = ...
    procesarMamografia(archivoDICOM, config, modelos, visible)

    figHandles = [];
    
    % ---- 1. CARGA DICOM ----
    info = dicominfo(archivoDICOM);
    volumen = dicomread(archivoDICOM);
    if ndims(volumen) > 2
        if size(volumen,3) > 1
            slice_idx = round(size(volumen,3)/2);
            imagen_original = volumen(:,:,slice_idx);
        else
            imagen_original = volumen;
        end
    else
        imagen_original = volumen;
    end
    
    % Normalización a 8 bits
    if isfield(info,'RescaleSlope') && isfield(info,'RescaleIntercept')
        imagen_norm = single(imagen_original) * info.RescaleSlope + info.RescaleIntercept;
    else
        imagen_norm = single(imagen_original);
    end
    try
        if isfield(info,'WindowCenter') && isfield(info,'WindowWidth')
            wc = double(info.WindowCenter(1)); ww = double(info.WindowWidth(1));
            low = wc - ww/2; high = wc + ww/2;
            imagen_para_procesar = uint8(255 * mat2gray(imagen_norm, [low high]));
        else
            p_low = prctile(imagen_norm(:),2); p_high = prctile(imagen_norm(:),98);
            imagen_para_procesar = uint8(255 * mat2gray(imagen_norm, [p_low p_high]));
        end
    catch
        p_low = prctile(imagen_norm(:),2); p_high = prctile(imagen_norm(:),98);
        imagen_para_procesar = uint8(255 * mat2gray(imagen_norm, [p_low p_high]));
    end
    
    % ---- 2. DENOISING (simulado) ----
    if config.denoising.uso_autoencoder_denoising
        imagen_para_procesar = aplicarDenoisingAutoencoder(imagen_para_procesar, config);
    end
    
    % ---- 3. PREPROCESAMIENTO ----
    if size(imagen_para_procesar,3)==3, imagen_gris = rgb2gray(imagen_para_procesar);
    else, imagen_gris = imagen_para_procesar; end
    imagen_filtrada = medfilt2(imagen_gris, [7 7], 'symmetric');
    imagen_contraste = imadjust(imagen_filtrada, stretchlim(imagen_filtrada), []);
    imagen_ecualizada = adapthisteq(imagen_contraste);
    imagen_suavizada = imgaussfilt(imagen_ecualizada, 2);
    
    % ---- 4. SEGMENTACIÓN HÍBRIDA ----
    mascara_adaptativa = imbinarize(imagen_suavizada, 'adaptive','Sensitivity',0.55);
    itoh = uint8(min(double(imagen_suavizada)*6, 255));
    se = strel('disk', config.r_tophat);
    otoh = imtophat(itoh, se);
    oehc = imadjust(otoh, [0 config.realce], [0 1]);
    mascara_tophat = imbinarize(oehc, config.umbralbin_tophat);
    mascara_combinada = mascara_adaptativa | mascara_tophat;
    ee = strel('disk', 6);
    mascara_limpia = imopen(mascara_combinada, ee);
    mascara_limpia = imclose(mascara_limpia, ee);
    mascara_final = bwareaopen(mascara_limpia, config.umbral_area_minima);
    mascara_final = imfill(mascara_final, 'holes');
    
    % Refinamiento CNN simulado
    if config.deep_learning.uso_cnn_clasificacion
        mascara_final = refinarSegmentacionConCNN(imagen_suavizada, mascara_final, modelos);
    end
    
    % Eliminar objetos gigantes
    stats = regionprops(mascara_final, 'Area','Centroid');
    umbral_area_max = 0.3 * numel(mascara_final);
    for i = 1:length(stats)
        if stats(i).Area > umbral_area_max
            mascara_final = mascara_final & ~bwselect(mascara_final, round(stats(i).Centroid(1)), round(stats(i).Centroid(2)));
        end
    end
    
    % ---- 5. MAPA DE DENSIDAD Y MÉTRICAS ----
    mapa_densidad = generarMapaDensidadAvanzado(imagen_suavizada, mascara_final);
    metricas_densidad = calcularMetricasDensidadAvanzadas(mapa_densidad, mascara_final);
    
    % ---- 6. MODELO BIOMECÁNICO ----
    [modelo_biomecanico, deformaciones] = generarModeloBiomecanicoAvanzado(imagen_suavizada, mapa_densidad, config.modelo_biomecanico);
    
    % ---- 7. CLASIFICACIÓN DE LESIONES ----
    [etiquetas, num_regiones] = bwlabel(mascara_final);
    resultados = [];
    if num_regiones > 0
        propiedades = regionprops(etiquetas, {'Area','Perimeter','Eccentricity','Solidity','BoundingBox','Centroid','MajorAxisLength'});
        for i = 1:num_regiones
            [clasificacion, puntuacion_riesgo, confianza] = clasificarLesionAvanzada(imagen_suavizada, propiedades(i), modelos, config);
            area_actual = propiedades(i).Area;
            perimetro_actual = propiedades(i).Perimeter;
            excentricidad_actual = propiedades(i).Eccentricity;
            solidez_actual = propiedades(i).Solidity;
            diametro_mayor = propiedades(i).MajorAxisLength;
            diametro_equivalente = 2*sqrt(area_actual/pi);
            compacidad = (perimetro_actual^2)/(4*pi*area_actual);
            resultados = [resultados, struct('ID',i,'Area',area_actual,'Perimetro',perimetro_actual,...
                'Diametro',diametro_equivalente,'DiametroMayor',diametro_mayor,...
                'Excentricidad',excentricidad_actual,'Solidez',solidez_actual,...
                'Compacidad',compacidad,'Clasificacion',clasificacion,...
                'PuntuacionRiesgo',puntuacion_riesgo,'Confianza',confianza)];
        end
    end
    
    % ---- 8. DIAGNÓSTICO INTEGRADO ----
    diagnostico = generarDiagnosticoIntegradoAvanzado(resultados, metricas_densidad, modelo_biomecanico, config);
    
    % ---- 9. FIGURAS (solo si visible = true) ----
    if visible
        % Cada figura se intenta por separado para que un fallo no detenga al resto
        try
            fig1 = visualizarProcesamientoAvanzado(imagen_original, imagen_suavizada, oehc, ...
                mascara_final, mascara_adaptativa, imagen_ecualizada, num_regiones, info);
            figHandles(end+1) = fig1;
        catch ME, warning('Figura 1: %s', ME.message); end
        
        try
            fig2 = visualizarDensidadTexturaAvanzada(imagen_suavizada, mascara_final, ...
                mapa_densidad, metricas_densidad, modelos);
            figHandles(end+1) = fig2;
        catch ME, warning('Figura 2: %s', ME.message); end
        
        try
            fig3 = visualizarModeloBiomecanicoAvanzado(imagen_suavizada, mapa_densidad, ...
                modelo_biomecanico, metricas_densidad);
            figHandles(end+1) = fig3;
        catch ME, warning('Figura 3: %s', ME.message); end
        
        try
            fig4 = visualizarRiesgoIntegradoAvanzado(imagen_suavizada, mascara_final, ...
                mapa_densidad, modelo_biomecanico, resultados, diagnostico);
            figHandles(end+1) = fig4;
        catch ME, warning('Figura 4: %s', ME.message); end
        
        try
            fig5 = visualizarCorrelacionMultimodalAvanzada_v2(resultados, deformaciones, metricas_densidad, config);
            figHandles(end+1) = fig5;
        catch ME, warning('Figura 5: %s', ME.message); end
        
        try
            fig6 = visualizarLesionesDetectadas(imagen_suavizada, mascara_final, resultados, etiquetas);
            figHandles(end+1) = fig6;
        catch ME, warning('Figura 6: %s', ME.message); end
        
        try
            fig7 = visualizarTablaCaracteristicas(resultados);
            figHandles(end+1) = fig7;
        catch ME, warning('Figura 7: %s', ME.message); end
        
        try
            fig8 = visualizarAnalisisEstadistico(imagen_suavizada, mascara_final, resultados, etiquetas);
            figHandles(end+1) = fig8;
        catch ME, warning('Figura 8: %s', ME.message); end
        
        try
            fig9 = visualizarResumenClinico(resultados, diagnostico.clasificacion, ...
                diagnostico.recomendacion, diagnostico.puntuacion_total);
            figHandles(end+1) = fig9;
        catch ME, warning('Figura 9: %s', ME.message); end
    end
end

%% ============================================================================
%% FUNCIONES DE PROCESAMIENTO (SIMULACIONES DE REDES)
%% ============================================================================
function modelos = inicializarModelosDeepLearning(config)
    % *** Si se dispone de redes reales entrenadas, cargarlas aquí.
    modelos.autoencoder_denoising = [];
    modelos.cnn_clasificacion = [];
    modelos.cnn_segmentacion = [];
end

function imagen_denoised = aplicarDenoisingAutoencoder(imagen, config)
    % Simulación: filtro bilateral en lugar de autoencoder real.
    imagen_double = double(imagen);
    imagen_denoised = imbilatfilt(imagen_double, ...
        'DegreeOfSmoothing', 0.01 * config.denoising.factor_ruido, ...
        'SpatialSigma', 3);
    imagen_denoised = uint8(imagen_denoised);
end

function mascara_mejorada = refinarSegmentacionConCNN(imagen, mascara, modelos)
    % Simulación de CNN de segmentación con gradientes.
    [gx, gy] = imgradientxy(imagen);
    magnitud_gradiente = sqrt(gx.^2 + gy.^2);
    umbral_gradiente = graythresh(magnitud_gradiente) * max(magnitud_gradiente(:));
    bordes_refinados = magnitud_gradiente > umbral_gradiente * 0.3;
    mascara_mejorada = mascara & ~bordes_refinados;
    mascara_mejorada = imfill(mascara_mejorada, 'holes');
    mascara_mejorada = bwareaopen(mascara_mejorada, 500);
end

function [clasificacion, puntuacion, confianza] = clasificarLesionAvanzada(imagen, prop, modelos, config)
    bbox = round(prop.BoundingBox);
    x1 = max(1, bbox(1)); y1 = max(1, bbox(2));
    x2 = min(size(imagen,2), x1+bbox(3)-1);
    y2 = min(size(imagen,1), y1+bbox(4)-1);
    area = prop.Area; excentricidad = prop.Eccentricity; solidez = prop.Solidity;
    diametro_mayor = prop.MajorAxisLength;
    
    if x2 > x1 && y2 > y1
        roi = imagen(y1:y2, x1:x2);
        % Clasificación morfológica base
        if area > 10000
            clasificacion_morf = 'Tumor'; puntuacion_morf = 4;
        elseif area >= 500
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
        
        % CNN simulada (análisis de textura)
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
                clasificacion = clasificacion_cnn; confianza = confianza_cnn;
            else
                clasificacion = clasificacion_morf; confianza = 0.70;
            end
            
            switch clasificacion
                case 'Maligno', puntuacion = 3 * confianza;
                case 'Benigno', puntuacion = 1 * confianza;
                case 'Tumor', puntuacion = 4;
                otherwise, puntuacion = 2 * confianza;
            end
        else
            clasificacion = clasificacion_morf; confianza = 0.65; puntuacion = puntuacion_morf;
        end
    else
        if area > 10000, clasificacion = 'Tumor'; puntuacion = 4;
        elseif area >= 500, clasificacion = 'Indeterminado'; puntuacion = 2;
        else, clasificacion = 'Ruido'; puntuacion = 0;
        end
        confianza = 0.50;
    end
end

%% ============================================================================
%% FUNCIONES DE DENSIDAD, BIOMECÁNICA, DIAGNÓSTICO
%% ============================================================================
function mapa_densidad = generarMapaDensidadAvanzado(imagen, mascara)
    mascara_mama = imfill(mascara, 'holes');
    nivel_graso = graythresh(imagen(mascara_mama)) * 0.6;
    nivel_intermedio = graythresh(imagen(mascara_mama)) * 1.1;
    nivel_denso = graythresh(imagen(mascara_mama)) * 1.5;
    mapa_densidad = zeros(size(imagen));
    mapa_densidad(mascara_mama & imagen < nivel_graso*max(imagen(:))) = 1;
    mapa_densidad(mascara_mama & imagen >= nivel_graso*max(imagen(:)) & imagen < nivel_intermedio*max(imagen(:))) = 2;
    mapa_densidad(mascara_mama & imagen >= nivel_intermedio*max(imagen(:)) & imagen < nivel_denso*max(imagen(:))) = 3;
    mapa_densidad(mascara_mama & imagen >= nivel_denso*max(imagen(:))) = 4;
    mapa_densidad = imgaussfilt(mapa_densidad, 2);
end

function metricas = calcularMetricasDensidadAvanzadas(mapa_densidad, mascara)
    mascara_mama = imfill(mascara, 'holes');
    area_total = sum(mascara_mama(:));
    if area_total == 0
        metricas = struct('porcentaje_densidad',0,'area_total',0,'area_densa',0,...
            'area_grasa',0,'birads_categoria','a','birads_descripcion','No calculable',...
            'entropia',0,'homogeneidad',0,'asimetria_espacial',0);
        return;
    end
    area_graso = sum(mapa_densidad(mascara_mama)==1);
    area_intermedio = sum(mapa_densidad(mascara_mama)==2);
    area_denso = sum(mapa_densidad(mascara_mama)==3);
    metricas.porcentaje_densidad = ((area_denso + area_intermedio*0.5)/area_total)*100;
    metricas.area_total = area_total;
    metricas.area_densa = area_denso + area_intermedio;
    metricas.area_grasa = area_graso;
    if metricas.porcentaje_densidad < 25
        metricas.birads_categoria = 'a'; metricas.birads_descripcion = 'Casi completamente grasa';
    elseif metricas.porcentaje_densidad < 50
        metricas.birads_categoria = 'b'; metricas.birads_descripcion = 'Densidades dispersas';
    elseif metricas.porcentaje_densidad < 75
        metricas.birads_categoria = 'c'; metricas.birads_descripcion = 'Heterogéneamente densa';
    else
        metricas.birads_categoria = 'd'; metricas.birads_descripcion = 'Extremadamente densa';
    end
    mapa_densidad_mama = mapa_densidad; mapa_densidad_mama(~mascara_mama) = 0;
    metricas.entropia = entropy(mapa_densidad_mama(mascara_mama));
    try
        [GLCM, ~] = graycomatrix(mapa_densidad_mama, 'Offset',[0 1; -1 1; -1 0; -1 -1], ...
                                 'NumLevels',4,'GrayLimits',[1 4]);
        props = graycoprops(GLCM,{'Contrast','Homogeneity'});
        metricas.contraste = mean(props.Contrast);
        metricas.homogeneidad = mean(props.Homogeneity);
    catch
        metricas.contraste = 0; metricas.homogeneidad = 0;
    end
    regiones_densas = mapa_densidad_mama >= 3;
    if sum(regiones_densas(:)) > 0
        stats_mama = regionprops(mascara_mama,'Centroid');
        centroide_mama = stats_mama.Centroid;
        stats_densas = regionprops(regiones_densas,'Centroid','Area');
        areas_densas = [stats_densas.Area];
        centroides_densas = vertcat(stats_densas.Centroid);
        centroide_densas = sum(centroides_densas.*areas_densas',1)/sum(areas_densas);
        [fil,col] = find(mascara_mama);
        diametro_mama = max(sqrt((fil-centroide_mama(2)).^2 + (col-centroide_mama(1)).^2))*2;
        distancia_centroides = sqrt(sum((centroide_mama - centroide_densas).^2))/diametro_mama;
        metricas.asimetria_espacial = distancia_centroides;
    else
        metricas.asimetria_espacial = 0;
    end
end

function [modelo, deformaciones] = generarModeloBiomecanicoAvanzado(imagen, mapa_densidad, config)
    modelo = struct();
    mascara_mama = mapa_densidad > 0;
    mascara_glandular = mapa_densidad >= 2;
    mascara_adiposo = mapa_densidad == 1;
    modelo.propiedades.young_glandular = config.young_glandular;
    modelo.propiedades.young_adipose = config.young_adipose;
    modelo.propiedades.poisson_ratio = config.poisson_ratio;
    [filas, columnas] = size(imagen);
    modelo.geometria.filas = filas; modelo.geometria.columnas = columnas;
    modelo.geometria.area_total = sum(mascara_mama(:));
    modelo.geometria.area_glandular = sum(mascara_glandular(:));
    modelo.geometria.area_adiposa = sum(mascara_adiposo(:));
    deformaciones = simularDeformacionCompresionAvanzada(mapa_densidad, config.compression_factor);
    modelo.tensiones = calcularTensionesBiomecanicasAvanzadas(mapa_densidad, deformaciones, config);
end

function deformaciones = simularDeformacionCompresionAvanzada(mapa_densidad, factor_compresion)
    [filas, columnas] = size(mapa_densidad);
    [X,Y] = meshgrid(1:columnas,1:filas);
    centro_x = columnas/2; centro_y = filas/2;
    distancia_centro = sqrt((X-centro_x).^2 + (Y-centro_y).^2);
    max_distancia = sqrt(centro_x^2 + centro_y^2);
    factor_radial = 1 - factor_compresion * (distancia_centro/max_distancia);
    factor_tejido = ones(size(mapa_densidad));
    factor_tejido(mapa_densidad>=3) = 0.7; factor_tejido(mapa_densidad==2) = 0.85; factor_tejido(mapa_densidad==1) = 1.0;
    factor_compresion_ajustado = factor_radial .* factor_tejido;
    deformaciones.desp_x = (X-centro_x).*(1-factor_compresion_ajustado)*0.1;
    deformaciones.desp_y = (Y-centro_y).*(1-factor_compresion_ajustado)*0.1;
    deformaciones.factor_compresion = factor_compresion_ajustado;
end

function tensiones = calcularTensionesBiomecanicasAvanzadas(mapa_densidad, deformaciones, config)
    [filas, columnas] = size(mapa_densidad);
    tensiones.maxima = zeros(filas, columnas); tensiones.media = zeros(filas, columnas); tensiones.gradiente = zeros(filas, columnas);
    [grad_x, grad_y] = gradient(deformaciones.factor_compresion);
    for i=1:filas
        for j=1:columnas
            if mapa_densidad(i,j)>0
                if mapa_densidad(i,j)>=3, E = config.young_glandular*1.2;
                elseif mapa_densidad(i,j)==2, E = config.young_glandular;
                else, E = config.young_adipose;
                end
                deformacion_local = 1 - deformaciones.factor_compresion(i,j);
                tensiones.maxima(i,j) = E * deformacion_local;
                gradiente_local = sqrt(grad_x(i,j)^2+grad_y(i,j)^2);
                tensiones.gradiente(i,j) = E * gradiente_local;
            end
        end
    end
    tensiones.media = tensiones.maxima/2;
end

function diagnostico = generarDiagnosticoIntegradoAvanzado(resultados, metricas, modelo, config)
    if isempty(resultados)
        diagnostico = struct('clasificacion','SIN HALLAZGOS DETECTABLES','color',[0.5 0.5 0.5],...
            'recomendacion',{{'• Continuar con revisiones preventivas'}},'puntuacion_total',0,'confianza',0.95);
        return;
    end
    puntuacion_total = sum([resultados.PuntuacionRiesgo]);
    num_malignas = sum(strcmp({resultados.Clasificacion},'Maligno'));
    num_tumores = sum(strcmp({resultados.Clasificacion},'Tumor'));
    confianza_promedio = mean([resultados.Confianza]);
    factor_densidad = metricas.porcentaje_densidad/100;
    if num_tumores>=1 || (num_malignas>=2 && puntuacion_total>=8)
        diagnostico.clasificacion = 'ALTA SOSPECHA DE MALIGNIDAD';
        diagnostico.color = [1 0 0];
        diagnostico.recomendacion = {'• Biopsia inmediata recomendada','• Consulta urgente con oncólogo','• Estudios complementarios necesarios'};
    elseif (num_malignas>=1 && puntuacion_total>=6) || factor_densidad>0.7
        diagnostico.clasificacion = 'SOSPECHA DE MALIGNIDAD MODERADA';
        diagnostico.color = [1 0.4 0];
        diagnostico.recomendacion = {'• Evaluación oncológica prioritaria','• Mamografía de seguimiento en 1-3 meses','• Considerar estudios adicionales'};
    elseif num_malignas>=1 || puntuacion_total>=4
        diagnostico.clasificacion = 'SOSPECHA DE MALIGNIDAD';
        diagnostico.color = [1 0.7 0];
        diagnostico.recomendacion = {'• Evaluación especializada necesaria','• Seguimiento en 3-6 meses','• Monitoreo cercano recomendado'};
    else
        diagnostico.clasificacion = 'HALLAZGOS PROBABLEMENTE BENIGNOS';
        diagnostico.color = [0 0.8 0];
        diagnostico.recomendacion = {'• Seguimiento rutinario','• Revisión anual recomendada','• Mantener estilo de vida saludable'};
    end
    diagnostico.puntuacion_total = puntuacion_total;
    diagnostico.confianza = confianza_promedio;
    diagnostico.metricas = metricas;
end

%% ============================================================================
%% FUNCIONES DE VISUALIZACIÓN (9 FIGURAS)
%% ============================================================================
function fig = visualizarProcesamientoAvanzado(imagen_original, imagen_suavizada, oehc, mascara_final, mascara_adaptativa, imagen_ecualizada, num_regiones, info)
    fig = figure('Name','Figura 1 - Procesamiento Avanzado','Position',[50 50 1400 900],'Color',[0.95 0.95 0.95],'NumberTitle','off');
    subplot(2,3,1); imshow(imagen_original,[]); title('A) Imagen DICOM Original'); colorbar('southoutside');
    subplot(2,3,2); imshow(imagen_suavizada,[]); title('B) Preprocesada (Autoencoder)'); colorbar('southoutside');
    subplot(2,3,3); imshow(oehc,[]); title('C) Segmentación Top-hat'); colorbar('southoutside');
    subplot(2,3,4); imshow(mascara_final); title(sprintf('D) Máscara Final (%d regiones)',num_regiones));
    subplot(2,3,5); imshow(mascara_adaptativa); title('E) Segmentación Adaptativa');
    subplot(2,3,6); imshow(imagen_ecualizada,[]); title('F) Imagen Ecualizada'); colorbar('southoutside');
end

function fig = visualizarDensidadTexturaAvanzada(imagen_suavizada, mascara_final, mapa_densidad, metricas, modelos)
    fig = figure('Name','Figura 2 - Densidad y Textura','Position',[100 100 1400 700],'Color',[1 1 1],'NumberTitle','off');
    subplot(1,2,1); imagesc(mapa_densidad); colormap([0.9 0.9 0.9;0.7 0.9 0.7;1 0.8 0.4;1 0.4 0.4]); caxis([0 3]);
    colorbar('Ticks',[0.375 1.125 1.875 2.625],'TickLabels',{'Fondo','Graso','Intermedio','Denso'});
    axis image; title('MAPA DE DENSIDAD CUANTITATIVA');
    text(0.02,0.98,sprintf('Porcentaje denso: %.1f%%\nBI-RADS: %s', metricas.porcentaje_densidad, metricas.birads_categoria),...
        'Units','normalized','FontSize',11,'FontWeight','bold','Color',[0 0 0.5],'VerticalAlignment','top','BackgroundColor',[1 1 1 0.9]);
    subplot(1,2,2); axis off;
    rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99],'EdgeColor',[0.2 0.4 0.6],'LineWidth',2);
    text(0.5,0.9,'ANÁLISIS DE TEXTURA','FontSize',14,'FontWeight','bold','HorizontalAlignment','center','Color',[0.1 0.3 0.5]);
    text(0.1,0.7,sprintf('Entropía: %.3f\nHomogeneidad: %.3f\nAsimetría: %.3f', metricas.entropia, metricas.homogeneidad, metricas.asimetria_espacial),...
        'FontSize',12,'FontWeight','bold','Color',[0.2 0.2 0.4]);
end

function fig = visualizarModeloBiomecanicoAvanzado(imagen_suavizada, mapa_densidad, modelo, metricas)
    fig = figure('Name','Figura 3 - Modelo Biomecánico','Position',[150 50 1400 900],'Color',[1 1 1]);
    subplot(2,3,1); imagesc(mapa_densidad); title('A) Densidad + Alta Tensión'); colorbar;
    subplot(2,3,2); imagesc(modelo.tensiones.maxima); title('B) Tensiones Máximas (kPa)'); colorbar;
    subplot(2,3,3); histogram(modelo.tensiones.maxima(modelo.tensiones.maxima>0),50,'FaceColor',[0.8 0.2 0.2]); title('C) Distribución de Tensiones'); grid on;
    subplot(2,3,4); imagesc(modelo.tensiones.gradiente); title('D) Gradientes de Tensión'); colorbar;
    subplot(2,3,5); axis off; text(0.1,0.9,{'MODELO BIOMECÁNICO', '', sprintf('Glandular: %.1f kPa',modelo.propiedades.young_glandular), sprintf('Adiposo: %.1f kPa',modelo.propiedades.young_adipose)},'FontSize',10,'FontWeight','bold');
    subplot(2,3,6); surf(modelo.tensiones.maxima(1:10:end,1:10:end),'EdgeColor','none'); title('E) Superficie de Tensiones');
end

function fig = visualizarRiesgoIntegradoAvanzado(imagen_suavizada, mascara_final, mapa_densidad, modelo_biomecanico, resultados, diagnostico_integrado)
    fig = figure('Name','Figura 4 - Riesgo Integrado','Position',[200 50 1400 800],'Color',[1 1 1]);
    subplot(1,3,[1,2]); imshow(imagen_suavizada,[]); hold on;
    mascara_mama = imfill(mascara_final,'holes');
    if any(mascara_mama(:))
        cont = bwboundaries(mascara_mama);
        for k=1:length(cont), plot(cont{k}(:,2), cont{k}(:,1), 'r', 'LineWidth',2); end
    end
    title(sprintf('RIESGO: %s', diagnostico_integrado.clasificacion), 'FontSize',14,'FontWeight','bold');
    hold off;
    subplot(1,3,3); axis off;
    rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99],'EdgeColor',diagnostico_integrado.color,'LineWidth',3);
    text(0.5,0.9,'DIAGNÓSTICO','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    text(0.5,0.7,diagnostico_integrado.clasificacion,'FontSize',12,'FontWeight','bold','HorizontalAlignment','center');
    text(0.1,0.4,sprintf('Puntuación: %.1f\nConfianza: %.1f%%', diagnostico_integrado.puntuacion_total, diagnostico_integrado.confianza*100),'FontSize',11,'FontWeight','bold');
end

function fig = visualizarCorrelacionMultimodalAvanzada_v2(resultados, deformaciones, metricas, config)
    % Versión sin gscatter (no requiere toolboxes adicionales)
    fig = figure('Name','Figura 5 - Correlación Multimodal','Position',[250 50 1400 800],'Color',[1 1 1]);
    if isempty(resultados)
        text(0.5,0.5,'No hay datos para correlación','HorizontalAlignment','center');
        return;
    end
    areas = [resultados.Area]; solideces = [resultados.Solidez];
    exc = [resultados.Excentricidad]; conf = [resultados.Confianza];
    class = {resultados.Clasificacion};
    colores = zeros(length(resultados),3);
    for i = 1:length(resultados)
        switch class{i}
            case 'Maligno', colores(i,:) = [1 0 0];
            case 'Benigno', colores(i,:) = [0 0.8 0];
            case 'Tumor', colores(i,:) = [1 0.5 0];
            otherwise, colores(i,:) = [0.5 0.5 0.5];
        end
    end
    subplot(2,3,1); scatter(areas, exc, 50, colores, 'filled'); xlabel('Área'); ylabel('Excentricidad'); grid on; title('A) Área vs Excentricidad');
    subplot(2,3,2); try, boxplot(areas, class); title('B) Áreas por tipo'); grid on; catch, text(0.5,0.5,'Boxplot no disponible'); end
    subplot(2,3,3); scatter(solideces, conf, 50, colores, 'filled'); xlabel('Solidez'); ylabel('Confianza'); grid on; title('C) Solidez vs Confianza');
    subplot(2,3,4); histogram(conf, 5); title('D) Distribución Confianza'); grid on;
    subplot(2,3,5); try, imagesc(corrcoef([areas; exc; solideces; conf]')); colorbar; title('E) Matriz de Correlación'); catch, end
    subplot(2,3,6); hold on;
    tipos_unicos = unique(class);
    for k = 1:length(tipos_unicos)
        idx = strcmp(class, tipos_unicos{k});
        switch tipos_unicos{k}
            case 'Maligno', col = [1 0 0];
            case 'Benigno', col = [0 0.8 0];
            case 'Tumor', col = [1 0.5 0];
            otherwise, col = [0.5 0.5 0.5];
        end
        scatter(areas(idx), exc(idx), 50, col, 'filled', 'DisplayName', tipos_unicos{k});
    end
    xlabel('Área'); ylabel('Excentricidad'); title('F) PCA (simplificado)'); grid on; legend('Location','best'); hold off;
    sgtitle('ANÁLISIS DE CORRELACIÓN MULTIMODAL');
end

function fig6 = visualizarLesionesDetectadas(imagen_suavizada, mascara_final, resultados, etiquetas)
    fig6 = figure('Name','Figura 6 - Lesiones Detectadas','Position',[100 100 1200 800],'Color',[1 1 1]);
    imshow(imagen_suavizada,[]); hold on;
    if ~isempty(resultados)
        for i = 1:length(resultados)
            mask = (etiquetas == resultados(i).ID);
            bound = bwboundaries(mask);
            switch resultados(i).Clasificacion
                case 'Maligno', col = 'r'; lw = 3;
                case 'Benigno', col = 'g'; lw = 2;
                case 'Tumor', col = 'm'; lw = 3;
                otherwise, col = 'k'; lw = 1;
            end
            for k = 1:length(bound), plot(bound{k}(:,2), bound{k}(:,1), col, 'LineWidth', lw); end
            s = regionprops(mask,'Centroid');
            text(s.Centroid(1), s.Centroid(2), num2str(resultados(i).ID), 'Color','w','FontWeight','bold','BackgroundColor',col);
        end
    end
    title('LESIONES DETECTADAS','FontSize',14,'FontWeight','bold'); hold off;
end

function fig7 = visualizarTablaCaracteristicas(resultados)
    fig7 = figure('Name','Figura 7 - Tabla de Características','Position',[150 100 1400 600],'Color',[1 1 1]);
    if isempty(resultados), text(0.5,0.5,'Sin datos','FontSize',14); return; end
    colNames = {'ID','Área','Solidez','Excentricidad','Clasificación','Riesgo','Confianza'};
    data = cell(length(resultados),7);
    for i = 1:length(resultados)
        r = resultados(i);
        data(i,:) = {i, r.Area, r.Solidez, r.Excentricidad, r.Clasificacion, r.PuntuacionRiesgo, r.Confianza};
    end
    uitable('Data',data,'ColumnName',colNames,'Position',[50 50 1300 500],'FontSize',10);
    title('CARACTERÍSTICAS DE LESIONES');
end

function fig8 = visualizarAnalisisEstadistico(imagen_suavizada, mascara_final, resultados, etiquetas)
    fig8 = figure('Name','Figura 8 - Análisis Estadístico','Position',[200 50 1400 900],'Color',[1 1 1]);
    if isempty(resultados), text(0.5,0.5,'Sin datos','FontSize',14); return; end
    subplot(2,2,1); histogram([resultados.Area]); xlabel('Área'); title('Distribución de Áreas'); grid on;
    subplot(2,2,2); pie([sum(strcmp({resultados.Clasificacion},'Maligno')), sum(strcmp({resultados.Clasificacion},'Benigno'))], {'Maligno','Benigno'}); title('Tipos');
    subplot(2,2,3); scatter([resultados.Solidez],[resultados.Excentricidad],40,'filled'); xlabel('Solidez'); ylabel('Excentricidad'); grid on; title('Forma');
    subplot(2,2,4); boxplot([resultados.Confianza],{resultados.Clasificacion}); title('Confianza por tipo'); grid on;
end

function fig9 = visualizarResumenClinico(resultados, diagnostico, recomendacion, puntuacion_total)
    fig9 = figure('Name','Figura 9 - Resumen Clínico','Position',[250 100 1400 900],'Color',[1 1 1]);
    subplot(2,2,1); axis off;
    rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.98 0.98 0.99],'EdgeColor',[0.2 0.4 0.6],'LineWidth',3);
    text(0.5,0.9,'DIAGNÓSTICO','FontSize',16,'FontWeight','bold','HorizontalAlignment','center');
    text(0.5,0.7,diagnostico,'FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    text(0.5,0.4,sprintf('Puntuación total: %.1f',puntuacion_total),'FontSize',12,'HorizontalAlignment','center');
    subplot(2,2,2); axis off;
    rectangle('Position',[0.05 0.05 0.9 0.9],'FaceColor',[0.97 0.98 0.95],'EdgeColor',[0.3 0.6 0.3],'LineWidth',2);
    text(0.5,0.9,'RECOMENDACIONES','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    for i = 1:length(recomendacion)
        text(0.1,0.7-(i-1)*0.1,recomendacion{i},'FontSize',11,'FontWeight','bold');
    end
    subplot(2,2,3); axis off; text(0.5,0.5,'ESTADÍSTICAS','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
    subplot(2,2,4); axis off; text(0.5,0.5,'CONCLUSIÓN','FontSize',14,'FontWeight','bold','HorizontalAlignment','center');
end

%% ============================================================================
%% FUNCIÓN DE EXPORTACIÓN (CORREGIDA: maneja componentes UI)
%% ============================================================================
function exportarResultados(archivoDICOM, resultados, diagnostico, metricas, modelo, figHandles)
    [carpeta, nombre, ~] = fileparts(archivoDICOM);
    carpetaRes = fullfile(carpeta, [nombre '_Resultados']);
    if ~exist(carpetaRes, 'dir'), mkdir(carpetaRes); end
    
    % Guardar figuras (manejo de componentes UI como uitable)
    if ~isempty(figHandles)
        for i = 1:length(figHandles)
            if ishandle(figHandles(i))
                nombreFig = fullfile(carpetaRes, sprintf('Figura_%d.png', i));
                
                % --- Ocultar componentes UI si los hay ---
                uiHandles = findall(figHandles(i), 'Type', 'uicontrol');
                uiHandles = [uiHandles; findall(figHandles(i), 'Type', 'uitable')];
                if ~isempty(uiHandles)
                    set(uiHandles, 'Visible', 'off');
                    drawnow;
                end
                
                try
                    print(figHandles(i), nombreFig, '-dpng', '-r300');
                catch
                    saveas(figHandles(i), nombreFig);
                end
                
                % --- Restaurar visibilidad ---
                if ~isempty(uiHandles)
                    set(uiHandles, 'Visible', 'on');
                    drawnow;
                end
            end
        end
    end
    
    % Informe TXT
    fid = fopen(fullfile(carpetaRes, 'Informe.txt'), 'w');
    fprintf(fid, 'INFORME DE ANÁLISIS MAMARIO\n');
    fprintf(fid, 'Archivo: %s\nFecha: %s\n\n', archivoDICOM, datestr(now));
    fprintf(fid, 'DENSIDAD: %.1f%% (BI-RADS %s)\n', metricas.porcentaje_densidad, metricas.birads_categoria);
    fprintf(fid, 'LESIONES DETECTADAS: %d\n', length(resultados));
    if ~isempty(resultados)
        for i=1:length(resultados)
            fprintf(fid, '  %d: %s | Riesgo: %.1f | Confianza: %.1f%%\n', i, resultados(i).Clasificacion, resultados(i).PuntuacionRiesgo, resultados(i).Confianza*100);
        end
    end
    fprintf(fid, 'DIAGNÓSTICO: %s\n', diagnostico.clasificacion);
    fprintf(fid, 'RECOMENDACIONES:\n');
    for j=1:length(diagnostico.recomendacion)
        fprintf(fid, '  - %s\n', diagnostico.recomendacion{j});
    end
    fclose(fid);
    
    % Datos .mat y CSV
    save(fullfile(carpetaRes, 'Datos.mat'), 'resultados', 'diagnostico', 'metricas', 'modelo');
    if ~isempty(resultados)
        tbl = struct2table(resultados);
        writetable(tbl, fullfile(carpetaRes, 'Lesiones.csv'));
    end
    fprintf('Resultados exportados en: %s\n', carpetaRes);
end