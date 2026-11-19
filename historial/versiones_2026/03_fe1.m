function main_tesis()
% =====================================================================================
%  ANEXO A - SOFTWARE DE CARACTERIZACION DE LA DENSIDAD MAMOGRAFICA POR PATRONES
%            GEOMETRICOS  (implementacion MATLAB, ejecutable y verificable)
%
%  Tesis : "Caracterizacion de la densidad mamografica en mujeres a partir del
%           reconocimiento de patrones geometricos"
%  Programa: Maestria en Ingenieria - Universidad ECCI (GIATME)
%
%  Este archivo implementa de forma REAL (no simulada con numeros escritos a mano)
%  todo lo que propone la metodologia del documento:
%
%    * Fisica medica       : formacion de imagen por atenuacion de rayos X
%                            (ley de Beer-Lambert) y dosis glandular media (MGD).
%    * Densidad            : porcentaje de tejido denso (proxy de la categoria BI-RADS).
%    * Radiomica (10)      : 4 GLCM (contraste, correlacion, energia, homogeneidad),
%                            5 de intensidad (media, desv., asimetria, curtosis, entropia),
%                            1 de energia de Fourier.
%    * Geometrica (7)      : contornos (compacidad por TEOREMA DE GREEN), esquinas de
%                            Harris, simetria horizontal y vertical, momentos de Hu (Hu1,
%                            Hu2 -asimetria-), analisis de gradientes.
%    * Complejidad fractal : dimension fractal por conteo de cajas (box-counting).
%    * Biomecanica         : modulo de Young diferenciado (E_glandular vs E_adiposo) y
%                            tensiones de von Mises con concentracion en interfases.
%    * Microcalcificaciones: energia de detalle por wavelet DWT 'db4'.
%
%  Y la VALIDACION ESTADISTICA:
%    * t-test de Welch por descriptor, ANOVA por terciles de densidad.
%    * Indice Geometrico de Riesgo (IGR) con Random Forest y validacion (OOB).
%    * Huella radiomico-geometrica ponderada (30% densidad + 35% microcalc + 35% biomec).
%    * AUC con IC95% por bootstrap y TEST DE DeLong frente a la densidad sola (BI-RADS).
%
%  DATOS:
%    Por defecto se genera un FANTOMA con base fisica (Beer-Lambert) en el que las dos
%    clases tienen la MISMA densidad (igualada por construccion) y difieren UNICAMENTE
%    en la GEOMETRIA. Asi se demuestra de forma controlada el argumento de la tesis:
%    la densidad sola no separa, la geometria si. El fantoma sirve para VALIDAR el
%    metodo; NO es evidencia clinica.
%
%    Para correr sobre las 249 mamografias reales del INC, ver la funcion
%    cargar_caso_real() al final del archivo: basta reemplazar la generacion del
%    fantoma por la lectura de cada DICOM; el resto del pipeline es identico.
%
%  TOOLBOXES NECESARIOS:
%    - Image Processing Toolbox        (graycomatrix, graythresh, bwboundaries, ...)
%    - Statistics and Machine Learning (TreeBagger, perfcurve, ttest2, anova1)
%    - Wavelet Toolbox (opcional)      (wavedec2 'db4'; si no esta, se usa un respaldo)
%
%  EJECUCION:   >> main_tesis
%  Requiere MATLAB R2019b+ (usa tiledlayout). Genera figuras en ./figuras y CSV/MAT.
%
%  NOTA DE HONESTIDAD: los modulos de aprendizaje profundo del documento (CNN, ViT,
%  difusion DDPM, aprendizaje federado) NO se incluyen "falsificados". Entrenarlos de
%  verdad requiere las imagenes reales y GPU; este software entrega el nucleo clasico
%  completo (fisica + descriptores geometricos + clasificador con AUC validado), que es
%  lo que puede ejecutarse y verificarse de forma reproducible.
% =====================================================================================

clc; close all;
rng(2026);                                  % reproducibilidad

% ---------------------------------------------------------------------------------
% 0) Verificacion de toolboxes
% ---------------------------------------------------------------------------------
need_ipt   = exist('graycomatrix','file')==2 && exist('graythresh','file')==2;
need_stats = exist('TreeBagger','file')==2  && exist('perfcurve','file')==2;
has_wavelet= exist('wavedec2','file')==2;
assert(need_ipt,   'Falta Image Processing Toolbox.');
assert(need_stats, 'Falta Statistics and Machine Learning Toolbox.');
if ~has_wavelet
    warning('Wavelet Toolbox no disponible: microcalcificaciones se calculan con respaldo (filtro paso-alto).');
end

outdir = fullfile(pwd,'figuras'); if ~exist(outdir,'dir'), mkdir(outdir); end

% ---------------------------------------------------------------------------------
% 1) Constantes fisicas y biomecanicas (valores de la literatura)
% ---------------------------------------------------------------------------------
P = struct();
P.MU_FIBRO = 0.80;     % atenuacion lineal tejido fibroglandular [1/cm] (Johns & Yaffe, ~19 keV)
P.MU_ADIPO = 0.46;     % atenuacion lineal tejido adiposo        [1/cm]
P.T_BREAST = 5.0;      % espesor comprimido de la mama           [cm]
P.I0       = 1.0e4;    % fluencia incidente (cuentas) -> ruido cuantico de Poisson
P.E_FIBRO  = 15.1;     % modulo de Young fibroglandular          [kPa] (elastografia)
P.E_ADIPO  = 4.46;     % modulo de Young adiposo                 [kPa]
P.NU       = 0.49;     % coef. de Poisson (casi incompresible)
P.EPS0     = 0.20;     % deformacion vertical aplicada (compresion 20%)
P.KAPPA    = 0.60;     % factor de concentracion de esfuerzos en interfases (proxy)
P.LSCALE   = 1.0;      % escala espacial del gradiente de rigidez
P.N        = 160;      % numero de pacientes del fantoma
P.SZ       = 256;      % tamano de imagen (px)

fprintf('\n========================================================================\n');
fprintf(' 1) GENERACION CON FISICA (Beer-Lambert) DE %d PACIENTES\n', P.N);
fprintf('========================================================================\n');

% ---------------------------------------------------------------------------------
% 2) Generacion del fantoma + 3) Segmentacion
% ---------------------------------------------------------------------------------
sil = breast_silhouette(P.SZ);
labels = mod(0:P.N-1,2)';                    % 50/50: clase 0 (compacta) / clase 1 (fragmentada)

mammos = cell(P.N,1); Ls = cell(P.N,1); tfgs = cell(P.N,1); masks = cell(P.N,1);
gland  = zeros(P.N,1); mgd = zeros(P.N,1); dice = zeros(P.N,1);

for p = 1:P.N
    clase = labels(p);
    tfg   = fibro_thickness_map(clase, sil, P);          % verdad de terreno (espesor)
    [mam,L]= acquire_mammogram(tfg, sil, P);             % FISICA: Beer-Lambert + Poisson
    mask  = segment_dense(mam, sil);                     % SEGMENTACION: Otsu + morfologia

    mammos{p}=mam; Ls{p}=L; tfgs{p}=tfg; masks{p}=mask;
    gland(p)= sum(tfg(sil))/(P.T_BREAST*sum(sil(:)));    % glandularidad volumetrica
    mgd(p)  = mean_glandular_dose(gland(p));             % dosis glandular media
    truth   = tfg > (0.5*0.55*P.T_BREAST);               % verdad del tejido denso
    dice(p) = 2*sum(mask(:)&truth(:))/(sum(mask(:))+sum(truth(:))+eps);
end

fprintf('   Clase 0 (compacta): %d   Clase 1 (fragmentada): %d\n', sum(labels==0), sum(labels==1));
fprintf('   Glandularidad media: %.1f%%  (clase0=%.1f%%, clase1=%.1f%%)  <- igualada a proposito\n', ...
    100*mean(gland), 100*mean(gland(labels==0)), 100*mean(gland(labels==1)));
fprintf('   Dosis glandular media estimada (MGD): %.2f mGy/proyeccion\n', mean(mgd));
fprintf('\n 2) SEGMENTACION  Dice medio vs verdad de terreno: %.3f (+/- %.3f)\n', mean(dice), std(dice));

% ---------------------------------------------------------------------------------
% 4) Extraccion de descriptores (todos REALES), agrupados como en el documento
% ---------------------------------------------------------------------------------
fprintf('\n========================================================================\n');
fprintf(' 3-4) EXTRACCION DE DESCRIPTORES (Densidad/Radiomica/Geometrica/Biomec/Microcalc)\n');
fprintf('========================================================================\n');

names = {};                         % se llena en el primer caso
F = [];                             % matriz de caracteristicas
green_err = zeros(P.N,1);
for p = 1:P.N
    [row, names] = extraer_descriptores(mammos{p}, masks{p}, sil, P, has_wavelet);
    if isempty(F), F = zeros(P.N, numel(row)); end
    F(p,:) = row;                                                       %#ok<AGROW>
    green_err(p) = row(strcmp(names,'green_area_err'));
end
T = array2table(F, 'VariableNames', names);
T.clase = labels;

fprintf('   Matriz de caracteristicas: %d pacientes x %d variables\n', size(F,1), size(F,2));
fprintf('   Validacion TEOREMA DE GREEN: error medio area(integral)-vs-area(pixeles) = %.2f%%\n', mean(green_err));

% Medias por clase de algunos descriptores clave
clave = {'areal_density','fractal_dim','compactness','n_components','glcm_entropy', ...
         'hu2','sym_lr','harris_density','vm_max','microcalc_energy'};
fprintf('\n   Medias por clase (descriptor: clase0 -> clase1):\n');
for i=1:numel(clave)
    c = clave{i};
    if any(strcmp(names,c))
        v = T.(c);
        fprintf('     %-16s: %9.3f -> %9.3f\n', c, mean(v(labels==0)), mean(v(labels==1)));
    end
end

% ---------------------------------------------------------------------------------
% 5) Estadistica: t-test de Welch por descriptor + ANOVA por terciles de densidad
% ---------------------------------------------------------------------------------
fprintf('\n========================================================================\n');
fprintf(' 5) ESTADISTICA REAL\n');
fprintf('========================================================================\n');
fprintf('\n   t-test de Welch (clase0 vs clase1):\n');
pvals = nan(numel(names),1); tstat = nan(numel(names),1);
for i=1:numel(names)
    a = F(labels==0,i); b = F(labels==1,i);
    if std(a)<1e-9 && std(b)<1e-9
        fprintf('     %-16s  (constante - no discrimina)\n', names{i});
        pvals(i)=1.0; continue;
    end
    [~,pp,~,st] = ttest2(a,b,'Vartype','unequal');
    pvals(i)=pp; tstat(i)=st.tstat;
    star = '   '; if pp<0.001, star='***'; elseif pp<0.01, star='** '; elseif pp<0.05, star='*  '; else, star='ns '; end
    fprintf('     %-16s  t=%7.2f  p=%.2e  %s\n', names{i}, st.tstat, pp, star);
end
fprintf('   -> %d/%d caracteristicas significativas (p<0.05)\n', sum(pvals<0.05), numel(names));

% ANOVA: entropia GLCM por tercil de densidad
dens = T.areal_density;
q = quantile(dens,[1/3 2/3]);
terc = ones(P.N,1); terc(dens>q(1))=2; terc(dens>q(2))=3;
[pA, tblA] = anova1(T.glcm_entropy, terc, 'off');
Fval = tblA{2,5};
fprintf('\n   ANOVA (entropia GLCM ~ tercil de densidad):  F=%.2f  p=%.2e\n', Fval, pA);

% ---------------------------------------------------------------------------------
% 6) Clasificadores: IGR, Huella ponderada y Densidad sola; AUC + IC95% + DeLong
% ---------------------------------------------------------------------------------
fprintf('\n========================================================================\n');
fprintf(' 6) CLASIFICADORES Y COMPARACION (validacion OOB, AUC + DeLong)\n');
fprintf('========================================================================\n');

% --- conjuntos de variables segun el documento ---
geo_radiom = setdiff(names, {'areal_density','green_area_err','vm_max','vm_mean', ...
                             'microcalc_energy','microcalc_count','intens_mean'}); % nucleo geom+radiomico (IGR)
Xigr = T{:, geo_radiom};
y    = labels;

% --- IGR: Random Forest con prediccion OOB (analogo a validacion cruzada) ---
B = TreeBagger(400, Xigr, categorical(y), 'Method','classification', ...
               'OOBPrediction','on', 'MinLeafSize',3);
[~, scoreIGRm] = oobPredict(B);
posCol = find(strcmp(B.ClassNames,'1'));
scoreIGR = scoreIGRm(:,posCol);
[~,~,~,aucIGR] = perfcurve(y, scoreIGR, 1);
ciIGR = bootci_auc(y, scoreIGR, 2000);

% --- Densidad sola (proxy BI-RADS): la propia densidad como marcador ---
scoreDens = dens;
[~,~,~,aucDens] = perfcurve(y, scoreDens, 1);
% orientacion del marcador (por si la densidad fuese protectora):
if aucDens < 0.5, scoreDens = -scoreDens; [~,~,~,aucDens] = perfcurve(y, scoreDens, 1); end
ciDens = bootci_auc(y, scoreDens, 2000);

% --- Huella radiomico-geometrica ponderada (30% densidad + 35% microcalc + 35% biomec) ---
sDens  = orient_score(zscore_(T.areal_density),      y);
sMicro = orient_score(zscore_(T.microcalc_energy),   y);
sBio   = orient_score(zscore_(T.vm_max + T.vm_mean), y);
scoreHuella = 0.30*sDens + 0.35*sMicro + 0.35*sBio;
[~,~,~,aucHuella] = perfcurve(y, scoreHuella, 1);
ciHuella = bootci_auc(y, scoreHuella, 2000);

% --- Test de DeLong (AUCs pareados, mismas muestras) ---
[z1, p1] = delong_test(y, scoreIGR,    scoreDens);
[z2, p2] = delong_test(y, scoreHuella, scoreDens);

fprintf('   AUC  IGR (geometria+radiomica)        : %.3f  IC95%% [%.3f, %.3f]\n', aucIGR,   ciIGR(1),   ciIGR(2));
fprintf('   AUC  Huella (30%%dens+35%%mc+35%%biom)   : %.3f  IC95%% [%.3f, %.3f]\n', aucHuella, ciHuella(1), ciHuella(2));
fprintf('   AUC  Densidad sola (proxy BI-RADS)    : %.3f  IC95%% [%.3f, %.3f]\n', aucDens,  ciDens(1),  ciDens(2));
fprintf('   DeLong  IGR    vs densidad            : z=%.2f  p=%.2e  %s\n', z1, p1, sig_txt(p1));
fprintf('   DeLong  Huella vs densidad            : z=%.2f  p=%.2e  %s\n', z2, p2, sig_txt(p2));

% importancia de variables del IGR (permutacion OOB)
Bimp = TreeBagger(400, Xigr, categorical(y), 'Method','classification', ...
                  'OOBPredictorImportance','on', 'MinLeafSize',3);
[impSorted, idx] = sort(Bimp.OOBPermutedPredictorDeltaError, 'descend');
fprintf('\n   Top-6 descriptores del IGR (importancia OOB):\n');
for i=1:min(6,numel(idx))
    fprintf('     %-16s  %.3f\n', geo_radiom{idx(i)}, impSorted(i));
end

% ---------------------------------------------------------------------------------
% 7) Figuras
% ---------------------------------------------------------------------------------
ej0 = find(labels==0,1); ej1 = find(labels==1,1);
fig1_fisica(tfgs{ej0}, Ls{ej0}, mammos{ej0}, P, mean(mgd), outdir);
fig2_fourier(mammos{ej0}, mammos{ej1}, masks{ej0}, masks{ej1}, outdir);
fig3_fractal(masks{ej1}, outdir);
fig4_vonmises(masks{ej1}, sil, P, outdir);
fig5_estadistica(T, names, pvals, labels, outdir);
fig6_roc(y, scoreIGR, scoreDens, aucIGR, aucDens, ciIGR, ciDens, p1, outdir);

% ---------------------------------------------------------------------------------
% 8) Exportar resultados
% ---------------------------------------------------------------------------------
writetable(T, fullfile(pwd,'features_matlab.csv'));
save(fullfile(pwd,'resultados_matlab.mat'), 'T','names','pvals','tstat', ...
     'aucIGR','aucDens','aucHuella','ciIGR','ciDens','ciHuella','z1','p1','z2','p2','dice','mgd','gland');
fprintf('\n   Figuras en %s | features_matlab.csv | resultados_matlab.mat\n', outdir);
fprintf('   LISTO.\n\n');
end % ====================== fin de main_tesis ======================


% =====================================================================================
%  FUNCIONES LOCALES
% =====================================================================================

function sil = breast_silhouette(sz)
% Mascara en forma de mama (semielipse) sobre el detector.
    [xx,yy] = meshgrid(0:sz-1, 0:sz-1);
    cx=sz*0.5; cy=sz*0.5; a=sz*0.42; b=sz*0.46;
    sil = (((xx-cx)/a).^2 + ((yy-cy)/b).^2) <= 1.0;
end

function out = powerlaw_noise(sz, beta)
% Ruido 1/f^beta (textura autosimilar): controla complejidad/fractal.
    f = randn(sz);
    Fc = fftshift(fft2(f));
    [kx,ky] = meshgrid(-floor(sz/2):ceil(sz/2)-1, -floor(sz/2):ceil(sz/2)-1);
    k = sqrt(kx.^2+ky.^2); k(k==0)=1;
    Fc = Fc ./ (k.^(beta/2));
    out = real(ifft2(ifftshift(Fc)));
    mn = min(out(:)); mx = max(out(:));
    out = (out-mn)/((mx-mn)+1e-9);
end

function tfg = fibro_thickness_map(clase, sil, P)
% Mapa de espesor fibroglandular t_fg(x,y) [cm].
% CONDICION CONTROLADA (hipotesis de la tesis): ambas clases con la MISMA densidad
% (misma fraccion de area densa -> misma BI-RADS, igualada por construccion) y que
% difieren UNICAMENTE en la GEOMETRIA. Se modela una "severidad geometrica" latente
% con distribuciones que se SOLAPAN entre clases -> una fraccion de casos es ambigua
% -> el AUC alcanzable queda acotado (~0.94) y es realista, no perfecto.
    sz=P.SZ;
    [xx,yy] = meshgrid(0:sz-1, 0:sz-1);
    cx=sz*0.5; cy=sz*0.5;
    a_target = 0.12 + 0.10*rand;                  % fraccion de area densa (comun a ambas clases)

    if clase==0, mu=0.30; else, mu=0.70; end
    sev = min(max(mu + 0.18*randn, 0), 1);        % severidad geometrica latente

    nblobs = round(1 + 7*sev);                    % 1 (compacto) .. 8 (fragmentado)
    spread = sz*(0.03 + 0.18*sev);                % dispersion espacial
    blobsz = sz*(0.12 - 0.07*sev);                % islotes mas pequenos si fragmentado
    rough_w= 0.05 + 0.40*sev;                     % aspereza de borde
    beta   = max(1.2, 4.5 - 2.7*sev);             % espectro: suave (4.5) -> aspero (1.8)

    field = zeros(sz);
    for b=1:max(1,nblobs)
        ox = cx + spread*randn; oy = cy + spread*randn;
        ss = max(sz*0.04, blobsz*(0.8+0.4*rand));
        field = field + exp(-(((xx-ox).^2+(yy-oy).^2)/(2*ss^2)));
    end
    field = field + rough_w*powerlaw_noise(sz, beta);
    field = field .* sil;

    % Umbral por PERCENTIL -> misma fraccion de area densa (densidad pareada)
    inside = field(sil);
    thr = quantile(inside, 1 - a_target);
    dense = (field > thr) & sil;

    base = 0.55*P.T_BREAST;
    tex  = 0.85 + 0.30*powerlaw_noise(sz, 3.0);
    tfg  = dense .* base .* tex;
    tfg  = min(max(tfg,0), P.T_BREAST) .* sil;
end

function [mammo, L] = acquire_mammogram(tfg, sil, P)
% FISICA REAL - ley de Beer-Lambert:
%   L = mu_fg*t_fg + mu_ad*t_ad ; I = I0*exp(-L) ; cuentas ~ Poisson(I)
%   mamografia 'for-processing' = -log(I/I0) = L recuperado (denso -> claro)
    t_ad = sil.*(P.T_BREAST - tfg);
    L = P.MU_FIBRO*tfg + P.MU_ADIPO*t_ad;
    I = P.I0*exp(-L);
    if exist('poissrnd','file')==2
        counts = poissrnd(max(I,0));
    else
        counts = I + sqrt(max(I,0)).*randn(size(I));   % aprox. gaussiana del ruido cuantico
    end
    counts = max(counts,1);
    mammo = -log(counts/P.I0);
    mammo(~sil)=0;
end

function mgd = mean_glandular_dose(glandularity)
% Dosis glandular media (estimacion DgN simplificada, Dance/Wu):
%   MGD = K*g*c  -> del orden de 1-2 mGy/proyeccion (FFDM moderna)
    K=8.0; g=0.18; c=0.90+0.20*glandularity;
    mgd = K*g*c;
end

function mask = segment_dense(mammo, sil)
% Segmentacion del tejido denso por Otsu sobre la senal fisica + limpieza morfologica.
    v = mammo(sil); lo=min(v); hi=max(v);
    g = (mammo-lo)/((hi-lo)+eps); g(~sil)=0;
    lvl = graythresh(g(sil));
    mask = (g>lvl) & sil;
    mask = imopen(mask, strel('square',3));
    mask = bwareaopen(mask, 40);
    mask = imfill(mask, 'holes');
end

function [row, names] = extraer_descriptores(mammo, mask, sil, P, has_wavelet)
% Devuelve un vector fila con TODOS los descriptores y sus nombres.
    if ~any(mask(:))            % salvaguarda: si no hay denso, devolver ceros
        mask = false(size(mask)); mask(round(end/2),round(end/2))=true;
    end
    % --- recorte al rectangulo del tejido denso (textura/Fourier/Harris/Hu) ---
    [rr,cc] = find(mask); pad=6;
    r1=max(min(rr)-pad,1); r2=min(max(rr)+pad,size(mask,1));
    c1=max(min(cc)-pad,1); c2=min(max(cc)+pad,size(mask,2));
    regC = mammo(r1:r2, c1:c2);  maskC = mask(r1:r2, c1:c2);

    % ---------- DENSIDAD (proxy BI-RADS) ----------
    areal_density = 100*sum(mask(:))/sum(sil(:));

    % ---------- RADIOMICA (10) ----------
    [glcm_contrast, glcm_correlation, glcm_energy, glcm_homogeneity, glcm_entropy] = ...
        glcm_feats(regC, maskC);
    v = mammo(mask);
    intens_mean = mean(v); intens_std = std(v);
    mu3 = mean(((v-intens_mean)/(intens_std+eps)).^3);   % asimetria
    mu4 = mean(((v-intens_mean)/(intens_std+eps)).^4);   % curtosis
    intens_entropy = hist_entropy(v);
    [fft_beta, fft_high_low, ~] = fourier_feats(mammo.*sil);
    fourier_energy = fft_high_low;                       % "energia de Fourier" (alta/baja)

    % ---------- GEOMETRICA (7) ----------
    [green_area, green_perim, compactness, n_components, green_area_err] = green_feats(mask);
    [harris_count, harris_density] = harris_feats(regC, maskC);
    [sym_lr, sym_ud] = symmetry_feats(mask);
    huv = hu_moments(double(mask));
    huLog = -sign(huv).*log10(abs(huv)+eps);
    hu1 = huLog(1); hu2 = huLog(2);
    [gx,gy]=gradient(mammo); gmag=hypot(gx,gy);
    grad_mean = mean(gmag(mask));

    % ---------- COMPLEJIDAD FRACTAL ----------
    fractal_dim = fractal_dimension(mask);

    % ---------- BIOMECANICA (von Mises) ----------
    [vm_max, vm_mean] = vonmises_feats(mask, sil, P);

    % ---------- MICROCALCIFICACIONES (DWT db4) ----------
    [microcalc_energy, microcalc_count] = microcalc_feats(regC, has_wavelet);

    row = [areal_density, ...
           glcm_contrast, glcm_correlation, glcm_energy, glcm_homogeneity, glcm_entropy, ...
           intens_mean, intens_std, mu3, mu4, intens_entropy, fourier_energy, fft_beta, ...
           green_area, green_perim, compactness, n_components, harris_count, harris_density, ...
           sym_lr, sym_ud, hu1, hu2, grad_mean, fractal_dim, ...
           vm_max, vm_mean, microcalc_energy, microcalc_count, green_area_err];
    names = {'areal_density', ...
           'glcm_contrast','glcm_correlation','glcm_energy','glcm_homogeneity','glcm_entropy', ...
           'intens_mean','intens_std','intens_skew','intens_kurt','intens_entropy','fourier_energy','fft_slope', ...
           'green_area','green_perimeter','compactness','n_components','harris_count','harris_density', ...
           'sym_lr','sym_ud','hu1','hu2','grad_mean','fractal_dim', ...
           'vm_max','vm_mean','microcalc_energy','microcalc_count','green_area_err'};
end

function [con,cor,ene,hom,ent] = glcm_feats(region, mask)
% Textura GLCM a 4 angulos (0,45,90,135), 16 niveles. Devuelve 4 props + entropia.
    inm = region(mask); lo=min(inm); hi=max(inm);
    Q = round((region-lo)/((hi-lo)+eps)*15)+1; Q(Q<1)=1; Q(Q>16)=16; Q(~mask)=1;
    offs = [0 1; -1 1; -1 0; -1 -1];
    G = graycomatrix(Q,'NumLevels',16,'GrayLimits',[1 16],'Offset',offs,'Symmetric',true);
    s = graycoprops(G, {'Contrast','Correlation','Energy','Homogeneity'});
    con=mean(s.Contrast); cor=mean(s.Correlation(~isnan(s.Correlation)));
    ene=mean(s.Energy);   hom=mean(s.Homogeneity);
    if isnan(cor), cor=0; end
    ent=0; n=size(offs,1);
    for o=1:n
        g=G(:,:,o); g=g/(sum(g(:))+eps); gp=g(g>0); ent=ent - sum(gp.*log2(gp));
    end
    ent=ent/n;
end

function e = hist_entropy(v)
% Entropia de Shannon de las intensidades (histograma de 64 cajas).
    if isempty(v), e=0; return; end
    [h,~]=histcounts(v,64); pr=h/(sum(h)+eps); pr=pr(pr>0);
    e = -sum(pr.*log2(pr));
end

function [beta, hlr, cen] = fourier_feats(img)
% Analisis espectral por Transformada de Fourier 2D: pendiente espectral (beta),
% razon de energia alta/baja frecuencia (hlr) y centroide espectral (cen).
    R = img - mean(img(:));
    Fc = fftshift(fft2(R)); Pw = abs(Fc).^2;
    [H,W]=size(Pw); cy=floor(H/2)+1; cx=floor(W/2)+1;
    [X,Y]=meshgrid(1:W,1:H); rad=round(hypot(X-cx,Y-cy));
    maxr=min(cx,cy)-1; psd=zeros(1,maxr);
    for k=1:maxr, psd(k)=mean(Pw(rad==k)); end
    k=1:maxr;
    band = k>=round(0.10*maxr) & k<=round(0.60*maxr) & psd>0;
    if nnz(band)>=2, pp=polyfit(log(k(band)),log(psd(band)),1); beta=pp(1); else, beta=0; end
    hi=sum(psd(k>round(0.50*maxr))); lo=sum(psd(k<=round(0.20*maxr)))+eps;
    hlr=hi/lo; cen=sum(k.*psd)/(sum(psd)+eps);
end

function [A, Pm, comp, ncomp, areaErr] = green_feats(mask)
% Contornos por TEOREMA DE GREEN: el area encerrada por una curva cerrada es una
% integral de contorno (formula del area de Gauss/shoelace = teorema de Green).
% Devuelve area, perimetro, compacidad P^2/(4*pi*A), n de componentes y error vs pixeles.
    [Lbl,ncomp] = bwlabel(mask);
    if ncomp==0, A=0; Pm=0; comp=0; areaErr=0; return; end
    % componente mayor
    szs = histcounts(Lbl(Lbl>0), 1:ncomp+1);
    [~,big] = max(szs); compMask = (Lbl==big);
    Bcell = bwboundaries(compMask,'noholes');
    poly = Bcell{1}; x=poly(:,2); y=poly(:,1);
    A  = polyarea(x,y);                                   % area por integral de Green
    d  = sqrt(sum(diff([x y]).^2,2)); Pm = sum(d);        % perimetro
    comp = (Pm^2)/(4*pi*A + eps);                         % compacidad (1 = circulo)
    areaErr = 100*abs(A - sum(compMask(:)))/(sum(compMask(:))+eps);
end

function [cnt, dens] = harris_feats(region, mask)
% Esquinas de Harris (deteccion de puntos de interes geometrico).
    I = mat2gray(region);
    c = corner(I,'Harris');
    cnt = size(c,1);
    dens = 1000*cnt/(sum(mask(:))+eps);
end

function [slr, sud] = symmetry_feats(mask)
% Simetria horizontal y vertical via coeficiente de Dice contra la imagen espejada.
    fl=fliplr(mask); fu=flipud(mask);
    slr=2*sum(mask(:)&fl(:))/(sum(mask(:))+sum(fl(:))+eps);
    sud=2*sum(mask(:)&fu(:))/(sum(mask(:))+sum(fu(:))+eps);
end

function hu = hu_moments(I)
% Momentos invariantes de Hu (7) calculados desde los momentos centrales normalizados.
    [r,c]=size(I); [X,Y]=meshgrid(1:c,1:r);
    m00=sum(I(:));
    if m00<=0, hu=zeros(1,7); return; end
    xb=sum(sum(X.*I))/m00; yb=sum(sum(Y.*I))/m00;
    Xc=X-xb; Yc=Y-yb;
    mu=@(p,q) sum(sum((Xc.^p).*(Yc.^q).*I));
    eta=@(p,q) mu(p,q)/(m00^(1+(p+q)/2));
    n20=eta(2,0); n02=eta(0,2); n11=eta(1,1);
    n30=eta(3,0); n12=eta(1,2); n21=eta(2,1); n03=eta(0,3);
    h1=n20+n02;
    h2=(n20-n02)^2+4*n11^2;
    h3=(n30-3*n12)^2+(3*n21-n03)^2;
    h4=(n30+n12)^2+(n21+n03)^2;
    h5=(n30-3*n12)*(n30+n12)*((n30+n12)^2-3*(n21+n03)^2)+(3*n21-n03)*(n21+n03)*(3*(n30+n12)^2-(n21+n03)^2);
    h6=(n20-n02)*((n30+n12)^2-(n21+n03)^2)+4*n11*(n30+n12)*(n21+n03);
    h7=(3*n21-n03)*(n30+n12)*((n30+n12)^2-3*(n21+n03)^2)-(n30-3*n12)*(n21+n03)*(3*(n30+n12)^2-(n21+n03)^2);
    hu=[h1 h2 h3 h4 h5 h6 h7];
end

function d = fractal_dimension(mask)
% Dimension fractal por conteo de cajas (box-counting) sobre el borde del tejido.
    E = bwperim(mask); [H,W]=size(E);
    sizes=[2 4 8 16 32]; N=zeros(size(sizes));
    for i=1:numel(sizes)
        s=sizes(i); cnt=0;
        for rr=1:s:H
            for cc=1:s:W
                blk=E(rr:min(rr+s-1,H), cc:min(cc+s-1,W));
                if any(blk(:)), cnt=cnt+1; end
            end
        end
        N(i)=cnt;
    end
    ok=N>0;
    if nnz(ok)>=2, p=polyfit(log(1./sizes(ok)),log(N(ok)),1); d=p(1); else, d=0; end
end

function [vmax, vmean] = vonmises_feats(mask, sil, P)
% Biomecanica: modulo de Young diferenciado (E_fibro vs E_adiposo) bajo compresion.
% Tension equivalente de von Mises (plano de esfuerzos):
%   sigma_vM = sqrt(sxx^2 - sxx*syy + syy^2 + 3*txy^2)
% Modelo de primer orden con CONCENTRACION DE ESFUERZOS en las interfases (proxy del
% gradiente de rigidez): mas interfases (tejido fragmentado) -> mayor von Mises.
    E = P.E_ADIPO*ones(size(mask)); E(mask)=P.E_FIBRO; E(~sil)=0;
    Ebar = mean(E(sil));
    [ex,ey]=gradient(E); gE=hypot(ex,ey);
    s0 = Ebar*P.EPS0/(1-P.NU^2);                         % esfuerzo de campo lejano
    sxx = s0*(E/Ebar);                                   % primer orden (txy ~ 0)
    syy = sxx;
    conc = 1 + P.KAPPA*gE*P.LSCALE/(Ebar+eps);           % concentracion en interfases
    VM = sqrt(sxx.^2 - sxx.*syy + syy.^2) .* conc;       % von Mises local
    VM(~sil)=0; reg = mask & sil;
    vmax=max(VM(reg)); vmean=mean(VM(reg));
end

function [me, mc] = microcalc_feats(region, has_wavelet)
% Microcalcificaciones: energia de detalle de alta frecuencia por wavelet DWT 'db4'.
    if has_wavelet
        lev=2; [coef,s]=wavedec2(region, lev, 'db4');
        [H1,V1,D1]=detcoef2('all', coef, s, 1);
        detail = H1.^2 + V1.^2 + D1.^2;
    else
        hp = region - imgaussfilt(region, 2);            % respaldo: paso-alto gaussiano
        detail = hp.^2;
    end
    me = mean(detail(:));
    thr = mean(detail(:)) + 3*std(detail(:));
    mc = sum(detail(:) > thr);
end

% ----------------------- utilidades de clasificacion/estadistica -----------------------

function z = zscore_(x)
    z = (x - mean(x))/(std(x)+eps);
end

function s = orient_score(s, y)
% Orienta un sub-score para que valores altos correspondan a la clase 1.
    if mean(s(y==1)) < mean(s(y==0)), s = -s; end
end

function ci = bootci_auc(y, score, nboot)
% IC95% del AUC por bootstrap.
    N=numel(y); a=nan(nboot,1);
    for b=1:nboot
        idx=randi(N,N,1);
        if numel(unique(y(idx)))<2, continue; end
        [~,~,~,a(b)]=perfcurve(y(idx), score(idx), 1);
    end
    a=a(~isnan(a)); ci=quantile(a,[0.025 0.975]);
end

function [z, pval] = delong_test(y, s1, s2)
% Test de DeLong para comparar dos AUC correlacionadas (mismas muestras).
% Implementacion rapida basada en midranks (Sun & Xu, 2014).
    y=y(:)'; s1=s1(:)'; s2=s2(:)';
    [aucs, S] = fast_delong([s1; s2], y);
    L=[1 -1]; v=L*S*L';
    if v<=0, z=0; pval=1; return; end
    z=(aucs(1)-aucs(2))/sqrt(v);
    pval = erfc(abs(z)/sqrt(2));                          % dos colas
end

function [aucs, S] = fast_delong(scores, labels)
% scores: K x N ; labels: 1 x N en {0,1}. Devuelve AUCs (1xK) y covarianza S (KxK).
    pos = find(labels==1); neg = find(labels==0);
    m=numel(pos); n=numel(neg); K=size(scores,1);
    ps=scores(:,pos); ns=scores(:,neg);
    tx=zeros(K,m); ty=zeros(K,n); tz=zeros(K,m+n);
    for r=1:K
        tx(r,:)=midrank(ps(r,:));
        ty(r,:)=midrank(ns(r,:));
        tz(r,:)=midrank([ps(r,:) ns(r,:)]);
    end
    aucs = (sum(tz(:,1:m),2)' - m*(m+1)/2)/(m*n);
    v01 = (tz(:,1:m) - tx)/n;          % K x m
    v10 = 1 - (tz(:,m+1:end) - ty)/m;  % K x n
    sx = cov(v01'); sy = cov(v10');    % KxK (cov sobre observaciones)
    if K==1, sx=var(v01); sy=var(v10); end
    S = sx/m + sy/n;
end

function r = midrank(x)
% Rangos medios (ties -> promedio), 1-based.
    [xs, J]=sort(x); n=numel(x); Tt=zeros(1,n); i=1;
    while i<=n
        j=i; while j<n && xs(j)==xs(j+1), j=j+1; end
        Tt(i:j)=(i+j)/2; i=j+1;
    end
    r=zeros(1,n); r(J)=Tt;
end

function t = sig_txt(p)
    if p<0.05, t='-> DIFERENCIA SIGNIFICATIVA'; else, t='-> no significativa'; end
end

% ----------------------------------- figuras -----------------------------------

function fig1_fisica(tfg, L, mammo, P, mgd, outdir)
    f=figure('Color','w','Position',[80 80 1400 360]);
    tl=tiledlayout(f,1,4,'Padding','compact','TileSpacing','compact');
    title(tl, sprintf('FIGURA 1 - Fisica medica: formacion por atenuacion de rayos X (MGD ~ %.2f mGy)', mgd));
    nexttile; imagesc(tfg); axis image off; colorbar; title('Espesor fibroglandular t_{fg} [cm]');
    nexttile; imagesc(L);   axis image off; colorbar; title('Integral de atenuacion L=\mu_{fg}t_{fg}+\mu_{ad}t_{ad}');
    nexttile; imagesc(P.I0*exp(-L)); axis image off; colorbar; title('Transmision I=I_0 e^{-L}');
    nexttile; imagesc(mammo); axis image off; colormap(gca,gray); colorbar; title('Mamografia -ln(I/I_0) (denso=claro)');
    guardar(f, fullfile(outdir,'Fig1_fisica_beer_lambert.png'));
end

function fig2_fourier(m0, m1, k0, k1, outdir)
    f=figure('Color','w','Position',[80 80 1300 800]);
    tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
    title(tl,'FIGURA 2 - Analisis espectral (Transformada de Fourier)');
    plot_fourier_row(m0, k0, 'Compacta (clase 0)');
    plot_fourier_row(m1, k1, 'Fragmentada (clase 1)');
    guardar(f, fullfile(outdir,'Fig2_fourier.png'));

    function plot_fourier_row(mammo, ~, etiqueta)
        nexttile; imagesc(mammo); axis image off; colormap(gca,gray); title(etiqueta);
        Pw=abs(fftshift(fft2(mammo-mean(mammo(:))))).^2;
        nexttile; imagesc(log(Pw+1)); axis image off; title('Espectro de potencia 2D  log|F|^2');
        [H,W]=size(Pw); cy=floor(H/2)+1; cx=floor(W/2)+1;
        [X,Y]=meshgrid(1:W,1:H); rad=round(hypot(X-cx,Y-cy)); maxr=min(cx,cy)-1;
        psd=zeros(1,maxr); for kk=1:maxr, psd(kk)=mean(Pw(rad==kk)); end
        kk=1:maxr; band=kk>=round(0.1*maxr)&kk<=round(0.6*maxr)&psd>0;
        pp=polyfit(log(kk(band)),log(psd(band)),1);
        nexttile; loglog(kk,psd,'.'); hold on; loglog(kk(band),exp(polyval(pp,log(kk(band)))),'r-','LineWidth',2);
        xlabel('frecuencia radial k'); ylabel('PSD'); title(sprintf('PSD radial  \\beta=%.2f',pp(1))); grid on;
    end
end

function fig3_fractal(mask, outdir)
    E=bwperim(mask); [H,W]=size(E);
    sizes=[2 4 8 16 32]; N=zeros(size(sizes));
    for i=1:numel(sizes)
        s=sizes(i); cnt=0;
        for rr=1:s:H, for cc=1:s:W
            blk=E(rr:min(rr+s-1,H),cc:min(cc+s-1,W)); if any(blk(:)), cnt=cnt+1; end
        end, end
        N(i)=cnt;
    end
    pp=polyfit(log(1./sizes),log(N),1);
    f=figure('Color','w','Position',[80 80 1100 480]);
    tl=tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');
    title(tl,'FIGURA 3 - Dimension fractal (conteo de cajas)');
    nexttile; imshow(E); title('Borde del tejido denso');
    nexttile; plot(log(1./sizes),log(N),'o','MarkerFaceColor','b'); hold on;
    plot(log(1./sizes),polyval(pp,log(1./sizes)),'r-','LineWidth',2);
    xlabel('log(1/\epsilon)'); ylabel('log N(\epsilon)'); grid on;
    title(sprintf('Dimension fractal D = %.3f', pp(1)));
    guardar(f, fullfile(outdir,'Fig3_fractal.png'));
end

function fig4_vonmises(mask, sil, P, outdir)
    E=P.E_ADIPO*ones(size(mask)); E(mask)=P.E_FIBRO; E(~sil)=0; Ebar=mean(E(sil));
    [ex,ey]=gradient(E); gE=hypot(ex,ey);
    s0=Ebar*P.EPS0/(1-P.NU^2); sxx=s0*(E/Ebar);
    conc=1+P.KAPPA*gE*P.LSCALE/(Ebar+eps);
    VM=sqrt(sxx.^2 - sxx.*sxx + sxx.^2).*conc; VM(~sil)=0;
    f=figure('Color','w','Position',[80 80 1300 480]);
    tl=tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');
    title(tl,'FIGURA 4 - Biomecanica: modulo de Young y tension de von Mises');
    nexttile; imagesc(E);  axis image off; colorbar; title('Mapa de modulo de Young E [kPa]');
    nexttile; imagesc(VM); axis image off; colorbar; title('Tension de von Mises \sigma_{vM} (concentracion en interfases)');
    guardar(f, fullfile(outdir,'Fig4_vonmises.png'));
end

function fig5_estadistica(T, names, pvals, labels, outdir)
    sel={'sym_lr','harris_density','hu2','n_components','compactness','fractal_dim'};
    f=figure('Color','w','Position',[60 60 1500 820]);
    tl=tiledlayout(f,2,4,'Padding','compact','TileSpacing','compact');
    title(tl,'FIGURA 5 - Validacion estadistica (t-test por descriptor + correlaciones)');
    for i=1:numel(sel)
        c=sel{i}; nexttile;
        boxplot(T.(c), labels, 'Labels',{'C0','C1'});
        p=pvals(strcmp(names,c)); title(sprintf('%s\np=%.1e', c, p), 'Interpreter','none');
    end
    nexttile([1 2]);
    R=corr(T{:,1:end-1},'rows','pairwise');               % matriz de correlacion
    imagesc(R,[-1 1]); axis image; colorbar; colormap(gca,parula);
    title('Matriz de correlacion de descriptores'); set(gca,'XTick',[],'YTick',[]);
    guardar(f, fullfile(outdir,'Fig5_estadistica.png'));
end

function fig6_roc(y, sIGR, sDens, aIGR, aDens, ciI, ciD, pDeLong, outdir)
    [xi,yi]=perfcurve(y,sIGR,1); [xd,yd]=perfcurve(y,sDens,1);
    f=figure('Color','w','Position',[120 80 720 720]);
    plot(xi,yi,'-','LineWidth',2.5,'Color',[0.10 0.62 0.27]); hold on;
    plot(xd,yd,'-','LineWidth',2.5,'Color',[0.84 0.15 0.16]);
    plot([0 1],[0 1],'k--');
    xlabel('Tasa de falsos positivos'); ylabel('Tasa de verdaderos positivos');
    legend({sprintf('IGR (geometria)  AUC=%.3f [%.2f-%.2f]',aIGR,ciI(1),ciI(2)), ...
            sprintf('Densidad sola (BI-RADS)  AUC=%.3f [%.2f-%.2f]',aDens,ciD(1),ciD(2)), ...
            'azar'}, 'Location','southeast');
    title(sprintf('FIGURA 6 - ROC: IGR vs densidad   (DeLong p=%.1e)', pDeLong));
    grid on; axis square;
    guardar(f, fullfile(outdir,'Fig6_ROC.png'));
end

function guardar(f, ruta)
% Guarda la figura a PNG (exportgraphics si existe; si no, print).
    try
        exportgraphics(f, ruta, 'Resolution', 150);
    catch
        print(f, ruta, '-dpng', '-r150');
    end
end

% ----------------------------- carga de DICOM reales -----------------------------

function [mammo, sil] = cargar_caso_real(ruta_dcm, P) %#ok<DEFNU>
% USO CON LAS 249 MAMOGRAFIAS REALES DEL INC:
%   Reemplace en el bucle principal las lineas
%       tfg = fibro_thickness_map(...); [mam,L] = acquire_mammogram(...);
%   por:
%       [mam, sil] = cargar_caso_real(rutas{p}, P);
%   y use sus etiquetas reales (BI-RADS / histologia) en 'labels'. El resto del
%   pipeline (segmentacion, descriptores, estadistica, IGR, DeLong) es IDENTICO.
    info = dicominfo(ruta_dcm);
    img  = double(dicomread(info));
    % Presentacion 'for processing': normalizar a una escala tipo -ln(I/I0).
    img = img - min(img(:)); img = img/(max(img(:))+eps);
    mammo = -log(max(1-img, 1e-3));                       % denso -> claro (ajuste segun fabricante)
    sil = mammo > graythresh(mammo);                      % silueta de la mama (ajuste el umbral de fondo)
    sil = imfill(bwareaopen(sil, 5000), 'holes');
    mammo(~sil)=0;
end