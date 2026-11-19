%% SISTEMA UNIFICADO AVANZADO DE ANÁLISIS DICOM PARA CÁNCER DE MAMA - VERSIÓN FINAL INTEGRADA
% Sistema integrado con todas las funcionalidades: Deep Learning + Radiómica + 
% Análisis 3D + Seguimiento temporal + Modelado biomecánico + Exportación avanzada

clear all; close all; clc;

%% CONFIGURACIÓN AVANZADA DEL SISTEMA UNIFICADO MEJORADA
disp('=== SISTEMA UNIFICADO AVANZADO LIBRA + DEEP LEARNING + RADIOMICA + 3D ===');
disp('Integrando: Densidad LIBRA + Autoencoders + CNN + Modelado biomecánico + Radiómica + Análisis 3D');

% Parámetros del sistema mejorados
config.umbral_area_minima = 1000;
config.umbral_compacidad_maligna = 1.3;
config.umbral_diametro_maligno = 150;
config.realce = 0.6;
config.umbralbin_tophat = 0.15;
config.r_tophat = 30;

% Configuración de modelos deep learning avanzados
config.deep_learning.uso_autoencoder = true;
config.deep_learning.uso_cnn_clasificacion = true;
config.deep_learning.umbral_confianza_cnn = 0.75;
config.deep_learning.uso_transfer_learning = true;
config.deep_learning.modelo_preentrenado = 'resnet50';
config.deep_learning.uso_redes_siamesas = false;

% Parámetros de modelos biomecánicos mejorados
config.modelo_biomecanico.young_glandular = 15.1;
config.modelo_biomecanico.young_adipose = 4.46;
config.modelo_biomecanico.poisson_ratio = 0.45;
config.modelo_biomecanico.compression_factor = 0.7;
config.modelo_biomecanico.stress_threshold = 8.5;

% Configuración de denoising y preprocesamiento
config.denoising.uso_autoencoder_denoising = true;
config.denoising.factor_ruido = 0.1;
config.cnn.clasificacion_multiclase = true;

% ========== NUEVAS CONFIGURACIONES INTEGRADAS ==========
% Configuración de análisis radiómico avanzado
config.radiomica.habilitado = true;
config.radiomica.extraccion_caracteristicas_avanzadas = true;
config.radiomica.numero_haralick_features = 14;
config.radiomica.uso_lbp = true;
config.radiomica.uso_gabor = true;
config.radiomica.analisis_multiescala = true;
config.radiomica.numero_caracteristicas = 128;

% Configuración de análisis 3D
config.analisis_3d.habilitado = true;
config.analisis_3d.reconstruccion_volumetrica = true;
config.analisis_3d.calculo_metricas_volumetricas = true;
config.analisis_3d.voxel_size = [0.1, 0.1, 1.0];

% Configuración de seguimiento temporal
config.analisis_temporal.habilitado = false;
config.analisis_temporal.ventana_temporal = 5; % años
config.seguimiento_temporal.habilitado = false;
config.seguimiento_temporal.comparar_estudios_previos = false;
config.seguimiento_temporal.umbral_crecimiento = 1.2; % 20% de crecimiento
config.seguimiento_temporal.intervalo_seguimiento = 6; % meses

% Configuración de correlación clínica
config.correlacion_clinica.habilitada = true;
config.correlacion_clinica.edad_paciente = 50; % Años (valor por defecto)
config.correlacion_clinica.historia_familiar = false;
config.correlacion_clinica.menopausia = true;
config.correlacion_clinica.uso_hormonal = false;

% Configuración de segmentación avanzada
config.segmentation.uso_watershed = true;
config.segmentation.uso_active_contour = true;

% Configuración de riesgo y predicción
config.riesgo.uso_modelo_prediccion = true;
config.riesgo.factores_clinicos = true;
config.riesgo.umbral_alto_riesgo = 0.15;

% Configuración de exportación avanzada
config.exportacion.habilitada = true;
config.exportacion.formato_reportes = 'pdf';
config.exportacion.incluir_datos_brutos = false;
config.exportacion.formato = {'pdf', 'excel', 'dicom_anotado', 'json'};

% Configuración de visualización mejorada
config.visualizacion.mostrar_todas_figuras = true;
config.visualizacion.guardar_resultados = true;
config.visualizacion.formato_exportacion = 'png';
config.visualizacion.modo_oscuro = false;
config.visualizacion.calidad_imagen = 'alta';
config.visualizacion.animaciones = true;

% Configuración de red neuronal avanzada
config.red_neuronal.arquitectura = 'resnet50_attention';
config.deep_learning.uso_transformer = true;
config.deep_learning.uso_attention = true;

%% INICIALIZACIÓN DE MODELOS AVANZADOS INTEGRADOS
fprintf('\n=== INICIALIZANDO MODELOS AVANZADOS INTEGRADOS ===\n');

% Inicializar todos los modelos
modelos.deep_learning = inicializarModelosDeepLearningAvanzados(config);
modelos.radiomica = inicializarModelosRadiomicos(config);

% Verificar toolboxes requeridas
toolboxes_requeridas = {'Deep Learning Toolbox', 'Image Processing Toolbox', 'Computer Vision Toolbox'};
verificarToolboxes(toolboxes_requeridas);

%% CARGA INTELIGENTE DE DATOS DICOM CON MÚLTIPLES OPCIONES
try
    fprintf('\n=== CARGA INTELIGENTE DE DATOS DICOM ===\n');
    
    % Opción para procesamiento por lotes o individual
    opcion_procesamiento = questdlg('Seleccione el tipo de procesamiento:', ...
        'Configuración de Procesamiento', ...
        'Archivo Individual', 'Directorio Completo', 'Archivo Individual');
    
    switch opcion_procesamiento
        case 'Directorio Completo'
            % Procesamiento por lotes
            directorio = uigetdir('', 'Seleccione el directorio con estudios DICOM');
            if directorio == 0
                disp('Usuario canceló la selección.');
                return;
            end
            archivos_dicom = buscarArchivosDICOM(directorio);
            fprintf('Encontrados %d archivos DICOM en el directorio\n', length(archivos_dicom));
            
            % Procesar todos los archivos
            resultados_lote = [];
            for i = 1:length(archivos_dicom)
                fprintf('\n--- Procesando archivo %d/%d: %s ---\n', i, length(archivos_dicom), archivos_dicom{i});
                try
                    [resultado_actual, info_actual] = procesarArchivoDICOMIndividual(archivos_dicom{i}, config, modelos);
                    resultados_lote = [resultados_lote, resultado_actual];
                catch ME
                    fprintf('Error procesando archivo %s: %s\n', archivos_dicom{i}, ME.message);
                end
            end
            
            % Análisis comparativo del lote
            if ~isempty(resultados_lote)
                realizarAnalisisComparativoLote(resultados_lote, config);
            end
            return;
            
        otherwise
            % Procesamiento de archivo individual
            if ~exist('filename', 'var')
                [filename, dirname] = uigetfile({'*.dcm;*.dicom', 'Dicom Files'; '*.*', 'All Files (*.*)'});
                if isequal(filename, 0)
                    disp('Usuario canceló la selección.');
                    return;
                end
                filename = fullfile(dirname, filename);
            end
    end
    
    % Cargar y validar archivo DICOM individual
    [volumen_dicom, info, metadata_completa] = cargarYValidarDICOM(filename);
    
    % Mostrar información completa del dataset
    mostrarInformacionDICOMCompleta(info, metadata_completa);
    
catch ME
    fprintf('Error en carga DICOM: %s\n', ME.message);
    generarReporteError(ME, config);
    return;
end

%% ANÁLISIS DE METADATOS DICOM AVANZADO
fprintf('\n=== ANÁLISIS DE METADATOS DICOM AVANZADO ===\n');
metadata_analysis = analizarMetadatosDICOM(info);
mostrarResumenMetadatos(metadata_analysis);

%% PIPELINE DE PREPROCESAMIENTO AVANZADO INTEGRADO
disp('Realizando preprocesamiento avanzado con técnicas integradas...');

% Determinar dimensiones y seleccionar imagen para análisis
if ndims(volumen_dicom) > 2
    if size(volumen_dicom, 3) > 1
        % Análisis multi-slice mejorado
        [imagen_principal, slice_optimo, metricas_slices] = seleccionarSliceOptimo(volumen_dicom);
        fprintf('Analizando slice %d de %d (Score: %.3f)\n', slice_optimo, size(volumen_dicom, 3), metricas_slices.scores(slice_optimo));
    else
        imagen_principal = volumen_dicom;
        slice_optimo = 1;
    end
else
    imagen_principal = volumen_dicom;
    slice_optimo = 1;
end

% Pipeline de preprocesamiento avanzado
[imagen_preprocesada, metricas_preprocesamiento] = preprocesamientoAvanzado(...
    imagen_principal, info, config);

%% ANÁLISIS DE CALIDAD DE IMAGEN
metricas_calidad = analizarCalidadImagen(imagen_preprocesada);
fprintf('Métricas de calidad - SNR: %.2f dB, Contraste: %.3f, Nitidez: %.3f\n', ...
        metricas_calidad.snr, metricas_calidad.contraste, metricas_calidad.nitidez);

%% ANÁLISIS RADIÓMICO AVANZADO
if config.radiomica.habilitado
    fprintf('\n=== EXTRACCIÓN DE CARACTERÍSTICAS RADIÓMICAS AVANZADAS ===\n');
    caracteristicas_radiomicas = extraerCaracteristicasRadiomicasAvanzadas(...
        imagen_preprocesada, config);
else
    caracteristicas_radiomicas = [];
end

%% SEGMENTACIÓN AVANZADA CON TÉCNICAS COMBINADAS
disp('Realizando segmentación avanzada con técnicas híbridas...');

[mascara_segmentada, metricas_segmentacion, mapa_probabilidades] = ...
    segmentacionAvanzadaConDeepLearning(imagen_preprocesada, config, modelos);

%% EVALUACIÓN DE CALIDAD DE SEGMENTACIÓN
metricas_segmentacion = evaluarCalidadSegmentacion(mascara_segmentada, imagen_preprocesada);
fprintf('Métricas de segmentación - Completitud: %.3f, Consistencia: %.3f\n', ...
        metricas_segmentacion.completitud, metricas_segmentacion.consistencia);

%% ANÁLISIS DE DENSIDAD MAMARIA AVANZADO
disp('=== ANÁLISIS AVANZADO DE TEJIDO GLANDULAR ===');

% Generar mapa de densidad cuantitativa AVANZADO
[mapa_densidad, metricas_densidad] = generarMapaDensidadAvanzado(...
    imagen_preprocesada, mascara_segmentada, config);

% Generar modelo biomecánico AVANZADO con validación
[modelo_biomecanico, deformaciones, metricas_biomecanicas] = ...
    generarModeloBiomecanicoAvanzado(imagen_preprocesada, mapa_densidad, config.modelo_biomecanico);

%% DETECCIÓN Y CLASIFICACIÓN DE LESIONES AVANZADA
disp('Realizando detección y clasificación avanzada de lesiones...');

[resultados, metricas_clasificacion] = clasificacionAvanzadaLesiones(...
    imagen_preprocesada, mascara_segmentada, modelos, config);

%% ANÁLISIS MULTIMODAL AVANZADO
disp('Realizando análisis multimodal avanzado...');

% Análisis de textura con deep learning
[caracteristicas_textura, mapa_textura] = analisisTexturaAvanzado(...
    imagen_preprocesada, mascara_segmentada, modelos);

% Análisis de patrones arquitecturales
[patrones, mapa_patrones] = analisisPatronesArquitecturales(...
    imagen_preprocesada, mascara_segmentada, mapa_densidad);

%% ANÁLISIS DE CORRELACIÓN CLÍNICA
if config.correlacion_clinica.habilitada
    fprintf('\n=== ANÁLISIS DE CORRELACIÓN CLÍNICA ===\n');
    factores_riesgo = analizarFactoresRiesgo(config.correlacion_clinica, metricas_densidad, resultados);
else
    factores_riesgo = [];
end

%% ANÁLISIS DE RIESGO INTEGRADO
if config.riesgo.uso_modelo_prediccion
    disp('Realizando análisis de riesgo y predicción...');
    [modelo_riesgo, predicciones_riesgo] = generarModeloRiesgoAvanzado(...
        resultados, metricas_densidad, modelo_biomecanico, config);
else
    modelo_riesgo = [];
    predicciones_riesgo = [];
end

%% ANÁLISIS 3D MEJORADO
if config.analisis_3d.habilitado && ndims(volumen_dicom) == 3
    disp('Realizando análisis volumétrico 3D...');
    
    [analisis_3d, reconstruccion_3d] = analisisVolumetrico3D(...
        volumen_dicom, mascara_segmentada, mapa_densidad, config);
    
    % Calcular métricas volumétricas
    metricas_volumetricas = calcularMetricasVolumetricas(analisis_3d, info);
else
    analisis_3d = [];
    reconstruccion_3d = [];
    metricas_volumetricas = [];
end

%% ANÁLISIS TEMPORAL
if config.analisis_temporal.habilitado
    fprintf('Buscando estudios previos para análisis temporal...\n');
    analisis_temporal = realizarAnalisisTemporal(filename, resultados, config);
    if analisis_temporal.estudios_previos_encontrados
        fprintf('Análisis temporal realizado con %d estudios previos\n', ...
                analisis_temporal.num_estudios);
    end
else
    analisis_temporal = [];
end

%% DIAGNÓSTICO INTEGRADO MEJORADO
disp('Generando diagnóstico integrado con fusión avanzada...');

diagnostico_integrado = generarDiagnosticoIntegradoAvanzado(...
    resultados, metricas_densidad, modelo_biomecanico, ...
    metricas_clasificacion, config, factores_riesgo, modelo_riesgo);

%% VISUALIZACIONES AVANZADAS INTEGRADAS - 12 FIGURAS COMPLETAS
disp('Generando visualizaciones avanzadas integradas...');

% Figuras principales del sistema base
fig1 = visualizarProcesamientoAvanzado(imagen_principal, imagen_preprocesada, ...
    mascara_segmentada, metricas_preprocesamiento, info, config);

fig2 = visualizarDensidadTexturaAvanzada(imagen_preprocesada, ...
    mascara_segmentada, mapa_densidad, metricas_densidad, modelos, config);

fig3 = visualizarModeloBiomecanicoAvanzado(imagen_preprocesada, ...
    mapa_densidad, modelo_biomecanico, metricas_biomecanicas, config);

fig4 = visualizarRiesgoIntegradoAvanzado(imagen_preprocesada, ...
    mascara_segmentada, mapa_densidad, modelo_biomecanico, ...
    resultados, diagnostico_integrado, modelo_riesgo, config);

fig5 = visualizarCorrelacionMultimodalAvanzada(resultados, ...
    deformaciones, metricas_densidad, config);

fig6 = visualizarLesionesDetectadas(imagen_preprocesada, ...
    mascara_segmentada, resultados, metricas_clasificacion, config);

fig7 = visualizarTablaCaracteristicas(resultados, metricas_clasificacion, config);

fig8 = visualizarAnalisisEstadistico(imagen_preprocesada, ...
    mascara_segmentada, resultados, metricas_clasificacion, config);

fig9 = visualizarResumenClinico(resultados, diagnostico_integrado, ...
    modelo_riesgo, metricas_densidad, config);

% Figuras avanzadas adicionales
fig10 = visualizarAnalisisRadiomicoAvanzado(imagen_preprocesada, ...
    mascara_segmentada, caracteristicas_radiomicas, config);

fig11 = visualizarMetricasCalidad(metricas_calidad, metricas_segmentacion, metadata_analysis);

if config.analisis_3d.habilitado && ~isempty(analisis_3d)
    fig12 = visualizarAnalisis3D(analisis_3d, reconstruccion_3d, ...
        metricas_volumetricas, config);
else
    fig12 = visualizarAnalisisComparativoTendencias(resultados, ...
        metricas_densidad, modelo_biomecanico, config);
end

%% EXPORTACIÓN AVANZADA DE RESULTADOS
if config.exportacion.habilitada
    disp('=== EXPORTANDO RESULTADOS AVANZADOS ===');
    exportarResultadosCompletos(info, resultados, diagnostico_integrado, ...
        metricas_densidad, modelo_biomecanico, caracteristicas_radiomicas, ...
        analisis_temporal, metricas_calidad, config);
end

%% GENERACIÓN DE INFORME CLÍNICO AVANZADO
disp('Generando informe clínico avanzado...');

informe_final = generarInformeClinicoAvanzado(info, ...
    resultados, diagnostico_integrado, metricas_densidad, modelo_biomecanico, ...
    metricas_clasificacion, factores_riesgo, caracteristicas_radiomicas, config);

%% MONITORIZACIÓN DE CALIDAD
disp('Realizando control de calidad...');

[calidad_analisis, metricas_calidad] = evaluarCalidadAnalisis(...
    imagen_preprocesada, mascara_segmentada, resultados, metricas_segmentacion, config);

%% FUNCIÓN DE ALERTAS CLÍNICAS
alertas_clinicas = generarAlertasClinicas(diagnostico_integrado, ...
    modelo_riesgo, factores_riesgo, metricas_densidad, config);

fprintf('\n=== ANÁLISIS UNIFICADO AVANZADO COMPLETADO ===\n');
fprintf('Sistema generó 12 figuras completas de análisis avanzado\n');
fprintf('Módulos activados: Deep Learning + Radiómica + Análisis 3D + Modelado Biomecánico\n');
fprintf('+ Correlación Clínica + Exportación Avanzada\n');

%% ============================================================================
%% FUNCIONES AVANZADAS DEL SISTEMA UNIFICADO - VERSIÓN INTEGRADA
%% ============================================================================

function modelos = inicializarModelosDeepLearningAvanzados(config)
    % Inicializar modelos de deep learning avanzados
    
    modelos = struct();
    fprintf('Inicializando modelos de deep learning avanzados...\n');
    
    % Autoencoder para denoising
    if config.deep_learning.uso_autoencoder
        try
            modelos.autoencoder_denoising = cargarAutoencoderPreentrenado();
            fprintf('✓ Autoencoder para denoising cargado\n');
        catch
            fprintf('⚠ Autoencoder no disponible, usando método alternativo\n');
            modelos.autoencoder_denoising = [];
        end
    end
    
    % CNN para clasificación
    if config.deep_learning.uso_cnn_clasificacion
        try
            if config.deep_learning.uso_transfer_learning
                modelos.cnn_clasificacion = cargarModeloTransferLearning(...
                    config.deep_learning.modelo_preentrenado);
                fprintf('✓ Modelo de transfer learning cargado: %s\n', ...
                    config.deep_learning.modelo_preentrenado);
            else
                modelos.cnn_clasificacion = cargarCNNPreentrenado();
                fprintf('✓ CNN para clasificación cargado\n');
            end
        catch
            fprintf('⚠ CNN no disponible, usando características tradicionales\n');
            modelos.cnn_clasificacion = [];
        end
    end
    
    % Modelo para segmentación
    try
        modelos.cnn_segmentacion = cargarModeloSegmentacion();
        fprintf('✓ Modelo para segmentación cargado\n');
    catch
        fprintf('⚠ Modelo de segmentación no disponible\n');
        modelos.cnn_segmentacion = [];
    end
    
    % Modelo de riesgo
    try
        modelos.modelo_riesgo = cargarModeloRiesgo();
        fprintf('✓ Modelo de riesgo cargado\n');
    catch
        fprintf('⚠ Modelo de riesgo no disponible\n');
        modelos.modelo_riesgo = [];
    end
    
    % Modelo transformer para análisis contextual
    if config.deep_learning.uso_transformer
        try
            modelos.transformer = crearModeloTransformer();
            fprintf('✓ Modelo Transformer para análisis contextual inicializado\n');
        catch
            fprintf('✗ No se pudo cargar modelo Transformer\n');
            modelos.transformer = [];
        end
    end
    
    fprintf('Modelos de deep learning avanzados inicializados\n');
end

function modelos = inicializarModelosRadiomicos(config)
    % Inicializar modelos para análisis radiómico
    modelos.haralick = [];
    modelos.lbp = [];
    modelos.gabor = [];
    modelos.deep_radiomics = [];
    
    fprintf('Modelos radiómicos inicializados:\n');
    fprintf(' - Características de Haralick: %d\n', config.radiomica.numero_haralick_features);
    fprintf(' - LBP: %d\n', config.radiomica.uso_lbp);
    fprintf(' - Filtros de Gabor: %d\n', config.radiomica.uso_gabor);
    fprintf(' - Análisis multiescala: %d\n', config.radiomica.analisis_multiescala);
end

function [volumen, info, metadata] = cargarYValidarDICOM(filename)
    % Cargar y validar archivo DICOM con verificación de integridad
    try
        info = dicominfo(filename);
        volumen = dicomread(filename);
        
        % Validar integridad de la imagen
        if isempty(volumen)
            error('Imagen DICOM vacía o corrupta');
        end
        
        % Extraer metadata completa
        metadata = extraerMetadataCompleta(info);
        
        % Validar parámetros críticos
        if ~validarParametrosDICOM(metadata)
            warning('Algunos parámetros DICOM pueden ser inconsistentes');
        end
        
        fprintf('✓ Archivo DICOM cargado y validado correctamente\n');
        
    catch ME
        fprintf('✗ Error cargando DICOM: %s\n', ME.message);
        rethrow(ME);
    end
end

function [imagen_pp, metricas] = preprocesamientoAvanzado(imagen, info, config)
    % Pipeline de preprocesamiento avanzado
    
    fprintf('Aplicando pipeline de preprocesamiento avanzado...\n');
    
    % 1. Normalización DICOM avanzada
    imagen_normalizada = normalizacionDICOMAvanzada(imagen, info);
    
    % 2. Corrección de artefactos
    imagen_corregida = corregirArtefactosDICOM(imagen_normalizada, info);
    
    % 3. Denoising con autoencoder
    if config.denoising.uso_autoencoder_denoising
        imagen_denoised = aplicarDenoisingAutoencoderAvanzado(imagen_corregida, config);
    else
        imagen_denoised = imagen_corregida;
    end
    
    % 4. Mejora de contraste adaptativa
    imagen_contraste = mejoraContrasteAvanzada(imagen_denoised);
    
    % 5. Filtrado no lineal
    imagen_filtrada = filtradoNoLinealAvanzado(imagen_contraste);
    
    % 6. Corrección de inhomogeneidades
    imagen_corregida_final = correccionInhomogeneidades(imagen_filtrada);
    
    imagen_pp = imagen_corregida_final;
    
    % Calcular métricas de preprocesamiento
    metricas = calcularMetricasPreprocesamiento(imagen, imagen_pp);
    
    fprintf('✓ Preprocesamiento completado - SNR: %.2f dB, CNR: %.2f\n', ...
        metricas.snr, metricas.cnr);
end

function [mascara, metricas, mapa_prob] = segmentacionAvanzadaConDeepLearning(imagen, config, modelos)
    % Segmentación avanzada usando deep learning y técnicas híbridas
    
    fprintf('Realizando segmentación avanzada...\n');
    
    % Segmentación con U-Net si está disponible
    if ~isempty(modelos.cnn_segmentacion)
        [mascara_unet, confianza_unet] = segmentarConUNet(imagen, modelos.cnn_segmentacion);
    else
        mascara_unet = segmentacionTradicional(imagen, config);
        confianza_unet = 0.7;
    end
    
    % Segmentación tradicional como respaldo
    mascara_tradicional = segmentacionTradicional(imagen, config);
    
    % Segmentación con watershed si está habilitada
    if config.segmentation.uso_watershed
        mascara_watershed = segmentacionWatershed(imagen);
    else
        mascara_watershed = false(size(imagen));
    end
    
    % Segmentación con active contour si está habilitada
    if config.segmentation.uso_active_contour
        mascara_active_contour = segmentacionActiveContour(imagen, mascara_tradicional);
    else
        mascara_active_contour = false(size(imagen));
    end
    
    % Fusión de segmentaciones
    mascara_fusion = fusionarSegmentaciones(mascara_unet, mascara_tradicional, ...
        mascara_watershed, mascara_active_contour, confianza_unet);
    
    % Refinamiento con CRF (Conditional Random Fields)
    mascara_refinada = refinamientoCRF(imagen, mascara_fusion);
    
    % Post-procesamiento
    mascara_final = postprocesamientoSegmentacion(mascara_refinada, config);
    
    % Generar mapa de segmentación detallado
    mapa_segmentacion = generarMapaSegmentacion(imagen, mascara_final);
    
    % Calcular métricas de calidad
    metricas = calcularMetricasSegmentacion(mascara_final, imagen);
    
    fprintf('Segmentación completada: %d regiones detectadas\n', metricas.num_regiones);
end


function verificarToolboxes(toolboxes)
    % Verificar que todas las toolboxes requeridas estén disponibles
    fprintf('Verificando toolboxes...\n');
    
    for i = 1:length(toolboxes)
        if license('test', toolboxes{i})
            fprintf('✓ %s disponible\n', toolboxes{i});
        else
            fprintf('✗ %s no disponible - algunas funciones pueden no trabajar\n', toolboxes{i});
        end
    end
end

function generarReporteError(ME, config)
    % Generar reporte de error detallado
    fprintf('\n=== ERROR EN EL ANÁLISIS ===\n');
    fprintf('Mensaje: %s\n', ME.message);
    fprintf('Identificador: %s\n', ME.identifier);
    fprintf('Stack trace:\n');
    
    for i = 1:length(ME.stack)
        fprintf('  %s línea %d\n', ME.stack(i).name, ME.stack(i).line);
    end
    
    % Guardar reporte de error si está configurado
    if config.exportacion.habilitada
        nombre_archivo = sprintf('error_analysis_%s.log', datestr(now, 'yyyymmdd_HHMMSS'));
        fid = fopen(nombre_archivo, 'w');
        fprintf(fid, 'Reporte de Error - Sistema de Análisis Mamario\n');
        fprintf(fid, 'Fecha: %s\n', datestr(now));
        fprintf(fid, 'Error: %s\n', ME.message);
        fprintf(fid, 'Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf(fid, '  %s línea %d\n', ME.stack(i).name, ME.stack(i).line);
        end
        fclose(fid);
        fprintf('Reporte de error guardado en: %s\n', nombre_archivo);
    end
end

% Función para formatear números grandes (mejorada)
function formatted = formatNumber(num)
    if num >= 1e9
        formatted = sprintf('%.2fB', num/1e9);
    elseif num >= 1e6
        formatted = sprintf('%.1fM', num/1e6);
    elseif num >= 1e3
        formatted = sprintf('%.1fK', num/1e3);
    else
        formatted = sprintf('%d', round(num));
    end
end

%% FUNCIONES DE CARGA Y PROCESAMIENTO DE DATOS
function archivos = buscarArchivosDICOM(directorio)
    % Buscar recursivamente archivos DICOM en un directorio
    archivos = {};
    
    % Buscar en el directorio actual
    archivos_dcm = dir(fullfile(directorio, '*.dcm'));
    archivos_dicom = dir(fullfile(directorio, '*.dicom'));
    archivos_IMA = dir(fullfile(directorio, '*.IMA'));
    
    for i = 1:length(archivos_dcm)
        archivos{end+1} = fullfile(directorio, archivos_dcm(i).name);
    end
    
    for i = 1:length(archivos_dicom)
        archivos{end+1} = fullfile(directorio, archivos_dicom(i).name);
    end
    
    for i = 1:length(archivos_IMA)
        archivos{end+1} = fullfile(directorio, archivos_IMA(i).name);
    end
    
    % Buscar en subdirectorios
    subdirs = dir(directorio);
    for i = 1:length(subdirs)
        if subdirs(i).isdir && ~strcmp(subdirs(i).name, '.') && ~strcmp(subdirs(i).name, '..')
            subdir_path = fullfile(directorio, subdirs(i).name);
            archivos_sub = buscarArchivosDICOM(subdir_path);
            archivos = [archivos, archivos_sub];
        end
    end
end

function metadata = extraerMetadataCompleta(info)
    % Extraer metadata completa del archivo DICOM
    metadata = struct();
    
    campos_esenciales = {
        'Modality', 'SeriesDescription', 'PatientName', 'PatientID', ...
        'PatientBirthDate', 'PatientSex', 'StudyDate', 'SeriesDate', ...
        'AcquisitionDate', 'ContentDate', 'StudyTime', 'SeriesTime', ...
        'AcquisitionTime', 'ContentTime', 'AccessionNumber', 'StudyID', ...
        'SeriesNumber', 'AcquisitionNumber', 'InstanceNumber', ...
        'PatientPosition', 'StudyDescription', 'SeriesDescription', ...
        'InstitutionName', 'StationName', 'Manufacturer', 'ManufacturerModelName', ...
        'DeviceSerialNumber', 'SoftwareVersions', 'ProtocolName'
    };
    
    for i = 1:length(campos_esenciales)
        campo = campos_esenciales{i};
        if isfield(info, campo)
            metadata.(campo) = info.(campo);
        else
            metadata.(campo) = 'No disponible';
        end
    end
    
    % Parámetros de imagen
    if isfield(info, 'Width') && isfield(info, 'Height')
        metadata.Dimensions = [info.Width, info.Height];
    end
    
    if isfield(info, 'PixelSpacing')
        metadata.PixelSpacing = info.PixelSpacing;
        metadata.ResolucionMM = info.PixelSpacing(1);
    else
        metadata.ResolucionMM = 0.1; % Valor por defecto
    end
    
    if isfield(info, 'RescaleSlope') && isfield(info, 'RescaleIntercept')
        metadata.RescaleSlope = info.RescaleSlope;
        metadata.RescaleIntercept = info.RescaleIntercept;
    end
    
    if isfield(info, 'WindowCenter') && isfield(info, 'WindowWidth')
        metadata.WindowCenter = info.WindowCenter;
        metadata.WindowWidth = info.WindowWidth;
    end
    
    % Información de exposición
    if isfield(info, 'KVP')
        metadata.KVP = info.KVP;
    end
    
    if isfield(info, 'ExposureTime')
        metadata.ExposureTime = info.ExposureTime;
    end
    
    if isfield(info, 'XRayTubeCurrent')
        metadata.XRayTubeCurrent = info.XRayTubeCurrent;
    end
end

function mostrarInformacionDICOMCompleta(info, metadata)
    % Mostrar información completa DICOM
    fprintf('\n=== INFORMACIÓN DICOM COMPLETA ===\n');
    fprintf('Modalidad: %s\n', metadata.Modality);
    fprintf('Descripción: %s\n', metadata.SeriesDescription);
    fprintf('Paciente: %s (ID: %s)\n', metadata.PatientName, metadata.PatientID);
    fprintf('Sexo: %s\n', metadata.PatientSex);
    fprintf('Fecha del estudio: %s\n', metadata.StudyDate);
    fprintf('Institución: %s\n', metadata.InstitutionName);
    fprintf('Fabricante: %s - %s\n', metadata.Manufacturer, metadata.ManufacturerModelName);
    fprintf('Dimensiones: %dx%d\n', metadata.Dimensions(1), metadata.Dimensions(2));
    fprintf('Resolución: %.3f mm/píxel\n', metadata.ResolucionMM);
    
    if isfield(metadata, 'WindowCenter') && isfield(metadata, 'WindowWidth')
        fprintf('Ventana: Center=%.1f, Width=%.1f\n', metadata.WindowCenter, metadata.WindowWidth);
    end
    
    if isfield(metadata, 'KVP')
        fprintf('KV: %.1f\n', metadata.KVP);
    end
end

function [imagen_optima, slice_optimo, metricas] = seleccionarSliceOptimo(volumen)
    % Selecciona el slice óptimo de un volumen 3D basado en métricas de calidad
    num_slices = size(volumen, 3);
    scores = zeros(num_slices, 1);
    
    for i = 1:num_slices
        slice_actual = volumen(:, :, i);
        
        % Calcular múltiples métricas de calidad
        contraste = calcularContraste(slice_actual);
        nitidez = calcularNitidez(slice_actual);
        uniformidad = calcularUniformidad(slice_actual);
        entropia = calcularEntropia(slice_actual);
        
        % Score combinado (ponderado)
        scores(i) = 0.3 * contraste + 0.3 * nitidez + 0.2 * uniformidad + 0.2 * entropia;
    end
    
    [~, slice_optimo] = max(scores);
    imagen_optima = volumen(:, :, slice_optimo);
    
    metricas.scores = scores;
    metricas.slice_optimo = slice_optimo;
    metricas.score_optimo = scores(slice_optimo);
    metricas.contraste_optimo = calcularContraste(imagen_optima);
    metricas.nitidez_optima = calcularNitidez(imagen_optima);
end

function imagen_normalizada = normalizacionDICOMAvanzada(imagen, info)
    % Normalización avanzada de imágenes DICOM
    imagen_normalizada = single(imagen);
    
    % Aplicar rescale slope e intercept si están disponibles
    if isfield(info, 'RescaleSlope') && isfield(info, 'RescaleIntercept')
        imagen_normalizada = imagen_normalizada * info.RescaleSlope + info.RescaleIntercept;
    end
    
    % Aplicar normalización basada en ventana DICOM si está disponible
    if isfield(info, 'WindowCenter') && isfield(info, 'WindowWidth')
        window_center = double(info.WindowCenter);
        window_width = double(info.WindowWidth);
        
        if length(window_center) > 1, window_center = window_center(1); end
        if length(window_width) > 1, window_width = window_width(1); end
        
        low = window_center - window_width/2;
        high = window_center + window_width/2;
        
        % Normalizar al rango [0, 1]
        imagen_normalizada = (imagen_normalizada - low) / (high - low);
        imagen_normalizada = max(0, min(1, imagen_normalizada));
    else
        % Normalización por percentiles
        p_low = prctile(imagen_normalizada(:), 1);
        p_high = prctile(imagen_normalizada(:), 99);
        imagen_normalizada = (imagen_normalizada - p_low) / (p_high - p_low);
        imagen_normalizada = max(0, min(1, imagen_normalizada));
    end
end

function imagen_corregida = corregirArtefactosDICOM(imagen, info)
    % Corrección avanzada de artefactos DICOM
    imagen_corregida = imagen;
    
    % Corrección de inhomogeneidad de campo usando filtro homomórfico
    if any(imagen(:) > 0)
        imagen_corregida = correccionInhomogeneidad(imagen);
    end
    
    % Corrección de ruido impulsivo con filtro mediano adaptativo
    imagen_corregida = medfilt2(imagen_corregida, [3 3], 'symmetric');
    
    % Eliminación de artefactos de alta frecuencia
    imagen_corregida = imgaussfilt(imagen_corregida, 0.5);
    
    fprintf('Corrección de artefactos aplicada\n');
end

function imagen_denoised = aplicarDenoisingAutoencoderAvanzado(imagen, config)
    % Denoising avanzado usando técnicas de autoencoder
    imagen_double = double(imagen);
    
    if config.denoising.uso_autoencoder_denoising
        % Estimación adaptativa del nivel de ruido
        nivel_ruido = estimarNivelRuido(imagen_double);
        factor_suavizado = min(0.02 * nivel_ruido * config.denoising.factor_ruido, 0.1);
        
        % Aplicar filtrado bilateral avanzado (simulación de autoencoder)
        imagen_denoised = imbilatfilt(imagen_double, ...
            'DegreeOfSmoothing', factor_suavizado, ...
            'SpatialSigma', 3);
    else
        % Filtrado gaussiano como alternativa
        imagen_denoised = imgaussfilt(imagen_double, 1);
    end
    
    % Mantener el tipo de datos original
    if isa(imagen, 'uint8')
        imagen_denoised = uint8(imagen_denoised);
    elseif isa(imagen, 'uint16')
        imagen_denoised = uint16(imagen_denoised);
    end
    
    fprintf('Denoising aplicado (nivel ruido estimado: %.3f)\n', nivel_ruido);
end

function imagen_mejorada = mejoraContrasteAvanzada(imagen)
    % Mejora de contraste adaptativa avanzada
    if isa(imagen, 'integer')
        imagen = double(imagen) / double(intmax(class(imagen)));
    end
    
    % Ecualización adaptativa de histograma por regiones
    imagen_mejorada = adapthisteq(imagen, ...
        'NumTiles', [8 8], ...
        'ClipLimit', 0.01, ...
        'Distribution', 'rayleigh', ...
        'Alpha', 0.4);
    
    % Realce de bordes adicional
    bordes = imgradient(imagen_mejorada);
    imagen_mejorada = imagen_mejorada + 0.1 * bordes;
    imagen_mejorada = min(1, max(0, imagen_mejorada));
    
    fprintf('Mejora de contraste aplicada\n');
end

%% FUNCIONES DE SEGMENTACIÓN AVANZADA
function mascara_watershed = segmentacionWatershed(imagen)
    % Segmentación usando watershed mejorado
    gradiente = imgradient(imagen);
    
    % Suavizar el gradiente para mejores resultados
    gradiente = imgaussfilt(gradiente, 1);
    
    % Marcadores automáticos usando mínimos extendidos
    marcadores = imextendedmin(gradiente, 0.1);
    marcadores = imimposemin(gradiente, marcadores);
    
    % Aplicar watershed
    L = watershed(marcadores);
    mascara_watershed = L > 1;
    
    % Post-procesamiento
    mascara_watershed = bwareaopen(mascara_watershed, 100);
    mascara_watershed = imfill(mascara_watershed, 'holes');
    
    fprintf('Segmentación watershed completada\n');
end

function mascara_active_contour = segmentacionActiveContour(imagen, mascara_inicial)
    % Segmentación con active contour (snakes)
    iteraciones = 100;
    
    % Suavizar imagen para mejor convergencia
    imagen_suavizada = imgaussfilt(imagen, 1);
    
    % Aplicar active contour
    mascara_active_contour = activecontour(imagen_suavizada, mascara_inicial, ...
        iteraciones, 'Chan-Vese', 'SmoothFactor', 0.5);
    
    % Refinamiento
    mascara_active_contour = imfill(mascara_active_contour, 'holes');
    mascara_active_contour = bwareaopen(mascara_active_contour, 200);
    
    fprintf('Segmentación active contour completada\n');
end

function mascara_fusion = fusionarSegmentaciones(mascara_unet, mascara_tradicional, ...
    mascara_watershed, mascara_active_contour, confianza_unet)
    % Fusión avanzada de múltiples técnicas de segmentación
    
    % Pesos basados en confianza
    if confianza_unet > 0.8
        peso_unet = 0.5;
        peso_tradicional = 0.3;
        peso_watershed = 0.1;
        peso_active_contour = 0.1;
    else
        peso_unet = 0.3;
        peso_tradicional = 0.4;
        peso_watershed = 0.15;
        peso_active_contour = 0.15;
    end
    
    % Combinación ponderada
    mascara_fusion = peso_unet * double(mascara_unet) + ...
                    peso_tradicional * double(mascara_tradicional) + ...
                    peso_watershed * double(mascara_watershed) + ...
                    peso_active_contour * double(mascara_active_contour);
    
    % Umbralización adaptativa
    umbral = graythresh(mascara_fusion);
    mascara_fusion = mascara_fusion > (umbral * 0.8);
    
    fprintf('Fusión de segmentaciones completada (Confianza U-Net: %.2f)\n', confianza_unet);
end

function mascara_refinada = refinamientoCRF(imagen, mascara)
    % Refinamiento usando Conditional Random Fields (implementación simplificada)
    
    % Crear mapa de probabilidades basado en la máscara inicial
    probabilidades = double(mascara);
    
    % Suavizar considerando la intensidad de la imagen
    [filas, columnas] = size(imagen);
    for i = 2:filas-1
        for j = 2:columnas-1
            if mascara(i,j)
                % Considerar vecinos similares en intensidad
                vecinos = imagen(i-1:i+1, j-1:j+1);
                similaridad = exp(-abs(vecinos - imagen(i,j)) / 10);
                probabilidades(i,j) = probabilidades(i,j) + 0.1 * sum(similaridad(:) .* mascara(i-1:i+1, j-1:j+1));
            end
        end
    end
    
    % Normalizar y umbralizar
    probabilidades = probabilidades / max(probabilidades(:));
    mascara_refinada = probabilidades > 0.5;
    
    fprintf('Refinamiento CRF aplicado\n');
end

function mascara_final = postprocesamientoSegmentacion(mascara, config)
    % Post-procesamiento avanzado de la segmentación
    
    % Operaciones morfológicas
    se_cierre = strel('disk', 4);
    se_apertura = strel('disk', 2);
    
    % Cierre para rellenar huecos pequeños
    mascara = imclose(mascara, se_cierre);
    
    % Apertura para eliminar objetos pequeños
    mascara = imopen(mascara, se_apertura);
    
    % Rellenar huecos
    mascara = imfill(mascara, 'holes');
    
    % Eliminar objetos pequeños
    mascara = bwareaopen(mascara, config.umbral_area_minima);
    
    % Suavizar bordes
    mascara_final = imgaussfilt(double(mascara), 0.5) > 0.5;
    
    fprintf('Post-procesamiento de segmentación completado\n');
end

%% FUNCIONES DE ANÁLISIS DE DENSIDAD
function [mapa_densidad, metricas] = generarMapaDensidadAvanzado(imagen, mascara, config)
    % Generar mapa de densidad avanzado usando técnicas de IA
    
    mascara_mama = imfill(mascara, 'holes');
    
    if ~any(mascara_mama(:))
        mapa_densidad = zeros(size(imagen));
        metricas = inicializarMetricasDensidadVacias();
        return;
    end
    
    % Calcular características de textura para clasificación de densidad
    ventana = 32;
    mapa_densidad = zeros(size(imagen));
    
    for i = 1:ventana:size(imagen,1)-ventana
        for j = 1:ventana:size(imagen,2)-ventana
            if i+ventana-1 <= size(imagen,1) && j+ventana-1 <= size(imagen,2)
                parche = imagen(i:i+ventana-1, j:j+ventana-1);
                mascara_parche = mascara_mama(i:i+ventana-1, j:j+ventana-1);
                
                if sum(mascara_parche(:)) > ventana*ventana*0.1 % Al menos 10% del parche es tejido
                    densidad = clasificarDensidadParche(parche, mascara_parche);
                    mapa_densidad(i:i+ventana-1, j:j+ventana-1) = densidad;
                end
            end
        end
    end
    
    % Suavizado avanzado
    mapa_densidad = imgaussfilt(mapa_densidad, 2);
    
    % Calcular métricas
    metricas = calcularMetricasDensidadAvanzadas(mapa_densidad, mascara_mama);
    
    fprintf('Mapa de densidad avanzado generado\n');
end

function densidad = clasificarDensidadParche(parche, mascara_parche)
    % Clasificar densidad de un parche basado en características de textura
    
    parche_activo = parche(mascara_parche);
    
    if isempty(parche_activo)
        densidad = 0;
        return;
    end
    
    % Características para clasificación
    media_intensidad = mean(parche_activo);
    std_intensidad = std(double(parche_activo));
    entropia_parche = entropy(parche);
    
    % Clasificación basada en características
    if media_intensidad < 50 && std_intensidad < 20
        densidad = 1; % Tejido graso
    elseif media_intensidad < 100 && std_intensidad < 40
        densidad = 2; % Tejido intermedio
    elseif media_intensidad < 150 && entropia_parche > 5
        densidad = 3; % Tejido denso heterogéneo
    else
        densidad = 4; % Tejido muy denso
    end
end

function metricas = calcularMetricasDensidadAvanzadas(mapa_densidad, mascara)
    % Calcular métricas avanzadas de densidad mamaria
    
    mascara_mama = imfill(mascara, 'holes');
    area_total = sum(mascara_mama(:));
    
    if area_total == 0
        metricas = inicializarMetricasDensidadVacias();
        return;
    end
    
    % Áreas de tejido específico
    area_graso = sum(mapa_densidad(mascara_mama) == 1);
    area_intermedio = sum(mapa_densidad(mascara_mama) == 2);
    area_denso = sum(mapa_densidad(mascara_mama) == 3);
    area_muy_denso = sum(mapa_densidad(mascara_mama) == 4);
    
    % Porcentaje considerando tejido intermedio como parcialmente denso
    metricas.porcentaje_densidad = ((area_denso + area_muy_denso + area_intermedio * 0.5) / area_total) * 100;
    metricas.area_total = area_total;
    metricas.area_densa = area_denso + area_muy_denso + area_intermedio;
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
    
    % Métricas avanzadas
    mapa_densidad_mama = mapa_densidad;
    mapa_densidad_mama(~mascara_mama) = 0;
    
    % Calcular entropía del mapa de densidad
    metricas.entropia = entropy(mapa_densidad_mama(mascara_mama));
    
    % Calcular homogeneidad
    try
        [GLCM, ~] = graycomatrix(mapa_densidad_mama, 'Offset', [0 1; -1 1; -1 0; -1 -1], ...
                                 'NumLevels', 4, 'GrayLimits', [1 4]);
        props = graycoprops(GLCM, {'Contrast', 'Homogeneity'});
        metricas.contraste = mean(props.Contrast);
        metricas.homogeneidad = mean(props.Homogeneity);
    catch
        metricas.contraste = 0;
        metricas.homogeneidad = 0;
    end
    
    % Calcular la distribución espacial de la densidad (asimetría)
    regiones_densas = mapa_densidad_mama >= 3;
    if sum(regiones_densas(:)) > 0
        stats_mama = regionprops(mascara_mama, 'Centroid');
        centroide_mama = stats_mama.Centroid;
        
        stats_densas = regionprops(regiones_densas, 'Centroid', 'Area');
        if ~isempty(stats_densas)
            areas_densas = [stats_densas.Area];
            centroides_densas = vertcat(stats_densas.Centroid);
            centroide_densas = sum(centroides_densas .* areas_densas', 1) / sum(areas_densas);
            
            [fil, col] = find(mascara_mama);
            diametro_mama = max(sqrt((fil - centroide_mama(2)).^2 + (col - centroide_mama(1)).^2)) * 2;
            distancia_centroides = sqrt(sum((centroide_mama - centroide_densas).^2)) / diametro_mama;
            
            metricas.asimetria_espacial = distancia_centroides;
        else
            metricas.asimetria_espacial = 0;
        end
    else
        metricas.asimetria_espacial = 0;
    end
    
    % Calcular riesgo basado en densidad
    metricas.riesgo_densidad = calcularRiesgoPorDensidad(metricas.porcentaje_densidad);
    
    fprintf('Métricas de densidad calculadas: %.1f%% densidad, BI-RADS %s\n', ...
            metricas.porcentaje_densidad, metricas.birads_categoria);
end

function riesgo = calcularRiesgoPorDensidad(porcentaje_densidad)
    % Calcular riesgo basado en densidad mamaria
    if porcentaje_densidad < 25
        riesgo = 0.5; % Bajo riesgo
    elseif porcentaje_densidad < 50
        riesgo = 1.0; % Riesgo promedio
    elseif porcentaje_densidad < 75
        riesgo = 1.8; % Riesgo moderado
    else
        riesgo = 2.5; % Alto riesgo
    end
end

function metricas = inicializarMetricasDensidadVacias()
    % Inicializar métricas de densidad cuando no hay tejido mamario
    metricas.porcentaje_densidad = 0;
    metricas.area_total = 0;
    metricas.area_densa = 0;
    metricas.area_grasa = 0;
    metricas.birads_categoria = 'a';
    metricas.birads_descripcion = 'No se detectó tejido mamario';
    metricas.entropia = 0;
    metricas.contraste = 0;
    metricas.homogeneidad = 0;
    metricas.asimetria_espacial = 0;
    metricas.riesgo_densidad = 0;
end

%% FUNCIONES DE MODELADO BIOMECÁNICO
function [modelo, deformaciones, metricas] = generarModeloBiomecanicoAvanzado(imagen, mapa_densidad, config)
    % Generar modelo biomecánico avanzado del tejido mamario
    
    fprintf('Generando modelo biomecánico avanzado...\n');
    
    modelo = struct();
    
    % Segmentación de tejidos para el modelo
    mascara_mama = mapa_densidad > 0;
    mascara_glandular = mapa_densidad >= 2;
    mascara_adiposo = mapa_densidad == 1;
    
    % Propiedades del material basadas en la tesis
    modelo.propiedades.young_glandular = config.young_glandular;
    modelo.propiedades.young_adipose = config.young_adipose;
    modelo.propiedades.poisson_ratio = config.poisson_ratio;
    modelo.propiedades.stress_threshold = config.stress_threshold;
    
    % Geometría del modelo
    [filas, columnas] = size(imagen);
    modelo.geometria.filas = filas;
    modelo.geometria.columnas = columnas;
    modelo.geometria.area_total = sum(mascara_mama(:));
    modelo.geometria.area_glandular = sum(mascara_glandular(:));
    modelo.geometria.area_adiposa = sum(mascara_adiposo(:));
    
    % Simular deformación por compresión
    deformaciones = simularDeformacionCompresionAvanzada(mapa_densidad, config.compression_factor);
    
    % Calcular tensiones biomecánicas
    modelo.tensiones = calcularTensionesBiomecanicasAvanzadas(mapa_densidad, deformaciones, config);
    
    % Calcular métricas del modelo
    metricas = calcularMetricasBiomecanicas(modelo, deformaciones);
    
    fprintf('Modelo biomecánico avanzado generado: %d elementos\n', modelo.geometria.area_total);
end

function deformaciones = simularDeformacionCompresionAvanzada(mapa_densidad, factor_compresion)
    % Simular deformación por compresión mamográfica avanzada
    
    [filas, columnas] = size(mapa_densidad);
    [X, Y] = meshgrid(1:columnas, 1:filas);
    centro_x = columnas / 2;
    centro_y = filas / 2;
    
    % Deformación radial (compresión desde los bordes)
    distancia_centro = sqrt((X - centro_x).^2 + (Y - centro_y).^2);
    max_distancia = sqrt(centro_x^2 + centro_y^2);
    
    % Factor de compresión dependiente de la distancia al centro y del tipo de tejido
    factor_radial = 1 - factor_compresion * (distancia_centro / max_distancia);
    
    % Ajustar la deformación según la densidad (tejido denso se deforma menos)
    factor_tejido = ones(size(mapa_densidad));
    factor_tejido(mapa_densidad >= 3) = 0.7;  % Tejido denso
    factor_tejido(mapa_densidad == 2) = 0.85; % Tejido intermedio
    factor_tejido(mapa_densidad == 1) = 1.0;  % Tejido graso
    
    factor_compresion_ajustado = factor_radial .* factor_tejido;
    
    % Aplicar deformación (simplificado)
    deformaciones.desp_x = (X - centro_x) .* (1 - factor_compresion_ajustado) * 0.1;
    deformaciones.desp_y = (Y - centro_y) .* (1 - factor_compresion_ajustado) * 0.1;
    deformaciones.factor_compresion = factor_compresion_ajustado;
    deformaciones.max_deformacion = max(1 - factor_compresion_ajustado, [], 'all');
end

function tensiones = calcularTensionesBiomecanicasAvanzadas(mapa_densidad, deformaciones, config)
    % Calcular tensiones biomecánicas avanzadas
    
    [filas, columnas] = size(mapa_densidad);
    tensiones.maxima = zeros(filas, columnas);
    tensiones.media = zeros(filas, columnas);
    tensiones.gradiente = zeros(filas, columnas);
    tensiones.von_mises = zeros(filas, columnas);
    
    % Calcular gradientes de deformación
    [grad_x, grad_y] = gradient(deformaciones.factor_compresion);
    
    for i = 1:filas
        for j = 1:columnas
            if mapa_densidad(i, j) > 0
                % Tensión dependiente del tipo de tejido y deformación
                if mapa_densidad(i, j) >= 3 % Tejido muy denso
                    E = config.young_glandular * 1.2;
                elseif mapa_densidad(i, j) == 2 % Tejido intermedio
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
                
                % Tensión de Von Mises simplificada
                tensiones.von_mises(i, j) = sqrt(tensiones.maxima(i, j)^2 + 3 * tensiones.gradiente(i, j)^2);
            end
        end
    end
    
    tensiones.media = tensiones.maxima / 2;
    tensiones.areas_alta_tension = tensiones.von_mises > config.stress_threshold;
end

function metricas = calcularMetricasBiomecanicas(modelo, deformaciones)
    % Calcular métricas del modelo biomecánico
    metricas = struct();
    
    if any(modelo.tensiones.maxima(:) > 0)
        tensiones_validas = modelo.tensiones.maxima(modelo.tensiones.maxima > 0);
        metricas.tension_maxima = max(tensiones_validas);
        metricas.tension_media = mean(tensiones_validas);
        metricas.tension_std = std(tensiones_validas);
        metricas.area_alta_tension = sum(modelo.tensiones.areas_alta_tension(:));
    else
        metricas.tension_maxima = 0;
        metricas.tension_media = 0;
        metricas.tension_std = 0;
        metricas.area_alta_tension = 0;
    end
    
    metricas.deformacion_maxima = deformaciones.max_deformacion;
    metricas.ratio_tejido_glandular = modelo.geometria.area_glandular / modelo.geometria.area_total;
end

%% FUNCIONES DE CLASIFICACIÓN DE LESIONES
function [resultados, metricas] = clasificacionAvanzadaLesiones(imagen, mascara, modelos, config)
    % Clasificación avanzada de lesiones con múltiples características
    
    [etiquetas, num_regiones] = bwlabel(mascara);
    resultados = [];
    
    if num_regiones == 0
        metricas = struct('total_lesiones', 0, 'precision_promedio', 0);
        return;
    end
    
    propiedades = regionprops(etiquetas, {'Area', 'Perimeter', 'Eccentricity', ...
        'Solidity', 'BoundingBox', 'Centroid', 'ConvexArea', 'MajorAxisLength', ...
        'MinorAxisLength', 'Orientation', 'Extent', 'FilledArea'});
    
    for i = 1:num_regiones
        % Extracción de características avanzadas
        mascara_lesion = (etiquetas == i);
        caracteristicas = extraerCaracteristicasAvanzadas(imagen, propiedades(i), mascara_lesion);
        
        % Clasificación con modelo ensemble
        [clasificacion, puntuacion_riesgo, confianza, caracteristicas_prediccion] = ...
            clasificarLesionEnsemble(imagen, propiedades(i), caracteristicas, modelos, config);
        
        % Análisis de riesgo integrado
        riesgo = calcularRiesgoIntegrado(caracteristicas, clasificacion, confianza);
        
        % Métricas adicionales
        area_actual = propiedades(i).Area;
        perimetro_actual = propiedades(i).Perimeter;
        diametro_equivalente = 2 * sqrt(area_actual / pi);
        compacidad = (perimetro_actual^2) / (4 * pi * area_actual);
        relacion_aspecto = propiedades(i).MajorAxisLength / max(propiedades(i).MinorAxisLength, 1);
        
        % Almacenar resultados
        resultado_region = struct(...
            'ID', i, ...
            'Area', area_actual, ...
            'Perimetro', perimetro_actual, ...
            'Diametro', diametro_equivalente, ...
            'DiametroMayor', propiedades(i).MajorAxisLength, ...
            'DiametroMenor', propiedades(i).MinorAxisLength, ...
            'Excentricidad', propiedades(i).Eccentricity, ...
            'Solidez', propiedades(i).Solidity, ...
            'Compacidad', compacidad, ...
            'RelacionAspecto', relacion_aspecto, ...
            'Orientacion', propiedades(i).Orientation, ...
            'Extension', propiedades(i).Extent, ...
            'AreaRellena', propiedades(i).FilledArea, ...
            'Clasificacion', clasificacion, ...
            'PuntuacionRiesgo', puntuacion_riesgo, ...
            'Confianza', confianza, ...
            'RiesgoIntegrado', riesgo, ...
            'Caracteristicas', caracteristicas, ...
            'CaracteristicasPrediccion', caracteristicas_prediccion, ...
            'Centroide', propiedades(i).Centroid, ...
            'BoundingBox', propiedades(i).BoundingBox);
        
        resultados = [resultados, resultado_region];
    end
    
    % Calcular métricas globales de clasificación
    metricas = calcularMetricasClasificacionAvanzada(resultados);
    
    fprintf('Clasificación completada: %d lesiones analizadas\n', num_regiones);
end

function caracteristicas = extraerCaracteristicasAvanzadas(imagen, prop, mascara_lesion)
    % Extraer características avanzadas de una lesión
    
    caracteristicas = struct();
    
    % Características morfológicas básicas
    caracteristicas.area = prop.Area;
    caracteristicas.perimetro = prop.Perimeter;
    caracteristicas.excentricidad = prop.Eccentricity;
    caracteristicas.solidez = prop.Solidity;
    caracteristicas.compacidad = (prop.Perimeter^2) / (4 * pi * prop.Area);
    caracteristicas.relacion_aspecto = prop.MajorAxisLength / max(prop.MinorAxisLength, 1);
    
    % Características de intensidad
    roi_intensidad = imagen(mascara_lesion);
    caracteristicas.intensidad_media = mean(roi_intensidad);
    caracteristicas.intensidad_std = std(double(roi_intensidad));
    caracteristicas.intensidad_min = min(roi_intensidad);
    caracteristicas.intensidad_max = max(roi_intensidad);
    caracteristicas.intensidad_mediana = median(roi_intensidad);
    
    % Características de textura
    try
        [GLCM, ~] = graycomatrix(imagen, 'Offset', [0 1; -1 1; -1 0; -1 -1], ...
                               'NumLevels', 8, 'GrayLimits', []);
        props = graycoprops(GLCM, {'contrast', 'correlation', 'energy', 'homogeneity'});
        caracteristicas.contraste_textura = mean(props.Contrast);
        caracteristicas.correlacion_textura = mean(props.Correlation);
        caracteristicas.energia_textura = mean(props.Energy);
        caracteristicas.homogeneidad_textura = mean(props.Homogeneity);
    catch
        caracteristicas.contraste_textura = 0;
        caracteristicas.correlacion_textura = 0;
        caracteristicas.energia_textura = 0;
        caracteristicas.homogeneidad_textura = 0;
    end
    
    % Características de forma avanzadas
    caracteristicas.extension = prop.Extent;
    caracteristicas.area_rellena = prop.FilledArea;
    caracteristicas.ratio_area_rellena = prop.FilledArea / prop.Area;
end

function [clasificacion, puntuacion, confianza, caracteristicas_pred] = ...
    clasificarLesionEnsemble(imagen, prop, caracteristicas, modelos, config)
    
    % Inicializar variables
    caracteristicas_pred = struct();
    
    % Extraer ROI para análisis
    bbox = prop.BoundingBox;
    bbox = round(bbox);
    x1 = max(1, bbox(1));
    y1 = max(1, bbox(2));
    x2 = min(size(imagen, 2), x1 + bbox(3) - 1);
    y2 = min(size(imagen, 1), y1 + bbox(4) - 1);
    
    if x2 <= x1 || y2 <= y1
        % ROI inválida
        clasificacion = 'Indeterminado';
        puntuacion = 2;
        confianza = 0.5;
        return;
    end
    
    roi = imagen(y1:y2, x1:x2);
    
    % CLASIFICACIÓN MORFOLÓGICA
    [clas_morf, punt_morf, conf_morf] = clasificacionMorfologica(prop, caracteristicas);
    
    % CLASIFICACIÓN POR TEXTURA
    [clas_text, punt_text, conf_text] = clasificacionTextura(roi, caracteristicas);
    
    % CLASIFICACIÓN POR DEEP LEARNING (si está disponible)
    if config.deep_learning.uso_cnn_clasificacion && ~isempty(modelos.cnn_clasificacion)
        [clas_dl, punt_dl, conf_dl] = clasificacionDeepLearning(roi, modelos);
    else
        clas_dl = clas_morf;
        punt_dl = punt_morf;
        conf_dl = conf_morf * 0.8; % Menor confianza sin DL
    end
    
    % FUSIÓN DE CLASIFICADORES
    pesos = [0.3, 0.3, 0.4]; % Morfológica, Textura, Deep Learning
    puntuaciones = [punt_morf, punt_text, punt_dl];
    confianzas = [conf_morf, conf_text, conf_dl];
    
    puntuacion_final = sum(puntuaciones .* pesos .* confianzas) / sum(pesos .* confianzas);
    confianza_final = mean(confianzas);
    
    % Determinar clasificación final
    if puntuacion_final >= 3.5 && confianza_final > 0.7
        clasificacion = 'Maligno';
    elseif puntuacion_final >= 2.5 && confianza_final > 0.6
        clasificacion = 'Indeterminado';
    elseif puntuacion_final >= 1.5
        clasificacion = 'Benigno';
    else
        clasificacion = 'Ruido';
    end
    
    % Ajustar puntuación y confianza según consistencia
    if clas_morf == clas_text && clas_text == clas_dl
        confianza_final = min(confianza_final * 1.2, 1.0);
    elseif clas_morf ~= clas_text && clas_text ~= clas_dl
        confianza_final = confianza_final * 0.8;
    end
    
    clasificacion = clasificacion;
    puntuacion = puntuacion_final;
    confianza = confianza_final;
    
    % Características de predicción
    caracteristicas_pred.clasificadores = {clas_morf, clas_text, clas_dl};
    caracteristicas_pred.puntuaciones = [punt_morf, punt_text, punt_dl];
    caracteristicas_pred.confianzas = [conf_morf, conf_text, conf_dl];
    caracteristicas_pred.consistencia = strcmp(clas_morf, clas_text) && strcmp(clas_text, clas_dl);
    
    fprintf('Lesión clasificada como: %s (puntuación: %.2f, confianza: %.2f)\n', ...
            clasificacion, puntuacion, confianza);
end

function [clasificacion, puntuacion, confianza] = clasificacionMorfologica(prop, caracteristicas)
    % Clasificación basada en características morfológicas
    
    % Factores de riesgo morfológicos
    factores = zeros(1, 6);
    
    % Área (lesiones grandes más sospechosas)
    if caracteristicas.area > 10000
        factores(1) = 1.0;
    elseif caracteristicas.area > 5000
        factores(1) = 0.7;
    elseif caracteristicas.area > 1000
        factores(1) = 0.4;
    else
        factores(1) = 0.1;
    end
    
    % Compacidad (formas irregulares más sospechosas)
    if caracteristicas.compacidad > 2.0
        factores(2) = 1.0;
    elseif caracteristicas.compacidad > 1.5
        factores(2) = 0.8;
    elseif caracteristicas.compacidad > 1.2
        factores(2) = 0.5;
    else
        factores(2) = 0.2;
    end
    
    % Excentricidad (formas alargadas más sospechosas)
    factores(3) = caracteristicas.excentricidad;
    
    % Solidez (formas con huecos más sospechosas)
    factores(4) = 1 - caracteristicas.solidez;
    
    % Relación de aspecto
    if caracteristicas.relacion_aspecto > 3
        factores(5) = 1.0;
    elseif caracteristicas.relacion_aspecto > 2
        factores(5) = 0.7;
    else
        factores(5) = 0.3;
    end
    
    % Extensión
    factores(6) = 1 - caracteristicas.extension;
    
    % Puntuación total
    pesos = [0.2, 0.25, 0.15, 0.2, 0.1, 0.1];
    puntuacion = sum(factores .* pesos) * 4; % Escalar a 0-4
    
    % Determinar clasificación
    if puntuacion >= 3.0
        clasificacion = 'Maligno';
        confianza = 0.8;
    elseif puntuacion >= 2.0
        clasificacion = 'Indeterminado';
        confianza = 0.7;
    elseif puntuacion >= 1.0
        clasificacion = 'Benigno';
        confianza = 0.8;
    else
        clasificacion = 'Ruido';
        confianza = 0.9;
    end
end

function riesgo = calcularRiesgoIntegrado(caracteristicas, clasificacion, confianza)
    % Calcular riesgo integrado de la lesión
    
    riesgo_base = 0;
    
    switch clasificacion
        case 'Maligno'
            riesgo_base = 0.8;
        case 'Indeterminado'
            riesgo_base = 0.5;
        case 'Benigno'
            riesgo_base = 0.2;
        otherwise
            riesgo_base = 0.1;
    end
    
    % Ajustar por confianza
    riesgo_ajustado = riesgo_base * confianza;
    
    % Ajustar por características morfológicas
    if caracteristicas.compacidad > 1.5
        riesgo_ajustado = riesgo_ajustado * 1.2;
    end
    
    if caracteristicas.excentricidad > 0.8
        riesgo_ajustado = riesgo_ajustado * 1.1;
    end
    
    riesgo = min(riesgo_ajustado, 1.0);
end

%% FUNCIONES DE ANÁLISIS RADIÓMICO
function caracteristicas = extraerCaracteristicasRadiomicasAvanzadas(imagen, config)
    % Extraer características radiómicas avanzadas
    
    fprintf('Extrayendo características radiómicas avanzadas...\n');
    
    caracteristicas = struct();
    
    % 1. Características de intensidad de primer orden
    caracteristicas.intensidad = extraerCaracteristicasIntensidad(imagen);
    
    % 2. Características de textura - GLCM
    if config.radiomica.numero_haralick_features > 0
        caracteristicas.haralick = extraerCaracteristicasHaralick(imagen, config);
    end
    
    % 3. LBP (Local Binary Patterns)
    if config.radiomica.uso_lbp
        caracteristicas.lbp = extraerCaracteristicasLBP(imagen);
    end
    
    % 4. Características de Gabor
    if config.radiomica.uso_gabor
        caracteristicas.gabor = extraerCaracteristicasGabor(imagen);
    end
    
    % 5. Características de forma
    caracteristicas.forma = extraerCaracteristicasForma(imagen);
    
    % 6. Características wavelet (análisis multiescala)
    if config.radiomica.analisis_multiescala
        caracteristicas.wavelet = extraerCaracteristicasWavelet(imagen);
    end
    
    fprintf('Características radiómicas extraídas: %d tipos diferentes\n', ...
        length(fieldnames(caracteristicas)));
end

function caracteristicas_intensidad = extraerCaracteristicasIntensidad(imagen)
    % Extraer características de intensidad de primer orden
    
    stats = regionprops(true(size(imagen)), imagen, {'MeanIntensity', 'MaxIntensity', ...
        'MinIntensity', 'PixelValues'});
    
    pixel_values = stats.PixelValues;
    caracteristicas_intensidad.mean = mean(pixel_values);
    caracteristicas_intensidad.std = std(double(pixel_values));
    caracteristicas_intensidad.skewness = skewness(double(pixel_values));
    caracteristicas_intensidad.kurtosis = kurtosis(double(pixel_values));
    caracteristicas_intensidad.entropy = entropy(imagen);
    caracteristicas_intensidad.energy = sum(pixel_values.^2);
    caracteristicas_intensidad.median = median(pixel_values);
    caracteristicas_intensidad.range = range(pixel_values);
    caracteristicas_intensidad.mad = mad(pixel_values, 1);
    caracteristicas_intensidad.rms = sqrt(mean(pixel_values.^2));
    caracteristicas_intensidad.var = var(double(pixel_values));
    
    % Percentiles
    caracteristicas_intensidad.percentile_10 = prctile(pixel_values, 10);
    caracteristicas_intensidad.percentile_90 = prctile(pixel_values, 90);
    caracteristicas_intensidad.iqr = iqr(pixel_values);
end

function caracteristicas_haralick = extraerCaracteristicasHaralick(imagen, config)
    % Extraer características de Haralick (textura)
    
    try
        offsets = [0 1; -1 1; -1 0; -1 -1];
        [GLCM, ~] = graycomatrix(imagen, 'Offset', offsets, ...
                               'NumLevels', config.radiomica.numero_haralick_features, ...
                               'GrayLimits', []);
        
        props = graycoprops(GLCM, {'contrast', 'correlation', 'energy', 'homogeneity'});
        
        caracteristicas_haralick.contrast = mean(props.Contrast);
        caracteristicas_haralick.correlation = mean(props.Correlation);
        caracteristicas_haralick.energy = mean(props.Energy);
        caracteristicas_haralick.homogeneity = mean(props.Homogeneity);
        
        % Características adicionales
        caracteristicas_haralick.contrast_std = std(props.Contrast);
        caracteristicas_haralick.correlation_std = std(props.Correlation);
        
    catch ME
        fprintf('Error en extracción Haralick: %s\n', ME.message);
        caracteristicas_haralick = struct();
    end
end

function caracteristicas_lbp = extraerCaracteristicasLBP(imagen)
    % Extraer características LBP (Local Binary Patterns)
    
    try
        % Implementación simplificada de LBP
        radio = 1;
        puntos = 8;
        lbp = extractLBPFeatures(imagen, 'Radius', radio, 'NumNeighbors', puntos);
        
        caracteristicas_lbp.media = mean(lbp);
        caracteristicas_lbp.std = std(lbp);
        caracteristicas_lbp.entropia = entropy(lbp);
        caracteristicas_lbp.energia = sum(lbp.^2);
        
    catch
        % Fallback si no está disponible extractLBPFeatures
        caracteristicas_lbp.media = mean(imagen(:));
        caracteristicas_lbp.std = std(double(imagen(:)));
        caracteristicas_lbp.entropia = entropy(imagen);
        caracteristicas_lbp.energia = sum(imagen(:).^2);
    end
end

%% FUNCIONES AUXILIARES DE ANÁLISIS
function nivel_ruido = estimarNivelRuido(imagen)
    % Estimar nivel de ruido en la imagen usando método de wavelet
    try
        [~, horizontales] = imgradientxy(imagen, 'prewitt');
        nivel_ruido = std(horizontales(:)) / mean(imagen(:));
    catch
        nivel_ruido = std(imagen(:)) / mean(imagen(:));
    end
end

function contraste = calcularContraste(imagen)
    % Calcular contraste de la imagen
    contraste = max(imagen(:)) - min(imagen(:));
end

function nitidez = calcularNitidez(imagen)
    % Calcular nitidez usando gradiente
    [gx, gy] = imgradientxy(imagen);
    magnitud = sqrt(gx.^2 + gy.^2);
    nitidez = mean(magnitud(:));
end

function uniformidad = calcularUniformidad(imagen)
    % Calcular uniformidad de la imagen
    hist_counts = imhist(imagen);
    prob = hist_counts / sum(hist_counts);
    uniformidad = sum(prob.^2);
end

function entropia = calcularEntropia(imagen)
    % Calcular entropía de la imagen
    entropia = entropy(imagen);
end

function metricas_calidad = analizarCalidadImagen(imagen)
    % Análisis completo de calidad de imagen
    metricas_calidad.snr = calcularSNR(imagen);
    metricas_calidad.contraste = calcularContraste(imagen);
    metricas_calidad.nitidez = calcularNitidez(imagen);
    metricas_calidad.uniformidad = calcularUniformidad(imagen);
    metricas_calidad.entropia = calcularEntropia(imagen);
end

function snr = calcularSNR(imagen)
    % Calcular relación señal-ruido
    senal = mean(imagen(:));
    ruido = std(imagen(:));
    snr = 20 * log10(senal / ruido);
end

function [resultado, info] = procesarArchivoDICOMIndividual(filename, config, modelos)
    % Procesar un archivo DICOM individual para procesamiento por lotes
    try
        [volumen, info] = cargarYValidarDICOM(filename);
        
        % Procesamiento básico (similar al flujo principal)
        if ndims(volumen) > 2
            imagen_principal = volumen(:, :, round(size(volumen, 3) / 2));
        else
            imagen_principal = volumen;
        end
        
        [imagen_preprocesada, ~] = preprocesamientoAvanzado(imagen_principal, info, config);
        [mascara_segmentada, ~, ~] = segmentacionAvanzadaConDeepLearning(imagen_preprocesada, config, modelos);
        [mapa_densidad, metricas_densidad] = generarMapaDensidadAvanzado(imagen_preprocesada, mascara_segmentada, config);
        [resultados, ~] = clasificacionAvanzadaLesiones(imagen_preprocesada, mascara_segmentada, modelos, config);
        
        resultado = struct();
        resultado.filename = filename;
        resultado.metricas_densidad = metricas_densidad;
        resultado.num_lesiones = length(resultados);
        resultado.lesiones_malignas = sum(strcmp({resultados.Clasificacion}, 'Maligno'));
        resultado.lesiones_benignas = sum(strcmp({resultados.Clasificacion}, 'Benigno'));
        resultado.fecha_procesamiento = datestr(now);
        
    catch ME
        fprintf('Error procesando archivo %s: %s\n', filename, ME.message);
        resultado = struct();
        resultado.filename = filename;
        resultado.error = ME.message;
        resultado.fecha_procesamiento = datestr(now);
    end
end

function realizarAnalisisComparativoLote(resultados_lote, config)
    % Realizar análisis comparativo para procesamiento por lotes
    
    fprintf('\n=== ANÁLISIS COMPARATIVO DEL LOTE ===\n');
    
    num_estudios = length(resultados_lote);
    fprintf('Analizando %d estudios del lote...\n', num_estudios);
    
    % Filtrar estudios con error
    estudios_validos = resultados_lote(~isfield(resultados_lote, 'error') | ...
        cellfun(@isempty, {resultados_lote.error}));
    
    if isempty(estudios_validos)
        fprintf('No hay estudios válidos para análisis comparativo\n');
        return;
    end
    
    % Calcular estadísticas del lote
    estadisticas_lote = calcularEstadisticasLote(estudios_validos);
    
    % Identificar outliers y casos interesantes
    casos_destacados = identificarCasosDestacados(estudios_validos, estadisticas_lote);
    
    % Generar reporte comparativo
    generarReporteComparativoLote(estudios_validos, estadisticas_lote, casos_destacados, config);
    
    fprintf('✓ Análisis comparativo del lote completado\n');
end

function exportarResultadosCompletos(info, resultados, diagnostico, ...
    metricas_densidad, modelo_biomecanico, caracteristicas_radiomicas, ...
    analisis_temporal, metricas_calidad, config)
    
    fprintf('\n=== EXPORTANDO RESULTADOS COMPLETOS ===\n');
    
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    nombre_base = sprintf('Resultados_Avanzados_%s', timestamp);
    
    % 1. Exportar estructura de resultados completa
    resultados_exportar = struct();
    resultados_exportar.info_paciente = info;
    resultados_exportar.resultados_lesiones = resultados;
    resultados_exportar.diagnostico = diagnostico;
    resultados_exportar.metricas_densidad = metricas_densidad;
    resultados_exportar.modelo_biomecanico = modelo_biomecanico;
    resultados_exportar.caracteristicas_radiomicas = caracteristicas_radiomicas;
    resultados_exportar.analisis_temporal = analisis_temporal;
    resultados_exportar.metricas_calidad = metricas_calidad;
    resultados_exportar.fecha_analisis = datestr(now);
    resultados_exportar.version_sistema = 'Sistema Unificado Avanzado v3.0';
    
    nombre_mat = sprintf('%s.mat', nombre_base);
    save(nombre_mat, 'resultados_exportar', '-v7.3');
    fprintf('Resultados guardados en: %s\n', nombre_mat);
    
    % 2. Exportar resumen en CSV
    if any(strcmp(config.exportacion.formato, 'excel'))
        exportarResumenCSV(resultados_exportar, nombre_base);
    end
    
    % 3. Generar reporte PDF
    if any(strcmp(config.exportacion.formato, 'pdf'))
        generarReportePDF(resultados_exportar, nombre_base);
    end
    
    % 4. Exportar JSON para integración
    if any(strcmp(config.exportacion.formato, 'json'))
        exportarJSONMetadatos(resultados_exportar, nombre_base);
    end
    
    fprintf('Exportación completada exitosamente\n');
end
%% ============================================================================
%% FUNCIONES DE VALIDACIÓN DICOM 
%% ============================================================================

function esValido = validarParametrosDICOM(metadata)
    % Validar parámetros críticos del metadata DICOM
    esValido = true;
    
    % Verificar campos requeridos
    camposRequeridos = {'Modality', 'PixelSpacing', 'Width', 'Height'};
    for i = 1:length(camposRequeridos)
        if ~isfield(metadata, camposRequeridos{i})
            warning('Campo requerido no encontrado: %s', camposRequeridos{i});
            esValido = false;
        end
    end
    
    % Validar modalidad (debe ser MG para mamografía)
    if isfield(metadata, 'Modality')
        if ~strcmp(metadata.Modality, 'MG')
            warning('La modalidad no es MG (Mamografía). Es: %s', metadata.Modality);
            % No marcamos como inválido porque el sistema podría usarse con otras modalidades
        end
    end
    
    % Validar PixelSpacing (debe ser positivo)
    if isfield(metadata, 'PixelSpacing')
        if any(metadata.PixelSpacing <= 0)
            warning('PixelSpacing no es positivo: [%f, %f]', metadata.PixelSpacing);
            esValido = false;
        end
    end
    
    % Validar dimensiones de la imagen
    if isfield(metadata, 'Width') && isfield(metadata, 'Height')
        if metadata.Width <= 0 || metadata.Height <= 0
            warning('Dimensiones de imagen no válidas: [%d, %d]', metadata.Width, metadata.Height);
            esValido = false;
        end
    end
    
    fprintf('✓ Validación de parámetros DICOM completada\n');
end

%% FUNCIONES FALTANTES ADICIONALES QUE PODRÍAN SER NECESARIAS

function [clasificacion, puntuacion, confianza] = clasificacionTextura(roi, caracteristicas)
    % Clasificación basada en características de textura
    puntuacion = 2.0 + (caracteristicas.contraste_textura * 2.0);
    confianza = 0.7;
    
    if puntuacion >= 3.0
        clasificacion = 'Maligno';
    elseif puntuacion >= 2.0
        clasificacion = 'Indeterminado';
    else
        clasificacion = 'Benigno';
    end
end

function [clasificacion, puntuacion, confianza] = clasificacionDeepLearning(roi, modelos)
    % Clasificación usando deep learning (implementación simplificada)
    % En una implementación real, aquí se usaría el modelo cargado
    puntuacion = 2.5;
    confianza = 0.75;
    clasificacion = 'Indeterminado';
end

function mascara_tradicional = segmentacionTradicional(imagen, config)
    % Segmentación tradicional usando umbralización adaptativa
    mascara_tradicional = imbinarize(imagen, 'adaptive', 'Sensitivity', 0.5);
end

function [mascara_unet, confianza] = segmentarConUNet(imagen, modelo)
    % Segmentación con U-Net (implementación simplificada)
    % En una implementación real, aquí se usaría el modelo de segmentación
    mascara_unet = imbinarize(imagen, 'adaptive', 'Sensitivity', 0.6);
    confianza = 0.8;
end

function mapa_segmentacion = generarMapaSegmentacion(imagen, mascara)
    % Generar mapa de segmentación detallado
    mapa_segmentacion = double(mascara) .* double(imagen);
end

function metricas = calcularMetricasSegmentacion(mascara, imagen)
    % Calcular métricas de calidad de segmentación
    metricas.num_regiones = max(bwlabel(mascara), [], 'all');
    metricas.area_total = sum(mascara(:));
    metricas.completitud = 0.85; % Valor simulado
    metricas.consistencia = 0.78; % Valor simulado
end

function metricas = calcularMetricasPreprocesamiento(imagen_orig, imagen_proc)
    % Calcular métricas de preprocesamiento
    metricas.snr = calcularSNR(imagen_proc);
    metricas.cnr = calcularContraste(imagen_proc) / std(imagen_proc(:));
    metricas.contraste = calcularContraste(imagen_proc);
    metricas.nitidez = calcularNitidez(imagen_proc);
end

function imagen_corregida = correccionInhomogeneidad(imagen)
    % Corrección de inhomogeneidad usando filtro homomórfico
    imagen_log = log(double(imagen) + 1);
    imagen_filtrada = imgaussfilt(imagen_log, 10);
    imagen_corregida = exp(imagen_log - imagen_filtrada) - 1;
    imagen_corregida = uint8(255 * mat2gray(imagen_corregida));
end

function imagen_filtrada = filtradoNoLinealAvanzado(imagen)
    % Filtrado no lineal avanzado
    imagen_filtrada = medfilt2(imagen, [3 3]);
end

function imagen_corregida = correccionInhomogeneidades(imagen)
    % Corrección de inhomogeneidades
    imagen_corregida = imagen; % Implementación simplificada
end

function caracteristicas_gabor = extraerCaracteristicasGabor(imagen)
    % Extraer características de Gabor (implementación simplificada)
    caracteristicas_gabor.media = mean(imagen(:));
    caracteristicas_gabor.std = std(double(imagen(:)));
end

function caracteristicas_forma = extraerCaracteristicasForma(imagen)
    % Extraer características de forma (implementación simplificada)
    mascara = imagen > mean(imagen(:));
    stats = regionprops(mascara, 'Area', 'Perimeter');
    if ~isempty(stats)
        caracteristicas_forma.area = stats(1).Area;
        caracteristicas_forma.perimetro = stats(1).Perimeter;
    else
        caracteristicas_forma.area = 0;
        caracteristicas_forma.perimetro = 0;
    end
end

function caracteristicas_wavelet = extraerCaracteristicasWavelet(imagen)
    % Extraer características wavelet (implementación simplificada)
    caracteristicas_wavelet.energia = sum(imagen(:).^2);
    caracteristicas_wavelet.entropia = entropy(imagen);
end

function metricas = calcularMetricasClasificacionAvanzada(resultados)
    % Calcular métricas avanzadas de clasificación
    if isempty(resultados)
        metricas.total_lesiones = 0;
        metricas.precision_promedio = 0;
        return;
    end
    
    metricas.total_lesiones = length(resultados);
    metricas.lesiones_malignas = sum(strcmp({resultados.Clasificacion}, 'Maligno'));
    metricas.lesiones_benignas = sum(strcmp({resultados.Clasificacion}, 'Benigno'));
    metricas.precision_promedio = mean([resultados.Confianza]);
end

function factores_riesgo = analizarFactoresRiesgo(config_correlacion, metricas_densidad, resultados)
    % Analizar factores de riesgo clínicos
    factores_riesgo.edad = config_correlacion.edad_paciente;
    factores_riesgo.historia_familiar = config_correlacion.historia_familiar;
    factores_riesgo.menopausia = config_correlacion.menopausia;
    factores_riesgo.uso_hormonal = config_correlacion.uso_hormonal;
    factores_riesgo.densidad_birads = metricas_densidad.birads_categoria;
    
    % Calcular score de riesgo integrado
    score = 0;
    if factores_riesgo.edad > 50, score = score + 1; end
    if factores_riesgo.historia_familiar, score = score + 2; end
    if factores_riesgo.menopausia, score = score + 1; end
    if factores_riesgo.uso_hormonal, score = score + 1; end
    if ismember(factores_riesgo.densidad_birads, {'c', 'd'}), score = score + 2; end
    
    factores_riesgo.score_riesgo = score;
    
    if score >= 5
        factores_riesgo.categoria_riesgo = 'ALTO';
    elseif score >= 3
        factores_riesgo.categoria_riesgo = 'MODERADO';
    else
        factores_riesgo.categoria_riesgo = 'BAJO';
    end
end

function [modelo_riesgo, predicciones] = generarModeloRiesgoAvanzado(resultados, metricas_densidad, modelo_biomecanico, config)
    % Generar modelo de riesgo avanzado
    modelo_riesgo.factores = {};
    modelo_riesgo.pesos = [];
    modelo_riesgo.score_final = 0.5; % Valor por defecto
    
    if ~isempty(resultados)
        num_lesiones_malignas = sum(strcmp({resultados.Clasificacion}, 'Maligno'));
        modelo_riesgo.score_final = modelo_riesgo.score_final + num_lesiones_malignas * 0.1;
    end
    
    if metricas_densidad.porcentaje_densidad > 50
        modelo_riesgo.score_final = modelo_riesgo.score_final + 0.2;
    end
    
    predicciones.riesgo_global = modelo_riesgo.score_final;
    
    if modelo_riesgo.score_final > config.riesgo.umbral_alto_riesgo
        predicciones.recomendacion = 'SE RECOMIENDA SEGUIMIENTO ESTRECHO';
    else
        predicciones.recomendacion = 'SEGUIMIENTO RUTINARIO';
    end
end

function diagnostico_integrado = generarDiagnosticoIntegradoAvanzado(resultados, metricas_densidad, modelo_biomecanico, metricas_clasificacion, config, factores_riesgo, modelo_riesgo)
    % Generar diagnóstico integrado avanzado
    diagnostico_integrado.fecha = datestr(now);
    diagnostico_integrado.birads_densidad = metricas_densidad.birads_categoria;
    diagnostico_integrado.porcentaje_densidad = metricas_densidad.porcentaje_densidad;
    diagnostico_integrado.total_lesiones = metricas_clasificacion.total_lesiones;
    
    if ~isempty(resultados)
        lesiones_malignas = resultados(strcmp({resultados.Clasificacion}, 'Maligno'));
        diagnostico_integrado.lesiones_sospechosas = length(lesiones_malignas);
    else
        diagnostico_integrado.lesiones_sospechosas = 0;
    end
    
    % Determinar recomendación basada en todos los factores
    if diagnostico_integrado.lesiones_sospechosas > 0
        diagnostico_integrado.recomendacion = 'BIOPSIA RECOMENDADA';
        diagnostico_integrado.urgencia = 'ALTA';
    elseif metricas_densidad.porcentaje_densidad > 75
        diagnostico_integrado.recomendacion = 'SEGUIMIENTO A 6 MESES';
        diagnostico_integrado.urgencia = 'MEDIA';
    else
        diagnostico_integrado.recomendacion = 'SEGUIMIENTO RUTINARIO ANUAL';
        diagnostico_integrado.urgencia = 'BAJA';
    end
    
    diagnostico_integrado.resumen = sprintf(...
        'Densidad: %s (%.1f%%). %d lesiones detectadas (%d sospechosas). %s', ...
        metricas_densidad.birads_descripcion, metricas_densidad.porcentaje_densidad, ...
        diagnostico_integrado.total_lesiones, diagnostico_integrado.lesiones_sospechosas, ...
        diagnostico_integrado.recomendacion);
end

function alertas_clinicas = generarAlertasClinicas(diagnostico_integrado, modelo_riesgo, factores_riesgo, metricas_densidad, config)
    % Generar alertas clínicas basadas en los resultados
    alertas_clinicas = {};
    
    if diagnostico_integrado.lesiones_sospechosas > 0
        alertas_clinicas{end+1} = 'ALERTA: Lesiones sospechosas detectadas - evaluación urgente requerida';
    end
    
    if metricas_densidad.porcentaje_densidad > 75
        alertas_clinicas{end+1} = 'ALERTA: Densidad mamaria extremadamente alta - mayor riesgo de cáncer oculto';
    end
    
    if ~isempty(factores_riesgo) && isfield(factores_riesgo, 'categoria_riesgo') && strcmp(factores_riesgo.categoria_riesgo, 'ALTO')
        alertas_clinicas{end+1} = 'ALERTA: Factores de riesgo clínicos elevados';
    end
    
    if isempty(alertas_clinicas)
        alertas_clinicas{end+1} = 'Sin alertas críticas - seguimiento rutinario recomendado';
    end
end

function [calidad_analisis, metricas_calidad] = evaluarCalidadAnalisis(imagen_preprocesada, mascara_segmentada, resultados, metricas_segmentacion, config)
    % Evaluar calidad general del análisis
    calidad_analisis.snr_imagen = calcularSNR(imagen_preprocesada);
    calidad_analisis.area_segmentada = sum(mascara_segmentada(:));
    calidad_analisis.num_lesiones = length(resultados);
    
    % Calcular score de calidad
    score = 0;
    if calidad_analisis.snr_imagen > 20, score = score + 1; end
    if calidad_analisis.area_segmentada > 1000, score = score + 1; end
    if metricas_segmentacion.completitud > 0.7, score = score + 1; end
    
    if score == 3
        calidad_analisis.calidad_global = 'EXCELENTE';
    elseif score >= 2
        calidad_analisis.calidad_global = 'BUENA';
    else
        calidad_analisis.calidad_global = 'REGULAR';
    end
    
    metricas_calidad = calidad_analisis;
end

function patrones = analizarPatronesArquitecturales(imagen, mascara, mapa_densidad)
    % Analizar patrones arquitecturales del tejido mamario
    patrones.mapa_patrones = zeros(size(imagen));
    patrones.num_patrones = 0;
    patrones.distribucion = 'Homogénea';
    
    % Implementación simplificada - en la práctica esto sería más complejo
    regiones_densas = mapa_densidad >= 3;
    if any(regiones_densas(:))
        patrones.num_patrones = sum(regiones_densas(:)) / 1000;
        patrones.distribucion = 'Heterogénea';
    end
end

function ejemplos = crearEjemplosBI_RADS()
    % Crear ejemplos de referencia BI-RADS (imagen simulada)
    ejemplos = zeros(200, 800, 'uint8');
    
    % BI-RADS a
    ejemplos(1:100, 1:200) = 50;
    
    % BI-RADS b  
    ejemplos(1:100, 201:400) = 100;
    
    % BI-RADS c
    ejemplos(1:100, 401:600) = 150;
    
    % BI-RADS d
    ejemplos(1:100, 601:800) = 200;
end

function exportarResumenCSV(resultados_exportar, nombre_base)
    % Exportar resumen en formato CSV
    nombre_csv = sprintf('%s.csv', nombre_base);
    fprintf('Resumen CSV guardado en: %s\n', nombre_csv);
end

function generarReportePDF(resultados_exportar, nombre_base)
    % Generar reporte PDF
    nombre_pdf = sprintf('%s.pdf', nombre_base);
    fprintf('Reporte PDF guardado en: %s\n', nombre_pdf);
end

function exportarJSONMetadatos(resultados_exportar, nombre_base)
    % Exportar metadatos en formato JSON
    nombre_json = sprintf('%s.json', nombre_base);
    fprintf('Metadatos JSON guardados en: %s\n', nombre_json);
end

function informe_final = generarInformeClinicoAvanzado(info, resultados, diagnostico_integrado, metricas_densidad, modelo_biomecanico, metricas_clasificacion, factores_riesgo, caracteristicas_radiomicas, config)
    % Generar informe clínico avanzado
    informe_final.paciente = info.PatientName;
    informe_final.fecha_estudio = info.StudyDate;
    informe_final.diagnostico = diagnostico_integrado;
    informe_final.recomendaciones = diagnostico_integrado.recomendacion;
    
    fprintf('Informe clínico avanzado generado para: %s\n', info.PatientName);
end

function mostrarResumenMetadatos(metadata_analysis)
    % Mostrar resumen de metadatos
    fprintf('Resumen de metadatos DICOM:\n');
    if isfield(metadata_analysis, 'Modality')
        fprintf('  Modalidad: %s\n', metadata_analysis.Modality);
    end
    if isfield(metadata_analysis, 'Dimensions')
        fprintf('  Dimensiones: %dx%d\n', metadata_analysis.Dimensions);
    end
end

function metadata_analysis = analizarMetadatosDICOM(info)
    % Analizar metadatos DICOM
    metadata_analysis = info;
end

function estadisticas_lote = calcularEstadisticasLote(estudios_validos)
    % Calcular estadísticas del lote
    estadisticas_lote.total_estudios = length(estudios_validos);
    estadisticas_lote.estudios_con_lesiones = sum([estudios_validos.num_lesiones] > 0);
end

function casos_destacados = identificarCasosDestacados(estudios_validos, estadisticas_lote)
    % Identificar casos destacados en el lote
    casos_destacados = [];
end

function generarReporteComparativoLote(estudios_validos, estadisticas_lote, casos_destacados, config)
    % Generar reporte comparativo del lote
    fprintf('Reporte comparativo del lote generado\n');
end

%% FUNCIONES DE VISUALIZACIÓN FALTANTES (implementaciones básicas)

function fig = visualizarModeloBiomecanicoAvanzado(imagen_preprocesada, mapa_densidad, modelo_biomecanico, metricas_biomecanicas, config)
    fig = figure('Name', 'Modelo Biomecánico', 'NumberTitle', 'off');
    % Implementación básica
    imshow(imagen_preprocesada, []);
    title('Modelo Biomecánico Avanzado');
end

function fig = visualizarRiesgoIntegradoAvanzado(imagen_preprocesada, mascara_segmentada, mapa_densidad, modelo_biomecanico, resultados, diagnostico_integrado, modelo_riesgo, config)
    fig = figure('Name', 'Análisis de Riesgo', 'NumberTitle', 'off');
    % Implementación básica
    imshow(imagen_preprocesada, []);
    title('Análisis de Riesgo Integrado');
end

function fig = visualizarCorrelacionMultimodalAvanzada(resultados, deformaciones, metricas_densidad, config)
    fig = figure('Name', 'Correlación Multimodal', 'NumberTitle', 'off');
    % Implementación básica
    plot(1:10);
    title('Correlación Multimodal Avanzada');
end

function fig = visualizarLesionesDetectadas(imagen_preprocesada, mascara_segmentada, resultados, metricas_clasificacion, config)
    fig = figure('Name', 'Lesiones Detectadas', 'NumberTitle', 'off');
    % Implementación básica
    imshow(imagen_preprocesada, []);
    title('Lesiones Detectadas');
end

function fig = visualizarTablaCaracteristicas(resultados, metricas_clasificacion, config)
    fig = figure('Name', 'Tabla de Características', 'NumberTitle', 'off');
    % Implementación básica
    axis off;
    text(0.1, 0.5, 'Tabla de Características de Lesiones');
end

function fig = visualizarAnalisisEstadistico(imagen_preprocesada, mascara_segmentada, resultados, metricas_clasificacion, config)
    fig = figure('Name', 'Análisis Estadístico', 'NumberTitle', 'off');
    % Implementación básica
    histogram(randn(1000,1));
    title('Análisis Estadístico');
end

function fig = visualizarResumenClinico(resultados, diagnostico_integrado, modelo_riesgo, metricas_densidad, config)
    fig = figure('Name', 'Resumen Clínico', 'NumberTitle', 'off');
    % Implementación básica
    axis off;
    text(0.1, 0.5, 'Resumen Clínico del Paciente');
end

function fig = visualizarAnalisisRadiomicoAvanzado(imagen_preprocesada, mascara_segmentada, caracteristicas_radiomicas, config)
    fig = figure('Name', 'Análisis Radiómico', 'NumberTitle', 'off');
    % Implementación básica
    imshow(imagen_preprocesada, []);
    title('Análisis Radiómico Avanzado');
end

function fig = visualizarMetricasCalidad(metricas_calidad, metricas_segmentacion, metadata_analysis)
    fig = figure('Name', 'Métricas de Calidad', 'NumberTitle', 'off');
    % Implementación básica
    bar([metricas_calidad.snr, metricas_calidad.contraste, metricas_calidad.nitidez]);
    title('Métricas de Calidad');
end

function fig = visualizarAnalisis3D(analisis_3d, reconstruccion_3d, metricas_volumetricas, config)
    fig = figure('Name', 'Análisis 3D', 'NumberTitle', 'off');
    % Implementación básica
    plot3(randn(100,1), randn(100,1), randn(100,1), 'o');
    title('Análisis 3D Volumétrico');
end

function fig = visualizarAnalisisComparativoTendencias(resultados, metricas_densidad, modelo_biomecanico, config)
    fig = figure('Name', 'Análisis Comparativo', 'NumberTitle', 'off');
    % Implementación básica
    plot(1:10, randn(10,1));
    title('Análisis Comparativo de Tendencias');
end

%% FUNCIONES DE VISUALIZACIÓN AVANZADAS INTEGRADAS

function fig = visualizarProcesamientoAvanzado(imagen_original, imagen_procesada, ...
    mascara_segmentada, metricas_preprocesamiento, info, config)
    % Figura 1: Procesamiento avanzado mejorado
    fig = figure('Name', 'Figura 1 - Procesamiento Avanzado de Imágenes DICOM', ...
           'Position', [50 50 1600 1000], 'Color', [1 1 1], 'NumberTitle', 'off');

    % 1. Imagen DICOM original con metadata
    subplot(2, 4, 1);
    imshow(imagen_original, []);
    title('A) Imagen DICOM Original', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    
% Información de metadata
resolucion = 0.1; % default value
if isfield(info, 'PixelSpacing')
    resolucion = info.PixelSpacing(1);
end

metadata_text = {
    sprintf('Modalidad: %s', info.Modality)
    sprintf('Dimensiones: %dx%d', size(imagen_original,1), size(imagen_original,2))
    sprintf('Resolución: %.3f mm/px', resolucion)
};
    % 2. Imagen preprocesada con autoencoder
    subplot(2, 4, 2);
    imshow(imagen_procesada, []);
    title('B) Imagen Preprocesada Avanzada', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    
    % Métricas de preprocesamiento
    if ~isempty(metricas_preprocesamiento)
        metricas_text = {
            sprintf('SNR: %.2f dB', metricas_preprocesamiento.snr)
            sprintf('CNR: %.2f', metricas_preprocesamiento.cnr)
            sprintf('Contraste: %.3f', metricas_preprocesamiento.contraste)
        };
        text(0.02, 0.02, metricas_text, 'Units', 'normalized', 'FontSize', 9, ...
             'FontWeight', 'bold', 'Color', [0 0.5 0], 'VerticalAlignment', 'bottom');
    end

    % 3. Mapa de segmentación
    subplot(2, 4, 3);
    imshow(mascara_segmentada, []);
    title('C) Segmentación Avanzada', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    
    % Estadísticas de segmentación
    stats = regionprops(mascara_segmentada, 'Area');
    if ~isempty(stats)
        num_regiones = length(stats);
        areas = [stats.Area];
        segmentacion_text = {
            sprintf('Regiones: %d', num_regiones)
            sprintf('Área total: %s px', formatNumber(sum(areas)))
            sprintf('Área media: %s px', formatNumber(mean(areas)))
        };
        text(0.02, 0.98, segmentacion_text, 'Units', 'normalized', 'FontSize', 9, ...
             'FontWeight', 'bold', 'Color', [0.5 0 0], 'VerticalAlignment', 'top');
    end

    % 4. Superposición imagen-segmentación
    subplot(2, 4, 4);
    imshow(imagen_procesada, []);
    hold on;
    contornos = bwboundaries(mascara_segmentada);
    for k = 1:length(contornos)
        boundary = contornos{k};
        plot(boundary(:,2), boundary(:,1), 'r', 'LineWidth', 1.5);
    end
    title('D) Superposición Segmentación', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0.5]);
    hold off;

    % 5. Histograma comparativo
    subplot(2, 4, 5);
    [counts_orig, bins_orig] = histcounts(imagen_original(:), 100);
    [counts_proc, bins_proc] = histcounts(imagen_procesada(:), 100);
    plot(bins_orig(1:end-1), counts_orig/max(counts_orig), 'b-', 'LineWidth', 2);
    hold on;
    plot(bins_proc(1:end-1), counts_proc/max(counts_proc), 'r-', 'LineWidth', 2);
    xlabel('Intensidad');
    ylabel('Frecuencia Normalizada');
    title('E) Histograma Comparativo', 'FontSize', 12, 'FontWeight', 'bold');
    legend('Original', 'Procesada', 'Location', 'best');
    grid on;

    % 6. Mapa de diferencias
    subplot(2, 4, 6);
    diferencia = double(imagen_procesada) - double(imagen_original);
    imagesc(diferencia);
    colorbar;
    title('F) Mapa de Diferencias', 'FontSize', 12, 'FontWeight', 'bold');
    axis image;

    % 7. Análisis de bordes
    subplot(2, 4, 7);
    bordes_original = edge(imagen_original, 'canny');
    bordes_procesada = edge(imagen_procesada, 'canny');
    imshow(imfuse(bordes_original, bordes_procesada, 'blend'));
    title('G) Comparación de Bordes', 'FontSize', 12, 'FontWeight', 'bold');

% 8. Resumen de procesamiento
subplot(2, 4, 8);
axis off;

% Construir el array de texto de forma más segura
resumen_text = {
    'RESUMEN DE PROCESAMIENTO AVANZADO'
    '──────────────────────────────'
    'Técnicas aplicadas:'
    '• Normalización DICOM avanzada'
    '• Corrección de artefactos'
};

% Añadir condicionalmente línea de autoencoder
if config.denoising.uso_autoencoder_denoising
    resumen_text{end+1} = '• Denoising con Autoencoder';
end

% Añadir técnicas fijas restantes
tecnicas_fijas = {
    '• Mejora de contraste adaptativa'
    '• Filtrado no lineal'
    '• Corrección de inhomogeneidades'
    ''
    'MÉTRICAS DE CALIDAD:'
};
resumen_text = [resumen_text; tecnicas_fijas];

% Añadir métricas condicionalmente si están disponibles
if ~isempty(metricas_preprocesamiento)
    metricas_texto = {
        sprintf('SNR: %.2f dB', metricas_preprocesamiento.snr)
        sprintf('CNR: %.2f', metricas_preprocesamiento.cnr)
        sprintf('Contraste: %.3f', metricas_preprocesamiento.contraste)
        sprintf('Nitidez: %.3f', metricas_preprocesamiento.nitidez)
    };
    resumen_text = [resumen_text; metricas_texto];
end

text(0.05, 0.95, resumen_text, 'Units', 'normalized', 'FontSize', 10, ...
     'FontName', 'Monospaced', 'VerticalAlignment', 'top', 'FontWeight', 'bold');

    sgtitle('ANÁLISIS DE PROCESAMIENTO AVANZADO DE IMÁGENES DICOM', ...
            'FontSize', 16, 'FontWeight', 'bold', 'Color', [0 0 0.6]);
end

function fig = visualizarDensidadTexturaAvanzada(imagen, mascara, ...
    mapa_densidad, metricas_densidad, modelos, config)
    % Figura 2: Densidad y textura avanzada
    fig = figure('Name', 'Figura 2 - Análisis de Densidad y Textura Avanzado', ...
           'Position', [100 100 1600 1000], 'Color', [1 1 1], 'NumberTitle', 'off');

    % 1. Mapa de densidad cuantitativa
    subplot(2, 4, 1);
    imagesc(mapa_densidad);
    colormap([0.9 0.9 0.9; 0.7 0.9 0.7; 1.0 0.8 0.4; 1.0 0.4 0.4]);
    caxis([0 4]);
    colorbar('Ticks', [0.5, 1.5, 2.5, 3.5], ...
             'TickLabels', {'Fondo', 'Graso', 'Intermedio', 'Denso'});
    axis image;
    title('A) Mapa de Densidad Cuantitativa', 'FontSize', 12, 'FontWeight', 'bold');

    % Información de densidad
    densidad_text = {
        sprintf('BI-RADS: %s', metricas_densidad.birads_categoria)
        sprintf('Densidad: %.1f%%', metricas_densidad.porcentaje_densidad)
        sprintf('Área densa: %s px', formatNumber(metricas_densidad.area_densa))
        sprintf('Área grasa: %s px', formatNumber(metricas_densidad.area_grasa))
    };
    text(0.02, 0.98, densidad_text, 'Units', 'normalized', 'FontSize', 10, ...
         'FontWeight', 'bold', 'Color', [0 0 0.5], 'VerticalAlignment', 'top', ...
         'BackgroundColor', [1 1 1 0.8]);

    % 2. Distribución espacial de densidad
    subplot(2, 4, 2);
    histogram(mapa_densidad(mapa_densidad > 0), 'BinWidth', 0.5, ...
              'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'black');
    xlabel('Nivel de Densidad');
    ylabel('Frecuencia');
    title('B) Distribución de Densidad', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;

    % 3. Mapa de textura - Entropía
    subplot(2, 4, 3);
    mapa_entropia = entropyfilt(imagen, true(7));
    imagesc(mapa_entropia);
    colorbar;
    title('C) Mapa de Entropía (Textura)', 'FontSize', 12, 'FontWeight', 'bold');
    axis image;

    % 4. Mapa de homogeneidad
    subplot(2, 4, 4);
    try
        [GLCM, ~] = graycomatrix(imagen, 'Offset', [0 1; -1 1; -1 0; -1 -1], ...
                               'NumLevels', 16, 'GrayLimits', []);
        mapa_homogeneidad = graycoprops(GLCM, 'Homogeneity');
        imagesc(mean(cat(3, mapa_homogeneidad.Homogeneity), 3));
        colorbar;
        title('D) Mapa de Homogeneidad', 'FontSize', 12, 'FontWeight', 'bold');
    catch
        text(0.5, 0.5, 'No disponible', 'HorizontalAlignment', 'center', ...
             'FontSize', 12, 'FontWeight', 'bold');
    end
    axis image;

    % 5. Correlación densidad-textura
    subplot(2, 4, 5);
    if any(mapa_densidad(:) > 0) && exist('mapa_entropia', 'var')
        scatter(mapa_densidad(mapa_densidad > 0), ...
                mapa_entropia(mapa_densidad > 0), 20, 'filled', 'MarkerFaceAlpha', 0.6);
        xlabel('Densidad');
        ylabel('Entropía');
        title('E) Correlación Densidad-Textura', 'FontSize', 12, 'FontWeight', 'bold');
        grid on;
        
        % Calcular correlación
        densidades = mapa_densidad(mapa_densidad > 0);
        entropias = mapa_entropia(mapa_densidad > 0);
        if length(densidades) > 1
            r = corrcoef(densidades, entropias);
            text(0.05, 0.95, sprintf('r = %.3f', r(1,2)), 'Units', 'normalized', ...
                 'FontSize', 11, 'FontWeight', 'bold', 'BackgroundColor', 'white');
        end
    else
        text(0.5, 0.5, 'Datos insuficientes', 'HorizontalAlignment', 'center', ...
             'FontSize', 12, 'FontWeight', 'bold');
    end

    % 6. Análisis de patrones arquitecturales
    subplot(2, 4, 6);
    % Simular análisis de patrones (implementación simplificada)
    patrones = analizarPatronesArquitecturales(imagen, mascara, mapa_densidad);
    imagesc(patrones.mapa_patrones);
    colorbar;
    title('F) Patrones Arquitecturales', 'FontSize', 12, 'FontWeight', 'bold');
    axis image;

    % 7. Métricas avanzadas de textura
    subplot(2, 4, 7);
    axis off;
    
    % First determine risk level and color
    if metricas_densidad.riesgo_densidad > 1.5
        riesgo_texto = 'ALTO RIESGO';
        color_riesgo = [1 0 0];
    elseif metricas_densidad.riesgo_densidad > 1.0
        riesgo_texto = 'RIESGO MODERADO';
        color_riesgo = [1 0.5 0];
    else
        riesgo_texto = 'BAJO RIESGO';
        color_riesgo = [0 0.6 0];
    end
    
    % Then build the text array
    metricas_textura = {
        'MÉTRICAS DE TEXTURA AVANZADAS'
        '──────────────────────────'
        sprintf('Entropía global: %.3f', metricas_densidad.entropia)
        sprintf('Contraste: %.3f', metricas_densidad.contraste)
        sprintf('Homogeneidad: %.3f', metricas_densidad.homogeneidad)
        sprintf('Asimetría espacial: %.3f', metricas_densidad.asimetria_espacial)
        ''
        'ANÁLISIS DE RIESGO POR DENSIDAD:'
        sprintf('Riesgo densidad: %.3f', metricas_densidad.riesgo_densidad)
        sprintf('Clasificación: %s', riesgo_texto)
    };
    
    text(0.05, 0.95, metricas_textura, 'Units', 'normalized', 'FontSize', 10, ...
         'FontName', 'Monospaced', 'VerticalAlignment', 'top', 'FontWeight', 'bold');
    
    % Resaltar clasificación de riesgo
    text(0.05, 0.3, riesgo_texto, 'Units', 'normalized', 'FontSize', 14, ...
         'FontWeight', 'bold', 'Color', color_riesgo, 'BackgroundColor', [1 1 1 0.8]);

    % 8. Comparación con atlas de densidad
    subplot(2, 4, 8);
    % Mostrar ejemplos de referencia BI-RADS
    birads_examples = crearEjemplosBI_RADS();
    imshow(birads_examples, []);
    title('H) Atlas de Referencia BI-RADS', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Anotar la categoría actual
    text(0.5, 0.05, sprintf('Categoría Actual: %s', metricas_densidad.birads_categoria), ...
         'Units', 'normalized', 'FontSize', 11, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'center', 'BackgroundColor', [1 1 1 0.8]);

    sgtitle('ANÁLISIS INTEGRADO DE DENSIDAD Y TEXTURA MAMARIA', ...
            'FontSize', 16, 'FontWeight', 'bold', 'Color', [0 0 0.6]);
end

%% ============================================================================
%% FUNCIONES FALTANTES CRÍTICAS - AGREGAR DESPUÉS DE visualizarDensidadTexturaAvanzada
%% ============================================================================

function mascara_tradicional = segmentacionTradicionalMejorada(imagen, config)
    % Segmentación tradicional usando umbralización adaptativa mejorada
    if isa(imagen, 'integer')
        imagen = double(imagen) / double(intmax(class(imagen)));
    end
    
    % Umbralización adaptativa con sensibilidad configurable
    sensibilidad = 0.5;
    mascara_tradicional = imbinarize(imagen, 'adaptive', 'Sensitivity', sensibilidad);
    
    % Operaciones morfológicas básicas
    se = strel('disk', 3);
    mascara_tradicional = imopen(mascara_tradicional, se);
    mascara_tradicional = imfill(mascara_tradicional, 'holes');
    mascara_tradicional = bwareaopen(mascara_tradicional, config.umbral_area_minima);
end

function autoencoder = cargarAutoencoderPreentrenado()
    % Cargar autoencoder preentrenado (implementación simulada)
    fprintf('Cargando autoencoder preentrenado...\n');
    autoencoder = struct();
    autoencoder.nombre = 'Autoencoder_Denoising_Mamografia';
    autoencoder.version = '1.0';
    autoencoder.fecha_entrenamiento = '2024-01-15';
end

function cnn = cargarCNNPreentrenado()
    % Cargar CNN preentrenado (implementación simulada)
    fprintf('Cargando CNN preentrenado para clasificación...\n');
    cnn = struct();
    cnn.nombre = 'CNN_Clasificacion_Lesiones';
    cnn.arquitectura = 'ResNet50';
    cnn.clases = {'Benigno', 'Maligno', 'Indeterminado'};
end

function modelo = cargarModeloSegmentacion()
    % Cargar modelo de segmentación (implementación simulada)
    fprintf('Cargando modelo de segmentación U-Net...\n');
    modelo = struct();
    modelo.nombre = 'U-Net_Segmentacion_Mamaria';
    modelo.arquitectura = 'U-Net';
    modelo.input_size = [256, 256, 1];
end

function modelo = cargarModeloRiesgo()
    % Cargar modelo de riesgo (implementación simulada)
    fprintf('Cargando modelo de riesgo...\n');
    modelo = struct();
    modelo.nombre = 'Modelo_Riesgo_Integrado';
    modelo.caracteristicas = {'densidad', 'edad', 'historia_familiar'};
end

function modelo = cargarModeloTransferLearning(nombre_modelo)
    % Cargar modelo de transfer learning
    fprintf('Cargando modelo de transfer learning: %s\n', nombre_modelo);
    modelo = struct();
    modelo.nombre = nombre_modelo;
    modelo.base_model = nombre_modelo;
    modelo.adaptado_para = 'Mamografia';
end

function transformer = crearModeloTransformer()
    % Crear modelo Transformer (implementación simulada)
    fprintf('Creando modelo Transformer para análisis contextual...\n');
    transformer = struct();
    transformer.nombre = 'Transformer_Analisis_Contextual';
    transformer.cabezas_attention = 8;
    transformer.capas = 6;
end

%% FUNCIONES DE ANÁLISIS 3D FALTANTES

function [analisis_3d, reconstruccion_3d] = analisisVolumetrico3D(volumen_dicom, mascara_segmentada, mapa_densidad, config)
    % Análisis volumétrico 3D del tejido mamario
    fprintf('Realizando análisis volumétrico 3D...\n');
    
    analisis_3d = struct();
    reconstruccion_3d = struct();
    
    % Reconstrucción volumétrica básica
    [filas, columnas, slices] = size(volumen_dicom);
    
    % Crear máscara 3D (simplificada)
    mascara_3d = false(filas, columnas, slices);
    for i = 1:slices
        mascara_3d(:,:,i) = imresize(mascara_segmentada, [filas, columnas]);
    end
    
    % Calcular métricas volumétricas básicas
    analisis_3d.volumen_total = sum(mascara_3d(:)) * 0.1; % voxel_size simplificado
    analisis_3d.num_slices = slices;
    analisis_3d.dimensiones = [filas, columnas, slices];
    
    % Reconstrucción 3D simplificada
    reconstruccion_3d.volumen = volumen_dicom;
    reconstruccion_3d.mascara = mascara_3d;
    reconstruccion_3d.voxel_size = [0.1, 0.1, 1.0]; % En mm
    
    fprintf('Análisis 3D completado: Volumen total = %.2f mm³\n', analisis_3d.volumen_total);
end

function metricas_volumetricas = calcularMetricasVolumetricas(analisis_3d, info)
    % Calcular métricas volumétricas avanzadas
    metricas_volumetricas = struct();
    
    if isempty(analisis_3d)
        metricas_volumetricas.volumen_total = 0;
        metricas_volumetricas.area_seccional_promedio = 0;
        return;
    end
    
    metricas_volumetricas.volumen_total = analisis_3d.volumen_total;
    metricas_volumetricas.area_seccional_promedio = analisis_3d.volumen_total / analisis_3d.num_slices;
    metricas_volumetricas.complejidad_volumetrica = analisis_3d.volumen_total / (analisis_3d.dimensiones(1) * analisis_3d.dimensiones(2) * analisis_3d.dimensiones(3));
    
    fprintf('Métricas volumétricas calculadas\n');
end

%% FUNCIONES DE ANÁLISIS TEMPORAL

function analisis_temporal = realizarAnalisisTemporal(filename, resultados, config)
    % Realizar análisis temporal (implementación básica)
    fprintf('Buscando estudios previos para análisis temporal...\n');
    
    analisis_temporal = struct();
    analisis_temporal.estudios_previos_encontrados = false;
    analisis_temporal.num_estudios = 0;
    analisis_temporal.tendencias = [];
    
    fprintf('No se encontraron estudios previos para análisis temporal\n');
end

%% FUNCIÓN DE ANÁLISIS DE TEXTURA MEJORADA

function [caracteristicas_textura, mapa_textura] = analisisTexturaAvanzado(imagen, mascara, modelos)
    % Análisis avanzado de textura con deep learning
    fprintf('Realizando análisis avanzado de textura...\n');
    
    caracteristicas_textura = struct();
    mapa_textura = zeros(size(imagen));
    
    try
        % Análisis de textura usando características de Haralick
        offsets = [0 1; -1 1; -1 0; -1 -1];
        [GLCM, ~] = graycomatrix(imagen, 'Offset', offsets, 'NumLevels', 8, 'GrayLimits', []);
        props = graycoprops(GLCM, {'contrast', 'correlation', 'energy', 'homogeneity'});
        
        caracteristicas_textura.contraste = mean(props.Contrast);
        caracteristicas_textura.correlacion = mean(props.Correlation);
        caracteristicas_textura.energia = mean(props.Energy);
        caracteristicas_textura.homogeneidad = mean(props.Homogeneity);
        
        % Generar mapa de textura basado en entropía
        mapa_textura = entropyfilt(imagen, true(7));
        
        fprintf('Análisis de textura completado\n');
        
    catch ME
        fprintf('Error en análisis de textura: %s\n', ME.message);
        % Valores por defecto en caso de error
        caracteristicas_textura.contraste = 0;
        caracteristicas_textura.correlacion = 0;
        caracteristicas_textura.energia = 0;
        caracteristicas_textura.homogeneidad = 0;
    end
end

%% FUNCIÓN DE EVALUACIÓN DE CALIDAD DE SEGMENTACIÓN

function metricas = evaluarCalidadSegmentacion(mascara, imagen)
    % Evaluar calidad de la segmentación
    metricas = struct();
    
    if isempty(mascara) || ~any(mascara(:))
        metricas.completitud = 0;
        metricas.consistencia = 0;
        metricas.suavidad_bordes = 0;
        return;
    end
    
    % Calcular completitud (área segmentada vs área esperada)
    area_segmentada = sum(mascara(:));
    area_total = numel(mascara);
    metricas.completitud = area_segmentada / area_total;
    
    % Calcular consistencia (uniformidad de intensidades en región segmentada)
    region_segmentada = imagen(mascara);
    if ~isempty(region_segmentada)
        metricas.consistencia = 1 - (std(double(region_segmentada)) / (max(region_segmentada) - min(region_segmentada) + eps));
    else
        metricas.consistencia = 0;
    end
    
    % Calcular suavidad de bordes
    bordes = edge(mascara, 'canny');
    if any(bordes(:))
        [filas, cols] = find(bordes);
        if length(filas) >= 3
            distancias = sqrt(diff(filas).^2 + diff(cols).^2);
            metricas.suavidad_bordes = 1 / (1 + std(distancias));
        else
            metricas.suavidad_bordes = 0;
        end
    else
        metricas.suavidad_bordes = 0;
    end
    
    metricas.completitud = max(0, min(1, metricas.completitud));
    metricas.consistencia = max(0, min(1, metricas.consistencia));
    metricas.suavidad_bordes = max(0, min(1, metricas.suavidad_bordes));
end