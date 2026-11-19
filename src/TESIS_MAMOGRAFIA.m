function TESIS_MAMOGRAFIA(modo)
%% ==========================================================================================
%  TESIS_MAMOGRAFIA - Lanzador unico de la linea de la tesis (V13)
%  Tesis: "Caracterizacion de la densidad mamografica en mujeres a partir del reconocimiento
%          de patrones geometricos" - Universidad ECCI
%
%  NO modifica SISTEMA_V13_UNIFICADO.m: lo llama tal cual, con la configuracion elegida.
%
%  Uso:
%    >> TESIS_MAMOGRAFIA('rapido')    % ~1,5 h, ResNet-50 y ResNet-50 + geometria (sin ViT)
%    >> TESIS_MAMOGRAFIA('completo')  % ~12-14 h en GTX 1060 6 GB (todos los modelos)
%
%  Requisitos: Image Processing Toolbox, Deep Learning Toolbox y Statistics and ML Toolbox.
%  Las rutas de datos (INbreast, CBIS-DDSM, CMMD) se toman de configuracion() en V13.
%
%  ESTADO: escrito, NO ejecutado en MATLAB. Antes de la corrida larga, validar con
%          >> TESIS_MAMOGRAFIA('rapido')  y revisar la carpeta SALIDA_V12\V13_<fecha>.
%% ==========================================================================================

if nargin < 1 || isempty(modo)
    modo = 'rapido';
end

carpetaV13 = fileparts(mfilename('fullpath'));   % carpeta src/ del repositorio
archivoV13 = fullfile(carpetaV13, 'SISTEMA_V13_UNIFICADO.m');
if ~isfile(archivoV13)
    error('TESIS_MAMOGRAFIA:noV13', 'No se encuentra SISTEMA_V13_UNIFICADO.m en: %s', carpetaV13);
end
addpath(carpetaV13);

switch lower(string(modo))
    case "rapido"
        c = struct();
        c.modelos          = ["resnet50" "resnet50_geo"];
        c.modeloReferencia = "resnet50";
        fprintf('[TESIS_MAMOGRAFIA] Modo rapido: %s\n', strjoin(c.modelos, ', '));
        SISTEMA_V13_UNIFICADO(c);
    case "completo"
        fprintf('[TESIS_MAMOGRAFIA] Modo completo: configuracion por defecto de V13.\n');
        SISTEMA_V13_UNIFICADO();
    otherwise
        error('TESIS_MAMOGRAFIA:modo', 'modo debe ser ''rapido'' o ''completo''.');
end
end
