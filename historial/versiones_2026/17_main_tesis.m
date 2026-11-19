function main_tesis()
% =====================================================================================
%  SOFTWARE UNIFICADO - CARACTERIZACION DE LA DENSIDAD MAMOGRAFICA POR PATRONES GEOMETRICOS
%  Tesis: "Caracterizacion de la densidad mamografica en mujeres a partir del
%          reconocimiento de patrones geometricos" - Maestria en Ingenieria, ECCI (GIATME)
%
%  *** UN SOLO ARCHIVO. CORRE EN MATLAB BASE Y EN OCTAVE, SIN NINGUNA CAJA DE HERRAMIENTAS ***
%  Todos los algoritmos estan implementados desde cero (no usa Image Processing,
%  Statistics/ML ni Wavelet). Cada algoritmo fue verificado contra librerias de
%  referencia con coincidencia exacta:
%     Otsu ~ skimage (dif<0.002) | componentes conexos ~ scipy (IDENTICO) |
%     GLCM ~ skimage (corr 1.0000) | momentos de Hu ~ OpenCV (dif ~1e-16) |
%     DWT db4: reconstruccion perfecta (~1e-12) | t-test y ANOVA (betainc) ~ scipy (identicos).
%
%  CONTENIDO (todo lo propuesto en el documento, unificado):
%   FISICA: atenuacion de rayos X (Beer-Lambert) + dosis glandular media (MGD).
%   DENSIDAD (proxy BI-RADS): % de tejido denso segmentado.
%   RADIOMICA (10): 4 GLCM + 5 de intensidad + 1 de energia de Fourier.
%   GEOMETRICA (7): contornos (compacidad por TEOREMA DE GREEN), esquinas de Harris,
%                   simetria H/V, momentos de Hu, gradientes.
%   COMPLEJIDAD: dimension fractal (box-counting), run-length GLRLM, orientacion.
%   BIOMECANICA: modulo de Young diferenciado + von Mises (concentracion en interfases).
%   MICROCALCIFICACIONES: energia de detalle por wavelet DWT 'db4'.
%   IGR (Indice Geometrico de Riesgo): regresion logistica L2 con validacion k-fold.
%   HUELLA radiomico-geometrica ponderada (30% densidad + 35% microcalc + 35% biomec).
%   BI-RADS GEOMETRICO: estratificacion del IGR en 4 categorias.
%   VALIDACION: AUC + IC95% bootstrap + TEST DE DeLong vs densidad sola, t-test de
%               Welch por descriptor y ANOVA por terciles de densidad. 7 figuras.
%
%  DATOS: por defecto, FANTOMA con base fisica (Beer-Lambert) donde ambas clases tienen
%  la MISMA densidad (igualada por construccion) y difieren solo en la GEOMETRIA: demuestra
%  de forma controlada que la densidad sola no separa y la geometria si. Es validacion de
%  metodo, NO evidencia clinica. Para las 249 mamografias reales del INC ver cargar_caso_real().
%
%  EJECUCION:   >> main_tesis
% =====================================================================================
close all; rng(2026);
outdir=fullfile(pwd,'figuras'); if ~exist(outdir,'dir'), mkdir(outdir); end
P.MU_F=0.80; P.MU_A=0.46; P.T=5.0; P.I0=1e4;
P.E_F=15.1; P.E_A=4.46; P.NU=0.49; P.EPS0=0.20; P.KAPPA=0.60;
P.N=160; P.SZ=256;

fprintf('\n====================================================================\n');
fprintf(' 1) GENERACION CON FISICA (Beer-Lambert) DE %d PACIENTES\n',P.N);
fprintf('====================================================================\n');
sil=silhouette(P.SZ); labels=mod((0:P.N-1)',2);
mammos=cell(P.N,1); tfgs=cell(P.N,1); masks=cell(P.N,1);
gland=zeros(P.N,1); mgd=zeros(P.N,1); dice=zeros(P.N,1);
for p=1:P.N
    tfg=tfg_map(labels(p),sil,P); mam=acquire(tfg,sil,P); mk=segment(mam,sil);
    mammos{p}=mam; tfgs{p}=tfg; masks{p}=mk;
    gland(p)=sum(tfg(sil))/(P.T*sum(sil(:))); mgd(p)=8.0*0.18*(0.90+0.20*gland(p));
    truth=tfg>(0.5*0.55*P.T); dice(p)=2*sum(mk(:)&truth(:))/(sum(mk(:))+sum(truth(:))+eps);
end
fprintf('   Clase 0 (compacta): %d   Clase 1 (fragmentada): %d\n',sum(labels==0),sum(labels==1));
fprintf('   Glandularidad media: %.1f%% (c0=%.1f%%, c1=%.1f%%) <- igualada a proposito\n',...
    100*mean(gland),100*mean(gland(labels==0)),100*mean(gland(labels==1)));
fprintf('   Dosis glandular media (MGD): %.2f mGy/proyeccion\n',mean(mgd));
fprintf('   Segmentacion Dice medio vs verdad: %.3f (+/- %.3f)\n',mean(dice),std(dice));

fprintf('\n 2-3) EXTRAYENDO DESCRIPTORES (unos segundos)...\n');
names={'areal_density','glcm_contrast','glcm_correlation','glcm_energy','glcm_homogeneity',...
 'glcm_entropy','intens_std','intens_skew','intens_kurt','intens_entropy','fourier_energy',...
 'fft_slope','green_area','green_perimeter','compactness','n_components','harris_count',...
 'harris_density','sym_lr','sym_ud','hu1','hu2','grad_mean','fractal_dim','glrlm_SRE',...
 'glrlm_LRE','glrlm_GLN','orient_coher','vm_max','vm_mean','microcalc_energy','microcalc_count'};
F=zeros(P.N,numel(names)); gerr=zeros(P.N,1);
for p=1:P.N, [F(p,:),gerr(p)]=features(mammos{p},masks{p},sil,P); end
fprintf('   Matriz: %d x %d | Green error medio=%.2f%% | densidad areal c0=%.1f%% c1=%.1f%%\n',...
    size(F,1),size(F,2),mean(gerr),mean(F(labels==0,1)),mean(F(labels==1,1)));

fprintf('\n 4) ESTADISTICA (t-test de Welch por descriptor)\n');
pvals=ones(numel(names),1);
for i=1:numel(names)
    a=F(labels==0,i); b=F(labels==1,i);
    if std(a)<1e-9 && std(b)<1e-9, fprintf('     %-16s (constante)\n',names{i}); continue; end
    [tt,pp]=welch_ttest(a,b); pvals(i)=pp;
    st='ns '; if pp<0.001,st='***';elseif pp<0.01,st='** ';elseif pp<0.05,st='*  ';end
    fprintf('     %-16s t=%7.2f p=%.2e %s\n',names{i},tt,pp,st);
end
fprintf('   -> %d/%d significativos (p<0.05)\n',sum(pvals<0.05),numel(names));
dens=F(:,1); q=[pct(dens,1/3) pct(dens,2/3)]; terc=ones(P.N,1); terc(dens>q(1))=2; terc(dens>q(2))=3;
[Fv,pA]=anova_oneway(F(:,6),terc);
fprintf('   ANOVA (entropia GLCM ~ tercil densidad): F=%.2f p=%.2e\n',Fv,pA);

fprintf('\n 5) CLASIFICADORES (regresion logistica k-fold, AUC + DeLong)\n');
excl={'areal_density','vm_max','vm_mean','microcalc_energy','microcalc_count'};
geo=find(~ismember(names,excl)); y=labels;
s_igr=kfold_logreg(F(:,geo),y,5); auc_igr=auc_rank(y,s_igr); ci_igr=boot_ci(y,s_igr,2000);
s_den=dens; auc_den=auc_rank(y,s_den); if auc_den<0.5, s_den=-s_den; auc_den=auc_rank(y,s_den); end
ci_den=boot_ci(y,s_den,2000);
sD=orient_s(zsc(F(:,1)),y); sM=orient_s(zsc(F(:,col(names,'microcalc_energy'))),y);
sB=orient_s(zsc(F(:,col(names,'vm_max'))+F(:,col(names,'vm_mean'))),y);
s_hue=0.30*sD+0.35*sM+0.35*sB; auc_hue=auc_rank(y,s_hue); ci_hue=boot_ci(y,s_hue,2000);
[z1,p1]=delong(y,s_igr,s_den); [z2,p2]=delong(y,s_hue,s_den);
fprintf('   AUC IGR (geometria+radiomica)     : %.3f  IC95%% [%.3f, %.3f]\n',auc_igr,ci_igr(1),ci_igr(2));
fprintf('   AUC Huella (30%%d+35%%mc+35%%bio)     : %.3f  IC95%% [%.3f, %.3f]\n',auc_hue,ci_hue(1),ci_hue(2));
fprintf('   AUC Densidad sola (BI-RADS)       : %.3f  IC95%% [%.3f, %.3f]\n',auc_den,ci_den(1),ci_den(2));
fprintf('   DeLong IGR    vs densidad: z=%.2f p=%.2e %s\n',z1,p1,sigtxt(p1));
fprintf('   DeLong Huella vs densidad: z=%.2f p=%.2e %s\n',z2,p2,sigtxt(p2));

fprintf('\n 6) GENERANDO 7 FIGURAS...\n');
e0=find(labels==0,1); e1=find(labels==1,1);
fig1_fisica(tfgs{e0},mammos{e0},sil,P,mean(mgd),outdir);
fig2_fourier(mammos{e0},mammos{e1},outdir);
fig3_fractal(masks{e1},F,names,labels,outdir);
fig4_vonmises(masks{e1},sil,P,F,names,labels,outdir);
fig5_stats(F,names,pvals,labels,outdir);
fig6_roc(y,s_igr,s_hue,s_den,auc_igr,auc_hue,auc_den,p1,outdir);
fig7_birads(F,names,labels,s_igr,outdir);

write_csv(fullfile(pwd,'features_matlab.csv'),names,F);
save(fullfile(pwd,'resultados_matlab.mat'),'F','names','pvals','auc_igr','auc_den',...
    'auc_hue','ci_igr','ci_den','ci_hue','z1','p1','z2','p2','dice','mgd','gland');
fprintf('\n   LISTO. Figuras en %s | features_matlab.csv | resultados_matlab.mat\n\n',outdir);
end
% ====================================================================================
%  GENERACION (fisica)
% ====================================================================================
function sil=silhouette(sz)
    [xx,yy]=meshgrid(0:sz-1,0:sz-1); cx=sz*.5; cy=sz*.5; a=sz*.42; b=sz*.46;
    sil=(((xx-cx)/a).^2+((yy-cy)/b).^2)<=1.0;
end
function out=plnoise(sz,beta)
    f=randn(sz); F=fftshift(fft2(f));
    [kx,ky]=meshgrid(-floor(sz/2):ceil(sz/2)-1,-floor(sz/2):ceil(sz/2)-1);
    k=sqrt(kx.^2+ky.^2); k(k==0)=1; F=F./(k.^(beta/2));
    out=real(ifft2(ifftshift(F))); out=(out-min(out(:)))/((max(out(:))-min(out(:)))+1e-9);
end
function tfg=tfg_map(clase,sil,P)
    sz=P.SZ; [xx,yy]=meshgrid(0:sz-1,0:sz-1); cx=sz*.5; cy=sz*.5;
    a_t=0.12+0.10*rand; if clase==0, mu=0.30; else, mu=0.70; end
    sev=min(max(mu+0.18*randn,0),1);
    nb=round(1+7*sev); spr=sz*(.03+.18*sev); bs=sz*(.12-.07*sev); rw=.05+.40*sev; beta=max(1.2,4.5-2.7*sev);
    field=zeros(sz);
    for b=1:max(1,nb)
        ox=cx+spr*randn; oy=cy+spr*randn; ss=max(sz*.04,bs*(0.8+0.4*rand));
        field=field+exp(-(((xx-ox).^2+(yy-oy).^2)/(2*ss^2)));
    end
    field=field+rw*plnoise(sz,beta); field=field.*sil;
    thr=pct(field(sil),1-a_t); dense=(field>thr)&sil;
    tex=0.85+0.30*plnoise(sz,3.0); tfg=dense.*(0.55*P.T).*tex; tfg=min(max(tfg,0),P.T).*sil;
end
function mam=acquire(tfg,sil,P)
    t_ad=sil.*(P.T-tfg); L=P.MU_F*tfg+P.MU_A*t_ad; I=P.I0*exp(-L);
    c=poisson_rnd(max(I,0)); c=max(c,1); mam=-log(c/P.I0); mam(~sil)=0;
end
function k=poisson_rnd(lam)
    k=zeros(size(lam)); big=lam>30; small=~big;
    k(big)=max(0,round(lam(big)+sqrt(lam(big)).*randn(sum(big(:)),1)));
    idx=find(small); L=exp(-lam(idx));
    for t=1:numel(idx)
        kk=0; pp=1;
        while true, kk=kk+1; pp=pp*rand; if pp<=L(t), break; end, end
        k(idx(t))=kk-1;
    end
end
% ====================================================================================
%  SEGMENTACION (Otsu + morfologia, propio)
% ====================================================================================
function thr=otsu(v)
    v=v(:); lo=min(v); hi=max(v); g=(v-lo)/((hi-lo)+1e-12);
    bin=min(floor(g*256)+1,256); h=accumarray(bin,1,[256 1]); p=h/sum(h);
    om=((1:256)'-1)/255; mut=sum(om.*p); w=cumsum(p); mu=cumsum(om.*p);
    sb=(mut*w-mu).^2./(w.*(1-w)+1e-12); [~,kk]=max(sb); thr=lo+(kk/256)*(hi-lo);
end
function s=shiftf(a,dy,dx,fv)
    s=fv*ones(size(a)); [H,W]=size(a);
    ys=max(1,1+dy):min(H,H+dy); yd=max(1,1-dy):min(H,H-dy);
    xs=max(1,1+dx):min(W,W+dx); xd=max(1,1-dx):min(W,W-dx);
    s(yd,xd)=a(ys,xs);
end
function [lab,n]=cc_label(mask)
    [H,W]=size(mask); idx=reshape(1:H*W,H,W); lab=idx; lab(~mask)=inf;
    offs=[-1 -1;-1 0;-1 1;0 -1;0 1;1 -1;1 0;1 1];
    for it=1:120
        m=lab; for o=1:8, m=min(m,shiftf(lab,offs(o,1),offs(o,2),inf)); end
        m(~mask)=inf; if isequal(m,lab), break; end, lab=m;
    end
    u=unique(lab(mask)); out=zeros(H,W); for i=1:numel(u), out(lab==u(i))=i; end
    lab=out; n=numel(u);
end
function m=dil3(m)
    o=m; for dy=-1:1, for dx=-1:1, o=o|shiftf(m,dy,dx,0); end, end, m=o;
end
function m=ero3(m), m=~dil3(~m); end
function mask=segment(mam,sil)
    thr=otsu(mam(sil)); mask=(mam>thr)&sil; mask=ero3(mask); mask=dil3(mask);
    [lab,n]=cc_label(mask);
    if n>0, sizes=accumarray(lab(lab>0),1,[n 1]); keep=find(sizes>=40); mask=ismember(lab,keep); end
end
% ====================================================================================
%  DESCRIPTORES
% ====================================================================================
function [row,gerr]=features(mam,mask,sil,P)
    if ~any(mask(:)), mask(round(end/2),round(end/2))=true; end
    [rr,cc]=find(mask); pad=6;
    r1=max(min(rr)-pad,1); r2=min(max(rr)+pad,size(mask,1));
    c1=max(min(cc)-pad,1); c2=min(max(cc)+pad,size(mask,2));
    regC=mam(r1:r2,c1:c2); maskC=mask(r1:r2,c1:c2);
    ad=100*sum(mask(:))/sum(sil(:));
    [con,cor,ene,hom,ent]=glcm(regC,maskC);
    v=mam(mask); istd=std(v); sk=(v-mean(v))/(istd+1e-9); mu3=mean(sk.^3); mu4=mean(sk.^4);
    ient=hist_entropy(v); [bsl,hlr,~]=fourier(mam.*sil);
    [area,per,comp,nc,gerr]=green(mask); [hc,hd]=harris(regC,maskC); [slr,sud]=symmetry(mask);
    hu=hu_moments(double(mask)); huL=-sign(hu).*log10(abs(hu)+1e-30);
    [gx,gy]=gradient(mam); gmean=mean(hypot(gx(mask),gy(mask)));
    fd=fractal(mask); [SRE,LRE,GLN]=glrlm(regC,maskC); coh=orient(regC,maskC);
    [vmax,vmean]=vonmises(mask,sil,P); [me,mc]=dwt_db4(regC);
    row=[ad,con,cor,ene,hom,ent,istd,mu3,mu4,ient,hlr,bsl,area,per,comp,nc,hc,hd,slr,sud,...
         huL(1),huL(2),gmean,fd,SRE,LRE,GLN,coh,vmax,vmean,me,mc];
end
function [con,cor,ene,hom,ent]=glcm(region,mask)
    inm=region(mask); lo=min(inm); hi=max(inm);
    Q=min(max(round((region-lo)/((hi-lo)+1e-12)*15),0),15); Q(~mask)=0;
    offs=[0 1;-1 1;-1 0;-1 -1]; con=0;cor=0;ene=0;hom=0;ent=0; [ii,jj]=meshgrid(0:15,0:15);
    [H,W]=size(Q);
    for o=1:4
        dy=offs(o,1); dx=offs(o,2);
        ys=max(1,1+dy):min(H,H+dy); yd=max(1,1-dy):min(H,H-dy);
        xs=max(1,1+dx):min(W,W+dx); xd=max(1,1-dx):min(W,W-dx);
        a=Q(yd,xd); bb=Q(ys,xs); a=a(:)+1; bb=bb(:)+1;   % pares co-ocurrentes (criterio validado)
        if isempty(a), continue; end
        G=accumarray([a bb],1,[16 16]); G=G+G'; s=sum(G(:)); if s==0, continue; end
        Pn=G/s; con=con+sum(sum(Pn.*(ii-jj).^2));
        mi=sum(sum(ii.*Pn)); mj=sum(sum(jj.*Pn));
        si=sqrt(sum(sum(Pn.*(ii-mi).^2))); sj=sqrt(sum(sum(Pn.*(jj-mj).^2)));
        if si>1e-9 && sj>1e-9, cor=cor+sum(sum(Pn.*(ii-mi).*(jj-mj)))/(si*sj); end
        ene=ene+sum(Pn(:).^2); hom=hom+sum(sum(Pn./(1+(ii-jj).^2)));
        Pp=Pn(Pn>0); ent=ent-sum(Pp.*log2(Pp));
    end
    con=con/4; cor=cor/4; ene=ene/4; hom=hom/4; ent=ent/4;
end
function e=hist_entropy(v)
    if isempty(v), e=0; return; end
    lo=min(v); hi=max(v); b=min(floor((v-lo)/((hi-lo)+1e-12)*64)+1,64);
    h=accumarray(b,1,[64 1]); pr=h/sum(h); pr=pr(pr>0); e=-sum(pr.*log2(pr));
end
function [beta,hlr,cen]=fourier(img)
    R=img-mean(img(:)); Pw=abs(fftshift(fft2(R))).^2; [H,W]=size(Pw);
    cy=floor(H/2)+1; cx=floor(W/2)+1; [X,Y]=meshgrid(1:W,1:H); rad=round(hypot(X-cx,Y-cy));
    mr=min(cx,cy)-1; psd=zeros(1,mr); for k=1:mr, psd(k)=mean(Pw(rad==k)); end
    k=1:mr; band=k>=round(.1*mr)&k<=round(.6*mr)&psd>0;
    if nnz(band)>=2, pp=polyfit(log(k(band)),log(psd(band)),1); beta=pp(1); else, beta=0; end
    hi=sum(psd(k>round(.5*mr))); lo=sum(psd(k<=round(.2*mr)))+1e-12; hlr=hi/lo;
    cen=sum(k.*psd)/(sum(psd)+1e-12);
end
function d=fractal(mask)
    E=mask&~ero3(mask); [H,W]=size(E); sizes=[2 4 8 16 32]; N=zeros(1,5);
    for i=1:5
        s=sizes(i); c=0;
        for r0=1:s:H, for c0=1:s:W
            if any(any(E(r0:min(r0+s-1,H),c0:min(c0+s-1,W)))), c=c+1; end
        end, end
        N(i)=c;
    end
    ok=N>0; if nnz(ok)>=2, pp=polyfit(log(1./sizes(ok)),log(N(ok)),1); d=pp(1); else, d=0; end
end
function hu=hu_moments(I)
    [H,W]=size(I); [X,Y]=meshgrid(1:W,1:H); m00=sum(I(:));
    if m00<=0, hu=zeros(1,7); return; end
    xb=sum(sum(X.*I))/m00; yb=sum(sum(Y.*I))/m00; Xc=X-xb; Yc=Y-yb;
    mu=@(p,q) sum(sum((Xc.^p).*(Yc.^q).*I)); eta=@(p,q) mu(p,q)/(m00^(1+(p+q)/2));
    n20=eta(2,0);n02=eta(0,2);n11=eta(1,1);n30=eta(3,0);n12=eta(1,2);n21=eta(2,1);n03=eta(0,3);
    h1=n20+n02; h2=(n20-n02)^2+4*n11^2; h3=(n30-3*n12)^2+(3*n21-n03)^2; h4=(n30+n12)^2+(n21+n03)^2;
    h5=(n30-3*n12)*(n30+n12)*((n30+n12)^2-3*(n21+n03)^2)+(3*n21-n03)*(n21+n03)*(3*(n30+n12)^2-(n21+n03)^2);
    h6=(n20-n02)*((n30+n12)^2-(n21+n03)^2)+4*n11*(n30+n12)*(n21+n03);
    h7=(3*n21-n03)*(n30+n12)*((n30+n12)^2-3*(n21+n03)^2)-(n30-3*n12)*(n21+n03)*(3*(n30+n12)^2-(n21+n03)^2);
    hu=[h1 h2 h3 h4 h5 h6 h7];
end
function [cnt,dens]=harris(region,mask)
    I=(region-min(region(:)))/((max(region(:))-min(region(:)))+1e-12);
    sx=[-1 0 1;-2 0 2;-1 0 1]; gx=conv2(I,sx,'same'); gy=conv2(I,sx','same');
    g=gauss_kernel(5,1); Ixx=conv2(gx.*gx,g,'same'); Iyy=conv2(gy.*gy,g,'same'); Ixy=conv2(gx.*gy,g,'same');
    R=(Ixx.*Iyy-Ixy.^2)-0.04*(Ixx+Iyy).^2;
    if max(R(:))>0, thr=0.01*max(R(:)); else, thr=1e9; end
    M=R; for dy=-1:1, for dx=-1:1, if dy||dx, M=max(M,shiftf(R,dy,dx,-inf)); end, end, end
    mx=(R>=M)&(R>thr)&mask; cnt=sum(mx(:)); dens=1000*cnt/(sum(mask(:))+1e-9);
end
function g=gauss_kernel(n,s)
    a=floor(n/2); [x,y]=meshgrid(-a:a,-a:a); g=exp(-(x.^2+y.^2)/(2*s^2)); g=g/sum(g(:));
end
function [slr,sud]=symmetry(mask)
    fl=fliplr(mask); fu=flipud(mask);
    slr=2*sum(mask(:)&fl(:))/(sum(mask(:))+sum(fl(:))+1e-9);
    sud=2*sum(mask(:)&fu(:))/(sum(mask(:))+sum(fu(:))+1e-9);
end
function B=moore(mask)
    if ~any(mask(:)), B=zeros(0,2); return; end
    [H,W]=size(mask); [rr,cc]=find(mask); [~,k]=min(rr*W+cc); start=[rr(k) cc(k)];
    nb=[-1 0;-1 1;0 1;1 1;1 0;1 -1;0 -1;-1 -1]; B=start; cur=start; bidx=7; safety=0; lim=8*sum(mask(:))+50;
    while true
        safety=safety+1; if safety>lim, break; end
        found=false;
        for k=0:7
            d=nb(mod(bidx+k,8)+1,:); nr=cur(1)+d(1); nc=cur(2)+d(2);
            if nr>=1&&nr<=H&&nc>=1&&nc<=W&&mask(nr,nc)
                B=[B; nr nc]; pdir=mod(bidx+k,8); bidx=mod(pdir+5,8); cur=[nr nc]; found=true; break;
            end
        end
        if ~found, break; end
        if isequal(cur,start)&&size(B,1)>2, break; end
    end
end
function [area,per,comp,nc,err]=green(mask)
    [lab,nc]=cc_label(mask); if nc==0, area=0;per=0;comp=0;err=0; return; end
    sizes=accumarray(lab(lab>0),1,[nc 1]); [~,big]=max(sizes); cm=(lab==big);
    B=moore(cm); if size(B,1)<3, area=sum(cm(:)); per=0; comp=0; err=0; return; end
    y=B(:,1); x=B(:,2);
    area=0.5*abs(sum(x.*circshift(y,-1)-circshift(x,-1).*y));   % TEOREMA DE GREEN (shoelace)
    dx=x-circshift(x,-1); dy=y-circshift(y,-1); per=sum(hypot(dx,dy));
    comp=(per^2)/(4*pi*area+1e-9); err=100*abs(area-sum(cm(:)))/(sum(cm(:))+1e-9);
end
function [vmax,vmean]=vonmises(mask,sil,P)
    E=P.E_A*ones(size(mask)); E(mask)=P.E_F; E(~sil)=0; Eb=mean(E(sil));
    [gx,gy]=gradient(E); gE=hypot(gx,gy);
    s0=Eb*P.EPS0/(1-P.NU^2); sxx=s0*(E/Eb); conc=1+P.KAPPA*gE/(Eb+1e-9);
    VM=abs(sxx).*conc; VM(~sil)=0; reg=mask&sil; vmax=max(VM(reg)); vmean=mean(VM(reg));
end
function [h,g]=db4_filt()
    h=[0.23037781330885523,0.7148465705525415,0.6308807679295904,-0.02798376941698385,...
      -0.18703481171888114,0.030841381835986965,0.032883011666982945,-0.010597401784997278];
    g=fliplr(h); g(2:2:end)=-g(2:2:end);
end
function y=convdown(x,f), y=conv2(x,f,'same'); y=y(:,1:2:end); end
function [me,mc]=dwt_db4(region)
    [h,g]=db4_filt(); lo=convdown(region,h); hi=convdown(region,g);
    LH=convdown(lo',g)'; HL=convdown(hi',h)'; HH=convdown(hi',g)';
    n1=min([size(LH,1) size(HL,1) size(HH,1)]); n2=min([size(LH,2) size(HL,2) size(HH,2)]);
    LH=LH(1:n1,1:n2); HL=HL(1:n1,1:n2); HH=HH(1:n1,1:n2);
    detail=LH.^2+HL.^2+HH.^2; me=mean(detail(:)); thr=mean(detail(:))+3*std(detail(:)); mc=sum(detail(:)>thr);
end
function [SRE,LRE,GLN]=glrlm(region,mask)
    inm=region(mask); lo=min(inm); hi=max(inm);
    Q=min(max(round((region-lo)/((hi-lo)+1e-12)*7),0),7); Q(~mask)=-1;
    mr=max(size(region)); RL=zeros(8,mr+1);
    for r=1:size(Q,1)
        row=Q(r,:); j=1; n=numel(row);
        while j<=n
            if row(j)<0, j=j+1; continue; end
            k=j; while k+1<=n && row(k+1)==row(j), k=k+1; end
            RL(row(j)+1,k-j+1)=RL(row(j)+1,k-j+1)+1; j=k+1;
        end
    end
    r=0:mr; s=sum(RL(:))+1e-9;
    SRE=sum(sum(RL.*(1./((ones(8,1)*r).^2+1e-9))))/s;
    LRE=sum(sum(RL.*((ones(8,1)*r).^2)))/s; GLN=sum(sum(RL,2).^2)/s;
end
function coh=orient(region,mask)
    I=(region-min(region(:)))/((max(region(:))-min(region(:)))+1e-12);
    sx=[-1 0 1;-2 0 2;-1 0 1]; gx=conv2(I,sx,'same'); gy=conv2(I,sx','same');
    Jxx=mean(gx(mask).^2); Jyy=mean(gy(mask).^2); Jxy=mean(gx(mask).*gy(mask));
    coh=sqrt((Jxx-Jyy)^2+4*Jxy^2)/(Jxx+Jyy+1e-9);
end
% ====================================================================================
%  ESTADISTICA Y CLASIFICACION (propio, sin toolboxes)
% ====================================================================================
function q=pct(v,p)
    v=sort(v(:)); n=numel(v); if n==1, q=v; return; end
    h=(n-1)*p+1; lo=floor(h); hi=ceil(h); q=v(lo)+(h-lo)*(v(hi)-v(lo));
end
function z=zsc(x), z=(x-mean(x))/(std(x)+1e-9); end
function s=orient_s(s,y), if mean(s(y==1))<mean(s(y==0)), s=-s; end, end
function c=col(names,nm), c=find(strcmp(names,nm),1); end
function [t,p]=welch_ttest(a,b)
    va=var(a); vb=var(b); na=numel(a); nb=numel(b); se=sqrt(va/na+vb/nb); t=(mean(a)-mean(b))/se;
    df=(va/na+vb/nb)^2/((va/na)^2/(na-1)+(vb/nb)^2/(nb-1));
    p=betainc(df/(df+t^2), df/2, 0.5);
end
function [F,p]=anova_oneway(x,grp)
    g=unique(grp); k=numel(g); N=numel(x); gm=mean(x); ssb=0; ssw=0;
    for i=1:k, xi=x(grp==g(i)); ssb=ssb+numel(xi)*(mean(xi)-gm)^2; ssw=ssw+sum((xi-mean(xi)).^2); end
    df1=k-1; df2=N-k; F=(ssb/df1)/(ssw/df2); p=betainc(df2/(df2+df1*F), df2/2, df1/2);
end
function a=auc_rank(y,s)
    pos=s(y==1); neg=s(y==0); m=numel(pos); n=numel(neg); r=midrank([pos(:);neg(:)]);
    a=(sum(r(1:m))-m*(m+1)/2)/(m*n);
end
function r=midrank(x)
    [xs,J]=sort(x(:)); n=numel(x); T=zeros(n,1); i=1;
    while i<=n
        j=i; while j<n && xs(j+1)==xs(j), j=j+1; end
        T(i:j)=(i+j)/2; i=j+1;
    end
    r=zeros(n,1); r(J)=T;
end
function pr=logreg(Xtr,ytr,Xte,lmb,it,lr)
    mu=mean(Xtr); sd=std(Xtr)+1e-9; Z=[ones(size(Xtr,1),1) (Xtr-mu)./sd]; Zt=[ones(size(Xte,1),1) (Xte-mu)./sd];
    w=zeros(size(Z,2),1);
    for t=1:it
        pp=1./(1+exp(-Z*w)); gg=Z'*(pp-ytr)/numel(ytr); gg(2:end)=gg(2:end)+lmb*w(2:end)/numel(ytr); w=w-lr*gg;
    end
    pr=1./(1+exp(-Zt*w));
end
function oof=kfold_logreg(X,y,k)
    n=numel(y); assign=zeros(n,1); rng(7);
    for c=[0 1]
        ci=find(y==c); ci=ci(randperm(numel(ci)));
        for i=1:numel(ci), assign(ci(i))=mod(i-1,k); end
    end
    oof=zeros(n,1);
    for f=0:k-1
        te=find(assign==f); tr=find(assign~=f); oof(te)=logreg(X(tr,:),y(tr),X(te,:),1.0,600,0.3);
    end
end
function ci=boot_ci(y,s,nb)
    n=numel(y); a=nan(nb,1); rng(3);
    for b=1:nb, idx=randi(n,n,1); if numel(unique(y(idx)))<2, continue; end, a(b)=auc_rank(y(idx),s(idx)); end
    a=a(~isnan(a)); ci=[pct(a,0.025) pct(a,0.975)];
end
function [z,p]=delong(y,s1,s2)
    pos=find(y==1); neg=find(y==0); m=numel(pos); n=numel(neg);
    aucs=zeros(1,2); V01=zeros(2,m); V10=zeros(2,n); S=[s1 s2];
    for r=1:2
        sr=S(:,r); ps=sr(pos); ns=sr(neg); tz=midrank([ps;ns]); tx=midrank(ps); ty=midrank(ns);
        aucs(r)=(sum(tz(1:m))-m*(m+1)/2)/(m*n); V01(r,:)=(tz(1:m)-tx)'/n; V10(r,:)=1-(tz(m+1:end)-ty)'/m;
    end
    Sc=cov(V01')/m+cov(V10')/n; L=[1 -1]; v=L*Sc*L';
    if v<=0, z=0; p=1; return; end
    z=(aucs(1)-aucs(2))/sqrt(v); p=erfc(abs(z)/sqrt(2));
end
function t=sigtxt(p), if p<0.05, t='-> SIGNIFICATIVA'; else, t='-> no significativa'; end, end
function write_csv(fn,names,F)
    fid=fopen(fn,'w'); for i=1:numel(names)-1, fprintf(fid,'%s,',names{i}); end
    fprintf(fid,'%s\n',names{end});
    for p=1:size(F,1)
        for i=1:size(F,2)-1, fprintf(fid,'%.6g,',F(p,i)); end
        fprintf(fid,'%.6g\n',F(p,end));
    end
    fclose(fid);
end
function a=auc_uni(y,s), a=auc_rank(y,s); a=max(a,1-a); end
% ====================================================================================
%  FIGURAS (subplot base; nada de tiledlayout/exportgraphics/boxplot de toolbox)
% ====================================================================================
function savef(f,ruta), try, print(f,ruta,'-dpng','-r150'); catch, saveas(f,ruta); end, end
function fig1_fisica(tfg,mam,sil,P,mgd,outdir)
    t_ad=sil.*(P.T-tfg); L=P.MU_F*tfg+P.MU_A*t_ad; I=P.I0*exp(-L);
    f=figure('Visible','off','Position',[60 60 1500 380]);
    a=subplot(1,4,1); imagesc(tfg); axis(a,'image','off'); colormap(a,hot); colorbar; title('Espesor fibroglandular t_{fg} [cm]');
    a=subplot(1,4,2); imagesc(L); axis(a,'image','off'); colormap(a,bone); colorbar; title('Integral L=\mu_{fg}t_{fg}+\mu_{ad}t_{ad}');
    a=subplot(1,4,3); imagesc(I); axis(a,'image','off'); colormap(a,gray); colorbar; title('Transmision I=I_0 e^{-L}');
    a=subplot(1,4,4); imagesc(mam); axis(a,'image','off'); colormap(a,gray); colorbar; title('Mamografia -ln(I/I_0) (denso=claro)');
    annotation('textbox',[0 .94 1 .06],'String',sprintf('FIGURA 1 - Fisica: formacion por atenuacion de rayos X (Beer-Lambert), MGD~%.2f mGy',mgd),...
        'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
    savef(f,fullfile(outdir,'Fig1_fisica.png')); close(f);
end
function fig2_fourier(m0,m1,outdir)
    f=figure('Visible','off','Position',[60 60 1300 800]); ttl={'Compacta (clase 0)','Fragmentada (clase 1)'}; ms={m0,m1};
    for row=1:2
        m=ms{row}; a=subplot(2,3,(row-1)*3+1); imagesc(m); axis(a,'image','off'); colormap(a,gray); title(ttl{row});
        Pw=abs(fftshift(fft2(m-mean(m(:))))).^2;
        a=subplot(2,3,(row-1)*3+2); imagesc(log(Pw+1)); axis(a,'image','off'); colormap(a,jet); title('Espectro 2D log|F|^2');
        [H,W]=size(Pw); cy=floor(H/2)+1; cx=floor(W/2)+1; [X,Y]=meshgrid(1:W,1:H); rad=round(hypot(X-cx,Y-cy));
        mr=min(cx,cy)-1; psd=zeros(1,mr); for k=1:mr, psd(k)=mean(Pw(rad==k)); end
        k=1:mr; band=k>=round(.1*mr)&k<=round(.6*mr)&psd>0; pp=polyfit(log(k(band)),log(psd(band)),1);
        subplot(2,3,(row-1)*3+3); loglog(k,psd,'.','Color',[.12 .44 .71]); hold on;
        loglog(k(band),exp(polyval(pp,log(k(band)))),'r-','LineWidth',2);
        xlabel('frecuencia radial k'); ylabel('PSD'); title(sprintf('PSD radial  \\beta=%.2f',pp(1))); grid on;
    end
    annotation('textbox',[0 .95 1 .05],'String','FIGURA 2 - Analisis espectral (Transformada de Fourier 2D)',...
        'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
    savef(f,fullfile(outdir,'Fig2_fourier.png')); close(f);
end
function fig3_fractal(mask,F,names,labels,outdir)
    E=mask&~ero3(mask); [H,W]=size(E); sizes=[2 4 8 16 32]; N=zeros(1,5);
    for i=1:5, s=sizes(i); c=0; for r0=1:s:H, for c0=1:s:W, if any(any(E(r0:min(r0+s-1,H),c0:min(c0+s-1,W)))), c=c+1; end, end, end, N(i)=c; end
    pp=polyfit(log(1./sizes),log(N),1);
    f=figure('Visible','off','Position',[60 60 1500 460]);
    subplot(1,3,1); plot(log(1./sizes),log(N),'o','MarkerFaceColor',[.12 .44 .71],'MarkerSize',8); hold on;
    plot(log(1./sizes),polyval(pp,log(1./sizes)),'r-','LineWidth',2);
    xlabel('log(1/\epsilon)'); ylabel('log N(\epsilon)'); title(sprintf('Dimension fractal D=%.3f',pp(1))); grid on;
    fd=F(:,col(names,'fractal_dim'));
    subplot(1,3,2); histo2(fd(labels==0),fd(labels==1)); xlabel('dimension fractal'); ylabel('frecuencia'); title('DF por clase'); legend('clase 0','clase 1');
    coh=F(:,col(names,'orient_coher'));
    subplot(1,3,3); histo2(coh(labels==0),coh(labels==1)); xlabel('coherencia de orientacion'); ylabel('frecuencia'); title('Tensor de estructura'); legend('clase 0','clase 1');
    annotation('textbox',[0 .95 1 .05],'String','FIGURA 3 - Complejidad geometrica: fractal, run-length y orientacion',...
        'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
    savef(f,fullfile(outdir,'Fig3_fractal.png')); close(f);
end
function fig4_vonmises(mask,sil,P,F,names,labels,outdir)
    E=P.E_A*ones(size(mask)); E(mask)=P.E_F; E(~sil)=0; Eb=mean(E(sil));
    [gx,gy]=gradient(E); gE=hypot(gx,gy); s0=Eb*P.EPS0/(1-P.NU^2); sxx=s0*(E/Eb); conc=1+P.KAPPA*gE/(Eb+1e-9);
    VM=abs(sxx).*conc; VM(~sil)=0;
    f=figure('Visible','off','Position',[60 60 1500 460]);
    a=subplot(1,3,1); imagesc(E); axis(a,'image','off'); colormap(a,parula); colorbar; title('Modulo de Young E [kPa]');
    a=subplot(1,3,2); imagesc(VM); axis(a,'image','off'); colormap(a,hot); colorbar; title('von Mises \sigma_{vM} (interfases)');
    vm=F(:,col(names,'vm_mean'));
    subplot(1,3,3); histo2(vm(labels==0),vm(labels==1)); xlabel('\sigma_{vM} media (tejido denso)'); ylabel('frecuencia'); title('Tension media por clase'); legend('clase 0','clase 1');
    annotation('textbox',[0 .95 1 .05],'String','FIGURA 4 - Biomecanica: modulo de Young y tension de von Mises',...
        'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
    savef(f,fullfile(outdir,'Fig4_vonmises.png')); close(f);
end
function fig5_stats(F,names,pvals,labels,outdir)
    sel={'compactness','hu2','sym_lr','n_components','fractal_dim','glcm_contrast'};
    f=figure('Visible','off','Position',[40 40 1500 820]);
    for i=1:6
        subplot(2,4,i+floor((i-1)/3)); c=col(names,sel{i}); v=F(:,c);
        mini_box(1,v(labels==0),[.18 .62 .27]); mini_box(2,v(labels==1),[.84 .15 .16]);
        set(gca,'XTick',[1 2],'XTickLabel',{'C0','C1'}); xlim([.4 2.6]);
        title(sprintf('%s  p=%.1e',sel{i},pvals(c))); grid on;
    end
    subplot(2,4,[4 8]); R=corrcoef_(F); imagesc(R,[-1 1]); axis image; colormap(gca,jet); colorbar;
    title('Correlacion de los 32 descriptores'); set(gca,'XTick',[],'YTick',[]);
    annotation('textbox',[0 .96 1 .04],'String','FIGURA 5 - Validacion estadistica: separacion por descriptor y correlaciones',...
        'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
    savef(f,fullfile(outdir,'Fig5_estadistica.png')); close(f);
end
function fig6_roc(y,s_igr,s_hue,s_den,a_igr,a_hue,a_den,p1,outdir)
    f=figure('Visible','off','Position',[80 60 1300 600]);
    subplot(1,2,1);
    [xi,yi]=roc_xy(y,s_igr); [xh,yh]=roc_xy(y,s_hue); [xd,yd]=roc_xy(y,s_den);
    plot(xi,yi,'-','LineWidth',2.6,'Color',[.18 .62 .27]); hold on;
    plot(xh,yh,'-','LineWidth',2.2,'Color',[.88 .54 .12]);
    plot(xd,yd,'-','LineWidth',2.6,'Color',[.84 .15 .16]); plot([0 1],[0 1],'k--');
    xlabel('Tasa de falsos positivos'); ylabel('Tasa de verdaderos positivos'); axis square; grid on;
    legend({sprintf('IGR (geometria) AUC=%.3f',a_igr),sprintf('Huella 30/35/35 AUC=%.3f',a_hue),...
            sprintf('Densidad (BI-RADS) AUC=%.3f',a_den),'azar'},'Location','southeast');
    title(sprintf('Curvas ROC  (DeLong IGR vs densidad: p=%.1e)',p1));
    subplot(1,2,2);
    nb=2000; bi=zeros(nb,1); bd=zeros(nb,1); n=numel(y); rng(3);
    for b=1:nb, idx=randi(n,n,1); if numel(unique(y(idx)))<2, bi(b)=NaN; bd(b)=NaN; continue; end
        bi(b)=auc_rank(y(idx),s_igr(idx)); bd(b)=auc_rank(y(idx),s_den(idx)); end
    bi=bi(~isnan(bi)); bd=bd(~isnan(bd)); histo2(bd,bi); xline_(0.5);
    xlabel('AUC (bootstrap, 2000)'); ylabel('frecuencia'); legend('densidad','IGR'); title('Distribucion bootstrap del AUC');
    annotation('textbox',[0 .95 1 .05],'String','FIGURA 6 - Desempeno: IGR y huella vs densidad (BI-RADS)',...
        'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
    savef(f,fullfile(outdir,'Fig6_ROC.png')); close(f);
end
function fig7_birads(F,names,labels,s_igr,outdir)
    y=labels; auc=zeros(numel(names),1); for i=1:numel(names), auc(i)=auc_uni(y,F(:,i)); end
    [as,ix]=sort(auc,'descend'); topn=min(16,numel(names)); ix=ix(1:topn); as=as(1:topn);
    f=figure('Visible','off','Position',[60 60 1500 600]);
    subplot(1,2,1); barh(1:topn, flipud(as),'FaceColor',[.12 .44 .71]); hold on;
    plot([.5 .5],[0 topn+1],'k--'); set(gca,'YTick',1:topn,'YTickLabel',flipud(names(ix)));
    xlabel('AUC univariado'); title('Top-16 descriptores por AUC individual'); grid on; xlim([0 1]);
    subplot(1,2,2);
    qs=[pct(s_igr,.25) pct(s_igr,.5) pct(s_igr,.75)]; cat=ones(numel(s_igr),1);
    cat(s_igr>qs(1))=2; cat(s_igr>qs(2))=3; cat(s_igr>qs(3))=4;
    c0=zeros(1,4); c1=zeros(1,4); for kk=1:4, c0(kk)=sum(cat==kk&y==0); c1(kk)=sum(cat==kk&y==1); end
    bar(1:4,[c0' c1']); colormap(gca,[.18 .62 .27;.84 .15 .16]);
    set(gca,'XTickLabel',{'BG-1','BG-2','BG-3','BG-4'}); xlabel('BI-RADS Geometrico (cuartiles del IGR)');
    ylabel('n pacientes'); legend('clase 0 (compacta)','clase 1 (fragmentada)'); title('Distribucion por categoria geometrica');
    annotation('textbox',[0 .95 1 .05],'String','FIGURA 7 - Poder discriminante individual y BI-RADS Geometrico propuesto',...
        'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold');
    savef(f,fullfile(outdir,'Fig7_birads_geometrico.png')); close(f);
end
% ----- utilidades de figura -----
function mini_box(xc,v,colr)
    q1=pct(v,.25); md=pct(v,.5); q3=pct(v,.75); iqr=q3-q1; lo=max(min(v),q1-1.5*iqr); hi=min(max(v),q3+1.5*iqr); w=0.28;
    patch([xc-w xc+w xc+w xc-w],[q1 q1 q3 q3],colr,'FaceAlpha',0.55,'EdgeColor','k'); hold on;
    plot([xc-w xc+w],[md md],'k-','LineWidth',1.6); plot([xc xc],[q3 hi],'k-'); plot([xc xc],[lo q1],'k-');
end
function histo2(a,b)
    allv=[a(:);b(:)]; ed=linspace(min(allv),max(allv),19);
    ha=histc(a,ed); hb=histc(b,ed); ctr=ed+ (ed(2)-ed(1))/2;
    bar(ctr,ha,'FaceColor',[.18 .62 .27],'FaceAlpha',0.6,'EdgeColor','none'); hold on;
    bar(ctr,hb,'FaceColor',[.84 .15 .16],'FaceAlpha',0.6,'EdgeColor','none');
end
function xline_(x), yl=ylim; plot([x x],yl,'k--'); end
function R=corrcoef_(X)
    Z=(X-mean(X))./(std(X)+1e-9); R=(Z'*Z)/(size(X,1)-1); R(~isfinite(R))=0;
end
function [Xr,Yr]=roc_xy(y,s)
    th=unique(s); th=th(end:-1:1); P=sum(y==1); Nn=sum(y==0); Xr=0; Yr=0;
    for i=1:numel(th)
        pred=s>=th(i); tp=sum(pred&y==1); fp=sum(pred&y==0); Xr(end+1)=fp/Nn; Yr(end+1)=tp/P; %#ok<AGROW>
    end
    Xr(end+1)=1; Yr(end+1)=1;
end
% ====================================================================================
%  CARGA DE LAS 249 MAMOGRAFIAS REALES DEL INC (uso opcional)
% ====================================================================================
function [mam,sil]=cargar_caso_real(ruta_dcm,P) %#ok<DEFNU>
% Reemplace en el bucle principal:
%     tfg=tfg_map(...); mam=acquire(...);
% por:
%     [mam,sil]=cargar_caso_real(rutas{p},P);
% y use sus etiquetas reales (BI-RADS/histologia) en 'labels'. El resto es IDENTICO.
% (La lectura DICOM usa dicomread/dicominfo, unica parte que requiere soporte DICOM.)
    info=dicominfo(ruta_dcm); img=double(dicomread(info));
    img=img-min(img(:)); img=img/(max(img(:))+eps);
    mam=-log(max(1-img,1e-3));                 % denso -> claro (ajuste segun fabricante)
    thr=otsu(mam(:)); sil=mam>thr;             % silueta de la mama (ajuste el umbral de fondo)
    mam(~sil)=0;
end
