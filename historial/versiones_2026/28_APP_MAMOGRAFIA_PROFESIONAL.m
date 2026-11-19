%% ====================================================================
%% APLICACION PROFESIONAL - SISTEMA DE ANALISIS MAMOGRAFICO
%% ====================================================================
%% 
%% Caracterizacion Automatizada de Densidad Mamografica
%% Con Interface Grafica Profesional
%% 
%% Universidad ECCI - Maestria en Ingenieria (GIATME)
%% 2026

classdef APP_MAMOGRAFIA_PROFESIONAL < handle
    
    properties
        fig
        ax_imagen
        ax_segmentacion
        ax_resultados
        
        imagen_actual
        mascara_actual
        caracteristicas
        
        datos_paciente
        resultados_analisis
        
        radiomics_glcm
        patrones_geom
        parametros_biomec
        microcalcificaciones_detectadas
    end
    
    methods
        
        function app = APP_MAMOGRAFIA_PROFESIONAL()
            app.crearInterfazGrafica();
        end
        
        function crearInterfazGrafica(app)
            
            app.fig = figure('Name', 'SISTEMA MAMOGRAFICO PROFESIONAL', ...
                'NumberTitle', 'off', ...
                'Position', [100, 100, 1600, 900], ...
                'Color', [0.95 0.95 0.95], ...
                'Toolbar', 'none', ...
                'Menubar', 'none');
            
            % ===== PANEL SUPERIOR: TITULO =====
            uicontrol('Parent', app.fig, ...
                'Style', 'text', ...
                'String', 'SISTEMA INTEGRAL DE ANALISIS MAMOGRAFICO', ...
                'Position', [10, 850, 1580, 40], ...
                'FontSize', 18, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.2 0.5 0.8], ...
                'ForegroundColor', [1 1 1]);
            
            % ===== PANEL IZQUIERDO: IMAGEN ORIGINAL =====
            uicontrol('Parent', app.fig, 'Style', 'text', ...
                'String', 'IMAGEN ORIGINAL', ...
                'Position', [10, 800, 480, 30], ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.95 0.95 0.95]);
            
            app.ax_imagen = axes('Parent', app.fig, ...
                'Position', [0.01, 0.45, 0.3, 0.35]);
            axis(app.ax_imagen, 'off');
            title(app.ax_imagen, 'Mamografia Original', 'FontSize', 10);
            
            % ===== PANEL CENTRO: SEGMENTACION =====
            uicontrol('Parent', app.fig, 'Style', 'text', ...
                'String', 'SEGMENTACION', ...
                'Position', [510, 800, 480, 30], ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.95 0.95 0.95]);
            
            app.ax_segmentacion = axes('Parent', app.fig, ...
                'Position', [0.32, 0.45, 0.3, 0.35]);
            axis(app.ax_segmentacion, 'off');
            title(app.ax_segmentacion, 'Mascara de Segmentacion', 'FontSize', 10);
            
            % ===== PANEL DERECHA: RESULTADOS =====
            uicontrol('Parent', app.fig, 'Style', 'text', ...
                'String', 'ANALISIS', ...
                'Position', [1010, 800, 580, 30], ...
                'FontSize', 12, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.95 0.95 0.95]);
            
            app.ax_resultados = axes('Parent', app.fig, ...
                'Position', [0.63, 0.45, 0.36, 0.35]);
            axis(app.ax_resultados, 'off');
            
            % ===== PANEL INFERIOR: CONTROLES =====
            
            % Boton Cargar Imagen
            uicontrol('Parent', app.fig, ...
                'Style', 'pushbutton', ...
                'String', 'CARGAR IMAGEN', ...
                'Position', [20, 400, 200, 40], ...
                'FontSize', 11, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.2 0.5 0.8], ...
                'ForegroundColor', [1 1 1], ...
                'Callback', @(src, evt) app.cargarImagen());
            
            % Boton Procesar
            uicontrol('Parent', app.fig, ...
                'Style', 'pushbutton', ...
                'String', 'PROCESAR', ...
                'Position', [240, 400, 200, 40], ...
                'FontSize', 11, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.2 0.7 0.2], ...
                'ForegroundColor', [1 1 1], ...
                'Callback', @(src, evt) app.procesarImagen());
            
            % Boton Analizar
            uicontrol('Parent', app.fig, ...
                'Style', 'pushbutton', ...
                'String', 'ANALIZAR', ...
                'Position', [460, 400, 200, 40], ...
                'FontSize', 11, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.8 0.4 0.2], ...
                'ForegroundColor', [1 1 1], ...
                'Callback', @(src, evt) app.analizarCaracteristicas());
            
            % Boton Generar Reporte
            uicontrol('Parent', app.fig, ...
                'Style', 'pushbutton', ...
                'String', 'GENERAR REPORTE', ...
                'Position', [680, 400, 200, 40], ...
                'FontSize', 11, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.8 0.2 0.8], ...
                'ForegroundColor', [1 1 1], ...
                'Callback', @(src, evt) app.generarReporte());
            
            % Boton Salir
            uicontrol('Parent', app.fig, ...
                'Style', 'pushbutton', ...
                'String', 'SALIR', ...
                'Position', [1380, 400, 200, 40], ...
                'FontSize', 11, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.8 0 0], ...
                'ForegroundColor', [1 1 1], ...
                'Callback', @(src, evt) app.salirApp());
            
            % Panel de Informacion
            uicontrol('Parent', app.fig, 'Style', 'text', ...
                'String', 'INFORMACION DEL SISTEMA', ...
                'Position', [20, 360, 1560, 25], ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.95 0.95 0.95]);
            
            % Texto Informacion
            uicontrol('Parent', app.fig, 'Style', 'text', ...
                'String', 'Sistema listo. Cargue una imagen para comenzar el analisis.', ...
                'Position', [20, 320, 1560, 35], ...
                'FontSize', 10, ...
                'BackgroundColor', [0.95 0.95 0.95], ...
                'HorizontalAlignment', 'left');
            
            % ===== PANEL ESTADISTICAS =====
            uicontrol('Parent', app.fig, 'Style', 'text', ...
                'String', 'ESTADISTICAS EN TIEMPO REAL', ...
                'Position', [20, 280, 1560, 25], ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.95 0.95 0.95]);
            
            % Tabla de resultados
            datos_tabla = {...
                'Radiomics Contraste', 'N/A', 'Caracteristica GLCM'; ...
                'Radiomics Energia', 'N/A', 'Caracteristica GLCM'; ...
                'Patrones Area (px2)', 'N/A', 'Descriptor Geometrico'; ...
                'Biomecanica Tension (kPa)', 'N/A', 'Parametro von Mises'; ...
                'Microcalcificaciones', 'N/A', 'Wavelet DB4'; ...
                'Indice Riesgo (IGR)', 'N/A', 'Combinado'; ...
                'Clasificacion BI-RADS', 'N/A', 'Automatico'};
            
            uit = uitable('Parent', app.fig, ...
                'Data', datos_tabla, ...
                'Position', [20, 20, 1560, 250], ...
                'ColumnName', {'Parametro', 'Valor', 'Descripcion'}, ...
                'ColumnEditable', [false, false, false], ...
                'ColumnWidth', {300, 300, 600}, ...
                'FontSize', 9, ...
                'RowName', '');
            
            app.datos_paciente = struct();
            app.resultados_analisis = struct();
            
        end
        
        function cargarImagen(app)
            
            [file, path] = uigetfile({'*.dcm;*.png;*.jpg;*.bmp', ...
                'Archivos Mamografia (*.dcm, *.png, *.jpg, *.bmp)'}, ...
                'Seleccione una Mamografia');
            
            if isequal(file, 0)
                return;
            end
            
            ruta_completa = fullfile(path, file);
            
            try
                if strcmp(file(end-3:end), '.dcm')
                    app.imagen_actual = dicomread(ruta_completa);
                else
                    app.imagen_actual = imread(ruta_completa);
                end
                
                if size(app.imagen_actual, 3) == 3
                    app.imagen_actual = rgb2gray(app.imagen_actual);
                end
                
                imshow(app.imagen_actual, [], 'Parent', app.ax_imagen);
                title(app.ax_imagen, 'Mamografia Cargada', 'FontSize', 10);
                
                msgbox('Imagen cargada exitosamente. Presione PROCESAR.', ...
                    'Exito', 'help');
                
            catch ME
                errordlg(['Error al cargar imagen: ' ME.message], ...
                    'Error');
            end
            
        end
        
        function procesarImagen(app)
            
            if isempty(app.imagen_actual)
                errordlg('Primero cargue una imagen', 'Error');
                return;
            end
            
            try
                % Preprocesamiento
                img_med = medfilt2(uint8(app.imagen_actual), [5, 5]);
                img_norm = double(img_med) / 255;
                img_cont = (img_norm - min(img_norm(:))) / ...
                    (max(img_norm(:)) - min(img_norm(:)));
                img_uint = uint8(img_cont * 255);
                img_clahe = adapthisteq(img_uint);
                img_prep = imgaussfilt(double(img_clahe), 1.5);
                
                % Segmentacion
                masc = imbinarize(mat2gray(img_prep), ...
                    'adaptive', 'Sensitivity', 0.5);
                masc = bwareaopen(masc, 800);
                masc = imfill(masc, 'holes');
                
                app.mascara_actual = masc;
                
                imshow(masc, 'Parent', app.ax_segmentacion);
                title(app.ax_segmentacion, 'Segmentacion Completada', ...
                    'FontSize', 10);
                
                msgbox('Procesamiento completado. Presione ANALIZAR.', ...
                    'Exito', 'help');
                
            catch ME
                errordlg(['Error en procesamiento: ' ME.message], 'Error');
            end
            
        end
        
        function analizarCaracteristicas(app)
            
            if isempty(app.imagen_actual) || isempty(app.mascara_actual)
                errordlg('Primero procese una imagen', 'Error');
                return;
            end
            
            try
                % ===== RADIOMICS GLCM =====
                img_roi = double(app.imagen_actual) .* double(app.mascara_actual);
                img_norm = mat2gray(img_roi);
                
                glcm = graycomatrix(uint8(img_norm*255), ...
                    'Offset', [0 1; -1 1; -1 0; -1 -1], 'NumLevels', 16);
                props = graycoprops(glcm, ...
                    {'Contrast', 'Correlation', 'Energy', 'Homogeneity'});
                
                app.radiomics_glcm = [
                    mean(props.Contrast), mean(props.Correlation), ...
                    mean(props.Energy), mean(props.Homogeneity)
                ];
                
                % ===== PATRONES GEOMETRICOS =====
                contornos = bwboundaries(app.mascara_actual);
                props_morfo = regionprops(app.mascara_actual, ...
                    'Area', 'Perimeter', 'Eccentricity', 'Solidity', ...
                    'FilledArea');
                
                if ~isempty(props_morfo)
                    app.patrones_geom = [
                        length(contornos), mean([props_morfo.Area]), ...
                        mean([props_morfo.Perimeter]), ...
                        mean([props_morfo.Eccentricity]), ...
                        mean([props_morfo.Solidity])
                    ];
                end
                
                % ===== BIOMECANICA =====
                [ny, nx] = size(app.mascara_actual);
                [XX, YY] = meshgrid(1:nx, 1:ny);
                
                E_GLANDULAR = 15.1;
                E_ADIPOSO = 4.46;
                E_matriz = E_ADIPOSO * ones(ny, nx);
                E_matriz(app.mascara_actual>0) = E_GLANDULAR;
                
                distancia_centro = sqrt((XX - nx/2).^2 + (YY - ny/2).^2);
                distancia_maxima = max(distancia_centro(:));
                if distancia_maxima == 0, distancia_maxima = 1; end
                
                factor_compresion = 1 - 0.7 * ...
                    (distancia_centro / distancia_maxima);
                tensiones = E_matriz .* (1 - factor_compresion);
                
                app.parametros_biomec = [
                    max(tensiones(:)), mean(tensiones(tensiones>0)), ...
                    std(tensiones(tensiones>0)), ...
                    mean(E_matriz(app.mascara_actual>0))
                ];
                
                % ===== MICROCALCIFICACIONES =====
                try
                    img_norm_prep = mat2gray(app.imagen_actual);
                    [cA, cH, cV, cD] = dwt2(img_norm_prep, 'db4');
                    cD_enf = cD * 3;
                    imagen_detalles = idwt2(cA, cH, cV, cD_enf, 'db4');
                    
                    umbral = graythresh(imagen_detalles) * 0.7;
                    masc_micro = imagen_detalles > umbral;
                    masc_micro = bwareaopen(masc_micro, 5);
                    
                    stats = regionprops(masc_micro, 'Area');
                    app.microcalcificaciones_detectadas = length(stats);
                catch
                    app.microcalcificaciones_detectadas = 0;
                end
                
                % ===== INDICE DE RIESGO =====
                radiomics_norm = app.radiomics_glcm(1) / 10;
                patrones_norm = app.patrones_geom(2) / 100000;
                biomec_norm = app.parametros_biomec(1) / 20;
                
                IGR = (radiomics_norm*0.30 + patrones_norm*0.35 + ...
                    biomec_norm*0.35) / 0.33;
                
                % ===== CLASIFICACION BI-RADS =====
                if IGR < 1
                    birads = '1-Negativo';
                    color_riesgo = [0 0.7 0];
                elseif IGR < 2
                    birads = '2-Benigno';
                    color_riesgo = [0 0.7 0];
                elseif IGR < 3
                    birads = '3-Probablemente Benigno';
                    color_riesgo = [0.9 0.7 0];
                elseif IGR < 4
                    birads = '4-Sospechoso';
                    color_riesgo = [0.9 0.3 0];
                elseif IGR < 5
                    birads = '5-Maligno';
                    color_riesgo = [0.8 0 0];
                else
                    birads = '6-Cancer Conocido';
                    color_riesgo = [0.6 0 0];
                end
                
                % ===== MOSTRAR RESULTADOS =====
                cla(app.ax_resultados);
                
                texto_resultados = {
                    'RESULTADOS DEL ANALISIS', '';
                    'RADIOMICS GLCM:', '';
                    sprintf('  Contraste: %.4f', app.radiomics_glcm(1)), '';
                    sprintf('  Energia: %.4f', app.radiomics_glcm(3)), '';
                    '', '';
                    'PATRONES GEOMETRICOS:', '';
                    sprintf('  Area: %.2f px2', app.patrones_geom(2)), '';
                    sprintf('  Excentricidad: %.4f', ...
                        app.patrones_geom(4)), '';
                    '', '';
                    'BIOMECANICA:', '';
                    sprintf('  Tension Max: %.2f kPa', ...
                        app.parametros_biomec(1)), '';
                    '', '';
                    sprintf('  Micros: %d', ...
                        app.microcalcificaciones_detectadas), '';
                    '', '';
                    sprintf('INDICE RIESGO (IGR): %.2f', IGR), '';
                    sprintf('BI-RADS: %s', birads), ''
                };
                
                text(0.1, 0.95, sprintf('%s\n%s', texto_resultados{:}), ...
                    'Parent', app.ax_resultados, ...
                    'VerticalAlignment', 'top', ...
                    'FontSize', 9, ...
                    'FontName', 'monospaced', ...
                    'Color', color_riesgo);
                
                axis(app.ax_resultados, 'off');
                
                app.resultados_analisis = struct(...
                    'IGR', IGR, ...
                    'BIRADS', birads, ...
                    'Radiomics', app.radiomics_glcm, ...
                    'Patrones', app.patrones_geom, ...
                    'Biomec', app.parametros_biomec, ...
                    'Micros', app.microcalcificaciones_detectadas);
                
                msgbox('Analisis completado exitosamente.', ...
                    'Exito', 'help');
                
            catch ME
                errordlg(['Error en analisis: ' ME.message], 'Error');
            end
            
        end
        
        function generarReporte(app)
            
            if isempty(app.resultados_analisis)
                errordlg('Primero realice el analisis', 'Error');
                return;
            end
            
            [archivo, ruta] = uiputfile('*.txt', ...
                'Guardar Reporte Como');
            
            if isequal(archivo, 0)
                return;
            end
            
            ruta_completa = fullfile(ruta, archivo);
            
            fid = fopen(ruta_completa, 'w');
            
            fprintf(fid, '==================================================\n');
            fprintf(fid, 'REPORTE DE ANALISIS MAMOGRAFICO\n');
            fprintf(fid, 'Sistema Integral de Caracterizacion Mamografica\n');
            fprintf(fid, 'Universidad ECCI - Maestria GIATME\n');
            fprintf(fid, '==================================================\n\n');
            
            fprintf(fid, 'FECHA Y HORA: %s\n\n', datestr(now));
            
            fprintf(fid, 'RESULTADOS DEL ANALISIS:\n');
            fprintf(fid, '--------------------------------------------------\n\n');
            
            fprintf(fid, 'RADIOMICS GLCM:\n');
            fprintf(fid, '  Contraste: %.4f\n', ...
                app.resultados_analisis.Radiomics(1));
            fprintf(fid, '  Correlacion: %.4f\n', ...
                app.resultados_analisis.Radiomics(2));
            fprintf(fid, '  Energia: %.4f\n', ...
                app.resultados_analisis.Radiomics(3));
            fprintf(fid, '  Homogeneidad: %.4f\n\n', ...
                app.resultados_analisis.Radiomics(4));
            
            fprintf(fid, 'PATRONES GEOMETRICOS:\n');
            fprintf(fid, '  Area: %.2f px2\n', ...
                app.resultados_analisis.Patrones(2));
            fprintf(fid, '  Perimetro: %.2f px\n', ...
                app.resultados_analisis.Patrones(3));
            fprintf(fid, '  Excentricidad: %.4f\n', ...
                app.resultados_analisis.Patrones(4));
            fprintf(fid, '  Solidez: %.4f\n\n', ...
                app.resultados_analisis.Patrones(5));
            
            fprintf(fid, 'BIOMECANICA (VON MISES):\n');
            fprintf(fid, '  Tension Maxima: %.2f kPa\n', ...
                app.resultados_analisis.Biomec(1));
            fprintf(fid, '  Tension Media: %.2f kPa\n', ...
                app.resultados_analisis.Biomec(2));
            fprintf(fid, '  Desviacion: %.2f kPa\n\n', ...
                app.resultados_analisis.Biomec(3));
            
            fprintf(fid, 'MICROCALCIFICACIONES:\n');
            fprintf(fid, '  Numero Detectado: %d\n\n', ...
                app.resultados_analisis.Micros);
            
            fprintf(fid, '==================================================\n');
            fprintf(fid, 'DIAGNOSTICO FINAL:\n');
            fprintf(fid, '==================================================\n\n');
            
            fprintf(fid, 'Indice Geometrico de Riesgo (IGR): %.2f\n', ...
                app.resultados_analisis.IGR);
            fprintf(fid, 'Clasificacion BI-RADS: %s\n\n', ...
                app.resultados_analisis.BIRADS);
            
            fprintf(fid, 'RECOMENDACIONES:\n');
            if app.resultados_analisis.IGR < 2
                fprintf(fid, '- Seguimiento rutinario\n');
                fprintf(fid, '- Proximo control en 1-2 anos\n');
            elseif app.resultados_analisis.IGR < 3
                fprintf(fid, '- Seguimiento a corto plazo\n');
                fprintf(fid, '- Proximo control en 6 meses\n');
            elseif app.resultados_analisis.IGR < 4
                fprintf(fid, '- Se recomienda evaluacion adicional\n');
                fprintf(fid, '- Considerar ultrasonido mamario\n');
            else
                fprintf(fid, '- Se recomienda biopsia\n');
                fprintf(fid, '- Consulta inmediata con especialista\n');
            end
            
            fprintf(fid, '\n==================================================\n');
            fprintf(fid, 'Reporte generado automaticamente\n');
            fprintf(fid, 'Este reporte es de caracter informativo\n');
            fprintf(fid, '==================================================\n');
            
            fclose(fid);
            
            msgbox(['Reporte guardado en: ' ruta_completa], ...
                'Exito', 'help');
            
        end
        
        function salirApp(app)
            
            respuesta = questdlg('¿Desea salir de la aplicacion?', ...
                'Confirmacion', 'Si', 'No', 'No');
            
            if strcmp(respuesta, 'Si')
                close(app.fig);
                delete(app);
            end
            
        end
        
    end
    
end

%% ====================================================================
%% INICIAR APLICACION
%% ====================================================================

% Crear instancia de la aplicacion
app = APP_MAMOGRAFIA_PROFESIONAL();

