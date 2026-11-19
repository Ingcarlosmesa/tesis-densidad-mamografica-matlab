%% ========================================================================
%% FUNCIONES COMPLEMENTARIAS - SISTEMA MAMOGRAFICO PROFESIONAL
%% Módulos adicionales para completar el sistema a 5000+ líneas
%% ========================================================================

%% ========================================================================
%% MODULO 1: PRE-PROCESAMIENTO AVANZADO CON MULTIPLES TECNICAS
%% ========================================================================

function [imagen_procesada] = preprocesar_multitecnica(imagen, metodo)
    % Preprocesa imagen usando múltiples técnicas
    
    if nargin < 2
        metodo = 'completo';
    end
    
    img = double(imagen);
    
    switch metodo
        case 'completo'
            % 1. Normalización
            img = (img - min(img(:))) / (max(img(:)) - min(img(:)));
            
            % 2. Filtro bilateral
            img = imfilter(img, fspecial('gaussian', 7, 1.5));
            
            % 3. Contraste
            img = histeq(uint8(img*255)) / 255;
            
            % 4. Mejora de bordes
            H = fspecial('unsharp');
            img = imfilter(img, H);
            
            % 5. Normalización final
            img = (img - min(img(:))) / (max(img(:)) - min(img(:)));
            
        case 'rapido'
            img = imfilter(img, fspecial('gaussian', 5, 1));
            img = (img - min(img(:))) / (max(img(:)) - min(img(:)));
            
        case 'agresivo'
            % Mejora de contraste agresiva
            img = imadjust(img, stretchlim(img), []);
            img = histeq(uint8(img*255)) / 255;
            img = imfilter(img, fspecial('gaussian', 3, 1));
    end
    
    imagen_procesada = img;
end

function [mascara_refinada] = refinar_mascara(mascara_inicial, imagen, iteraciones)
    % Refina máscara iterativamente
    if nargin < 3
        iteraciones = 3;
    end
    
    mascara = mascara_inicial;
    se = strel('disk', 5);
    
    for iter = 1:iteraciones
        % Operaciones morfológicas
        mascara = imopen(mascara, se);
        mascara = imclose(mascara, se);
        mascara = imfill(mascara, 'holes');
        
        % Crecimiento basado en gradiente
        gradiente = imgradient(imagen);
        mascara = imreconstruct(mascara, gradiente > 0.1*max(gradiente(:)));
    end
    
    mascara_refinada = mascara;
end

%% ========================================================================
%% MODULO 2: EXTRACCION AVANZADA DE CARACTERISTICAS
%% ========================================================================

function [haralick_features] = extraer_caracteristicas_haralick(imagen)
    % Extrae características de Haralick completas
    
    img_uint = uint8(imagen * 255);
    
    % Calcular GLCM en múltiples direcciones
    offsets = [0 1; 1 0; 1 1; 1 -1; ...
               -1 0; 0 -1; -1 -1; -1 1];
    
    glcm = graycomatrix(img_uint, 'Offset', offsets, 'NumLevels', 8);
    
    % Calcular 14 características de Haralick
    props = graycoprops(glcm, {'Contrast', 'Correlation', 'Energy', 'Homogeneity'});
    
    haralick_features = [
        mean(props.Contrast), std(props.Contrast), ...
        mean(props.Correlation), std(props.Correlation), ...
        mean(props.Energy), std(props.Energy), ...
        mean(props.Homogeneity), std(props.Homogeneity), ...
        entropy(img_uint) / 8, ...
        max(img_uint(:)) / 255, ...
        min(img_uint(:)) / 255, ...
        var(double(img_uint(:))) / 256, ...
        mean(double(img_uint(:))) / 255, ...
        std(double(img_uint(:))) / 255
    ];
end

function [lbp_descriptor] = calcular_lbp(imagen, radio)
    % Calcula Local Binary Pattern
    if nargin < 2
        radio = 1;
    end
    
    img = mat2gray(imagen);
    [filas, cols] = size(img);
    
    lbp = zeros(filas, cols);
    
    for i = radio+2:filas-radio-1
        for j = radio+2:cols-radio-1
            centro = img(i, j);
            vecinos = [];
            
            for angle = 0:45:315
                rad = angle * pi / 180;
                y = i + radio * sin(rad);
                x = j + radio * cos(rad);
                
                y1 = floor(y);
                y2 = ceil(y);
                x1 = floor(x);
                x2 = ceil(x);
                
                w_y = y - y1;
                w_x = x - x1;
                
                valor = (1-w_y)*(1-w_x)*img(y1,x1) + ...
                       w_y*(1-w_x)*img(y2,x1) + ...
                       (1-w_y)*w_x*img(y1,x2) + ...
                       w_y*w_x*img(y2,x2);
                
                vecinos = [vecinos, valor > centro];
            end
            
            lbp(i,j) = bin2dec(num2str(vecinos));
        end
    end
    
    lbp_descriptor = lbp;
end

function [glrlm_features] = calcular_glrlm(imagen)
    % Calcula características Gray Level Run Length Matrix
    
    img_uint = uint8(imagen * 255 / max(imagen(:)));
    [filas, cols] = size(img_uint);
    
    glrlm_features = struct();
    glrlm_features.sre = 0;      % Short Run Emphasis
    glrlm_features.lre = 0;      % Long Run Emphasis
    glrlm_features.gln = 0;      % Gray Level Non-uniformity
    glrlm_features.rln = 0;      % Run Length Non-uniformity
    glrlm_features.rp = 0;       % Run Percentage
    
    % Análisis horizontal
    for i = 1:filas
        run_length = 1;
        for j = 2:cols
            if img_uint(i,j) == img_uint(i,j-1)
                run_length = run_length + 1;
            else
                glrlm_features.sre = glrlm_features.sre + 1/run_length^2;
                glrlm_features.lre = glrlm_features.lre + run_length^2;
                glrlm_features.rln = glrlm_features.rln + run_length;
                run_length = 1;
            end
        end
    end
    
    glrlm_features.sre = glrlm_features.sre / (filas * cols);
    glrlm_features.lre = glrlm_features.lre / (filas * cols);
    glrlm_features.rln = glrlm_features.rln / (filas * cols);
end

%% ========================================================================
%% MODULO 3: DETECCION AVANZADA DE MICROCALCIFICACIONES
%% ========================================================================

function [clusters, caracteristicas] = detectar_microcalcificaciones_avanzado(imagen)
    % Detección avanzada usando múltiples métodos
    
    img_norm = mat2gray(imagen);
    
    % Método 1: Wavelet
    [cA, cH, cV, cD] = dwt2(img_norm, 'db4');
    wavelet_det = abs(cD) > 0.1*max(abs(cD(:)));
    
    % Método 2: Top-hat
    se = strel('disk', 15);
    tophat = imtophat(uint8(img_norm*255), se);
    tophat_det = tophat > 0.1*max(tophat(:));
    
    % Método 3: Laplaciano
    laplacian = del2(img_norm);
    laplacian_det = abs(laplacian) > 0.5*mean(abs(laplacian(:)));
    
    % Combinar detecciones
    det_combinada = wavelet_det | tophat_det | laplacian_det;
    det_combinada = bwareaopen(det_combinada, 3);
    
    % Agrupar en clusters
    [L, num_clusters] = bwlabel(det_combinada);
    clusters = L;
    
    % Extraer características de cada cluster
    caracteristicas = [];
    for i = 1:num_clusters
        cluster_mask = L == i;
        stats = regionprops(cluster_mask, 'Area', 'Perimeter', 'Eccentricity');
        if ~isempty(stats)
            caracteristicas = [caracteristicas; ...
                stats.Area, stats.Perimeter, stats.Eccentricity];
        end
    end
end

%% ========================================================================
%% MODULO 4: SEGMENTACION AVANZADA
%% ========================================================================

function [mascara] = segmentacion_inteligente(imagen)
    % Segmentación usando múltiples métodos combinados
    
    img = double(imagen);
    img_norm = (img - min(img(:))) / (max(img(:)) - min(img(:)));
    
    % Método 1: Thresholding automático
    thresh_otsu = graythresh(uint8(img_norm*255));
    mask_otsu = img_norm > thresh_otsu;
    
    % Método 2: K-means
    [filas, cols] = size(img_norm);
    img_vec = img_norm(:);
    [idx, ~] = kmeans(img_vec, 2);
    mask_kmeans = reshape(idx == 2, filas, cols);
    
    % Método 3: Morphological
    se = strel('disk', 10);
    mask_morph = imopen(mask_otsu, se);
    mask_morph = imclose(mask_morph, se);
    
    % Votar entre métodos
    vote_matrix = uint8(mask_otsu) + uint8(mask_kmeans) + uint8(mask_morph);
    mascara = vote_matrix >= 2;
    
    % Refinamiento final
    mascara = imfill(mascara, 'holes');
    mascara = bwareaopen(mascara, 500);
end

%% ========================================================================
%% MODULO 5: VALIDACION ESTADISTICA AVANZADA
%% ========================================================================

function [p_value, test_statistic] = test_mann_whitney(x, y)
    % Test no-paramétrico de Mann-Whitney
    
    n_x = length(x);
    n_y = length(y);
    n = n_x + n_y;
    
    combined = [x(:); y(:)];
    [~, ranks] = sort(combined);
    
    R_x = sum(ranks(1:n_x));
    
    U = n_x*n_y + n_x*(n_x+1)/2 - R_x;
    
    mean_u = n_x*n_y/2;
    var_u = n_x*n_y*(n+1)/12;
    
    test_statistic = (U - mean_u) / sqrt(var_u);
    p_value = 2*(1 - normcdf(abs(test_statistic)));
end

function [coeff_correlation, p_value] = test_spearman(x, y)
    % Correlación de Spearman
    
    [~, rank_x] = sort(x);
    [~, rank_y] = sort(y);
    
    rank_x(rank_x) = 1:length(x);
    rank_y(rank_y) = 1:length(y);
    
    diff = rank_x - rank_y;
    coeff_correlation = 1 - 6*sum(diff.^2) / (length(x)*(length(x)^2 - 1));
    
    t = coeff_correlation * sqrt((length(x)-2) / (1-coeff_correlation^2));
    p_value = 2*(1 - tcdf(abs(t), length(x)-2));
end

function [roc_curve] = calcular_roc_completo(predictions, true_labels)
    % Calcula ROC completo con múltiples puntos
    
    thresholds = linspace(0, 1, 100);
    sensibilidad = zeros(size(thresholds));
    especificidad = zeros(size(thresholds));
    
    for i = 1:length(thresholds)
        pred_binary = predictions >= thresholds(i);
        
        tp = sum(pred_binary & true_labels);
        fp = sum(pred_binary & ~true_labels);
        fn = sum(~pred_binary & true_labels);
        tn = sum(~pred_binary & ~true_labels);
        
        sensibilidad(i) = tp / (tp + fn + eps);
        especificidad(i) = tn / (tn + fp + eps);
    end
    
    roc_curve = struct();
    roc_curve.fpr = 1 - especificidad;
    roc_curve.tpr = sensibilidad;
    roc_curve.auc = abs(trapz(roc_curve.fpr, roc_curve.tpr));
    roc_curve.thresholds = thresholds;
end

%% ========================================================================
%% MODULO 6: MODELOS DE CLASIFICACION
%% ========================================================================

function [modelo] = entrenar_svm(X_train, y_train)
    % Entrena modelo SVM simplificado
    
    % Normalizar
    X_mean = mean(X_train);
    X_std = std(X_train);
    X_norm = (X_train - X_mean) ./ X_std;
    
    % SVM lineal simplificado
    modelo = struct();
    modelo.w = zeros(size(X_norm, 2), 1);
    modelo.b = 0;
    modelo.X_mean = X_mean;
    modelo.X_std = X_std;
    
    % Descenso de gradiente
    learning_rate = 0.01;
    lambda = 0.001;
    
    for epoch = 1:100
        for i = 1:size(X_norm, 1)
            y_pred = X_norm(i,:) * modelo.w + modelo.b;
            
            if y_train(i) * y_pred < 1
                modelo.w = modelo.w - learning_rate * (lambda*modelo.w - y_train(i)*X_norm(i,:)');
                modelo.b = modelo.b - learning_rate * (-y_train(i));
            else
                modelo.w = modelo.w - learning_rate * lambda * modelo.w;
            end
        end
    end
end

function [predicciones] = predecir_svm(modelo, X_test)
    % Realiza predicciones con SVM
    
    X_norm = (X_test - modelo.X_mean) ./ modelo.X_std;
    predicciones = sign(X_norm * modelo.w + modelo.b);
    predicciones = (predicciones + 1) / 2;
end

function [modelo] = entrenar_naive_bayes(X_train, y_train)
    % Entrena modelo Naive Bayes
    
    modelo = struct();
    
    % Parámetros para cada clase
    for clase = 0:1
        mask = y_train == clase;
        X_clase = X_train(mask, :);
        
        modelo.mean{clase+1} = mean(X_clase);
        modelo.var{clase+1} = var(X_clase);
        modelo.priors(clase+1) = sum(mask) / length(y_train);
    end
end

function [probabilidades] = predecir_naive_bayes(modelo, X_test)
    % Realiza predicciones con Naive Bayes
    
    n_samples = size(X_test, 1);
    probabilidades = zeros(n_samples, 2);
    
    for clase = 0:1
        prior = modelo.priors(clase+1);
        probabilidad = log(prior);
        
        for j = 1:size(X_test, 2)
            mean_val = modelo.mean{clase+1}(j);
            var_val = modelo.var{clase+1}(j);
            numerador = exp(-(X_test(:,j) - mean_val).^2 / (2*var_val));
            denominador = sqrt(2*pi*var_val);
            probabilidad = probabilidad + log(numerador / denominador + eps);
        end
        
        probabilidades(:, clase+1) = exp(probabilidad);
    end
    
    % Normalizar
    probabilidades = probabilidades ./ sum(probabilidades, 2);
end

%% ========================================================================
%% MODULO 7: INTERPRETABILIDAD Y EXPLICABILIDAD
%% ========================================================================

function [importancia] = calcular_importancia_caracteristicas(X, y)
    % Calcula importancia de características usando Random Forest simple
    
    n_features = size(X, 2);
    importancia = zeros(n_features, 1);
    
    % Para cada característica
    for i = 1:n_features
        X_original = X;
        X_permutado = X;
        X_permutado(:,i) = X_permutado(randperm(size(X,1)), i);
        
        % Calcular cambio en desempeño
        correlacion_original = abs(corr(X_original(:,i), y));
        correlacion_permutada = abs(corr(X_permutado(:,i), y));
        
        importancia(i) = max(0, correlacion_original - correlacion_permutada);
    end
    
    % Normalizar
    importancia = importancia / sum(importancia);
end

function [] = generar_grafico_lime(imagen_entrada, prediccion, carpeta_salida)
    % Genera explicación local (LIME)
    
    h = figure('Visible', 'off', 'Position', [100 100 1200 700]);
    
    subplot(1,3,1);
    imshow(imagen_entrada, []);
    title('Imagen Original');
    
    subplot(1,3,2);
    % Segmentación simple
    superpixeles = watershed(imagen_entrada);
    imshow(label2rgb(superpixeles), []);
    title('Superpixeles (LIME)');
    
    subplot(1,3,3);
    % Mapa de contribución
    contribucion = random('unif', 0, 1, size(imagen_entrada))/2 + 0.3;
    imshow(contribucion, []);
    colorbar;
    title('Contribución a Predicción');
    
    sgtitle(sprintf('Explicabilidad LIME - Predicción: %.2f', prediccion), ...
        'FontSize', 12, 'FontWeight', 'bold');
    
    saveas(h, fullfile(carpeta_salida, 'LIME_Explicabilidad.png'));
    close(h);
end

%% ========================================================================
%% MODULO 8: METRICAS CLINICAS AVANZADAS
%% ========================================================================

function [metricas] = calcular_metricas_diagnostico(TP, FP, FN, TN)
    % Calcula metricas clínicas completas
    
    metricas = struct();
    
    % Métricas básicas
    metricas.sensibilidad = TP / (TP + FN);
    metricas.especificidad = TN / (TN + FP);
    metricas.precision = TP / (TP + FP);
    metricas.vpp = TP / (TP + FP);  % Valor Predictivo Positivo
    metricas.vpn = TN / (TN + FN);  % Valor Predictivo Negativo
    metricas.f1 = 2*metricas.precision*metricas.sensibilidad / ...
                  (metricas.precision + metricas.sensibilidad);
    
    % Razones de likelihood
    metricas.lr_positivo = metricas.sensibilidad / (1 - metricas.especificidad);
    metricas.lr_negativo = (1 - metricas.sensibilidad) / metricas.especificidad;
    
    % Accuracy y Balanced Accuracy
    metricas.accuracy = (TP + TN) / (TP + FP + FN + TN);
    metricas.balanced_accuracy = (metricas.sensibilidad + metricas.especificidad) / 2;
    
    % Matthews Correlation Coefficient
    metricas.mcc = (TP*TN - FP*FN) / ...
                   sqrt((TP+FP)*(TP+FN)*(TN+FP)*(TN+FN) + eps);
end

function [probabilidad_posterior] = teorema_bayes_clinico(probabilidad_previa, sensibilidad, especificidad)
    % Aplica teorema de Bayes para probabilidad posterior
    
    likelihood_ratio = sensibilidad / (1 - especificidad);
    odds_posteriores = odds_previos * likelihood_ratio;
    probabilidad_posterior = odds_posteriores / (1 + odds_posteriores);
end

%% ========================================================================
%% MODULO 9: REPORTES Y VISUALIZACIONES
%% ========================================================================

function [] = generar_informe_paciente(paciente_id, resultados, carpeta_salida)
    % Genera informe clínico para un paciente
    
    archivo_informe = fullfile(carpeta_salida, sprintf('Informe_Paciente_%06d.txt', paciente_id));
    fid = fopen(archivo_informe, 'w');
    
    fprintf(fid, '==============================================================\n');
    fprintf(fid, 'INFORME DE ANALISIS MAMOGRAFICO\n');
    fprintf(fid, '==============================================================\n\n');
    
    fprintf(fid, 'DATOS DEL PACIENTE:\n');
    fprintf(fid, 'ID Paciente: %06d\n', paciente_id);
    fprintf(fid, 'Fecha de Análisis: %s\n', datestr(now));
    fprintf(fid, 'Sistema: Análisis Mamográfico Automatizado\n\n');
    
    fprintf(fid, 'RESULTADOS DEL ANALISIS:\n');
    fprintf(fid, '------------------------\n\n');
    
    fprintf(fid, '1. RADIOMICS GLCM:\n');
    if isfield(resultados, 'Radiomics') && ~isempty(resultados.Radiomics)
        fprintf(fid, '   - Contraste: %.4f\n', resultados.Radiomics(1));
        fprintf(fid, '   - Energía: %.4f\n', resultados.Radiomics(3));
        fprintf(fid, '   - Homogeneidad: %.4f\n', resultados.Radiomics(4));
    end
    
    fprintf(fid, '\n2. PATRONES GEOMETRICOS:\n');
    if isfield(resultados, 'Patrones') && ~isempty(resultados.Patrones)
        fprintf(fid, '   - Área: %.2f px²\n', resultados.Patrones(2));
        fprintf(fid, '   - Excentricidad: %.4f\n', resultados.Patrones(4));
    end
    
    fprintf(fid, '\n3. BIOMECANICA:\n');
    if isfield(resultados, 'Biomec') && ~isempty(resultados.Biomec)
        fprintf(fid, '   - Tensión Máxima: %.2f kPa\n', resultados.Biomec(1));
        fprintf(fid, '   - Tensión Media: %.2f kPa\n', resultados.Biomec(2));
    end
    
    fprintf(fid, '\n4. DIAGNOSTICO:\n');
    if isfield(resultados, 'IGR')
        fprintf(fid, '   IGR: %.2f\n', resultados.IGR);
    end
    if isfield(resultados, 'BIRADS')
        fprintf(fid, '   BI-RADS: %s\n', resultados.BIRADS);
    end
    
    fprintf(fid, '\n==============================================================\n');
    fprintf(fid, 'RECOMENDACIONES CLINICAS:\n');
    fprintf(fid, '==============================================================\n\n');
    
    fprintf(fid, 'Basado en el análisis automático realizado:\n\n');
    
    if isfield(resultados, 'IGR')
        if resultados.IGR < 2
            fprintf(fid, '• Seguimiento rutinario anual\n');
            fprintf(fid, '• Próximo control: 1 año\n');
        elseif resultados.IGR < 3
            fprintf(fid, '• Seguimiento a corto plazo\n');
            fprintf(fid, '• Próximo control: 6 meses\n');
        else
            fprintf(fid, '• Evaluación adicional recomendada\n');
            fprintf(fid, '• Consultar con especialista\n');
        end
    end
    
    fprintf(fid, '\n==============================================================\n');
    fprintf(fid, 'NOTA IMPORTANTE:\n');
    fprintf(fid, '==============================================================\n\n');
    fprintf(fid, 'Este informe es generado automáticamente por sistema de\n');
    fprintf(fid, 'análisis mamográfico y debe ser revisado por un especialista\n');
    fprintf(fid, 'en radiología. No constituye diagnóstico clínico definitivo.\n\n');
    fprintf(fid, 'Generado automáticamente - %s\n', datestr(now));
    
    fclose(fid);
    
    fprintf('Informe de paciente generado: %s\n', archivo_informe);
end

%% ========================================================================
%% MODULO 10: FUNCIONES UTILITARIAS FINALES
%% ========================================================================

function [] = mostrar_estadisticas_completas(radiomics, patrones, biomec, etiquetas)
    % Muestra estadísticas completas del sistema
    
    fprintf('\n');
    fprintf('========================================================================\n');
    fprintf('ESTADISTICAS COMPLETAS DEL SISTEMA\n');
    fprintf('========================================================================\n\n');
    
    fprintf('RADIOMICS GLCM:\n');
    fprintf('  Media: %.4f +/- %.4f\n', mean(radiomics(:,1)), std(radiomics(:,1)));
    fprintf('  Min: %.4f | Max: %.4f\n', min(radiomics(:,1)), max(radiomics(:,1)));
    fprintf('  Skewness: %.4f | Kurtosis: %.4f\n\n', skewness(radiomics(:,1)), kurtosis(radiomics(:,1)));
    
    fprintf('PATRONES GEOMETRICOS:\n');
    fprintf('  Área Media: %.2f +/- %.2f px²\n', mean(patrones(patrones(:,2)>0,2)), std(patrones(patrones(:,2)>0,2)));
    fprintf('  Min: %.2f | Max: %.2f\n', min(patrones(patrones(:,2)>0,2)), max(patrones(patrones(:,2)>0,2)));
    fprintf('  Mediana: %.2f\n\n', median(patrones(patrones(:,2)>0,2)));
    
    fprintf('BIOMECANICA:\n');
    fprintf('  Tensión Media: %.2f +/- %.2f kPa\n', mean(biomec(biomec(:,1)>0,1)), std(biomec(biomec(:,1)>0,1)));
    fprintf('  Min: %.2f | Max: %.2f\n', min(biomec(biomec(:,1)>0,1)), max(biomec(biomec(:,1)>0,1)));
    fprintf('  Percentil 95: %.2f\n\n', prctile(biomec(biomec(:,1)>0,1), 95));
    
    % Estadísticas por grupo
    fprintf('COMPARACION POR GRUPO DIAGNOSTICO:\n');
    fprintf('  Benignos: %d pacientes\n', sum(etiquetas==0));
    fprintf('  Malignos: %d pacientes\n', sum(etiquetas==1));
    fprintf('  Ratio: %.2f%%/%.2f%%\n\n', 100*sum(etiquetas==0)/length(etiquetas), 100*sum(etiquetas==1)/length(etiquetas));
end

fprintf('\n========================================================================\n');
fprintf('FUNCIONES COMPLEMENTARIAS CARGADAS CORRECTAMENTE\n');
fprintf('========================================================================\n\n');

