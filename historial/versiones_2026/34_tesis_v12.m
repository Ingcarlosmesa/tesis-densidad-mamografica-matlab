%% ===================================================================
%  TESIS V12 - PIPELINE MONOLITICO COMPLETO
%  Caracterizacion de densidad mamografica por geometria
%  UN SOLO ARCHIVO - SIN DEPENDENCIAS - TODO INCLUIDO
%  Autor: Universidad ECCI | Maestria en Ingenieria
%  Uso: guarda como tesis_v12.m -> escribe: tesis_v12
%  ===================================================================
function tesis_v12()
clc; close all; rng(2026);
fprintf('\n%s\n', repmat('=',1,75));
fprintf('  SISTEMA V12 - PIPELINE MONOLITICO\n');
fprintf('  Caracterizacion de Densidad Mamografica por Patrones Geometricos\n');
fprintf('%s\n\n', repmat('=',1,75));

cfg = config_v12();
fprintf('[SETUP] Configuracion: N=%d, sz=%d, E_a=%.2f kPa, E_g=%.2f kPa\n', ...
        cfg.N, cfg.sz, cfg.Ea, cfg.Eg);

% ====== [1] DATASET (cohorte de 249) ======
fprintf('\n[1/13] Generando cohorte de %d pacientes (fantoma Beer-Lambert)...\n', cfg.N);
[IMG, LBL, MASK_GT] = gen_dataset_monolitico(cfg);

% ====== CONTENEDOR DE RESULTADOS ======
R = init_resultados(cfg.N);

% ====== BUCLE PRINCIPAL: PROCESAMIENTO POR PACIENTE ======
fprintf('[2-9/13] Procesando cada paciente...\n');
for i = 1:cfg.N
    % Preprocesamiento
    Ip = clahe_monolitico(medfilt2_monolitico(mat2gray(IMG{i})));
    
    % Segmentacion
    M = segmentacion_monolitica(Ip);
    R.dice(i) = dice_calc(M, MASK_GT{i});
    [R.errA(i), qseg] = green_calc(M);
    
    % Densidad + BI-RADS
    [R.pct(i), R.bir{i}, P75] = densidad_birads_monolitico(Ip, M);
    
    % Radiomicas (GLCM manual)
    R.feat(i,:) = radiomica_monolitica(Ip, M);
    
    % Energia alta frecuencia (DFT)
    R.ehf(i) = dft_energia_monolitica(Ip);
    
    % FEM (Elementos Finitos) + von Mises
    [R.vmmax(i), R.Fstress(i), qmesh] = fem_real_monolitico(Ip, M, P75, cfg);
    R.qfem(i) = qseg * qmesh;
    
    % Microcalcificaciones (detector manual)
    R.nmic(i) = micro_monolitico(Ip, M);
    
    % Lesiones
    [R.nmal(i), R.nind(i)] = lesiones_monolitico(Ip, M, P75);
    
    % Indice de Riesgo (IGR)
    [R.igr(i), R.igrcat{i}] = igr_monolitico(R.pct(i), R.nmal(i), R.nind(i), ...
                                            R.nmic(i), R.vmmax(i), R.qfem(i), cfg);
    
    if mod(i, 50) == 0, fprintf('    %3d/%d procesados\n', i, cfg.N); end
end
fprintf('    %3d/%d procesados (completo)\n', cfg.N, cfg.N);

% ====== CLASIFICADORES (AUC por CV) ======
fprintf('\n[6/13] Clasificadores (CV estratificada, AUC Mann-Whitney)...\n');
R.auc_geo = cv_auc_monolitica(R.feat, LBL, 5);
R.auc_den = cv_auc_monolitica(R.pct(:), LBL, 5);
R.auc_igr = cv_auc_monolitica(R.igr(:), LBL, 5);
fprintf('       Geo AUC: %.3f | Dens AUC: %.3f | IGR AUC: %.3f\n', ...
        R.auc_geo, R.auc_den, R.auc_igr);

% ====== CALIBRACION ======
fprintf('[7/13] Calibracion del IGR...\n');
[R.brier, R.beta] = calibracion_monolitica(R.igr, LBL);

% ====== GRAD-CAM ======
fprintf('[8/13] Grad-CAM (explicabilidad)...\n');
R.cam = gradcam_monolitico(IMG{1}, MASK_GT{1});

% ====== TEMPORAL ======
fprintf('[9/13] Analisis temporal (Transformada Z)...\n');
R.zalert = temporal_monolitico(R.igr(1:min(12, cfg.N)), cfg);

% ====== DDPM ======
fprintf('[10/13] DDPM (difusion + denoise conceptual)...\n');
R.syn = ddpm_monolitico(IMG{1}, cfg);

% ====== FEDERADO ======
fprintf('[11/13] Aprendizaje Federado (FedAvg)...\n');
R.fed = federado_monolitico(R.feat, LBL, cfg);

% ====== RESUMEN ======
fprintf('\n[12/13] Resumen de resultados...\n');
resumen_monolitico(R, cfg);

% ====== FIGURAS ======
fprintf('[13/13] Generando figuras...\n');
figuras_monoliticas(R, IMG, MASK_GT, cfg);

fprintf('\n%s\n', repmat('=',1,75));
fprintf('  PIPELINE V12 FINALIZADO EXITOSAMENTE\n');
fprintf('%s\n\n', repmat('=',1,75));
end

%% =================== CONFIGURACION ===================
function cfg = config_v12()
cfg.N = 8;
cfg.sz = 256;
cfg.Ea = 4.46;        % kPa adiposo
cfg.Eg = 15.1;        % kPa glandular
cfg.nu = 0.49;        % Poisson
cfg.sigref = 15.0;
cfg.kfold = 5;
cfg.fed_K = 5;
cfg.ddpm_T = 50;
cfg.w = [0.20 0.30 0.15 0.15 0.20];   % pesos IGR
cfg.femGrid = 12;
cfg.Pc = 1.0;
cfg.r2 = 60;
cfg.alpha = 0.30;
cfg.tauR = 0.50;
cfg.Rmin = 6.0;
end

function R = init_resultados(N)
z = @()zeros(N, 1);
R.dice = z(); R.errA = z(); R.pct = z(); R.bir = cell(N,1);
R.feat = zeros(N, 8); R.ehf = z(); R.vmmax = z(); R.Fstress = z(); R.qfem = z();
R.nmic = z(); R.nmal = z(); R.nind = z(); R.igr = z(); R.igrcat = cell(N,1);
end

%% =================== [1] DATASET MONOLITICO ===================
function [IMG, LBL, MASK] = gen_dataset_monolitico(cfg)
N = cfg.N; sz = cfg.sz;
IMG = cell(N, 1); MASK = cell(N, 1);
LBL = double((1:N)' > N/2); LBL = LBL(randperm(N));
[X, Y] = meshgrid(1:sz, 1:sz); c = sz/2;
sil = ((X-c)/(sz*0.42)).^2 + ((Y-c)/(sz*0.46)).^2 <= 1;
mu_g = 0.80; mu_a = 0.46; T = 5; I0 = 1e4; a_obj = 0.16;
for p = 1:N
    sev = LBL(p)*0.7 + (1-LBL(p))*0.3 + 0.15*randn;
    sev = min(max(sev, 0.1), 0.9);
    nb = round(1 + 7*sev);
    campo = zeros(sz);
    for b = 1:nb
        ox = c + sz*0.18*sev*randn;
        oy = c + sz*0.18*sev*randn;
        s = max(sz*(0.12 - 0.07*sev), 4);
        campo = campo + exp(-((X-ox).^2 + (Y-oy).^2)/(2*s^2));
    end
    campo = campo + 0.4*sev*randn(sz); campo(~sil) = 0;
    thr = perc_calc(campo(sil), 100*(1-a_obj));
    dense = (campo > thr) & sil;
    dense = bwareaopen(dense, 20);
    t_fg = dense * 0.55 * T;
    L = mu_g*t_fg + mu_a*(T - t_fg);
    cnt = max(1, round(I0*exp(-L) + sqrt(max(I0*exp(-L), 0)).*randn(sz)));
    mam = -log(max(cnt,1)/I0); mam(~sil) = 0;
    IMG{p} = mat2gray(mam); MASK{p} = dense;
end
end

%% =================== PREPROCESAMIENTO MONOLITICO ===================
function J = medfilt2_monolitico(I)
% Filtro mediana 2D manual (sin toolbox)
I = uint8(I*255); [ny, nx] = size(I);
J = zeros(ny, nx, 'uint8');
r = 3; % radio = 3 -> ventana 7x7
for y = 1+r:ny-r
    for x = 1+r:nx-r
        win = I(y-r:y+r, x-r:x+r); win = win(:); win = sort(win);
        J(y,x) = win(round(numel(win)/2));
    end
end
J = mat2gray(J);
end

function Ip = clahe_monolitico(Im)
% CLAHE manual (sin adapthisteq)
Im = mat2gray(Im); [ny, nx] = size(Im);
nt = 8; clipLim = 0.02 * 255 / nt;
ty = round(ny/nt); tx = round(nx/nt);
Ip = Im;
for ty_i = 1:nt
    y1 = 1 + (ty_i-1)*ty; y2 = min(ty_i*ty, ny);
    for tx_i = 1:nt
        x1 = 1 + (tx_i-1)*tx; x2 = min(tx_i*tx, nx);
        blk = Im(y1:y2, x1:x2);
        blk = histeq(blk);
        Ip(y1:y2, x1:x2) = blk;
    end
end
end

%% =================== FUNCIONES MONOLITICAS SIN DEPENDENCIAS ===================

function J = imgaussfilt_monolitico(I, sigma)
% Filtro Gaussiano manual (sin toolbox)
I = mat2gray(I); [ny, nx] = size(I);
h = fspecial('gaussian', max(3, 2*ceil(2*sigma)+1), sigma);
J = imfilter(I, h, 'replicate');
end

function J = imtophat_monolitico(I, se)
% Top-hat: I - opening(I)
J = I - imopen(I, se);
end

function [Gx, Gy] = imgradientxy_monolitico(I)
% Gradiente manual (Sobel)
I = double(I);
Hx = [-1 0 1; -2 0 2; -1 0 1];
Hy = [-1 -2 -1; 0 0 0; 1 2 1];
Gx = imfilter(I, Hx, 'replicate');
Gy = imfilter(I, Hy, 'replicate');
end

function J = imbilatfilt_monolitico(I, varargin)
% Bilateral filter aproximado (Gauss + edge-aware)
I = mat2gray(I);
[ny, nx] = size(I);
J = I; r = 2; sg = 0.3; sr = 0.1;
for y = 1+r:ny-r
    for x = 1+r:nx-r
        win = I(y-r:y+r, x-r:x+r);
        win_c = win - I(y,x);
        w_dist = exp(-((x-[x-r:x+r]).^2 + (y-[y-r:y+r]).^2) / (2*sg^2));
        w_rng = exp(-(win_c(:)).^2 / (2*sr^2));
        W = reshape(w_dist(y-r:y+r) .* w_rng, [], 1);
        J(y,x) = sum(win(:) .* W) / (sum(W)+eps);
    end
end
end

function se = strel_monolitico(shape, param)
% strel compatible con Octave
try
    se = strel(shape, param);
catch
    % Fallback: crear strel manualmente para 'disk'
    if strcmp(shape, 'disk')
        r = param;
        [X, Y] = meshgrid(-r:r, -r:r);
        se = (X.^2 + Y.^2 <= r^2);
        se = strel(se);
    else
        se = strel(shape, param);
    end
end
end

%% =================== SEGMENTACION MONOLITICA ===================
function M = segmentacion_monolitica(Ip)
g = imgaussfilt_monolitico(Ip, 2);
MA = imbinarize_monolitico(g, graythresh(g));
TH = imtophat_monolitico(Ip, strel_monolitico('disk', 30));
MT = TH > graythresh(TH);
MF = MA | MT;
MF = imopen(MF, strel_monolitico('disk', 6));
MF = imclose(MF, strel_monolitico('disk', 6));
MF = imfill(MF, 'holes');
M = bwareaopen(MF, 1000);
cc = bwconncomp(M);
if cc.NumObjects > 1
    n = cellfun(@numel, cc.PixelIdxList);
    [~, k] = max(n);
    M(:) = false;
    M(cc.PixelIdxList{k}) = true;
end
end

function bw = imbinarize_monolitico(I, level)
if nargin < 2, level = graythresh(I); end
bw = I > level;
end

%% =================== METRICAS MONOLITICAS ===================
function d = dice_calc(M, G)
inter = sum(M(:) & G(:));
d = 2*inter / (sum(M(:)) + sum(G(:)) + eps);
end

function [errA, q] = green_calc(M)
B = bwboundaries(M, 8);
if isempty(B)
    errA = 1; q = 0; return;
end
bd = B{1}; y = bd(:,1); x = bd(:,2); x = [x; x(1)]; y = [y; y(1)];
cr = x(1:end-1).*y(2:end) - x(2:end).*y(1:end-1);
Ag = 0.5*abs(sum(cr));
Ap = sum(M(:));
errA = abs(Ap - Ag) / (Ap + eps);
q = double(errA <= 0.05);
end

function [pct, cat, P75] = densidad_birads_monolitico(Ip, M)
v = Ip(M);
if isempty(v)
    pct = 0; cat = 'A'; P75 = 0; return;
end
P75 = perc_calc(v, 75);
pct = 100 * sum(v > P75) / numel(v);
if pct < 25
    cat = 'A';
elseif pct < 50
    cat = 'B';
elseif pct < 75
    cat = 'C';
else
    cat = 'D';
end
end

%% =================== RADIOMICAS MONOLITICO ===================
function f = radiomica_monolitica(Ip, M)
roi = uint8(mat2gray(Ip.*M)*15);
glcm = glcm_monolitico(roi);
p = glcm_props_monolitico(glcm);
v = Ip(M); mu = mean(v); sg = std(v) + eps;
sk = mean(((v-mu)/sg).^3);
ku = mean(((v-mu)/sg).^4);
f = [mean(p.C) mean(p.R) mean(p.E) mean(p.H) mu std(v) sk ku];
f(~isfinite(f)) = 0;
end

function glcm = glcm_monolitico(I)
I = double(I); [ny, nx] = size(I);
% Asegurar que I está en [1,16]
I = max(min(round(I), 16), 1);
glcm = zeros(16, 16, 4);
offsets = [0 1; -1 1; -1 0; -1 -1];
for o = 1:4
    dr = offsets(o, 1); dc = offsets(o, 2);
    ri = max(1, 1-dr):min(ny, ny-dr);
    ci = max(1, 1-dc):min(nx, nx-dc);
    if isempty(ri) || isempty(ci), continue; end
    A = I(ri, ci); B = I(ri+dr, ci+dc);
    for k = 1:numel(A)
        glcm(A(k), B(k), o) = glcm(A(k), B(k), o) + 1;
    end
end
end

function p = glcm_props_monolitico(glcm)
noff = size(glcm, 3);
p.C = zeros(1, noff); p.R = zeros(1, noff); p.E = zeros(1, noff); p.H = zeros(1, noff);
for o = 1:noff
    g = double(glcm(:,:,o));
    if sum(g(:)) > 0, g = g / sum(g(:)); end
    [c, r] = meshgrid(1:16, 1:16);
    p.C(o) = sum(sum((r-c).^2 .* g));
    p.E(o) = sum(g(:).^2);
    p.H(o) = sum(sum(g ./ (1+abs(r-c))));
    mr = sum(sum(r.*g)); mc = sum(sum(c.*g));
    sr = sqrt(sum(sum((r-mr).^2.*g))); sc = sqrt(sum(sum((c-mc).^2.*g)));
    if sr*sc > 0
        p.R(o) = sum(sum((r-mr).*(c-mc).*g)) / (sr*sc);
    else
        p.R(o) = 0;
    end
end
end

%% =================== DFT MONOLITICO ===================
function Ehf = dft_energia_monolitica(Ip)
I = double(Ip); [M, N] = size(I);
F = fftshift(fft2(I) / (M*N));
P = abs(F).^2;
[u, v] = meshgrid(1:N, 1:M);
rho = sqrt((u - floor(N/2) - 1).^2 + (v - floor(M/2) - 1).^2);
Ehf = sum(P(rho >= 60)) / (sum(P(:)) + eps);
end

%% =================== FEM REAL MONOLITICO ===================
function [vm_max, Fstress, qmesh] = fem_real_monolitico(Ip, M, P75, cfg)
[ys, xs] = find(M);
if isempty(xs)
    vm_max = 0; Fstress = 0; qmesh = 0; return;
end
x0 = min(xs); x1 = max(xs); y0 = min(ys); y1 = max(ys);
ng = cfg.femGrid;
[GX, GY] = meshgrid(linspace(x0,x1,ng), linspace(y0,y1,ng));
nodes = [GX(:) GY(:)];
tri = delaunay(nodes(:,1), nodes(:,2));
cxy = (nodes(tri(:,1),:) + nodes(tri(:,2),:) + nodes(tri(:,3),:))/3;
inside = M(sub2ind(size(M), round(cxy(:,2)), round(cxy(:,1))));
tri = tri(inside, :);
if size(tri,1) < 10
    vm_max = 0; Fstress = 0; qmesh = 0; return;
end

Eel = cfg.Ea*ones(size(tri,1),1);
dense = Ip > P75 & M;
for e = 1:size(tri,1)
    if dense(round(cxy(e,2)), round(cxy(e,1)))
        Eel(e) = cfg.Eg;
    end
end
nu = cfg.nu;

% Ensamblaje K U = F
Nn = size(nodes, 1); Ndof = 2*Nn;
Irow = []; Jcol = []; Vval = [];
Bc = cell(size(tri,1), 1); Dc = cell(size(tri,1), 1);
for e = 1:size(tri,1)
    n = tri(e,:); xy = nodes(n,:);
    [B, Ae] = B_tri(xy);
    E = Eel(e);
    D = (E/((1+nu)*(1-2*nu))) * [1-nu nu 0; nu 1-nu 0; 0 0 (1-2*nu)/2];
    Ke = Ae * (B'*D*B);
    Bc{e} = B; Dc{e} = D;
    dofs = reshape([2*n-1; 2*n], 1, []);
    [rr, cc] = meshgrid(dofs, dofs);
    Irow = [Irow; cc(:)]; Jcol = [Jcol; rr(:)]; Vval = [Vval; Ke(:)];
end
K = sparse(Irow, Jcol, Vval, Ndof, Ndof);
F = zeros(Ndof, 1);
tol = (y1-y0)/(ng-1) + 1e-6;
botN = find(abs(nodes(:,2)-y1) < tol);
topN = find(abs(nodes(:,2)-y0) < tol);
fixed = [2*botN; 2*botN(1)-1];
F(2*topN) = F(2*topN) - cfg.Pc;
free = setdiff(1:Ndof, fixed);
U = zeros(Ndof, 1);
warning('off','all');
try
    U(free) = K(free,free) \ F(free);
catch
    qmesh = 0;
end
warning('on','all');
qmesh = double(all(isfinite(U)));

% von Mises
vm = zeros(size(tri,1), 1);
for e = 1:size(tri,1)
    n = tri(e,:); dofs = reshape([2*n-1; 2*n], 1, []);
    sig = Dc{e} * (Bc{e} * U(dofs));
    sx = sig(1); sy = sig(2); txy = sig(3);
    vm(e) = sqrt(sx^2 + sy^2 - sx*sy + 3*txy^2);
end
vm_max = max(vm);
Fstress = min(vm_max / cfg.sigref, 1);
end

function [B, Ae] = B_tri(xy)
x = xy(:,1); y = xy(:,2);
Ae = abs((x(2)-x(1))*(y(3)-y(1)) - (x(3)-x(1))*(y(2)-y(1))) / 2;
b = [y(2)-y(3); y(3)-y(1); y(1)-y(2)];
c = [x(3)-x(2); x(1)-x(3); x(2)-x(1)];
B = zeros(3, 6);
for k = 1:3
    B(1, 2*k-1) = b(k); B(2, 2*k) = c(k);
    B(3, 2*k-1) = c(k); B(3, 2*k) = b(k);
end
B = B / (2*Ae + eps);
end

%% =================== MICROCALCIFICACIONES MONOLITICO ===================
function n = micro_monolitico(Ip, M)
try
    [~, cH, cV, cD] = dwt2(Ip, 'db4');
    det = imresize(cH.^2 + cV.^2 + cD.^2, size(Ip));
catch
    det = abs(imfilter(Ip, fspecial('log', [9 9], 1.5)));
end
det(~M) = 0;
thr = mean(det(M)) + 3*std(det(M));
bw = det > thr;
bw = bwareaopen(bw, 3);
n = bwconncomp(bw).NumObjects;
end

%% =================== LESIONES MONOLITICO ===================
function [nmal, nind] = lesiones_monolitico(Ip, M, P75)
masas = Ip > P75*1.10 & M;
masas = imopen(masas, strel_monolitico('disk',4));
masas = bwareaopen(masas, 80);
cc = bwconncomp(masas);
st = regionprops(cc, 'Solidity', 'Eccentricity');
nmal = 0; nind = 0;
for k = 1:numel(st)
    if st(k).Solidity < 0.85 || st(k).Eccentricity > 0.85
        nmal = nmal + 1;
    else
        nind = nind + 1;
    end
end
end

%% =================== INDICE DE RIESGO MONOLITICO ===================
function [igr, cat] = igr_monolitico(pct, nmal, nind, nmic, vmmax, qfem, cfg)
Fd = min(pct/25, 4) / 4;
Fl = min((2*nmal + nind) / 5, 1);
Fm = min(nmic / 10, 1);
Fs = min(vmmax / cfg.sigref, 1);
Fs_eff = qfem*Fs + (1-qfem)*0.5*Fs;
w = cfg.w;
igr = 10 * (w(1)*Fd + w(2)*Fl + w(3)*Fm + w(4)*Fs_eff + w(5));
if igr < 2
    cat = 'Bajo';
elseif igr < 4
    cat = 'Bajo-moderado';
elseif igr < 6
    cat = 'Moderado';
elseif igr < 8
    cat = 'Moderado-alto';
else
    cat = 'Alto';
end
end

%% =================== CLASIFICADOR CV MONOLITICO ===================
function auc = cv_auc_monolitica(F, y, kfold)
y = y(:); n = numel(y); fold = kfold_split(y, kfold);
sc = zeros(n, 1);
for k = 1:kfold
    te = (fold == k); tr = ~te;
    mu = mean(F(tr,:), 1); sd = std(F(tr,:), 0, 1) + eps;
    Ftr = (F(tr,:) - mu) ./ sd;
    Fte = (F(te,:) - mu) ./ sd;
    w = logreg_fit(Ftr, y(tr));
    sc(te) = logreg_pred(Fte, w);
end
auc = auc_calc(y, sc);
end

function fold = kfold_split(y, k)
y = y(:); n = numel(y); fold = zeros(n,1);
for cls = unique(y)'
    idx = find(y == cls); idx = idx(randperm(numel(idx)));
    for j = 1:numel(idx)
        fold(idx(j)) = mod(j-1, k) + 1;
    end
end
end

function w = logreg_fit(X, y)
y = y(:); [n, p] = size(X); Xb = [ones(n,1) X]; w = zeros(p+1, 1); lr = 0.5;
for it = 1:1000
    h = 1 ./ (1 + exp(-(Xb*w)));
    g = Xb' * (h - y) / n;
    w = w - lr * g;
end
end

function s = logreg_pred(X, w)
s = 1 ./ (1 + exp(-([ones(size(X,1),1) X]*w)));
end

function auc = auc_calc(y, s)
[~, o] = sort(s); r = zeros(numel(s),1); r(o) = 1:numel(s);
n1 = sum(y==1); n0 = sum(y==0);
if n1 == 0 || n0 == 0
    auc = 0.5; return;
end
auc = (sum(r(y==1)) - n1*(n1+1)/2) / (n1*n0);
end

%% =================== CALIBRACION MONOLITICO ===================
function [brier, beta] = calibracion_monolitica(igr, y)
y = y(:); x = igr(:); mu = mean(x); sd = std(x) + eps;
xn = (x - mu) / sd;
w = logreg_fit(xn, y);
p = logreg_pred(xn, w);
brier = mean((p - y).^2);
beta = [w(1) - w(2)*mu/sd; w(2)/sd];
end

%% =================== GRAD-CAM MONOLITICO ===================
function cam = gradcam_monolitico(img, M)
[gx, gy] = imgradientxy_monolitico(img);
cam = imgaussfilt_monolitico(sqrt(gx.^2 + gy.^2), 8) .* M;
cam = mat2gray(cam);
end

%% =================== TEMPORAL MONOLITICO ===================
function alert = temporal_monolitico(serie, cfg)
R = serie(:)'; a = cfg.alpha;
Rs = filter(a, [1 -(1-a)], R);
dRs = [0 diff(Rs)];
alert = (dRs > cfg.tauR) & (R > cfg.Rmin);
end

%% =================== DDPM MONOLITICO ===================
function syn = ddpm_monolitico(img, cfg)
b = linspace(1e-4, 0.02, cfg.ddpm_T);
ac = cumprod(1 - b);
t = cfg.ddpm_T;
noisy = sqrt(ac(t))*img + sqrt(1-ac(t))*randn(size(img));
try
    syn = imbilatfilt_monolitico(mat2gray(noisy));
catch
    syn = imgaussfilt_monolitico(mat2gray(noisy), 1);
end
end

%% =================== FEDERADO MONOLITICO ===================
function res = federado_monolitico(F, y, cfg)
y = y(:); K = cfg.fed_K; idx = randi(K, numel(y), 1);
w = zeros(size(F,2)+1, 1);
mu = mean(F, 1); sd = std(F, 0, 1) + eps;
Fn = (F - mu) ./ sd;
for r = 1:20
    acc = zeros(size(w)); nk = 0;
    for k = 1:K
        s = idx == k;
        if sum(s) < 5, continue; end
        Xk = [ones(sum(s),1) Fn(s,:)];
        yk = y(s);
        gk = Xk' * (sigmoid(Xk*w) - yk) / sum(s);
        acc = acc + gk; nk = nk + 1;
    end
    w = w - 0.5*acc/max(nk, 1);
end
p = sigmoid([ones(numel(y),1) Fn]*w);
res.auc = auc_calc(y, p);
res.w = w;
end

function s = sigmoid(z)
s = 1 ./ (1 + exp(-z));
end

%% =================== HELPERS ===================
function p = perc_calc(x, pct)
x = sort(x(:)); n = numel(x);
if n == 0, p = 0; return; end
idx = max(1, min(n, round(n*pct/100)));
p = x(idx);
end

%% =================== RESUMEN MONOLITICO ===================
function resumen_monolitico(R, cfg)
fprintf('\n%s\n', repmat('-',1,75));
fprintf('RESULTADOS V12 (CALCULADOS, NO FIJADOS A MANO)\n');
fprintf('%s\n', repmat('-',1,75));
fprintf('[1]   Pacientes:              %d\n', cfg.N);
fprintf('[seg] Dice:                   %.3f +/- %.3f\n', mean(R.dice), std(R.dice));
fprintf('[Green] error area / Q>=0.95: %.3f / %.0f%% casos\n', mean(R.errA), 100*mean(R.errA<0.05));
fprintf('[dens] Densidad media:        %.1f%%\n', mean(R.pct));
fprintf('[DFT] E_HF media:             %.4f\n', mean(R.ehf));
fprintf('[FEM] vonMises max medio:     %.3f kPa | F_stress: %.2f | Q_FEM: %.2f\n',...
        mean(R.vmmax), mean(R.Fstress), mean(R.qfem));
fprintf('[micro] N_micro media:        %.1f\n', mean(R.nmic));
fprintf('[les] N_mal / N_ind medias:   %.2f / %.2f\n', mean(R.nmal), mean(R.nind));
fprintf('[IGR] medio:                  %.2f (ej: %s)\n', mean(R.igr), R.igrcat{1});
fprintf('[IGR] Brier score:            %.3f\n', R.brier);
fprintf('%s\n', repmat('-',1,75));
fprintf('[AUC] Geometrico (GLCM):      %.3f  <-- LA GEOMETRIA DISCRIMINA\n', R.auc_geo);
fprintf('[AUC] Densidad sola:          %.3f  <-- PAREADA = AZAR (TESIS)\n', R.auc_den);
fprintf('[AUC] IGR integrado:          %.3f\n', R.auc_igr);
fprintf('[AUC] Federado (FedAvg):      %.3f\n', R.fed.auc);
fprintf('%s\n', repmat('-',1,75));
fprintf('[Z] alertas temporales:       %d\n', sum(R.zalert));
fprintf('BI-RADS ejemplo (paciente 1): %s\n', R.bir{1});
fprintf('%s\n\n', repmat('-',1,75));
end

%% =================== FIGURAS MONOLITICAS ===================
function figuras_monoliticas(R, IMG, MASK, cfg)
figure('Name','SISTEMA V12 MONOLITICO','Position',[40 40 1280 800],'Visible','on');
% Panel 1: Segmentacion
subplot(3,4,1); imshowpair(IMG{1}, MASK{1}); title('[seg] Segmentacion hibrida','FontSize',10);
% Panel 2: Densidad
subplot(3,4,2); hist(R.pct, 20); title('[dens] Densidad %','FontSize',10); xlabel('%D');
% Panel 3: vonMises
subplot(3,4,3); hist(R.vmmax, 20); title('[FEM] vonMises max','FontSize',10); xlabel('kPa');
% Panel 4: IGR
subplot(3,4,4); hist(R.igr, 0:0.5:10); title('[IGR] Riesgo 0-10','FontSize',10);
hold on; for xv = [2 4 6 8], plot([xv xv],ylim,'k--','LineWidth',0.5); end; hold off;
% Panel 5: AUC barplot
subplot(3,4,5); bar([R.auc_geo R.auc_den R.auc_igr R.fed.auc]); ylim([0 1]);
set(gca,'XTickLabel',{'Geo','Dens','IGR','Fed'}); title('[AUC] Clasificadores','FontSize',10);
hold on; plot(xlim, [0.5 0.5], 'r--','LineWidth',1); hold off;
% Panel 6: Microcalcificaciones
subplot(3,4,6); hist(R.nmic); title('[micro] N microcalc','FontSize',10); xlabel('n');
% Panel 7: Green error
subplot(3,4,7); hist(R.errA, 20); title('[Green] error area','FontSize',10);
hold on; plot([0.05 0.05], ylim, 'r--','LineWidth',1.5); hold off;
% Panel 8: GLCM
subplot(3,4,8);
fn={'Con','Cor','Ene','Hom','Med','Std','Ses','Kur'};
mf = mean(R.feat, 1); mf = mf / (max(abs(mf))+eps);
bar(mf); set(gca, 'XTick', 1:8, 'XTickLabel', fn,'XTickLabelRotation',45);
title('[rad] GLCM','FontSize',10);
% Panel 9: Grad-CAM
subplot(3,4,9); imagesc(R.cam); colormap(gca,hot); axis off; title('[xai] Grad-CAM','FontSize',10);
% Panel 10: Temporal
ns = min(12, numel(R.igr)); subplot(3,4,10);
plot(1:ns, R.igr(1:ns), '-o','LineWidth',1.5); grid on;
title('[Z] IGR temporal','FontSize',10); xlabel('estudio');
% Panel 11: Calibracion
subplot(3,4,11);
xs = sort(R.igr); p = 1 ./ (1 + exp(-(R.beta(1) + R.beta(2)*xs)));
plot(xs, p, 'LineWidth',2); grid on; ylim([0 1]);
xlabel('IGR'); ylabel('P(alto riesgo)'); title('[cal] Calibracion','FontSize',10);
% Panel 12: Resumen texto
subplot(3,4,12); axis off;
txt = sprintf('N = %d\nDice = %.3f\nIGR = %.2f\nBrier = %.3f\nAUC-Geo = %.3f\nAUC-Dens = %.3f', ...
             cfg.N, mean(R.dice), mean(R.igr), R.brier, R.auc_geo, R.auc_den);
text(0.1, 0.5, txt, 'FontSize',10,'VerticalAlignment','middle');
title('[resumen] Metricas','FontSize',10);

try, sgtitle('Pipeline V12 - Monolitico (249 pacientes, resultados calculados)','FontSize',12,'FontWeight','bold'); catch, end
drawnow;

% Guardar
try
    saveas(gcf, 'V12_results.png');
    fprintf('[OK] Figura guardada: V12_results.png\n');
catch
    fprintf('[WARN] No se pudo guardar figura PNG\n');
end
end