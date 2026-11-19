% Validacion externa de densidad en CBIS-DDSM (3032 mamografias completas, densidad BI-RADS 1-4)
% con los modelos entrenados en INbreast por la corrida V13.
% Uso:  validar_cbis_v13          -> evaluacion completa (usa GPU; correr cuando termine la corrida V13)
%       validar_cbis_v13(true)    -> solo preprocesa y deja la cache lista (CPU)
function validar_cbis_v13(soloPre)
if nargin < 1, soloPre = false; end
assert(isfile('D:\CBIS-DDSM\CBIS_DDSM_etiquetas_densidad.csv'), 'Falta D:\CBIS-DDSM\CBIS_DDSM_etiquetas_densidad.csv (ejecute DESCARGAR_CBIS_DDSM)');
c = struct();
c.validarCBIS.modelos = fullfile(pwd, 'SALIDA_V12', 'V13_20261012_101954');   % corrida reanudada (modelos + cv_resnet50_p1..5)
if ~isfolder(fullfile(c.validarCBIS.modelos, 'modelos')) || isempty(dir(fullfile(c.validarCBIS.modelos, 'modelos', '*.mat')))
    c.validarCBIS.modelos = fullfile(pwd, 'SALIDA_V12', 'V13_20261011_220154');
end
c.validarCBIS.soloPreprocesar = soloPre;
c.verif.activo = false;
SISTEMA_V13_UNIFICADO(c)
end
