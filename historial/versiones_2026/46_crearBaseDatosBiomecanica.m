%% BASE DE DATOS BIOMECÁNICA INTEGRADA - TESIS DOCTORAL
% Sistema organizado de propiedades de tejidos y fantomas
% Basado en revisión bibliográfica 2015-2025

function database = crearBaseDatosBiomecanica()
%% INICIALIZAR ESTRUCTURA PRINCIPAL
database = struct();

fprintf('=== CREANDO BASE DE DATOS BIOMECÁNICA ===\n');

%% 1. TEJIDO MAMARIO - PROPIEDADES MECÁNICAS
fprintf('Cargando tejido mamario...\n');

database.mama = struct();

% Duraes et al. 2024 - Clinical Anatomy
database.mama(1).id = 'M001';
database.mama(1).autor = 'Duraes_2024';
database.mama(1).titulo = 'Evaluation of breast skin and tissue stiffness using non-invasive aspiration';
database.mama(1).doi = '10.1002/ca.24134';
database.mama(1).anio = 2024;

database.mama(1).propiedades.rigidez_piel.valor = 39000; % [Pa]
database.mama(1).propiedades.rigidez_piel.unidad = 'Pa';
database.mama(1).propiedades.rigidez_piel.desviacion = [];
database.mama(1).propiedades.rigidez_piel.n = 196;

database.mama(1).propiedades.rigidez_adiposa.valor = 3000; % [Pa]
database.mama(1).propiedades.rigidez_adiposa.unidad = 'Pa';
database.mama(1).propiedades.espesor_piel.valor = 1.83; % [mm]

database.mama(1).metodo = 'Aspiracion_VLASTIC';
database.mama(1).tipo_tejido = 'in_vivo_sano';
database.mama(1).muestra = '196 mujeres - cohorte clínica';
database.mama(1).relevancia = 'Valores in vivo para modelos FEA';
database.mama(1).capitulo_tesis = '2.1';

% Guillaumin et al. 2024 - Ultrasound in Medicine and Biology
database.mama(2).id = 'M002';
database.mama(2).autor = 'Guillaumin_2024';
database.mama(2).titulo = 'Biopathologic Characterization of Breast Cancer with 3D Multiparametric Ultrasound';
database.mama(2).doi = '10.1016/j.ultrasmedbio.2023.12.004';
database.mama(2).anio = 2024;

database.mama(2).propiedades.precision_diagnostica.valor = 95.7; % [%]
database.mama(2).propiedades.precision_diagnostica.unidad = '%';

database.mama(2).metodo = 'Shear_Wave_Elastography_BTI';
database.mama(2).tipo_tejido = 'ex_vivo_tumoral';
database.mama(2).muestra = '64 especímenes carcinoma';
database.mama(2).relevancia = 'Validación métodos imagen para propiedades tumorales';
database.mama(2).capitulo_tesis = '2.2';

%% 2. TEJIDO CEREBRAL - PROPIEDADES MECÁNICAS
fprintf('Cargando tejido cerebral...\n');

database.cerebro = struct();

% Jiang et al. 2015 - Biomechanics and Modeling in Mechanobiology
database.cerebro(1).id = 'C001';
database.cerebro(1).autor = 'Jiang_2015';
database.cerebro(1).titulo = 'Measuring linear and nonlinear elastic properties of brain tissue with shear waves';
database.cerebro(1).doi = '10.1007/s10237-015-0658-0';
database.cerebro(1).anio = 2015;

database.cerebro(1).propiedades.modulo_corte_inicial.valor = [1800, 3200]; % [Pa] - rango
database.cerebro(1).propiedades.modulo_corte_inicial.unidad = 'Pa';
database.cerebro(1).propiedades.parametro_hiperelastico.valor = [0.13, 0.73]; % rango

database.cerebro(1).metodo = 'Supersonic_Shear_Imaging';
database.cerebro(1).tipo_tejido = 'ex_vivo_porcino';
database.cerebro(1).muestra = 'Cerebro porcino completo';
database.cerebro(1).relevancia = 'Coeficientes no lineales para modelos hiperelásticos';
database.cerebro(1).capitulo_tesis = '2.1, 2.2';

% Türker et al. 2024 - Advanced Biology
database.cerebro(2).id = 'C002';
database.cerebro(2).autor = 'Turker_2024';
database.cerebro(2).titulo = 'Breast Tumor Cell Survival in Brain-like ECM';
database.cerebro(2).doi = '10.1002/adbi.202400184';
database.cerebro(2).anio = 2024;

database.cerebro(2).propiedades.modulo_elastico_blando.valor = 148; % [Pa]
database.cerebro(2).propiedades.modulo_elastico_blando.unidad = 'Pa';
database.cerebro(2).propiedades.modulo_elastico_blando.desviacion = 34;

database.cerebro(2).propiedades.modulo_elastico_rigido.valor = 1274; % [Pa]
database.cerebro(2).propiedades.modulo_elastico_rigido.unidad = 'Pa';
database.cerebro(2).propiedades.modulo_elastico_rigido.desviacion = 440;

database.cerebro(2).metodo = 'Caracterizacion_Hidrogeles';
database.cerebro(2).tipo_tejido = 'modelo_hidrogel';
database.cerebro(2).muestra = 'Hidrogeles basados en ácido hialurónico';
database.cerebro(2).relevancia = 'Referencia para modelos de interacción tumor-cerebro';
database.cerebro(2).capitulo_tesis = '2.1';

% Zhu et al. 2023 - APL Bioengineering
database.cerebro(3).id = 'C003';
database.cerebro(3).autor = 'Zhu_2023';
database.cerebro(3).titulo = 'Supershear Rayleigh wave imaging for brain biomechanics';
database.cerebro(3).doi = '10.1063/5.0160213';
database.cerebro(3).anio = 2023;

database.cerebro(3).propiedades.velocidad_SRW.valor = 1.9649; % [factor vs shear waves]
database.cerebro(3).propiedades.velocidad_SRW.unidad = 'relativo';
database.cerebro(3).propiedades.anisotropia_medulla.valor = 'alta';

database.cerebro(3).metodo = 'Optical_Coherence_Elastography';
database.cerebro(3).tipo_tejido = 'ex_vivo_humano';
database.cerebro(3).muestra = 'Lóbulos frontal, parietal, médula oblonga';
database.cerebro(3).relevancia = 'Datos regionales para modelos FEA anisotrópicos';
database.cerebro(3).capitulo_tesis = '2.2';

% Tardieu et al. 2022 - NMR in Biomedicine
database.cerebro(4).id = 'C004';
database.cerebro(4).autor = 'Tardieu_2022';
database.cerebro(4).titulo = 'Magnetic resonance elastography with guided pressure waves';
database.cerebro(4).doi = '10.1002/nbm.4701';
database.cerebro(4).anio = 2022;

database.cerebro(4).propiedades.modulo_corte.valor = 'no_explicito';
database.cerebro(4).propiedades.repetibilidad.valor = 'alta';

database.cerebro(4).metodo = 'MRE_presion_guiada';
database.cerebro(4).tipo_tejido = 'in_vivo_humano';
database.cerebro(4).muestra = 'Cerebro humano in vivo';
database.cerebro(4).relevancia = 'Protocolo no invasivo para propiedades viscoelásticas';
database.cerebro(4).capitulo_tesis = '2.2';

%% 3. MÉTODOS DE VALIDACIÓN EXPERIMENTAL
fprintf('Cargando métodos de validación...\n');

database.validacion = struct();

% Majumder et al. 2024 - IEEE Transactions on Medical Imaging
database.validacion(1).id = 'V001';
database.validacion(1).autor = 'Majumder_2024';
database.validacion(1).titulo = 'Non-invasive imaging of mechanical properties using Eshelby tensor transformations';
database.validacion(1).doi = '10.1109/TMI.2024.3385644';
database.validacion(1).anio = 2024;

database.validacion(1).propiedades.precision_reconstruccion.valor = 97.06; % [%]
database.validacion(1).propiedades.precision_reconstruccion.desviacion = 2.42;
database.validacion(1).propiedades.precision_reconstruccion.unidad = '%';

database.validacion(1).metodo = 'Compression_Elastography_Eshelby';
database.validacion(1).aplicacion = 'Tumores mama in vivo (ratón)';
database.validacion(1).relevancia = 'Reconstrucción simultánea YM y PR para FEA';
database.validacion(1).capitulo_tesis = '2.2, 2.3';

% Metzner et al. 2024 - APL Bioengineering
database.validacion(2).id = 'V002';
database.validacion(2).autor = 'Metzner_2024';
database.validacion(2).titulo = 'Novel stress sensor for quantitative micro elastography';
database.validacion(2).doi = '10.1063/5.0220309';
database.validacion(2).anio = 2024;

database.validacion(2).propiedades.escala.valor = 'micro';
database.validacion(2).metodo = 'QME_Stress_Sensor';
database.validacion(2).aplicacion = 'Mecánica tisular a microescala';
database.validacion(2).relevancia = 'Validación de supuestos constitutivos multiescala';
database.validacion(2).capitulo_tesis = '2.2';

% Singh & Chanda 2021 - Biomedical Materials
database.validacion(3).id = 'V003';
database.validacion(3).autor = 'Singh_2021';
database.validacion(3).titulo = 'Mechanical properties of whole body soft human tissues: a review';
database.validacion(3).doi = '10.1088/1748-605X/AC2B7A';
database.validacion(3).anio = 2021;

database.validacion(3).propiedades.ambito.valor = 'cuerpo_completo';
database.validacion(3).metodo = 'Revision_Sistematica';
database.validacion(3).aplicacion = 'Compilación propiedades tejidos blandos';
database.validacion(3).relevancia = 'Referencia para calibración y análisis de sensibilidad';
database.validacion(3).capitulo_tesis = '2.1, 2.4';

%% 4. FANTIMAS - MAMA
fprintf('Cargando fantomas mamarios...\n');

database.fantomas_mama = struct();

% Krenkevich et al. 2024 - IEEE Journal of Electromagnetics
database.fantomas_mama(1).id = 'FM001';
database.fantomas_mama(1).autor = 'Krenkevich_2024';
database.fantomas_mama(1).titulo = 'Tissue Mimicking Materials for Shell-Based Phantoms in Breast Microwave Sensing';
database.fantomas_mama(1).doi = '10.1109/jerm.2024.3379747';
database.fantomas_mama(1).anio = 2024;

database.fantomas_mama(1).materiales.piel = 'Resina + grafito + carbon-black';
database.fantomas_mama(1).materiales.adiposo = 'Soluciones DGBE';
database.fantomas_mama(1).materiales.fibroglandular = 'Soluciones DGBE';

database.fantomas_mama(1).fabricacion = 'Shell-based con relleno líquido';
database.fantomas_mama(1).validacion = 'Caracterización dieléctrica 0.4-9.0 GHz';
database.fantomas_mama(1).aplicacion = 'Microondas';
database.fantomas_mama(1).relevancia = 'Recetas prácticas para fidelidad dieléctrica';
database.fantomas_mama(1).capitulo_tesis = '2.3';

% Ikejimba et al. 2022 - Medical Physics
database.fantomas_mama(2).id = 'FM002';
database.fantomas_mama(2).autor = 'Ikejimba_2022';
database.fantomas_mama(2).titulo = 'Hyperia: Novel methodology for anthropomorphic breast phantoms';
database.fantomas_mama(2).doi = '10.1002/mp.16045';
database.fantomas_mama(2).anio = 2022;

database.fantomas_mama(2).materiales.sustrato = 'Papel de oficina';
database.fantomas_mama(2).materiales.contraste = 'Agujeros laser-engraved';

database.fantomas_mama(2).fabricacion = 'Hyperization → Laser cutting → Stacking';
database.fantomas_mama(2).validacion = 'Simulación Monte Carlo CT, correlación ρ=0.88-0.94';
database.fantomas_mama(2).aplicacion = 'Rayos X';
database.fantomas_mama(2).relevancia = 'Método antropomórfico de bajo costo';
database.fantomas_mama(2).capitulo_tesis = '2.3';

% Zhang & Fu 2023 - Physics in Medicine and Biology
database.fantomas_mama(3).id = 'FM003';
database.fantomas_mama(3).autor = 'Zhang_2023';
database.fantomas_mama(3).titulo = 'New breast phantom for mammography and tomosynthesis';
database.fantomas_mama(3).doi = '10.1088/1361-6560/acb636';
database.fantomas_mama(3).anio = 2023;

database.fantomas_mama(3).materiales.base = 'Materiales equivalentes tisulares propietarios';
database.fantomas_mama(3).materiales.inserciones = 'Microcalcificaciones, tumores inyectables';

database.fantomas_mama(3).fabricacion = 'Ensamblaje capa por capa';
database.fantomas_mama(3).validacion = 'Métricas IQ (CNR, MTF, ASF)';
database.fantomas_mama(3).aplicacion = 'Mamografía, CEDM, DBT';
database.fantomas_mama(3).relevancia = 'Diseño multimodal para optimización dosis-calidad';
database.fantomas_mama(3).capitulo_tesis = '4.1';

% Saleh et al. 2023 - PLOS ONE
database.fantomas_mama(4).id = 'FM004';
database.fantomas_mama(4).autor = 'Saleh_2023';
database.fantomas_mama(4).titulo = 'Heterogeneous breast phantom for CT and MRI';
database.fantomas_mama(4).doi = '10.1371/journal.pone.0284531';
database.fantomas_mama(4).anio = 2023;

database.fantomas_mama(4).materiales.piel = 'TMM personalizado';
database.fantomas_mama(4).materiales.adiposo = 'TMM personalizado';
database.fantomas_mama(4).materiales.fibroglandular = 'TMM personalizado';
database.fantomas_mama(4).materiales.carcinoma = 'TMM personalizado';

database.fantomas_mama(4).fabricacion = 'Segmentación MRI → Moldes → Colada TMM';
database.fantomas_mama(4).validacion = 'HU CT, T1/T2 MRI, propiedades ionizantes';
database.fantomas_mama(4).aplicacion = 'TC, RM';
database.fantomas_mama(4).relevancia = 'Referencia para validación multimodal';
database.fantomas_mama(4).capitulo_tesis = '3.1';

% Albanese et al. 2016 - Medical Physics
database.fantomas_mama(5).id = 'FM005';
database.fantomas_mama(5).autor = 'Albanese_2016';
database.fantomas_mama(5).titulo = 'Tissue Equivalent Phantom with Excised Human Tissue';
database.fantomas_mama(5).doi = '10.1118/1.4958103';
database.fantomas_mama(5).anio = 2016;

database.fantomas_mama(5).materiales.adiposo = 'Manteca';
database.fantomas_mama(5).materiales.tumoral = 'Tejido humano extirpado';

database.fantomas_mama(5).fabricacion = 'Geometría DICOM → Impresión 3D → Relleno';
database.fantomas_mama(5).validacion = 'Imágenes de dispersión coherente, 86% correlación';
database.fantomas_mama(5).aplicacion = 'Dispersión de rayos X';
database.fantomas_mama(5).relevancia = 'Firmas de dispersión realistas para microestructura';
database.fantomas_mama(5).capitulo_tesis = '4.2';

%% 5. FANTIMAS - CEREBRO
fprintf('Cargando fantomas cerebrales...\n');

database.fantomas_cerebro = struct();

% Kilian et al. 2022 - ACS Applied Materials & Interfaces
database.fantomas_cerebro(1).id = 'FC001';
database.fantomas_cerebro(1).autor = 'Kilian_2022';
database.fantomas_cerebro(1).titulo = '3D extrusion printing of biphasic anthropomorphic brain phantoms';
database.fantomas_cerebro(1).doi = '10.1021/acsami.2c12872';
database.fantomas_cerebro(1).anio = 2022;

database.fantomas_cerebro(1).materiales.base = 'Alginato, agarosa, carragenina';
database.fantomas_cerebro(1).materiales.dopante = 'GdCl3';

database.fantomas_cerebro(1).fabricacion = 'Impresión por extrusión multicanal → Reticulación Ca²⁺';
database.fantomas_cerebro(1).validacion = 'T1/T2 MRI, estabilidad temporal';
database.fantomas_cerebro(1).aplicacion = 'RM cuantitativa';
database.fantomas_cerebro(1).relevancia = 'Fabricación aditiva escalable con T1/T2 ajustables';
database.fantomas_cerebro(1).capitulo_tesis = '2.3';

% Kraft et al. 2023 - PLOS ONE
database.fantomas_cerebro(2).id = 'FC002';
database.fantomas_cerebro(2).autor = 'Kraft_2023';
database.fantomas_cerebro(2).titulo = 'Towards barrier-free anthropomorphic brain phantom for quantitative MRI';
database.fantomas_cerebro(2).doi = '10.1371/journal.pone.0285432';
database.fantomas_cerebro(2).anio = 2023;

database.fantomas_cerebro(2).materiales.materia_gris = 'Geles ajustados T1/T2';
database.fantomas_cerebro(2).materiales.materia_blanca = 'Geles ajustados T1/T2';

database.fantomas_cerebro(2).fabricacion = 'Moldes disolubles, anatomía 3D';
database.fantomas_cerebro(2).validacion = 'Estabilidad T1/T2 0-22 semanas, MRI 3T';
database.fantomas_cerebro(2).aplicacion = 'RM cuantitativa sin barreras';
database.fantomas_cerebro(2).relevancia = 'Lecciones sobre interfases y estabilidad temporal';
database.fantomas_cerebro(2).capitulo_tesis = '4.1';

% Wood et al. 2021 - NMR in Biomedicine
database.fantomas_cerebro(3).id = 'FC003';
database.fantomas_cerebro(3).autor = 'Wood_2021';
database.fantomas_cerebro(3).titulo = 'Comprehensive electromagnetic evaluation of MRI anthropomorphic head phantom';
database.fantomas_cerebro(3).doi = '10.1002/NBM.4441';
database.fantomas_cerebro(3).anio = 2021;

database.fantomas_cerebro(3).materiales.compartimentos = '6 compartimentos rellenables';
database.fantomas_cerebro(3).fabricacion = 'Impresión 3D de carcasa antropomórfica';
database.fantomas_cerebro(3).validacion = 'Simulaciones EM, mapeo campo B1+ 7T';
database.fantomas_cerebro(3).aplicacion = 'Evaluación bobinas RF MRI';
database.fantomas_cerebro(3).relevancia = 'Puente entre simulación y experimento en MRI alto campo';
database.fantomas_cerebro(3).capitulo_tesis = '3.2';

%% 6. MATERIALES Y FABRICACIÓN
fprintf('Cargando materiales y métodos de fabricación...\n');

database.materiales = struct();

% Malyarenko et al. 2023 - Medical Physics
database.materiales(1).id = 'MAT001';
database.materiales(1).autor = 'Malyarenko_2023';
database.materiales(1).titulo = 'Hydrogel-based mimics of prostate cancer for mpMRI validation';
database.materiales(1).doi = '10.1002/mp.16908';
database.materiales(1).anio = 2023;

database.materiales(1).composicion.agarosa = 'Control T2';
database.materiales(1).composicion.PVP = 'Modulación difusión monoexponencial';
database.materiales(1).composicion.vesiculas = 'Ajuste curtosis';
database.materiales(1).composicion.PAG = 'Estabilización mecánica UV';

database.materiales(1).propiedades_mri.T2 = [65, 255]; % [ms]
database.materiales(1).propiedades_mri.Da = [0.8, 1.7]; % [μm²/ms]
database.materiales(1).propiedades_mri.Ka = [0.5, 1.25];
database.materiales(1).estabilidad = '>6 meses';

database.materiales(1).fabricacion = 'Hidrogeles agarosa-PVP, opcional reticulación UV';
database.materiales(1).aplicacion = 'MRI multiparamétrico';
database.materiales(1).relevancia = 'Recetas modulares para biomarcadores MRI';
database.materiales(1).capitulo_tesis = '3.1';

% McGarry et al. 2020 - Physics in Medicine and Biology (REVISIÓN)
database.materiales(2).id = 'MAT002';
database.materiales(2).autor = 'McGarry_2020';
database.materiales(2).titulo = 'Tissue mimicking materials for imaging and therapy phantoms: a review';
database.materiales(2).doi = '10.1088/1361-6560/ABBD17';
database.materiales(2).anio = 2020;

database.materiales(2).clases_materiales = {'Geles agua', 'PVA', 'Agar/agarosa', 'Gelatina', 'Siliconas/PDMS', 'Materiales aceite'};
database.materiales(2).fabricacion = 'Moldeo, fundición, ciclos congelación-descongelación, UV, impresión 3D';
database.materiales(2).validacion = 'HU TC, relajación RM, velocidad/atenuación US, espectroscopía dieléctrica';
database.materiales(2).relevancia = 'Referencia autorizada para selección TMM y compensaciones';
database.materiales(2).capitulo_tesis = '1.2';

% Jawli et al. 2024 - Bioengineering (REVISIÓN SISTEMÁTICA)
database.materiales(3).id = 'MAT003';
database.materiales(3).autor = 'Jawli_2024';
database.materiales(3).titulo = 'Tissue mimicking material fabrication for multiparametric ultrasound phantoms';
database.materiales(3).doi = '10.3390/bioengineering11060620';
database.materiales(3).anio = 2024;

database.materiales(3).materiales_recomendados = 'Materiales agua, PVA';
database.materiales(3).fabricacion = 'Solventes agua/aceite, ciclos congelación-descongelación PVA';
database.materiales(3).validacion = 'Velocidad/atenuación acústica, compresión mecánica, elastografía';
database.materiales(3).relevancia = 'Guía para fidelidad ultrasónica/acústica';
database.materiales(3).capitulo_tesis = '3.1';

%% RESUMEN EJECUTIVO
database.metadata.fecha_creacion = datestr(now);
database.metadata.total_articulos = struct(...
    'mama', length(database.mama), ...
    'cerebro', length(database.cerebro), ...
    'validacion', length(database.validacion), ...
    'fantomas_mama', length(database.fantomas_mama), ...
    'fantomas_cerebro', length(database.fantomas_cerebro), ...
    'materiales', length(database.materiales) ...
);

fprintf('\n=== BASE DE DATOS CREADA EXITOSAMENTE ===\n');
fprintf('Resumen:\n');
fprintf('- Tejido mamario: %d artículos\n', database.metadata.total_articulos.mama);
fprintf('- Tejido cerebral: %d artículos\n', database.metadata.total_articulos.cerebro);
fprintf('- Métodos validación: %d artículos\n', database.metadata.total_articulos.validacion);
fprintf('- Fantomas mama: %d artículos\n', database.metadata.total_articulos.fantomas_mama);
fprintf('- Fantomas cerebro: %d artículos\n', database.metadata.total_articulos.fantomas_cerebro);
fprintf('- Materiales: %d artículos\n', database.metadata.total_articulos.materiales);
fprintf('----------------------------------------\n');
fprintf('TOTAL: %d artículos organizados\n', ...
    database.metadata.total_articulos.mama + ...
    database.metadata.total_articulos.cerebro + ...
    database.metadata.total_articulos.validacion + ...
    database.metadata.total_articulos.fantomas_mama + ...
    database.metadata.total_articulos.fantomas_cerebro + ...
    database.metadata.total_articulos.materiales);

end