% Reanuda la corrida V13 interrumpida: reutiliza los 4 modelos ya entrenados de V13_20261011_220154
% (fusion, fusion_sinFstress, resnet50, resnet50_geo) y sigue con validacion cruzada, lineas base,
% evaluacion, Grad-CAM, IGR en CMMD, federado, DDPM e informe. El ViT se omite (kappa <= 0.09 con lr 1e-5,
% ya documentado en V12 y en el registro de la corrida previa).
clc; close all;
assert(isfile('G:\tesis-base de datos\INbreast Release 1.0\INbreast.csv'), 'Disco G: no conectado');
assert(isfolder('F:\2021 tesis avances 2\data\manifest-1616439774456'), 'Disco F: (CMMD) no conectado');
c = struct();
c.reanudarDe = fullfile(pwd, 'SALIDA_V12', 'V13_20261011_220154');
c.modelos = ["fusion" "fusion_sinFstress" "resnet50" "resnet50_geo"];
SISTEMA_V13_UNIFICADO(c)
