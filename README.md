# Densidad mamográfica a partir de descriptores físicos y geométricos — código MATLAB

Código MATLAB de la tesis de maestría *"Caracterización de la densidad mamográfica en mujeres a partir del reconocimiento de patrones geométricos"* (Universidad ECCI, Bogotá) y del artículo asociado *"Physics-Based Geometric and Biomechanical Descriptors for Mammographic Density Assessment: A Reproducible Multimodel Study"* (en preparación).

Autor: Carlos Eduardo Mesa Mesa — Universidad ECCI · Universidad Agustiniana (Uniagustiniana).

## Contenido

| Carpeta | Contenido |
| --- | --- |
| `src/SISTEMA_V13_UNIFICADO.m` | Sistema final usado en el artículo: preprocesamiento, 16 descriptores radiómicos, 18 geométricos (fractal, espectro de Fourier, teorema de Green, GLRLM, Hu, Harris, coherencia), FEM en deformación plana, ResNet-50, ViT-B/16, fusión imagen–tabular, validación por paciente y estadística (κ cuadrático, bootstrap, DeLong, McNemar, Holm). |
| `src/TESIS_MAMOGRAFIA.m` | Lanzador: `TESIS_MAMOGRAFIA('rapido')` o `TESIS_MAMOGRAFIA('completo')`. |
| `src/SISTEMA_V12_*.m` | Versiones V12 (experimentos y red neuronal), antecedentes directos de V13. |
| `scripts/` | Utilidades de ejecución, diagnóstico y descarga/validación de conjuntos públicos (CBIS-DDSM, RSNA). |
| `historial/` | Versiones anteriores (2025–2026) conservadas como registro del desarrollo; no se mantienen. |

## Requisitos

MATLAB R2023b o posterior con Image Processing, Deep Learning y Statistics and Machine Learning Toolboxes. Una GPU con ≥ 6 GB acelera el entrenamiento de las redes.

## Datos

Las imágenes **no** se incluyen. INbreast (Moreira et al., *Acad Radiol* 2012) debe solicitarse a sus autores; CBIS-DDSM, CMMD y RSNA se descargan de sus repositorios públicos. Las rutas se configuran en la función `configuracion()` de `SISTEMA_V13_UNIFICADO.m`.

## Uso rápido

```matlab
addpath('src');
TESIS_MAMOGRAFIA('rapido')     % ~1,5 h: ResNet-50 y ResNet-50 + geometría
TESIS_MAMOGRAFIA('completo')   % todos los modelos y análisis
```

Los resultados (tablas T4–T9, figuras e informe) se escriben en `SALIDA_V12/V13_<fecha>/`.

## Aviso

Herramienta de investigación. No es un dispositivo médico ni sustituye la lectura de un radiólogo.

## Licencia

MIT (ver `LICENSE`).
