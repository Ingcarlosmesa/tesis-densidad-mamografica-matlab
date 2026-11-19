%% ═══════════════════════════════════════════════════════════════════════════
%  CARACTERIZACIÓN DE LA DENSIDAD MAMOGRÁFICA EN MUJERES 
%  A PARTIR DEL RECONOCIMIENTO DE PATRONES GEOMÉTRICOS
%  
%  Sistema Integrado Final - 25 FIGURAS - Análisis Matemático Completo
%  Universidad ECCI - Maestría en Ingeniería
%  Autor: Carlos Eduardo Mesa Mesa
% ═══════════════════════════════════════════════════════════════════════════

clear all; close all; clc;
warning off all;

%% ENCABEZADO Y CONFIGURACIÓN
fprintf('\n╔═══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║  CARACTERIZACIÓN DE LA DENSIDAD MAMOGRÁFICA EN MUJERES                ║\n');
fprintf('║  A PARTIR DEL RECONOCIMIENTO DE PATRONES GEOMÉTRICOS                  ║\n');
fprintf('║  Sistema Integrado Final - 25 Figuras - Universidad ECCI 2026         ║\n');
fprintf('╚═══════════════════════════════════════════════════════════════════════╝\n\n');

config = struct();
modo = input('Modo (1=Interactivo, 2=Batch): ');
if modo == 2
    carpeta = uigetdir(pwd, 'Carpeta con DICOM');
    if carpeta == 0, disp('Cancelado.'); return; end
    archivos = [dir(fullfile(carpeta, '*.dcm')); dir(fullfile(carpeta, '*.dicom'))];
    if isempty(archivos), disp('No hay DICOM.'); return; end
    listaArchivos = fullfile(carpeta, {archivos.name});
else
    listaArchivos = {};
end

config.umbral_area_minima = 1000;
config.realce = 0.6; config.umbralbin_tophat = 0.15; config.r_tophat = 30;
config.biomec.young_glandular = 15.1; config.biomec.young_adipose = 4.46;
config.biomec.compression_factor = 0.7;
config.export.dpi = 300;
config.export.carpeta = 'Resultados_Tesis_25_Figuras';

%% PROCESAMIENTO
if modo == 1
    [archivo, dirname] = uigetfile({'*.dcm;*.dicom','DICOM Files'});
    if isequal(archivo,0), return; end
    archivo = fullfile(dirname, archivo);
    [res, diag, met, pat, biomec, figs] = procesarMamografia25(archivo, config, true);
    opcion = questdlg('¿Exportar resultados (25 figuras, informe)?','Exportar','Sí','No','Sí');
    if strcmp(opcion,'Sí')
        exportar25(archivo, res, diag, met, pat, biomec, figs, config);
    end
    for h=figs, if ishandle(h), close(h); end; end
else
    fprintf('Procesando %d archivos en lote...\n', length(listaArchivos));
    for i=1:length(listaArchivos)
        fprintf('[%d/%d] %s\n', i, length(listaArchivos), listaArchivos{i});
        try
            [res, diag, met, pat, biomec, ~] = procesarMamografia25(listaArchivos{i}, config, false);
            exportar25(listaArchivos{i}, res, diag, met, pat, biomec, [], config);
            fprintf('   ✓ Exportado\n');
        catch ME, fprintf('   ✗ Error: %s\n', ME.message); end
    end
end
fprintf('\n✓ Sistema finalizado\n');

%% ============================================================================
%% FUNCIÓN PRINCIPAL - PROCESAMIENTO Y 25 FIGURAS
%% ============================================================================
function [resultados, diagnostico, metricas, patrones, biomecanica, figHandles] = ...
    procesarMamografia25(archivoDICOM, config, visible)

    figHandles = [];
    % ---- 1. CARGA Y NORMALIZACIÓN DICOM ----
    info = dicominfo(archivoDICOM);
    vol = dicomread(archivoDICOM);
    if ndims(vol)>2 && size(vol,3)>1
        img = vol(:,:,round(size(vol,3)/2));
    else
        img = vol;
    end
    if isfield(info,'RescaleSlope')
        img = single(img) * info.RescaleSlope + info.RescaleIntercept;
    end
    if isfield(info,'WindowCenter')
        wc = double(info.WindowCenter(1)); ww = double(info.WindowWidth(1));
        img = uint8(255 * mat2gray(img, [wc-ww/2, wc+ww/2]));
    else
        p2 = prctile(img(:),2); p98 = prctile(img(:),98);
        img = uint8(255 * mat2gray(img, [p2,p98]));
    end
    if size(img,3)==3, img = rgb2gray(img); end

    % ---- 2. PREPROCESAMIENTO ----
    img_filt = medfilt2(img, [7,7], 'symmetric');
    img_contr = imadjust(img_filt, stretchlim(img_filt), []);
    img_clahe = adapthisteq(img_contr);
    img_suave = imgaussfilt(img_clahe, 2);

    % ---- 3. SEGMENTACIÓN HÍBRIDA ----
    masc_adapt = imbinarize(img_suave, 'adaptive', 'Sensitivity', 0.55);
    itoh = uint8(min(double(img_suave)*6, 255));
    se = strel('disk', config.r_tophat);
    otoh = imtophat(itoh, se);
    oehc = imadjust(otoh, [0 config.realce], [0 1]);
    masc_top = imbinarize(oehc, config.umbralbin_tophat);
    masc_comb = masc_adapt | masc_top;
    ee = strel('disk', 6);
    masc_limpia = imclose(imopen(masc_comb, ee), ee);
    masc_final = bwareaopen(masc_limpia, config.umbral_area_minima);
    masc_final = imfill(masc_final, 'holes');

    % ---- 4. ANÁLISIS DE DENSIDAD (BI-RADS) ----
    img_mama = img_suave .* uint8(masc_final);
    p25 = prctile(img_mama(masc_final),25); p50 = prctile(img_mama(masc_final),50); p75 = prctile(img_mama(masc_final),75);
    mapa_dens = ones(size(img_suave));
    mapa_dens(img_mama>p25 & img_mama<=p50) = 2;
    mapa_dens(img_mama>p50 & img_mama<=p75) = 3;
    mapa_dens(img_mama>p75) = 4;
    mapa_dens(~masc_final) = 0;
    pct_dens = 100 * sum(mapa_dens(masc_final)>=3) / sum(masc_final(:));
    if pct_dens < 25, birads = 'a'; elseif pct_dens < 50, birads = 'b'; elseif pct_dens < 75, birads = 'c'; else birads = 'd'; end

    % ---- 5. PATRONES GEOMÉTRICOS AVANZADOS (CORREGIDO) ----
    patrones = calcularPatronesGeometricos(img_suave, masc_final, mapa_dens);

    % ---- 6. RADIOMICS COMPLETA ----
    radiomics = calcularRadiomicsCompleta(img_suave, masc_final);

    % ---- 7. MICROCALCIFICACIONES (Wavelet) ----
    micro = detectarMicrocalcWavelet(img_suave);

    % ---- 8. DETECCIÓN Y CLASIFICACIÓN DE LESIONES ----
    [etiquetas, numR] = bwlabel(masc_final);
    resultados = [];
    if numR > 0
        props = regionprops(etiquetas, img_suave, 'Area','Perimeter','Eccentricity','Solidity','MajorAxisLength');
        for i=1:min(numR,50)
            if props(i).Area < 50, continue; end
            comp = props(i).Perimeter^2 / (4*pi*props(i).Area);
            if props(i).Solidity > 0.85 && props(i).Eccentricity < 0.6 && comp < 1.5
                clasi = 'Benigno'; prob = 0.85; risk = 1;
            elseif props(i).Eccentricity > 0.7 && comp > 1.8
                clasi = 'Maligno'; prob = 0.80; risk = 8;
            else
                clasi = 'Indeterminado'; prob = 0.65; risk = 5;
            end
            lesion = struct('ID',i,'Area',props(i).Area,'Diametro',props(i).MajorAxisLength,...
                'Excentricidad',props(i).Eccentricity,'Solidez',props(i).Solidity,'Compacidad',comp,...
                'Clasificacion',clasi,'PuntuacionRiesgo',risk,'Confianza',prob);
            resultados = [resultados; lesion];
        end
    end

    % ---- 9. MODELADO BIOMECÁNICO ----
    [ny,nx] = size(mapa_dens);
    [X,Y] = meshgrid(1:nx,1:ny);
    E = config.biomec.young_adipose * ones(ny,nx);
    E(mapa_dens >= 3) = config.biomec.young_glandular;
    dist = sqrt((X-nx/2).^2 + (Y-ny/2).^2);
    max_dist = max(dist(:));
    factor_comp = 1 - config.biomec.compression_factor * (dist / max_dist);
    tension = E .* (1 - factor_comp);
    biomecanica = struct('tensiones',tension,'deformaciones',1-factor_comp);

    % ---- 10. RIESGO INTEGRADO Y DIAGNÓSTICO ----
    factor_dens = min(pct_dens/25,4)/4;
    factor_micro = min(micro.numero/10,1);
    factor_stress = min(max(tension(:))/15,1);
    riesgo = (factor_dens*0.3 + factor_micro*0.35 + factor_stress*0.35) * 10;
    riesgo = min(max(riesgo,0),10);
    if riesgo < 2, probBIRADS = [0.7,0.2,0.07,0.02,0.01,0];
    elseif riesgo < 4, probBIRADS = [0.3,0.5,0.15,0.04,0.01,0];
    elseif riesgo < 6, probBIRADS = [0.1,0.2,0.5,0.15,0.04,0.01];
    elseif riesgo < 8, probBIRADS = [0.05,0.1,0.2,0.5,0.1,0.05];
    else probBIRADS = [0.02,0.05,0.1,0.3,0.4,0.13]; end
    [~,catFinal] = max(probBIRADS); catFinal = catFinal-1;
    diagnostico = struct('densidad',pct_dens,'birads',catFinal,'riesgo',riesgo,'fecha',datetime('now'));
    metricas = struct('porcentaje_densidad',pct_dens,'birads_categoria',birads,'birads_final',catFinal,...
        'riesgo_integrado',riesgo,'microcalcificaciones',micro.numero,'lesiones',length(resultados),...
        'tension_max',max(tension(:)),'radiomics',radiomics,'patrones',patrones);

    % ---- 11. GENERACIÓN DE 25 FIGURAS (solo si visible) ----
    if ~visible, figHandles = []; return; end

    figHandles = zeros(1,25);
    % Figura 1: Preprocesamiento
    f1 = figure('Name','1_Preprocesamiento'); 
    subplot(1,3,1); imshow(img,[]); title('Original');
    subplot(1,3,2); imshow(img_clahe,[]); title('CLAHE');
    subplot(1,3,3); imshow(img_suave,[]); title('Suavizada');
    figHandles(1)=f1;

    % Figura 2: Segmentación
    f2 = figure('Name','2_Segmentacion');
    subplot(1,3,1); imshow(img_suave,[]); title('Original');
    subplot(1,3,2); imshow(masc_final); title('Máscara');
    subplot(1,3,3); imshow(img_suave,[]); hold on; contour(masc_final,'r'); title('Superposición');
    figHandles(2)=f2;

    % Figura 3: Mapa de densidad
    f3 = figure('Name','3_MapaDensidad');
    imagesc(mapa_dens); colormap([0.9 0.9 0.9;0.7 0.9 0.7;1 0.8 0.4;1 0.4 0.4]); colorbar;
    title(sprintf('Densidad: %.1f%% (BI-RADS %s)',pct_dens,birads));
    figHandles(3)=f3;

    % Figura 4: Histograma de intensidades
    f4 = figure('Name','4_HistogramaDensidad');
    histogram(img_mama(masc_final),40,'FaceColor',[0.2 0.6 0.8]); 
    xlabel('Intensidad'); ylabel('Frecuencia'); title('Distribución de intensidades'); grid on;
    figHandles(4)=f4;

    % Figura 5: Contornos y perímetros
    f5 = figure('Name','5_Contornos');
    B = bwboundaries(masc_final);
    subplot(1,2,1); imshow(img_suave,[]); hold on;
    for k=1:length(B), plot(B{k}(:,2),B{k}(:,1),'r','LineWidth',1.5); end
    title('Contornos detectados');
    subplot(1,2,2); histogram(cellfun(@length,B),10); xlabel('Perímetro (píxeles)'); ylabel('Frecuencia');
    title('Distribución de perímetros');
    figHandles(5)=f5;

    % Figura 6: Esquinas y gradientes
    f6 = figure('Name','6_Esquinas_Gradientes');
    corners = detectHarrisFeatures(img_suave);
    [Gx,Gy]=imgradientxy(double(img_suave)); mag = sqrt(Gx.^2+Gy.^2);
    subplot(1,2,1); imshow(img_suave,[]); hold on; plot(corners.Location(:,1),corners.Location(:,2),'ro','MarkerSize',4);
    title(sprintf('Esquinas Harris: %d',corners.Count));
    subplot(1,2,2); imshow(mag,[]); colorbar; title('Magnitud del gradiente');
    figHandles(6)=f6;

    % Figura 7: Simetría
    f7 = figure('Name','7_Simetria');
    [f,c] = size(img_suave); mid = round(c/2);
    izq = img_suave(:,1:mid); der = fliplr(img_suave(:,mid+1:end));
    if size(izq,2)~=size(der,2), der = imresize(der,size(izq)); end
    diff_sim = abs(double(izq)-double(der));
    subplot(1,2,1); imshow(diff_sim,[]); colorbar; title('Mapa de asimetría');
    subplot(1,2,2); histogram(diff_sim(:),30); xlabel('Diferencia'); ylabel('Frecuencia');
    title('Distribución de asimetría');
    figHandles(7)=f7;

    % Figura 8: Espectro de Fourier
    f8 = figure('Name','8_Fourier');
    F = fft2(double(img_suave)); Fshift = fftshift(F);
    magF = log(abs(Fshift)+1);
    imagesc(magF); colormap(gray); colorbar; title('Espectro de Fourier (log escala)');
    figHandles(8)=f8;

    % Figura 9: Momentos de Hu
    f9 = figure('Name','9_MomentosHu');
    if isfield(patrones,'hu1')
        bar([patrones.hu1, patrones.hu2, patrones.hu3]);
        set(gca,'XTickLabel',{'Hu1','Hu2','Hu3'}); title('Momentos de Hu (invariantes)');
    else
        text(0.5,0.5,'No se pudieron calcular','HorizontalAlignment','center');
    end
    figHandles(9)=f9;

    % Figura 10: GLCM
    f10 = figure('Name','10_GLCM');
    glcm = graycomatrix(img_suave, 'Offset',[0 1], 'NumLevels',16);
    propsGLCM = graycoprops(glcm,{'contrast','correlation','energy','homogeneity'});
    subplot(1,2,1); imagesc(glcm); colorbar; title('Matriz GLCM (offset 0,1)');
    subplot(1,2,2); bar([mean(propsGLCM.Contrast), mean(propsGLCM.Correlation), mean(propsGLCM.Energy), mean(propsGLCM.Homogeneity)]);
    set(gca,'XTickLabel',{'Contraste','Correlación','Energía','Homogeneidad'}); title('Métricas GLCM');
    figHandles(10)=f10;

    % Figura 11: Radiomics
    f11 = figure('Name','11_Radiomics');
    fn = fieldnames(radiomics); vals = zeros(length(fn),1);
    for i=1:length(fn), v = radiomics.(fn{i}); if isnumeric(v) && isscalar(v), vals(i)=v; end; end
    bar(vals); set(gca,'XTickLabel',fn); xtickangle(45); title('Características radiómicas');
    figHandles(11)=f11;

    % Figura 12: Microcalcificaciones
    f12 = figure('Name','12_Microcalcificaciones');
    subplot(1,2,1); imshow(img_suave,[]); hold on;
    if micro.numero>0 && ~isempty(micro.ubic), plot(micro.ubic(:,1),micro.ubic(:,2),'ro','MarkerSize',4); end
    title(sprintf('Microcalcificaciones: %d',micro.numero));
    subplot(1,2,2); if micro.numero>0, histogram(micro.areas,10,'FaceColor','r'); xlabel('Área (px)'); ylabel('Frecuencia'); end
    title('Tamaños');
    figHandles(12)=f12;

    % Figura 13: Tensiones
    f13 = figure('Name','13_Tensiones');
    subplot(1,2,1); imagesc(tension); colorbar; colormap(hot); title('Tensiones von Mises (kPa)');
    subplot(1,2,2); histogram(tension(tension>0),30,'FaceColor',[0.8 0.2 0.2]); xlabel('Tensión (kPa)'); ylabel('Frecuencia');
    title('Distribución de tensiones');
    figHandles(13)=f13;

    % Figura 14: Deformaciones
    f14 = figure('Name','14_Deformaciones');
    imagesc(biomecanica.deformaciones); colorbar; title('Mapa de deformación (compresión radial)');
    figHandles(14)=f14;

    % Figura 15: Scatter Solidez vs Excentricidad
    f15 = figure('Name','15_Lesiones_Formas');
    if ~isempty(resultados)
        sol = [resultados.Solidez]; exc = [resultados.Excentricidad];
        scatter(sol, exc, 50, 'filled'); xlabel('Solidez'); ylabel('Excentricidad');
        title('Patrón geométrico de lesiones'); grid on;
    else text(0.5,0.5,'Sin lesiones','HorizontalAlignment','center'); end
    figHandles(15)=f15;

    % Figura 16: Regresión área vs diámetro
    f16 = figure('Name','16_Area_vs_Diametro');
    if ~isempty(resultados)
        areas = [resultados.Area]; diam = [resultados.Diametro];
        scatter(areas, diam, 50, 'filled'); hold on;
        p = polyfit(areas, diam, 1); xfit = linspace(min(areas),max(areas),100);
        plot(xfit, polyval(p,xfit), 'r--'); xlabel('Área (px)'); ylabel('Diámetro mayor (px)');
        title('Correlación área-diámetro'); legend('Datos','Regresión');
    end
    figHandles(16)=f16;

    % Figura 17: Boxplot áreas por tipo (CORREGIDO)
    f17 = figure('Name','17_AreaPorTipo');
    if ~isempty(resultados)
        tipos_presentes = unique({resultados.Clasificacion});
        areas_por_tipo = cell(length(tipos_presentes),1);
        for j = 1:length(tipos_presentes)
            areas_por_tipo{j} = [resultados(strcmp({resultados.Clasificacion}, tipos_presentes{j})).Area];
        end
        datos = []; grupos = [];
        for j = 1:length(tipos_presentes)
            datos = [datos; areas_por_tipo{j}(:)];
            grupos = [grupos; j * ones(length(areas_por_tipo{j}),1)];
        end
        if ~isempty(datos)
            boxplot(datos, grupos, 'Labels', tipos_presentes);
            ylabel('Área (px)'); title('Comparación de áreas por tipo');
        end
    end
    figHandles(17)=f17;

    % Figura 18: Boxplot confianza por tipo (CORREGIDO)
    f18 = figure('Name','18_ConfianzaPorTipo');
    if ~isempty(resultados)
        tipos_presentes = unique({resultados.Clasificacion});
        conf_por_tipo = cell(length(tipos_presentes),1);
        for j = 1:length(tipos_presentes)
            conf_por_tipo{j} = [resultados(strcmp({resultados.Clasificacion}, tipos_presentes{j})).Confianza];
        end
        datos = []; grupos = [];
        for j = 1:length(tipos_presentes)
            datos = [datos; conf_por_tipo{j}(:)];
            grupos = [grupos; j * ones(length(conf_por_tipo{j}),1)];
        end
        if ~isempty(datos)
            boxplot(datos, grupos, 'Labels', tipos_presentes);
            ylabel('Confianza'); title('Confianza del clasificador');
        end
    end
    figHandles(18)=f18;

    % Figura 19: Riesgo integrado
    f19 = figure('Name','19_RiesgoIntegrado');
    bar(riesgo, 'FaceColor', [0.8 0.2 0.2]); ylim([0 10]); ylabel('Puntuación'); title(sprintf('Riesgo integrado: %.2f/10',riesgo));
    figHandles(19)=f19;

    % Figura 20: Probabilidades BI-RADS
    f20 = figure('Name','20_ProbabilidadesBIRADS');
    bar(0:5, probBIRADS, 'FaceColor', [0.2 0.6 0.8]); xlabel('Categoría BI-RADS'); ylabel('Probabilidad');
    title('Distribución de probabilidades BI-RADS'); grid on;
    figHandles(20)=f20;

    % Figura 21: Composición tisular
    f21 = figure('Name','21_ComposicionTisular');
    pie([pct_dens, 100-pct_dens], {'Tejido denso','Tejido graso'});
    title('Composición de tejido mamario');
    figHandles(21)=f21;

    % Figura 22: Resumen de diagnóstico
    f22 = figure('Name','22_ResumenDiagnostico');
    axis off;
    text(0.1,0.9, 'RESUMEN DE DIAGNÓSTICO', 'FontSize',16,'FontWeight','bold');
    text(0.1,0.8, sprintf('Densidad: %.1f%% (BI-RADS %s)', pct_dens, birads));
    text(0.1,0.7, sprintf('BI-RADS final: %d', catFinal));
    text(0.1,0.6, sprintf('Riesgo integrado: %.2f/10', riesgo));
    text(0.1,0.5, sprintf('Lesiones: %d', length(resultados)));
    text(0.1,0.4, sprintf('Microcalcificaciones: %d', micro.numero));
    text(0.1,0.3, sprintf('Tensión máxima: %.2f kPa', max(tension(:))));
    if riesgo>7, rec='BIOPSIA RECOMENDADA'; elseif riesgo>4, rec='SEGUIMIENTO EN 6 MESES'; else rec='REVISIÓN ANUAL'; end
    text(0.1,0.15, ['RECOMENDACIÓN: ' rec], 'FontSize',12,'FontWeight','bold');
    figHandles(22)=f22;

    % Figura 23: Matriz de correlación radiómica
    f23 = figure('Name','23_CorrelacionRadiomics');
    fn = fieldnames(radiomics); mat = [];
    for i=1:length(fn)
        if isnumeric(radiomics.(fn{i})) && isscalar(radiomics.(fn{i}))
            mat(end+1) = radiomics.(fn{i});
        end
    end
    if length(mat)>1
        corrMat = corrcoef(mat);
        imagesc(corrMat); colorbar; set(gca,'XTick',1:length(mat),'YTick',1:length(mat));
        title('Matriz de correlación (características radiómicas)');
    end
    figHandles(23)=f23;

    % Figura 24: Superficie 3D de tensiones
    f24 = figure('Name','24_SuperficieTensiones');
    step = max(1, floor(size(tension,1)/100)); % submuestreo
    [X,Y] = meshgrid(1:step:size(tension,2), 1:step:size(tension,1));
    Z = tension(1:step:end,1:step:end);
    surf(X,Y,Z, 'EdgeColor','none'); colormap(jet); colorbar; xlabel('X (px)'); ylabel('Y (px)'); zlabel('Tensión (kPa)');
    title('Superficie de tensiones von Mises (3D)');
    figHandles(24)=f24;

    % Figura 25: Curva ROC simulada
    f25 = figure('Name','25_CurvaROC');
    tpr = [0, 0.2, 0.5, 0.75, 0.9, 1]; fpr = [0, 0.05, 0.15, 0.35, 0.6, 1];
    plot(fpr, tpr, 'b-', 'LineWidth', 2); hold on; plot([0 1],[0 1],'k--'); 
    xlabel('Tasa falsos positivos'); ylabel('Tasa verdaderos positivos');
    title('Curva ROC (simulación)'); legend('Clasificador','Aleatorio','Location','southeast');
    auc = trapz(fpr, tpr); text(0.6,0.2, sprintf('AUC = %.3f', auc), 'FontSize',12);
    grid on;
    figHandles(25)=f25;
end

%% ============================================================================
%% FUNCIONES AUXILIARES DE CÁLCULO MATEMÁTICO
%% ============================================================================

function patrones = calcularPatronesGeometricos(img, masc, mapa_dens)
    img_d = double(img);
    patrones = struct();
    % Contornos
    B = bwboundaries(masc);
    if ~isempty(B)
        per = cellfun(@length, B);
        patrones.perimetro_medio = mean(per);
        patrones.num_contornos = length(B);
    end
    % Esquinas Harris
    corners = detectHarrisFeatures(img_d);
    patrones.num_esquinas = corners.Count;
    % Simetría
    sim_h = img_d - fliplr(img_d);
    sim_v = img_d - flipud(img_d);
    patrones.asimetria_h = norm(sim_h,'fro') / (norm(img_d,'fro')+1);
    patrones.asimetria_v = norm(sim_v,'fro') / (norm(img_d,'fro')+1);
    % Energía de Fourier
    F = fft2(img_d); Fs = fftshift(F);
    patrones.fourier_energia = sum(abs(Fs(:)));
    % Momentos de Hu (sobre región densa)
    region_densa = mapa_dens >= 3;
    if sum(region_densa(:)) > 0
        stats = regionprops(region_densa, 'Image', 'Centroid');
        if ~isempty(stats)
            areas = cellfun(@(x) sum(x(:)), {stats.Image});
            [~, idx] = max(areas);
            img_region = stats(idx).Image;
            [f,c] = find(img_region);
            if length(f) > 10
                xc = mean(c); yc = mean(f);
                mu20 = sum((c-xc).^2);   mu02 = sum((f-yc).^2);   mu11 = sum((c-xc).*(f-yc));
                mu30 = sum((c-xc).^3);   mu03 = sum((f-yc).^3);
                mu21 = sum((c-xc).^2.*(f-yc)); mu12 = sum((c-xc).*(f-yc).^2);
                area = length(f);
                mu20 = mu20/area; mu02 = mu02/area; mu11 = mu11/area;
                mu30 = mu30/area; mu03 = mu03/area; mu21 = mu21/area; mu12 = mu12/area;
                patrones.hu1 = mu20 + mu02;
                patrones.hu2 = (mu20 - mu02)^2 + 4*mu11^2;
                patrones.hu3 = (mu30 - 3*mu12)^2 + (3*mu21 - mu03)^2;
            end
        end
    end
end

function radiomics = calcularRadiomicsCompleta(img, masc)
    img_roi = double(img) .* double(masc);
    % GLCM
    glcm = graycomatrix(uint8(img_roi), 'Offset', [0 1; -1 1; -1 0; -1 -1], 'NumLevels', 16);
    props = graycoprops(glcm, {'contrast','correlation','energy','homogeneity'});
    radiomics.contraste = mean(props.Contrast);
    radiomics.correlacion = mean(props.Correlation);
    radiomics.energia = mean(props.Energy);
    radiomics.homogeneidad = mean(props.Homogeneity);
    % Intensidad
    vals = img_roi(masc);
    radiomics.media = mean(vals);
    radiomics.std = std(vals);
    radiomics.entropia = entropy(uint8(vals));
    radiomics.sesgo = skewness(vals);
    radiomics.kurtosis = kurtosis(vals);
    % Fourier
    F = fft2(img_roi); Fs = fftshift(F);
    radiomics.energia_fourier = sum(abs(Fs(:)));
end

function micro = detectarMicrocalcWavelet(img)
    img_norm = mat2gray(img);
    try
        [cA,cH,cV,cD] = dwt2(img_norm, 'db4');
        cD_enf = cD * 3;
        img_det = idwt2(cA,cH,cV,cD_enf, 'db4');
    catch
        img_det = img_norm;
    end
    umbral = graythresh(img_det) * 0.7;
    masc = img_det > umbral;
    masc = bwareaopen(masc, 5);
    stats = regionprops(masc, 'Centroid','Area');
    micro.numero = length(stats);
    if micro.numero > 0
        micro.ubic = vertcat(stats.Centroid);
        micro.areas = [stats.Area];
    else
        micro.ubic = []; micro.areas = [];
    end
end

%% ============================================================================
%% FUNCIÓN DE EXPORTACIÓN (MANEJA UI)
%% ============================================================================
function exportar25(archivoDICOM, resultados, diagnostico, metricas, patrones, biomecanica, figHandles, config)
    [carpeta, nombre, ~] = fileparts(archivoDICOM);
    carpetaSalida = fullfile(carpeta, [nombre '_' config.export.carpeta]);
    if ~exist(carpetaSalida,'dir'), mkdir(carpetaSalida); end

    % Guardar figuras
    for i = 1:length(figHandles)
        if ishandle(figHandles(i))
            nombreFig = fullfile(carpetaSalida, sprintf('Fig%02d.png', i));
            uih = findall(figHandles(i), 'Type', 'uicontrol');
            uih = [uih; findall(figHandles(i), 'Type', 'uitable')];
            if ~isempty(uih), set(uih,'Visible','off'); drawnow; end
            try
                print(figHandles(i), nombreFig, sprintf('-r%d',config.export.dpi), '-dpng');
            catch
                saveas(figHandles(i), nombreFig);
            end
            if ~isempty(uih), set(uih,'Visible','on'); drawnow; end
        end
    end

    % Informe TXT
    fid = fopen(fullfile(carpetaSalida, 'Informe_25_Figuras.txt'), 'w');
    fprintf(fid, '=== INFORME DE ANÁLISIS MAMOGRÁFICO (25 FIGURAS) ===\n');
    fprintf(fid, 'Archivo: %s\nFecha: %s\n\n', archivoDICOM, datestr(now));
    fprintf(fid, 'DENSIDAD: %.1f%% (BI-RADS %s) -> Final: %d\n', metricas.porcentaje_densidad, metricas.birads_categoria, metricas.birads_final);
    fprintf(fid, 'RIESGO INTEGRADO: %.2f/10\n', metricas.riesgo_integrado);
    fprintf(fid, 'MICROCALCIFICACIONES: %d\n', metricas.microcalcificaciones);
    fprintf(fid, 'LESIONES DETECTADAS: %d\n', metricas.lesiones);
    fprintf(fid, 'TENSIÓN MÁXIMA: %.2f kPa\n\n', metricas.tension_max);
    fprintf(fid, 'PATRONES GEOMÉTRICOS:\n');
    campos = fieldnames(patrones);
    for i=1:length(campos), fprintf(fid, '  %s: %g\n', campos{i}, patrones.(campos{i})); end
    fprintf(fid, '\nRADIOMICS (GLCM): Contraste=%.3f, Correlación=%.3f, Energía=%.3f, Homogeneidad=%.3f\n',...
        metricas.radiomics.contraste, metricas.radiomics.correlacion, metricas.radiomics.energia, metricas.radiomics.homogeneidad);
    fclose(fid);

    save(fullfile(carpetaSalida, 'Datos_Completos.mat'), 'resultados','diagnostico','metricas','patrones','biomecanica');
    if ~isempty(resultados)
        tbl = struct2table(resultados);
        writetable(tbl, fullfile(carpetaSalida, 'Lesiones.csv'));
    end
    fprintf('   ✓ Exportación completada en: %s\n', carpetaSalida);
end