%% ============================================================================
%  TESIS - CARACTERIZACION DE LA DENSIDAD MAMOGRAFICA POR PATRONES GEOMETRICOS
%  Universidad ECCI | Maestria en Ingenieria (GIATME)
%  Linea: Imagenes Diagnosticas & Bio-diseno
%
%  SISTEMA UNIFICADO FINAL - UN SOLO ARCHIVO
%  Compatible: MATLAB Base (sin toolboxes requeridos)
%  
%  Contenido integrado:
%   [1] FANTOMA FISICO: Atenuacion Beer-Lambert + dosis glandular (MGD)
%   [2] SEGMENTACION: Otsu + morfologia manual
%   [3] DENSIDAD: Proxy BI-RADS (% tejido denso)
%   [4] RADIOMICA (10): 4 GLCM + 5 intensidad + 1 Fourier
%   [5] GEOMETRICA (7): Contornos/Green, Harris, simetria, momentos Hu, gradientes
%   [6] COMPLEJIDAD: Fractal box-counting, GLRLM, orientacion
%   [7] BIOMECANICA: Modulo Young diferenciado + von Mises en interfases
%   [8] MICROCALCIFICACIONES: DWT db4 propio
%   [9] IGR: Regresion logistica L2 + validacion k-fold estratificada
%   [10] HUELLA: Fusion 30% densidad + 35% microcalc + 35% biomecanica
%   [11] BI-RADS GEOMETRICO: Estratificacion del IGR en 4 categorias
%   [12] VALIDACION: AUC + IC95% bootstrap + DeLong vs densidad sola
%   [13] FIGURAS: 9 figuras profesionales completas
%
%  Ejecucion: >> tesis_unificada
%% ============================================================================

function tesis_unificada()
%% INICIALIZACION
close all; clc; rng(2026);
fprintf('\n');
fprintf('============================================================\n');
fprintf('  CARACTERIZACION DE DENSIDAD MAMOGRAFICA POR GEOMETRIA\n');
fprintf('  Sistema Unificado - Tesis Maestria ECCI\n');
fprintf('============================================================\n\n');

% Crear carpeta de salida
outdir = fullfile(pwd, 'figuras_tesis');
if ~exist(outdir, 'dir'), mkdir(outdir); end

%% PARAMETROS FISICOS Y DE CONFIGURACION
P.MU_F    = 0.80;   % cm^-1 tejido fibroglandular
P.MU_A    = 0.46;   % cm^-1 tejido adiposo
P.T       = 5.0;    % cm espesor total compresion
P.I0      = 1e4;    % fotones incidentes
P.E_F     = 15.1;   % kPa modulo Young glandular
P.E_A     = 4.46;   % kPa modulo Young adiposo
P.NU      = 0.49;   % coeficiente Poisson
P.EPS0    = 0.20;   % deformacion de referencia
P.KAPPA   = 0.60;   % factor concentracion interfase
P.N       = 160;    % numero de pacientes simulados
P.SZ      = 256;    % tamano imagen
P.NBOOT   = 2000;   % repeticiones bootstrap

fprintf('>> Parametros fisicos configurados\n');
fprintf('   Pacientes: %d | Tamano: %dx%d\n', P.N, P.SZ, P.SZ);

%% ========================================================================
%  [1] GENERACION DEL DATASET CON FISICA (Beer-Lambert)
%% ========================================================================
fprintf('\n[1/5] GENERANDO DATASET CON FISICA (Beer-Lambert)...\n');

% Silueta mamaria eliptica
[xx, yy] = meshgrid(0:P.SZ-1, 0:P.SZ-1);
cx = P.SZ * 0.5; cy = P.SZ * 0.5; a = P.SZ * 0.42; b = P.SZ * 0.46;
sil = (((xx - cx)/a).^2 + ((yy - cy)/b).^2) <= 1.0;

% Etiquetas: 0=compacta, 1=fragmentada (geometrias distintas)
labels = mod((0:P.N-1)', 2);

mammos = cell(P.N, 1);      % imagenes mamograficas
tfgs   = cell(P.N, 1);      % mapas de espesor glandular
masks  = cell(P.N, 1);      % mascaras de segmentacion
gland  = zeros(P.N, 1);     % glandularidad
mgd    = zeros(P.N, 1);     % dosis glandular media
dice   = zeros(P.N, 1);     % coeficiente Dice

for p = 1:P.N
    tfg = generar_tfg(labels(p), sil, P);           % mapa espesor glandular
    mam = adquirir_mamografia(tfg, sil, P);         % Beer-Lambert + Poisson
    mk  = segmentar_mamografia(mam, sil);            % Otsu + morfologia
    
    mammos{p} = mam;
    tfgs{p}   = tfg;
    masks{p}  = mk;
    
    gland(p) = sum(tfg(sil)) / (P.T * sum(sil(:)));
    mgd(p)   = 8.0 * 0.18 * (0.90 + 0.20 * gland(p));
    
    % Verdad de terreno para Dice
    truth = tfg > (0.5 * 0.55 * P.T);
    dice(p) = 2 * sum(mk(:) & truth(:)) / (sum(mk(:)) + sum(truth(:)) + eps);
end

fprintf('   Clase 0 (compacta):  %d\n', sum(labels == 0));
fprintf('   Clase 1 (fragmentada): %d\n', sum(labels == 1));
fprintf('   Glandularidad media: %.1f%% (c0=%.1f%%, c1=%.1f%%) <- IGUALADA\n',...
    100*mean(gland), 100*mean(gland(labels==0)), 100*mean(gland(labels==1)));
fprintf('   Dosis glandular media (MGD): %.2f mGy\n', mean(mgd));
fprintf('   Dice medio segmentacion: %.3f (+/- %.3f)\n', mean(dice), std(dice));

%% ========================================================================
%  [2-3] EXTRACCION DE DESCRIPTORES RADIOMICOS Y GEOMETRICOS
%% ========================================================================
fprintf('\n[2/5] EXTRAYENDO DESCRIPTORES (32 dimensiones)...\n');

names = {'areal_density','glcm_contrast','glcm_correlation','glcm_energy',...
    'glcm_homogeneity','glcm_entropy','intens_std','intens_skew',...
    'intens_kurt','intens_entropy','fourier_energy','fft_slope',...
    'green_area','green_perimeter','compactness','n_components',...
    'harris_count','harris_density','sym_lr','sym_ud','hu1','hu2',...
    'grad_mean','fractal_dim','glrlm_SRE','glrlm_LRE','glrlm_GLN',...
    'orient_coher','vm_max','vm_mean','microcalc_energy','microcalc_count'};

F = zeros(P.N, numel(names));
gerr = zeros(P.N, 1);

for p = 1:P.N
    [F(p,:), gerr(p)] = extraer_descriptores(mammos{p}, masks{p}, sil, P);
end

fprintf('   Matriz de caracteristicas: %d x %d\n', size(F,1), size(F,2));
fprintf('   Error Green medio: %.2f%%\n', mean(gerr));
fprintf('   Densidad areal c0=%.1f%% | c1=%.1f%%\n',...
    mean(F(labels==0,1)), mean(F(labels==1,1)));

%% ========================================================================
%  [4] ESTADISTICA DESCRIPTIVA (t-test de Welch + ANOVA)
%% ========================================================================
fprintf('\n[3/5] ANALISIS ESTADISTICO (t-test Welch por descriptor)...\n');

pvals = ones(numel(names), 1);
for i = 1:numel(names)
    a = F(labels==0, i); b = F(labels==1, i);
    if std(a) < 1e-9 && std(b) < 1e-9
        fprintf('   %-20s (constante)\n', names{i});
        continue;
    end
    [tt, pp] = welch_ttest(a, b);
    pvals(i) = pp;
    sig = 'ns ';
    if pp < 0.001, sig = '***';
    elseif pp < 0.01, sig = '** ';
    elseif pp < 0.05, sig = '*  '; end
    fprintf('   %-20s t=%7.2f  p=%.2e  %s\n', names{i}, tt, pp, sig);
end

fprintf('   Descriptores significativos (p<0.05): %d/%d\n', sum(pvals<0.05), numel(names));

% ANOVA: entropia GLCM vs terciles de densidad
dens = F(:,1);
q = [percentil(dens, 1/3) percentil(dens, 2/3)];
terc = ones(P.N, 1); terc(dens > q(1)) = 2; terc(dens > q(2)) = 3;
[Fv, pA] = anova_oneway(F(:,6), terc);
fprintf('   ANOVA (entropia GLCM ~ tercil densidad): F=%.2f  p=%.2e\n', Fv, pA);

%% ========================================================================
%  [5] CLASIFICADORES (Regresion Logistica k-fold + DeLong)
%% ========================================================================
fprintf('\n[4/5] CLASIFICADORES (k-fold + DeLong)...\n');

% IGR geometrico (sin densidad areal, sin biomecanica directa)
excluir = {'areal_density','vm_max','vm_mean','microcalc_energy','microcalc_count'};
geo = find(~ismember(names, excluir));
y = labels;

s_igr = kfold_logreg(F(:, geo), y, 5);
auc_igr = calcular_auc(y, s_igr);
ci_igr = bootstrap_ci(y, s_igr, P.NBOOT);

% Densidad sola (BI-RADS proxy)
s_den = dens;
auc_den = calcular_auc(y, s_den);
if auc_den < 0.5, s_den = -s_den; auc_den = calcular_auc(y, s_den); end
ci_den = bootstrap_ci(y, s_den, P.NBOOT);

% Huella ponderada (30% densidad + 35% microcalc + 35% biomecanica)
sD = orientar(zscore_columnas(F(:,1)), y);
sM = orientar(zscore_columnas(F(:, indice(names, 'microcalc_energy'))), y);
sB = orientar(zscore_columnas(F(:, indice(names, 'vm_max')) + F(:, indice(names, 'vm_mean'))), y);
s_hue = 0.30*sD + 0.35*sM + 0.35*sB;
auc_hue = calcular_auc(y, s_hue);
ci_hue = bootstrap_ci(y, s_hue, P.NBOOT);

% Test de DeLong
[z1, p1] = delong_test(y, s_igr, s_den);
[z2, p2] = delong_test(y, s_hue, s_den);

fprintf('   AUC IGR (geometria+radiomica)    : %.3f  IC95%% [%.3f, %.3f]\n', auc_igr, ci_igr(1), ci_igr(2));
fprintf('   AUC Huella (30/35/35)            : %.3f  IC95%% [%.3f, %.3f]\n', auc_hue, ci_hue(1), ci_hue(2));
fprintf('   AUC Densidad sola (BI-RADS)      : %.3f  IC95%% [%.3f, %.3f]\n', auc_den, ci_den(1), ci_den(2));
fprintf('   DeLong IGR    vs densidad: z=%.2f  p=%.2e  %s\n', z1, p1, texto_significancia(p1));
fprintf('   DeLong Huella vs densidad: z=%.2f  p=%.2e  %s\n', z2, p2, texto_significancia(p2));

%% ========================================================================
%  [6] GENERACION DE 9 FIGURAS PROFESIONALES
%% ========================================================================
fprintf('\n[5/5] GENERANDO 9 FIGURAS PROFESIONALES...\n');

e0 = find(labels == 0, 1);  % ejemplo clase 0 (compacta)
e1 = find(labels == 1, 1);  % ejemplo clase 1 (fragmentada)

fig1_fisica(tfgs{e0}, mammos{e0}, sil, P, mean(mgd), outdir);
fig2_fourier(mammos{e0}, mammos{e1}, outdir);
fig3_fractal(masks{e1}, F, names, labels, outdir);
fig4_vonmises(masks{e1}, sil, P, F, names, labels, outdir);
fig5_estadistica(F, names, pvals, labels, outdir);
fig6_roc(y, s_igr, s_hue, s_den, auc_igr, auc_hue, auc_den, p1, outdir);
fig7_birads(F, names, labels, s_igr, outdir);
fig8_muestras(mammos{e0}, mammos{e1}, masks{e0}, masks{e1}, tfgs{e0}, tfgs{e1}, outdir);
fig9_resumen(F, names, auc_igr, auc_den, auc_hue, p1, p2, outdir);

%% EXPORTAR RESULTADOS
exportar_csv(fullfile(pwd, 'features_tesis.csv'), names, F);
save(fullfile(pwd, 'resultados_tesis.mat'), 'F', 'names', 'pvals', 'auc_igr',...
    'auc_den', 'auc_hue', 'ci_igr', 'ci_den', 'ci_hue', 'z1', 'p1', 'z2', 'p2',...
    'dice', 'mgd', 'gland', 'labels');

fprintf('\n');
fprintf('============================================================\n');
fprintf('  SISTEMA FINALIZADO EXITOSAMENTE\n');
fprintf('  Figuras en: %s\n', outdir);
fprintf('  features_tesis.csv | resultados_tesis.mat\n');
fprintf('============================================================\n\n');
end

%% ============================================================================
%  FUNCIONES DE GENERACION FISICA (Beer-Lambert)
%% ============================================================================

function sil = generar_silueta(sz)
    [xx, yy] = meshgrid(0:sz-1, 0:sz-1);
    cx = sz * 0.5; cy = sz * 0.5; a = sz * 0.42; b = sz * 0.46;
    sil = (((xx - cx)/a).^2 + ((yy - cy)/b).^2) <= 1.0;
end

function ruido = ruido_planck(sz, beta)
    f = randn(sz); F = fftshift(fft2(f));
    [kx, ky] = meshgrid(-floor(sz/2):ceil(sz/2)-1, -floor(sz/2):ceil(sz/2)-1);
    k = sqrt(kx.^2 + ky.^2); k(k == 0) = 1;
    F = F ./ (k.^(beta/2));
    ruido = real(ifft2(ifftshift(F)));
    ruido = (ruido - min(ruido(:))) / ((max(ruido(:)) - min(ruido(:))) + 1e-9);
end

function tfg = generar_tfg(clase, sil, P)
    sz = P.SZ; [xx, yy] = meshgrid(0:sz-1, 0:sz-1); cx = sz * 0.5; cy = sz * 0.5;
    a_t = 0.12 + 0.10 * rand;
    
    if clase == 0, mu = 0.30; else, mu = 0.70; end
    
    sev = min(max(mu + 0.18 * randn, 0), 1);
    nb = round(1 + 7 * sev);
    spr = sz * (0.03 + 0.18 * sev);
    bs = sz * (0.12 - 0.07 * sev);
    rw = 0.05 + 0.40 * sev;
    beta = max(1.2, 4.5 - 2.7 * sev);
    
    campo = zeros(sz);
    for b = 1:max(1, nb)
        ox = cx + spr * randn;
        oy = cy + spr * randn;
        ss = max(sz * 0.04, bs * (0.8 + 0.4 * rand));
        campo = campo + exp(-(((xx - ox).^2 + (yy - oy).^2) / (2 * ss^2)));
    end
    
    campo = campo + rw * ruido_planck(sz, beta);
    campo = campo .* sil;
    
    thr = percentil(campo(sil), 1 - a_t);
    denso = (campo > thr) & sil;
    
    tex = 0.85 + 0.30 * ruido_planck(sz, 3.0);
    tfg = denso .* (0.55 * P.T) .* tex;
    tfg = min(max(tfg, 0), P.T) .* sil;
end

function mam = adquirir_mamografia(tfg, sil, P)
    t_ad = sil .* (P.T - tfg);
    L = P.MU_F * tfg + P.MU_A * t_ad;
    I = P.I0 * exp(-L);
    c = poisson_simular(max(I, 0));
    c = max(c, 1);
    mam = -log(c / P.I0);
    mam(~sil) = 0;
end

function k = poisson_simular(lam)
    k = zeros(size(lam));
    grande = lam > 30;
    pequeno = ~grande;
    
    k(grande) = max(0, round(lam(grande) + sqrt(lam(grande)) .* randn(sum(grande(:)), 1)));
    
    idx = find(pequeno);
    L = exp(-lam(idx));
    for t = 1:numel(idx)
        kk = 0; pp = 1;
        while true
            kk = kk + 1;
            pp = pp * rand;
            if pp <= L(t), break; end
        end
        k(idx(t)) = kk - 1;
    end
end

%% ============================================================================
%  FUNCIONES DE SEGMENTACION (sin toolbox)
%% ============================================================================

function thr = otsu_manual(v)
    v = v(:); lo = min(v); hi = max(v);
    g = (v - lo) / ((hi - lo) + 1e-12);
    bin = min(floor(g * 256) + 1, 256);
    h = accumarray(bin, 1, [256 1]); p = h / sum(h);
    om = ((1:256)' - 1) / 255;
    mut = sum(om .* p); w = cumsum(p); mu = cumsum(om .* p);
    sb = (mut * w - mu).^2 ./ (w .* (1 - w) + 1e-12);
    [~, kk] = max(sb);
    thr = lo + (kk / 256) * (hi - lo);
end

function s = desplazar_matriz(a, dy, dx, fv)
    s = fv * ones(size(a)); [H, W] = size(a);
    ys = max(1, 1+dy):min(H, H+dy); yd = max(1, 1-dy):min(H, H-dy);
    xs = max(1, 1+dx):min(W, W+dx); xd = max(1, 1-dx):min(W, W+dx);
    s(yd, xd) = a(ys, xs);
end

function [lab, n] = etiquetar_componentes(mask)
    [H, W] = size(mask);
    idx = reshape(1:H*W, H, W);
    lab = idx; lab(~mask) = inf;
    offs = [-1 -1; -1 0; -1 1; 0 -1; 0 1; 1 -1; 1 0; 1 1];
    
    for iter = 1:120
        m = lab;
        for o = 1:8
            m = min(m, desplazar_matriz(lab, offs(o,1), offs(o,2), inf));
        end
        m(~mask) = inf;
        if isequal(m, lab), break; end
        lab = m;
    end
    
    u = unique(lab(mask));
    out = zeros(H, W);
    for i = 1:numel(u), out(lab == u(i)) = i; end
    lab = out;
    n = numel(u);
end

function m = dilatar3(m)
    o = m;
    for dy = -1:1
        for dx = -1:1
            o = o | desplazar_matriz(m, dy, dx, 0);
        end
    end
    m = o;
end

function m = erosionar3(m), m = ~dilatar3(~m); end

function mask = segmentar_mamografia(mam, sil)
    thr = otsu_manual(mam(sil));
    mask = (mam > thr) & sil;
    mask = erosionar3(mask);
    mask = dilatar3(mask);
    [lab, n] = etiquetar_componentes(mask);
    if n > 0
        sizes = accumarray(lab(lab > 0), 1, [n 1]);
        keep = find(sizes >= 40);
        mask = ismember(lab, keep);
    end
end

%% ============================================================================
%  FUNCIONES DE EXTRACCION DE DESCRIPTORES
%% ============================================================================

function [row, gerr] = extraer_descriptores(mam, mask, sil, P)
    if ~any(mask(:)), mask(round(end/2), round(end/2)) = true; end
    
    [rr, cc] = find(mask); pad = 6;
    r1 = max(min(rr) - pad, 1); r2 = min(max(rr) + pad, size(mask, 1));
    c1 = max(min(cc) - pad, 1); c2 = min(max(cc) + pad, size(mask, 2));
    
    regC = mam(r1:r2, c1:c2);
    maskC = mask(r1:r2, c1:c2);
    
    % [1] Densidad areal
    ad = 100 * sum(mask(:)) / sum(sil(:));
    
    % [2-6] GLCM
    [con, cor, ene, hom, ent] = glcm_manual(regC, maskC);
    
    % [7-10] Estadisticas de intensidad
    v = mam(mask);
    istd = std(v);
    sk = (v - mean(v)) / (istd + 1e-9);
    mu3 = mean(sk.^3);
    mu4 = mean(sk.^4);
    ient = entropia_histograma(v);
    
    % [11-12] Fourier
    [bsl, hlr, ~] = analisis_fourier(mam .* sil);
    
    % [13-16] Contornos / Teorema de Green
    [area, per, comp, nc, gerr] = green_manual(mask);
    
    % [17-18] Esquinas Harris
    [hc, hd] = harris_manual(regC, maskC);
    
    % [19-20] Simetria
    [slr, sud] = simetria_manual(mask);
    
    % [21-22] Momentos de Hu (logaritmicos)
    hu = momentos_hu(double(mask));
    huL = -sign(hu) .* log10(abs(hu) + 1e-30);
    
    % [23] Gradiente medio
    [gx, gy] = gradient(mam);
    gmean = mean(hypot(gx(mask), gy(mask)));
    
    % [24] Dimension fractal
    fd = fractal_manual(mask);
    
    % [25-27] GLRLM
    [SRE, LRE, GLN] = glrlm_manual(regC, maskC);
    
    % [28] Coherencia de orientacion
    coh = orientacion_manual(regC, maskC);
    
    % [29-30] Von Mises
    [vmax, vmean] = von_mises_manual(mask, sil, P);
    
    % [31-32] Microcalcificaciones DWT
    [me, mc] = dwt_db4_manual(regC);
    
    row = [ad, con, cor, ene, hom, ent, istd, mu3, mu4, ient, hlr, bsl,...
           area, per, comp, nc, hc, hd, slr, sud, huL(1), huL(2), gmean,...
           fd, SRE, LRE, GLN, coh, vmax, vmean, me, mc];
end

function [con, cor, ene, hom, ent] = glcm_manual(region, mask)
    inm = region(mask); lo = min(inm); hi = max(inm);
    Q = min(max(round((region - lo) / ((hi - lo) + 1e-12) * 15), 0), 15);
    Q(~mask) = 0;
    
    offs = [0 1; -1 1; -1 0; -1 -1];
    con = 0; cor = 0; ene = 0; hom = 0; ent = 0;
    [ii, jj] = meshgrid(0:15, 0:15);
    [H, W] = size(Q);
    
    for o = 1:4
        dy = offs(o,1); dx = offs(o,2);
        ys = max(1, 1+dy):min(H, H+dy); yd = max(1, 1-dy):min(H, H-dy);
        xs = max(1, 1+dx):min(W, W+dx); xd = max(1, 1-dx):min(W, W+dx);
        
        A = Q(yd, xd); BB = Q(ys, xs);
        A = A(:) + 1; BB = BB(:) + 1;
        
        if isempty(A), continue; end
        
        G = accumarray([A BB], 1, [16 16]);
        G = G + G'; s = sum(G(:));
        if s == 0, continue; end
        
        Pn = G / s;
        con = con + sum(sum(Pn .* (ii - jj).^2));
        
        mi = sum(sum(ii .* Pn)); mj = sum(sum(jj .* Pn));
        si = sqrt(sum(sum(Pn .* (ii - mi).^2)));
        sj = sqrt(sum(sum(Pn .* (jj - mj).^2)));
        if si > 1e-9 && sj > 1e-9
            cor = cor + sum(sum(Pn .* (ii - mi) .* (jj - mj))) / (si * sj);
        end
        
        ene = ene + sum(Pn(:).^2);
        hom = hom + sum(sum(Pn ./ (1 + (ii - jj).^2)));
        Pp = Pn(Pn > 0);
        ent = ent - sum(Pp .* log2(Pp));
    end
    
    con = con / 4; cor = cor / 4; ene = ene / 4; hom = hom / 4; ent = ent / 4;
end

function e = entropia_histograma(v)
    if isempty(v), e = 0; return; end
    lo = min(v); hi = max(v);
    b = min(floor((v - lo) / ((hi - lo) + 1e-12) * 64) + 1, 64);
    h = accumarray(b, 1, [64 1]); pr = h / sum(h);
    pr = pr(pr > 0); e = -sum(pr .* log2(pr));
end

function [beta, hlr, cen] = analisis_fourier(img)
    R = img - mean(img(:));
    Pw = abs(fftshift(fft2(R))).^2;
    [H, W] = size(Pw);
    cy = floor(H/2) + 1; cx = floor(W/2) + 1;
    [X, Y] = meshgrid(1:W, 1:H);
    rad = round(hypot(X - cx, Y - cy));
    mr = min(cx, cy) - 1;
    psd = zeros(1, mr);
    for k = 1:mr, psd(k) = mean(Pw(rad == k)); end
    k = 1:mr;
    band = k >= round(0.1 * mr) & k <= round(0.6 * mr) & psd > 0;
    if nnz(band) >= 2
        pp = polyfit(log(k(band)), log(psd(band)), 1);
        beta = pp(1);
    else
        beta = 0;
    end
    hi = sum(psd(k > round(0.5 * mr)));
    lo = sum(psd(k <= round(0.2 * mr))) + 1e-12;
    hlr = hi / lo;
    cen = sum(k .* psd) / (sum(psd) + 1e-12);
end

function d = fractal_manual(mask)
    E = mask & ~erosionar3(mask);
    [H, W] = size(E);
    sizes = [2 4 8 16 32];
    N = zeros(1, 5);
    for i = 1:5
        s = sizes(i); c = 0;
        for r0 = 1:s:H
            for c0 = 1:s:W
                if any(any(E(r0:min(r0+s-1, H), c0:min(c0+s-1, W)))), c = c + 1; end
            end
        end
        N(i) = c;
    end
    ok = N > 0;
    if nnz(ok) >= 2
        pp = polyfit(log(1./sizes(ok)), log(N(ok)), 1);
        d = pp(1);
    else
        d = 0;
    end
end

function hu = momentos_hu(I)
    [H, W] = size(I);
    [X, Y] = meshgrid(1:W, 1:H);
    m00 = sum(I(:));
    if m00 <= 0, hu = zeros(1, 7); return; end
    
    xb = sum(sum(X .* I)) / m00;
    yb = sum(sum(Y .* I)) / m00;
    Xc = X - xb; Yc = Y - yb;
    
    mu = @(p,q) sum(sum((Xc.^p) .* (Yc.^q) .* I));
    eta = @(p,q) mu(p,q) / (m00^(1 + (p+q)/2));
    
    n20 = eta(2,0); n02 = eta(0,2); n11 = eta(1,1);
    n30 = eta(3,0); n12 = eta(1,2); n21 = eta(2,1); n03 = eta(0,3);
    
    h1 = n20 + n02;
    h2 = (n20 - n02)^2 + 4 * n11^2;
    h3 = (n30 - 3*n12)^2 + (3*n21 - n03)^2;
    h4 = (n30 + n12)^2 + (n21 + n03)^2;
    h5 = (n30 - 3*n12)*(n30 + n12)*((n30 + n12)^2 - 3*(n21 + n03)^2) +...
         (3*n21 - n03)*(n21 + n03)*(3*(n30 + n12)^2 - (n21 + n03)^2);
    h6 = (n20 - n02)*((n30 + n12)^2 - (n21 + n03)^2) + 4*n11*(n30 + n12)*(n21 + n03);
    h7 = (3*n21 - n03)*(n30 + n12)*((n30 + n12)^2 - 3*(n21 + n03)^2) -...
         (n30 - 3*n12)*(n21 + n03)*(3*(n30 + n12)^2 - (n21 + n03)^2);
    
    hu = [h1 h2 h3 h4 h5 h6 h7];
end

function [cnt, dens] = harris_manual(region, mask)
    I = (region - min(region(:))) / ((max(region(:)) - min(region(:))) + 1e-12);
    sx = [-1 0 1; -2 0 2; -1 0 1];
    gx = conv2(I, sx, 'same'); gy = conv2(I, sx', 'same');
    g = kernel_gaussiano(5, 1);
    Ixx = conv2(gx .* gx, g, 'same');
    Iyy = conv2(gy .* gy, g, 'same');
    Ixy = conv2(gx .* gy, g, 'same');
    R = (Ixx .* Iyy - Ixy.^2) - 0.04 * (Ixx + Iyy).^2;
    
    if max(R(:)) > 0, thr = 0.01 * max(R(:)); else, thr = 1e9; end
    
    M = R;
    for dy = -1:1
        for dx = -1:1
            if dy || dx, M = max(M, desplazar_matriz(R, dy, dx, -inf)); end
        end
    end
    
    mx = (R >= M) & (R > thr) & mask;
    cnt = sum(mx(:));
    dens = 1000 * cnt / (sum(mask(:)) + 1e-9);
end

function g = kernel_gaussiano(n, s)
    a = floor(n/2);
    [x, y] = meshgrid(-a:a, -a:a);
    g = exp(-(x.^2 + y.^2) / (2 * s^2));
    g = g / sum(g(:));
end

function [slr, sud] = simetria_manual(mask)
    fl = fliplr(mask); fu = flipud(mask);
    slr = 2 * sum(mask(:) & fl(:)) / (sum(mask(:)) + sum(fl(:)) + 1e-9);
    sud = 2 * sum(mask(:) & fu(:)) / (sum(mask(:)) + sum(fu(:)) + 1e-9);
end

function B = contorno_moore(mask)
    if ~any(mask(:)), B = zeros(0, 2); return; end
    [H, W] = size(mask);
    [rr, cc] = find(mask);
    [~, k] = min(rr * W + cc);
    start = [rr(k) cc(k)];
    
    nb = [-1 0; -1 1; 0 1; 1 1; 1 0; 1 -1; 0 -1; -1 -1];
    B = start; cur = start; bidx = 7; safety = 0; lim = 8 * sum(mask(:)) + 50;
    
    while true
        safety = safety + 1;
        if safety > lim, break; end
        found = false;
        
        for k = 0:7
            d = nb(mod(bidx + k, 8) + 1, :);
            nr = cur(1) + d(1); nc = cur(2) + d(2);
            if nr >= 1 && nr <= H && nc >= 1 && nc <= W && mask(nr, nc)
                B = [B; nr nc]; %#ok<AGROW>
                pdir = mod(bidx + k, 8);
                bidx = mod(pdir + 5, 8);
                cur = [nr nc];
                found = true;
                break;
            end
        end
        
        if ~found, break; end
        if isequal(cur, start) && size(B, 1) > 2, break; end
    end
end

function [area, per, comp, nc, err] = green_manual(mask)
    [lab, nc] = etiquetar_componentes(mask);
    if nc == 0, area = 0; per = 0; comp = 0; err = 0; return; end
    
    sizes = accumarray(lab(lab > 0), 1, [nc 1]);
    [~, big] = max(sizes);
    cm = (lab == big);
    
    B = contorno_moore(cm);
    if size(B, 1) < 3
        area = sum(cm(:)); per = 0; comp = 0; err = 0;
        return;
    end
    
    y = B(:,1); x = B(:,2);
    area = 0.5 * abs(sum(x .* circshift(y, -1) - circshift(x, -1) .* y));
    dx = x - circshift(x, -1); dy = y - circshift(y, -1);
    per = sum(hypot(dx, dy));
    comp = (per^2) / (4 * pi * area + 1e-9);
    err = 100 * abs(area - sum(cm(:))) / (sum(cm(:)) + 1e-9);
end

function [vmax, vmean] = von_mises_manual(mask, sil, P)
    E = P.E_A * ones(size(mask));
    E(mask) = P.E_F;
    E(~sil) = 0;
    Eb = mean(E(sil));
    
    [gx, gy] = gradient(E);
    gE = hypot(gx, gy);
    
    s0 = Eb * P.EPS0 / (1 - P.NU^2);
    sxx = s0 * (E / Eb);
    conc = 1 + P.KAPPA * gE / (Eb + 1e-9);
    VM = abs(sxx) .* conc;
    VM(~sil) = 0;
    
    reg = mask & sil;
    vmax = max(VM(reg));
    vmean = mean(VM(reg));
end

function y = convdown(x, f)
    y = conv2(x, f, 'same');
    y = y(:, 1:2:end);
end

function [me, mc] = dwt_db4_manual(region)
    [h, g] = db4_filtros();
    lo = convdown(region, h);
    hi = convdown(region, g);
    LH = convdown(lo', g)';
    HL = convdown(hi', h)';
    HH = convdown(hi', g)';
    
    n1 = min([size(LH,1), size(HL,1), size(HH,1)]);
    n2 = min([size(LH,2), size(HL,2), size(HH,2)]);
    LH = LH(1:n1, 1:n2);
    HL = HL(1:n1, 1:n2);
    HH = HH(1:n1, 1:n2);
    
    detail = LH.^2 + HL.^2 + HH.^2;
    me = mean(detail(:));
    thr = mean(detail(:)) + 3 * std(detail(:));
    mc = sum(detail(:) > thr);
end

function [h, g] = db4_filtros()
    h = [0.23037781330885523, 0.7148465705525415, 0.6308807679295904,...
         -0.02798376941698385, -0.18703481171888114, 0.030841381835986965,...
         0.032883011666982945, -0.010597401784997278];
    g = fliplr(h);
    g(2:2:end) = -g(2:2:end);
end

function [SRE, LRE, GLN] = glrlm_manual(region, mask)
    inm = region(mask); lo = min(inm); hi = max(inm);
    Q = min(max(round((region - lo) / ((hi - lo) + 1e-12) * 7), 0), 7);
    Q(~mask) = -1;
    
    mr = max(size(region));
    RL = zeros(8, mr + 1);
    
    for r = 1:size(Q, 1)
        row = Q(r, :); j = 1; n = numel(row);
        while j <= n
            if row(j) < 0, j = j + 1; continue; end
            k = j;
            while k + 1 <= n && row(k+1) == row(j), k = k + 1; end
            RL(row(j) + 1, k - j + 1) = RL(row(j) + 1, k - j + 1) + 1;
            j = k + 1;
        end
    end
    
    r = 0:mr; s = sum(RL(:)) + 1e-9;
    SRE = sum(sum(RL .* (1 ./ ((ones(8,1) * r).^2 + 1e-9)))) / s;
    LRE = sum(sum(RL .* ((ones(8,1) * r).^2))) / s;
    GLN = sum(sum(RL, 2).^2) / s;
end

function coh = orientacion_manual(region, mask)
    I = (region - min(region(:))) / ((max(region(:)) - min(region(:))) + 1e-12);
    sx = [-1 0 1; -2 0 2; -1 0 1];
    gx = conv2(I, sx, 'same'); gy = conv2(I, sx', 'same');
    Jxx = mean(gx(mask).^2); Jyy = mean(gy(mask).^2);
    Jxy = mean(gx(mask) .* gy(mask));
    coh = sqrt((Jxx - Jyy)^2 + 4 * Jxy^2) / (Jxx + Jyy + 1e-9);
end

%% ============================================================================
%  FUNCIONES ESTADISTICAS Y CLASIFICACION (sin toolbox)
%% ============================================================================

function q = percentil(v, p)
    v = sort(v(:)); n = numel(v);
    if n == 1, q = v; return; end
    h = (n - 1) * p + 1;
    lo = floor(h); hi = ceil(h);
    q = v(lo) + (h - lo) * (v(hi) - v(lo));
end

function z = zscore_columnas(x)
    z = (x - mean(x)) ./ (std(x) + 1e-9);
end

function s = orientar(s, y)
    if mean(s(y == 1)) < mean(s(y == 0)), s = -s; end
end

function idx = indice(names, nm)
    idx = find(strcmp(names, nm), 1);
end

function [t, p] = welch_ttest(a, b)
    va = var(a); vb = var(b); na = numel(a); nb = numel(b);
    se = sqrt(va/na + vb/nb);
    t = (mean(a) - mean(b)) / se;
    df = (va/na + vb/nb)^2 / ((va/na)^2/(na-1) + (vb/nb)^2/(nb-1));
    p = betainc(df / (df + t^2), df/2, 0.5);
end

function [F, p] = anova_oneway(x, grp)
    g = unique(grp); k = numel(g); N = numel(x);
    gm = mean(x); ssb = 0; ssw = 0;
    for i = 1:k
        xi = x(grp == g(i));
        ssb = ssb + numel(xi) * (mean(xi) - gm)^2;
        ssw = ssw + sum((xi - mean(xi)).^2);
    end
    df1 = k - 1; df2 = N - k;
    F = (ssb/df1) / (ssw/df2);
    p = betainc(df2 / (df2 + df1*F), df2/2, df1/2);
end

function a = calcular_auc(y, s)
    pos = s(y == 1); neg = s(y == 0);
    m = numel(pos); n = numel(neg);
    r = ranking_medio([pos(:); neg(:)]);
    a = (sum(r(1:m)) - m*(m+1)/2) / (m * n);
end

function r = ranking_medio(x)
    [xs, J] = sort(x(:));
    n = numel(x); T = zeros(n, 1); i = 1;
    while i <= n
        j = i;
        while j < n && xs(j+1) == xs(j), j = j + 1; end
        T(i:j) = (i + j) / 2;
        i = j + 1;
    end
    r = zeros(n, 1); r(J) = T;
end

function pr = regresion_logistica(Xtr, ytr, Xte, lmb, iter, lr)
    mu = mean(Xtr); sd = std(Xtr) + 1e-9;
    Z = [ones(size(Xtr,1), 1) (Xtr - mu) ./ sd];
    Zt = [ones(size(Xte,1), 1) (Xte - mu) ./ sd];
    w = zeros(size(Z, 2), 1);
    
    for t = 1:iter
        pp = 1 ./ (1 + exp(-Z * w));
        gg = Z' * (pp - ytr) / numel(ytr);
        gg(2:end) = gg(2:end) + lmb * w(2:end) / numel(ytr);
        w = w - lr * gg;
    end
    
    pr = 1 ./ (1 + exp(-Zt * w));
end

function oof = kfold_logreg(X, y, k)
    n = numel(y); assign = zeros(n, 1); rng(7);
    for c = [0 1]
        ci = find(y == c); ci = ci(randperm(numel(ci)));
        for i = 1:numel(ci), assign(ci(i)) = mod(i-1, k); end
    end
    oof = zeros(n, 1);
    for f = 0:k-1
        te = find(assign == f); tr = find(assign ~= f);
        oof(te) = regresion_logistica(X(tr,:), y(tr), X(te,:), 1.0, 600, 0.3);
    end
end

function ci = bootstrap_ci(y, s, nb)
    n = numel(y); a = nan(nb, 1); rng(3);
    for b = 1:nb
        idx = randi(n, n, 1);
        if numel(unique(y(idx))) < 2, continue; end
        a(b) = calcular_auc(y(idx), s(idx));
    end
    a = a(~isnan(a));
    ci = [percentil(a, 0.025) percentil(a, 0.975)];
end

function [z, p] = delong_test(y, s1, s2)
    pos = find(y == 1); neg = find(y == 0);
    m = numel(pos); n = numel(neg);
    aucs = zeros(1, 2);
    V01 = zeros(2, m); V10 = zeros(2, n);
    S = [s1 s2];
    
    for r = 1:2
        sr = S(:, r); ps = sr(pos); ns = sr(neg);
        tz = ranking_medio([ps; ns]); tx = ranking_medio(ps); ty = ranking_medio(ns);
        aucs(r) = (sum(tz(1:m)) - m*(m+1)/2) / (m * n);
        V01(r, :) = (tz(1:m) - tx)' / n;
        V10(r, :) = 1 - (tz(m+1:end) - ty)' / m;
    end
    
    Sc = cov(V01')/m + cov(V10')/n;
    L = [1 -1]; v = L * Sc * L';
    if v <= 0, z = 0; p = 1; return; end
    z = (aucs(1) - aucs(2)) / sqrt(v);
    p = erfc(abs(z) / sqrt(2));
end

function txt = texto_significancia(p)
    if p < 0.05, txt = '-> SIGNIFICATIVA'; else, txt = '-> no significativa'; end
end

function exportar_csv(fn, names, F)
    fid = fopen(fn, 'w');
    for i = 1:numel(names)-1, fprintf(fid, '%s,', names{i}); end
    fprintf(fid, '%s\n', names{end});
    for p = 1:size(F, 1)
        for i = 1:size(F, 2)-1, fprintf(fid, '%.6g,', F(p,i)); end
        fprintf(fid, '%.6g\n', F(p,end));
    end
    fclose(fid);
end

%% ============================================================================
%  FIGURAS PROFESIONALES (9 figuras completas)
%% ============================================================================

function guardar_fig(f, ruta)
    try
        print(f, ruta, '-dpng', '-r150');
    catch
        saveas(f, ruta);
    end
end

function fig1_fisica(tfg, mam, sil, P, mgd, outdir)
    t_ad = sil .* (P.T - tfg);
    L = P.MU_F * tfg + P.MU_A * t_ad;
    I = P.I0 * exp(-L);
    
    f = figure('Visible', 'off', 'Position', [60 60 1500 380]);
    
    subplot(1, 4, 1); imagesc(tfg); axis image off; colormap(gca, hot); colorbar;
    title('t_{fg} [cm]');
    
    subplot(1, 4, 2); imagesc(L); axis image off; colormap(gca, bone); colorbar;
    title('L = \mu_{fg}t_{fg} + \mu_{ad}t_{ad}');
    
    subplot(1, 4, 3); imagesc(I); axis image off; colormap(gca, gray); colorbar;
    title('I = I_0 e^{-L}');
    
    subplot(1, 4, 4); imagesc(mam); axis image off; colormap(gca, gray); colorbar;
    title('Mamografia -ln(I/I_0)');
    
    annotation('textbox', [0 0.94 1 0.06], 'String',...
        sprintf('FIGURA 1 - Fisica: formacion por atenuacion X (Beer-Lambert), MGD ~ %.2f mGy', mgd),...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    guardar_fig(f, fullfile(outdir, 'Fig01_fisica.png'));
    close(f);
    fprintf('   Figura 1: Fisica Beer-Lambert\n');
end

function fig2_fourier(m0, m1, outdir)
    f = figure('Visible', 'off', 'Position', [60 60 1300 800]);
    ttl = {'Compacta (clase 0)', 'Fragmentada (clase 1)'};
    ms = {m0, m1};
    
    for row = 1:2
        m = ms{row};
        
        subplot(2, 3, (row-1)*3 + 1); imagesc(m); axis image off; colormap(gca, gray);
        title(ttl{row});
        
        Pw = abs(fftshift(fft2(m - mean(m(:))))).^2;
        subplot(2, 3, (row-1)*3 + 2); imagesc(log(Pw + 1)); axis image off; colormap(gca, jet);
        title('Espectro 2D log|F|^2');
        
        [H, W] = size(Pw);
        cy = floor(H/2) + 1; cx = floor(W/2) + 1;
        [X, Y] = meshgrid(1:W, 1:H);
        rad = round(hypot(X - cx, Y - cy));
        mr = min(cx, cy) - 1;
        psd = zeros(1, mr);
        for k = 1:mr, psd(k) = mean(Pw(rad == k)); end
        
        k = 1:mr;
        band = k >= round(0.1 * mr) & k <= round(0.6 * mr) & psd > 0;
        pp = polyfit(log(k(band)), log(psd(band)), 1);
        
        subplot(2, 3, (row-1)*3 + 3);
        loglog(k, psd, '.', 'Color', [0.12 0.44 0.71]); hold on;
        loglog(k(band), exp(polyval(pp, log(k(band)))), 'r-', 'LineWidth', 2);
        xlabel('frecuencia radial k'); ylabel('PSD');
        title(sprintf('PSD radial  \\beta = %.2f', pp(1))); grid on;
    end
    
    annotation('textbox', [0 0.95 1 0.05], 'String',...
        'FIGURA 2 - Analisis espectral (Transformada de Fourier 2D)',...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    guardar_fig(f, fullfile(outdir, 'Fig02_fourier.png'));
    close(f);
    fprintf('   Figura 2: Analisis de Fourier\n');
end

function fig3_fractal(mask, F, names, labels, outdir)
    E = mask & ~erosionar3(mask);
    [H, W] = size(E);
    sizes = [2 4 8 16 32]; N = zeros(1, 5);
    
    for i = 1:5
        s = sizes(i); c = 0;
        for r0 = 1:s:H
            for c0 = 1:s:W
                if any(any(E(r0:min(r0+s-1, H), c0:min(c0+s-1, W)))), c = c + 1; end
            end
        end
        N(i) = c;
    end
    
    pp = polyfit(log(1./sizes), log(N), 1);
    
    f = figure('Visible', 'off', 'Position', [60 60 1500 460]);
    
    subplot(1, 3, 1);
    plot(log(1./sizes), log(N), 'o', 'MarkerFaceColor', [0.12 0.44 0.71], 'MarkerSize', 8);
    hold on; plot(log(1./sizes), polyval(pp, log(1./sizes)), 'r-', 'LineWidth', 2);
    xlabel('log(1/\epsilon)'); ylabel('log N(\epsilon)');
    title(sprintf('Dimension fractal D = %.3f', pp(1))); grid on;
    
    fd = F(:, indice(names, 'fractal_dim'));
    subplot(1, 3, 2); histograma_doble(fd(labels==0), fd(labels==1));
    xlabel('dimension fractal'); ylabel('frecuencia');
    title('DF por clase'); legend('clase 0', 'clase 1');
    
    coh = F(:, indice(names, 'orient_coher'));
    subplot(1, 3, 3); histograma_doble(coh(labels==0), coh(labels==1));
    xlabel('coherencia de orientacion'); ylabel('frecuencia');
    title('Tensor de estructura'); legend('clase 0', 'clase 1');
    
    annotation('textbox', [0 0.95 1 0.05], 'String',...
        'FIGURA 3 - Complejidad geometrica: fractal, run-length y orientacion',...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    guardar_fig(f, fullfile(outdir, 'Fig03_fractal.png'));
    close(f);
    fprintf('   Figura 3: Complejidad geometrica\n');
end

function fig4_vonmises(mask, sil, P, F, names, labels, outdir)
    E = P.E_A * ones(size(mask));
    E(mask) = P.E_F; E(~sil) = 0;
    Eb = mean(E(sil));
    
    [gx, gy] = gradient(E);
    gE = hypot(gx, gy);
    s0 = Eb * P.EPS0 / (1 - P.NU^2);
    sxx = s0 * (E / Eb);
    conc = 1 + P.KAPPA * gE / (Eb + 1e-9);
    VM = abs(sxx) .* conc; VM(~sil) = 0;
    
    f = figure('Visible', 'off', 'Position', [60 60 1500 460]);
    
    subplot(1, 3, 1); imagesc(E); axis image off; colormap(gca, parula); colorbar;
    title('E [kPa]');
    
    subplot(1, 3, 2); imagesc(VM); axis image off; colormap(gca, hot); colorbar;
    title('\sigma_{vM} (interfases)');
    
    vm = F(:, indice(names, 'vm_mean'));
    subplot(1, 3, 3); histograma_doble(vm(labels==0), vm(labels==1));
    xlabel('\sigma_{vM} media'); ylabel('frecuencia');
    title('Tension por clase'); legend('clase 0', 'clase 1');
    
    annotation('textbox', [0 0.95 1 0.05], 'String',...
        'FIGURA 4 - Biomecanica: modulo de Young y von Mises',...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    guardar_fig(f, fullfile(outdir, 'Fig04_vonmises.png'));
    close(f);
    fprintf('   Figura 4: Modelo biomecanico\n');
end

function fig5_estadistica(F, names, pvals, labels, outdir)
    sel = {'compactness', 'hu2', 'sym_lr', 'n_components', 'fractal_dim', 'glcm_contrast'};
    
    f = figure('Visible', 'off', 'Position', [40 40 1500 820]);
    
    for i = 1:6
        subplot(2, 4, i + floor((i-1)/3));
        c = indice(names, sel{i});
        v = F(:, c);
        mini_boxplot(1, v(labels==0), [0.18 0.62 0.27]);
        mini_boxplot(2, v(labels==1), [0.84 0.15 0.16]);
        set(gca, 'XTick', [1 2], 'XTickLabel', {'C0', 'C1'});
        xlim([0.4 2.6]);
        title(sprintf('%s  p = %.1e', sel{i}, pvals(c)));
        grid on;
    end
    
    subplot(2, 4, [4 8]);
    R = matriz_correlacion(F);
    imagesc(R, [-1 1]); axis image; colormap(gca, jet); colorbar;
    title('Correlacion 32 descriptores'); set(gca, 'XTick', [], 'YTick', []);
    
    annotation('textbox', [0 0.96 1 0.04], 'String',...
        'FIGURA 5 - Validacion estadistica: separacion por descriptor y correlaciones',...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    guardar_fig(f, fullfile(outdir, 'Fig05_estadistica.png'));
    close(f);
    fprintf('   Figura 5: Validacion estadistica\n');
end

function fig6_roc(y, s_igr, s_hue, s_den, a_igr, a_hue, a_den, p1, outdir)
    f = figure('Visible', 'off', 'Position', [80 60 1300 600]);
    
    subplot(1, 2, 1);
    [xi, yi] = curva_roc(y, s_igr);
    [xh, yh] = curva_roc(y, s_hue);
    [xd, yd] = curva_roc(y, s_den);
    
    plot(xi, yi, '-', 'LineWidth', 2.6, 'Color', [0.18 0.62 0.27]); hold on;
    plot(xh, yh, '-', 'LineWidth', 2.2, 'Color', [0.88 0.54 0.12]);
    plot(xd, yd, '-', 'LineWidth', 2.6, 'Color', [0.84 0.15 0.16]);
    plot([0 1], [0 1], 'k--');
    xlabel('Tasa de falsos positivos'); ylabel('Tasa de verdaderos positivos');
    axis square; grid on;
    legend({sprintf('IGR AUC=%.3f', a_igr), sprintf('Huella AUC=%.3f', a_hue),...
            sprintf('Densidad AUC=%.3f', a_den), 'azar'}, 'Location', 'southeast');
    title(sprintf('Curvas ROC (DeLong IGR vs densidad: p=%.1e)', p1));
    
    subplot(1, 2, 2);
    nb = 2000; bi = zeros(nb, 1); bd = zeros(nb, 1); n = numel(y); rng(3);
    for b = 1:nb
        idx = randi(n, n, 1);
        if numel(unique(y(idx))) < 2, bi(b) = NaN; bd(b) = NaN; continue; end
        bi(b) = calcular_auc(y(idx), s_igr(idx));
        bd(b) = calcular_auc(y(idx), s_den(idx));
    end
    bi = bi(~isnan(bi)); bd = bd(~isnan(bd));
    histograma_doble(bd, bi);
    linea_vertical(0.5);
    xlabel('AUC (bootstrap, 2000)'); ylabel('frecuencia');
    legend('densidad', 'IGR'); title('Distribucion bootstrap AUC');
    
    annotation('textbox', [0 0.95 1 0.05], 'String',...
        'FIGURA 6 - Desempeno: IGR y huella vs densidad (BI-RADS)',...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    guardar_fig(f, fullfile(outdir, 'Fig06_ROC.png'));
    close(f);
    fprintf('   Figura 6: Curvas ROC y bootstrap\n');
end

function fig7_birads(F, names, labels, s_igr, outdir)
    y = labels;
    auc = zeros(numel(names), 1);
    for i = 1:numel(names)
        auc(i) = auc_univariado(y, F(:, i));
    end
    
    [as, ix] = sort(auc, 'descend');
    topn = min(16, numel(names));
    ix = ix(1:topn); as = as(1:topn);
    
    f = figure('Visible', 'off', 'Position', [60 60 1500 600]);
    
    subplot(1, 2, 1);
    barh(1:topn, flipud(as), 'FaceColor', [0.12 0.44 0.71]); hold on;
    plot([0.5 0.5], [0 topn+1], 'k--');
    set(gca, 'YTick', 1:topn, 'YTickLabel', flipud(names(ix)));
    xlabel('AUC univariado'); title('Top-16 descriptores por AUC');
    grid on; xlim([0 1]);
    
    subplot(1, 2, 2);
    qs = [percentil(s_igr, 0.25) percentil(s_igr, 0.5) percentil(s_igr, 0.75)];
    cat = ones(numel(s_igr), 1);
    cat(s_igr > qs(1)) = 2; cat(s_igr > qs(2)) = 3; cat(s_igr > qs(3)) = 4;
    
    c0 = zeros(1, 4); c1 = zeros(1, 4);
    for kk = 1:4
        c0(kk) = sum(cat == kk & y == 0);
        c1(kk) = sum(cat == kk & y == 1);
    end
    
    bar(1:4, [c0' c1']);
    colormap(gca, [0.18 0.62 0.27; 0.84 0.15 0.16]);
    set(gca, 'XTickLabel', {'BG-1', 'BG-2', 'BG-3', 'BG-4'});
    xlabel('BI-RADS Geometrico (cuartiles IGR)');
    ylabel('n pacientes');
    legend('clase 0 (compacta)', 'clase 1 (fragmentada)');
    title('Distribucion por categoria geometrica');
    
    annotation('textbox', [0 0.95 1 0.05], 'String',...
        'FIGURA 7 - Poder discriminante individual y BI-RADS Geometrico propuesto',...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    guardar_fig(f, fullfile(outdir, 'Fig07_birads.png'));
    close(f);
    fprintf('   Figura 7: BI-RADS Geometrico propuesto\n');
end

function fig8_muestras(m0, m1, k0, k1, t0, t1, outdir)
    f = figure('Visible', 'off', 'Position', [60 60 1500 700]);
    
    subplot(2, 3, 1); imagesc(m0); axis image off; colormap(gca, gray); colorbar;
    title('Mamografia clase 0 (compacta)');
    
    subplot(2, 3, 2); imagesc(k0); axis image off; colormap(gca, gray);
    title('Segmentacion clase 0');
    
    subplot(2, 3, 3); imagesc(t0); axis image off; colormap(gca, hot); colorbar;
    title('Espesor glandular clase 0');
    
    subplot(2, 3, 4); imagesc(m1); axis image off; colormap(gca, gray); colorbar;
    title('Mamografia clase 1 (fragmentada)');
    
    subplot(2, 3, 5); imagesc(k1); axis image off; colormap(gca, gray);
    title('Segmentacion clase 1');
    
    subplot(2, 3, 6); imagesc(t1); axis image off; colormap(gca, hot); colorbar;
    title('Espesor glandular clase 1');
    
    annotation('textbox', [0 0.95 1 0.05], 'String',...
        'FIGURA 8 - Comparacion visual: geometria compacta vs fragmentada',...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    guardar_fig(f, fullfile(outdir, 'Fig08_muestras.png'));
    close(f);
    fprintf('   Figura 8: Comparacion visual de clases\n');
end

function fig9_resumen(F, names, auc_igr, auc_den, auc_hue, p1, p2, outdir)
    f = figure('Visible', 'off', 'Position', [60 60 1200 600]);
    axis off;
    
    % Fondo
    rectangle('Position', [0.05 0.05 0.9 0.9], 'FaceColor', [0.98 0.98 0.99],...
              'EdgeColor', [0.2 0.4 0.6], 'LineWidth', 3, 'Curvature', 0.02);
    
    text(0.5, 0.92, 'RESUMEN EJECUTIVO - SISTEMA DE CARACTERIZACION',...
         'Units', 'normalized', 'FontSize', 16, 'FontWeight', 'bold',...
         'HorizontalAlignment', 'center', 'Color', [0.1 0.3 0.5]);
    
    line([0.1 0.9], [0.87 0.87], 'Color', [0.3 0.5 0.7], 'LineWidth', 2);
    
    % Resultados principales
    resultados_texto = {
        'HIPOTESIS CENTRAL:'
        'La geometria del tejido denso contiene informacion diagnostica'
        'independiente de la densidad areal global (BI-RADS).'
        ''
        'RESULTADOS CLAVE:'
        sprintf('AUC IGR (geometria + radiomica) : %.3f', auc_igr)
        sprintf('AUC Huella (30/35/35)           : %.3f', auc_hue)
        sprintf('AUC Densidad sola (BI-RADS)     : %.3f', auc_den)
        ''
        'TEST DE DeLong (IGR vs densidad):'
        sprintf('Estadistico z = %.2f  |  p = %.2e  |  %s',...
                abs(p1), p1, texto_significancia(p1))
        ''
        'DESCRIPTORES EVALUADOS: 32'
        sprintf('Significativos (p < 0.05): %d', sum(F < 0.05, 1))
        ''
        'FANTOMA: 160 pacientes (clase 0 = compacta, clase 1 = fragmentada)'
        'Glandularidad IGUALADA entre clases por construccion'
    };
    
    text(0.12, 0.82, resultados_texto, 'Units', 'normalized', 'FontSize', 11,...
         'FontName', 'Monospaced', 'FontWeight', 'bold', 'VerticalAlignment', 'top',...
         'Color', [0.1 0.3 0.5]);
    
    % Conclusion
    if p1 < 0.05
        conclusion = 'CONCLUSION: La geometria discrimina significativamente';
        color_concl = [0.18 0.62 0.27];
    else
        conclusion = 'CONCLUSION: No hay evidencia de ventaja geometrica';
        color_concl = [0.84 0.15 0.16];
    end
    
    rectangle('Position', [0.15 0.12 0.7 0.12], 'FaceColor', color_concl,...
              'EdgeColor', 'black', 'LineWidth', 2, 'Curvature', 0.03);
    text(0.5, 0.2, conclusion, 'Units', 'normalized', 'FontSize', 13,...
         'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', 'white');
    
    annotation('textbox', [0 0.95 1 0.05], 'String',...
        'FIGURA 9 - Resumen ejecutivo del sistema de caracterizacion',...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    guardar_fig(f, fullfile(outdir, 'Fig09_resumen.png'));
    close(f);
    fprintf('   Figura 9: Resumen ejecutivo\n');
end

%% ============================================================================
%  UTILIDADES PARA FIGURAS
%% ============================================================================

function mini_boxplot(xc, v, colr)
    q1 = percentil(v, 0.25); md = percentil(v, 0.5); q3 = percentil(v, 0.75);
    iqr = q3 - q1;
    lo = max(min(v), q1 - 1.5*iqr);
    hi = min(max(v), q3 + 1.5*iqr);
    w = 0.28;
    
    patch([xc-w xc+w xc+w xc-w], [q1 q1 q3 q3], colr, 'FaceAlpha', 0.55, 'EdgeColor', 'k');
    hold on;
    plot([xc-w xc+w], [md md], 'k-', 'LineWidth', 1.6);
    plot([xc xc], [q3 hi], 'k-');
    plot([xc xc], [lo q1], 'k-');
end

function histograma_doble(a, b)
    allv = [a(:); b(:)];
    ed = linspace(min(allv), max(allv), 19);
    ha = histc(a, ed); hb = histc(b, ed);
    ctr = ed + (ed(2) - ed(1))/2;
    
    bar(ctr, ha, 'FaceColor', [0.18 0.62 0.27], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    hold on;
    bar(ctr, hb, 'FaceColor', [0.84 0.15 0.16], 'FaceAlpha', 0.6, 'EdgeColor', 'none');
end

function linea_vertical(x)
    yl = ylim;
    plot([x x], yl, 'k--');
end

function R = matriz_correlacion(X)
    Z = (X - mean(X)) ./ (std(X) + 1e-9);
    R = (Z' * Z) / (size(X, 1) - 1);
    R(~isfinite(R)) = 0;
end

function [Xr, Yr] = curva_roc(y, s)
    th = unique(s); th = th(end:-1:1);
    P = sum(y == 1); Nn = sum(y == 0);
    Xr = 0; Yr = 0;
    
    for i = 1:numel(th)
        pred = s >= th(i);
        tp = sum(pred & y == 1);
        fp = sum(pred & y == 0);
        Xr(end+1) = fp / Nn; %#ok<AGROW>
        Yr(end+1) = tp / P;  %#ok<AGROW>
    end
    
    Xr(end+1) = 1; Yr(end+1) = 1;
end

function a = auc_univariado(y, s)
    a = calcular_auc(y, s);
    a = max(a, 1 - a);
end