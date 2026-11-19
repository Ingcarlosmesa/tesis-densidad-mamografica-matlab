% Validacion externa de densidad en RSNA (Kaggle, FFDM) con los modelos V13 entrenados en INbreast.
% Uso: validar_rsna_v13 (GPU) | validar_rsna_v13(true) (solo preprocesar, CPU)
function validar_rsna_v13(soloPre)
if nargin < 1, soloPre = false; end
assert(isfile('D:\RSNA\RSNA_etiquetas_densidad.csv'), 'Falta D:\RSNA\RSNA_etiquetas_densidad.csv (ejecute DESCARGAR_RSNA)');
c = struct();
c.validarCBIS.modelos = fullfile(pwd, 'SALIDA_V12', 'V13_20261012_101954');
if isempty(dir(fullfile(c.validarCBIS.modelos, 'modelos', '*.mat')))
    c.validarCBIS.modelos = fullfile(pwd, 'SALIDA_V12', 'V13_20261011_220154');
end
c.validarCBIS.etiquetas = 'D:\RSNA\RSNA_etiquetas_densidad.csv';
c.validarCBIS.nombre = 'RSNA';
c.validarCBIS.soloPreprocesar = soloPre;
c.verif.activo = false;
SISTEMA_V13_UNIFICADO(c)
end
