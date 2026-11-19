clc, close all,clear all
%===========================================================
%seleccion de imagen para lectura
%===========================================================
    if(exist('filename','var')==0)
    dirname=''; 
    [filename, dirname] = uigetfile( {'*.dcm;*.dicom', 'Dicom Files'; '*.*', 'All Files (*.*)'});
    if(filename==0), return; end
    filename=[dirname filename];
    end
%===========================================================
% Read directory for Dicom File Series
%===========================================================
datasets=dicom_folder_info(filename,false);
if(isempty(datasets))
    datasets=dicom_folder_info(filename,true);
end
if(length(datasets)>1)
    c=cell(1,length(datasets));
    for i=1:length(datasets)
        c{i}=datasets(i).Filenames{1};
    end
    id=choose_from_list(c,'Select a Dicom Dataset');
    datasets=datasets(id);
end
info=datasets.DicomInfo;
info.Filenames=datasets.Filenames;
info.PixelDimensions=datasets.Scales;
info.Dimensions=datasets.Sizes;
%===========================================================
% datos de interes 
%===========================================================
ID=info.SeriesInstanceUID
Edad=info.PatientAge
Fuerza_de_compresion_Newton=info.CompressionForce
Espesormilimetro=info.BodyPartThickness
KVp=info.KVP
%corriente_en_el_tubo_miliAmpe=info.XrayTubeCurrent
tmiliSeg=info.ExposureTime
mAS=info.FieldOfViewDimensions
%%::::::::::::::::::::::::::::::::::::::::::::::::::::::
%%%%formacion de matrix en exel CON DATOS
%%%:::::::::::::::::::::::::::::::::::::::::::::::::::::
xstamAStus=('libroprueba1.xls');
xlswrite(xstamAStus,ID,Edad)%Fuerza_de_compresion_Newton,Espesormilimetro,KVp,corriente_en_el_tubo_miliAmpe,tmiliSeg,mAS) 
%===========================================================
% imagen cruda del RX
%============parametros=============================================
realce = 0.5 ;
umbralbin_tophat = 0.25 ;
r_tophat = 399 ;
limite_execb = 0.95 ;
limite_solb = 0.745 ;
limite_execm = 0.25;
limite_solm = 0.935 ;
%=============LECTURA DE LA IMAGEN=================================
[fn pn] = uigetfile('*.dcm','select dcm file');
complete = strcat(pn,fn);
ct = dicomread(complete);
%--------------*-*-*-*-*-*-*--*--------------------------------------------+
%conversor a png
%-----------------******---------------------------------------------------+algo
window_center = info.WindowCenter;
window_width = info.WindowWidth;
rescale_slope = info.RescaleSlope;
rescale_intercept = info.RescaleIntercept;
low = abs(info.RescaleIntercept)-abs(info.WindowCenter)+30;
high = low+info.WindowWidth;
figure(1),subplot(1,2,1), imshow(ct, [low high]),title('iamgen dicom bruto');
[nrows, ncols] = size(ct);
output_image = zeros(size(ct));
new_image = zeros(nrows, ncols);
max_pixel_intensity = 255;
for i = 1:nrows
    for j = 1:ncols
        new_image(i, j) = ct(i, j) * rescale_slope + rescale_intercept;
        if (new_image(i, j) < (window_center - window_width / 2))
            output_image(i, j) = 0;
        else if (new_image(i, j) > (window_center + window_width / 2))
                output_image(i, j) = max_pixel_intensity;
            else
                output_image (i, j) = (max_pixel_intensity / window_width) * (new_image(i, j) + window_width / 2 - window_center);
            end
        end
    end
end
output_image = uint8(output_image);
subplot(1,2,2), imshow(output_image),title('DICOM A PNG');
imwrite(output_image,'proces1.png');
ct1 = imread('proces1.png');
%******************************************************************
% PREPROCESAMIENTO
%*****************************************************************
%====Convertir a escala de 8 bits - 256 niveles de gris
K =uint16(ct1);
%==================================================================
%preprocesamiento de la imagen: filtro media?o
%entrada fm1
%Salida f1
%==================================================================
LevelsK = unique(K(:));       % determine number of unique code values
disp(['image K: # levels: ' num2str(length(LevelsK))]);
disp(['max level = ' num2str( max(LevelsK) )]);
disp(['min level = ' num2str( min(LevelsK) )]);
% Scale it to full 16-bit range
Kdouble = double(K);                  % cast uint16 to double
kmult = 65535/(max(max(Kdouble(:)))); % full range multiplier
Ref = uint16(kmult*Kdouble);   % full range 16-bit reference 
% build concave bow-shaped curve for darkening Reference image
ramp = [0:65535]/65535;
ppconcave = spline([0 .01 .0577  .0972 .187 1],[0 .025 .55 .85 .95 1]);
Ybuf = ppval( ppconcave, ramp);
Lut16bit = uint16( round( 65535*Ybuf ) );

% pass image Ref through LUT to darken image
A = intlut(Ref,Lut16bit);
figure(2)
title('Imagen original'); subplot(1,4,1), imshow(Ref);
title('referencia imagen'); 
B16bit64 = imhistmatch(A(:,:,1),Ref(:,:,1));  % default # bins: N = 64
N = length(LevelsK);      % number of unique 16-bit code values in image A
B16bitUniq = imhistmatch(A(:,:,1),Ref(:,:,1),N);
SUMAOX=Ref+B16bit64;
ref_sup=SUMAOX-Ref;
subplot(1,4,2), imshow(B16bit64)
title('proces1');
subplot(1,4,3), imshow(SUMAOX)
title('proces2')
subplot(1,4,4), imshow(ref_sup)
title('proces3')
%******************************************************************
% DETTTTTTECCION DE GANGLIOS CARCINOMAS
% VECNICNOS Y MALIGNOS
%*****************************************************************
%============parametros=============================================
realce = 0.5 ;
umbralbin_tophat = 0.25 ;
r_tophat = 190;
limite_execb = 0.95 ;
limite_solb = 0.745 ;
limite_execm = 0.25;
limite_solm = 0.935 ;
%=============LECTURA DE LA IMAGEN=================================
im1 =im2uint8(Ref);
imag = im2uint8(ref_sup);
%******************************************************************
% PREPROCESAMIENTO
%*****************************************************************
%====Convertir a escala de 8 bits - 256 niveles de gris
imag1=imag;
im001 =uint8(imag1);
%==================================================================
%preprocesamiento de la imagen: filtro media?o
%entrada fm1
%Salida f1
%==================================================================
fm1 =  mat2gray (im001);
f1 = medfilt2 (fm1 , 'symmetric');
imediana=f1;
% %********************************************************************
% % EXTRACION DE CARACTERISTICAS
% %*******************************************************************
% %Opcion 1. - tophat
% % entrada itoh1
% % Salida otoh1
% %===================================================================
 itoh = (((imediana))*16) ;
 itoh = round (itoh);
 se= strel('disk', r_tophat) ;
 otoh = imtophat(itoh, se );
% % procesamiento de la imagen: enhandced
 iehc= otoh ;
  oehc= imadjust(iehc,[0 realce],[0 1]);
% % Binarizacion
 inbin_tophat = oehc ;
 obin_tophat=im2bw(inbin_tophat,umbralbin_tophat);
% %=============Figure preprocesamiento 2===========================
 figure (3);
subplot (3,2,1), imshow(im1); title(' imagen original');
subplot (3,2,2), imshow(im001); title(' imagen recortada');
subplot (3,2,3), imshow(imediana); title ('imagen filtrada');
subplot (3,2,4), imshow(otoh); title('SEGMENTACION Top hat');
subplot (3,2,5), imshow(oehc); title('realce iamgen');
subplot (3,2,6), imshow(obin_tophat); title ('Imagen Binarizada');
% %***************************************************************
% %************ SELECION DE CARACTERISTICAS **************************
% % rango imagnes Binignas: 77 a 385 pixeles
% % rango imagnes Malignas: 5 a 77 pixeles
% % im?genes mayores a 386 pixeles se consideran posibles tumores
% %==================================================================
 roi_b = obin_tophat ;
 roi_m = obin_tophat ;
% %==================================================================
% % paso 1)
% % procedimiento para quitar objetos menores a <77 pixeles
% % para dejra solo obejtos probables de ser Benignos
% %=================================================================
% %figure; imshow(roi_b); title('Imagen a discriminar ');
% %*****************************************************************
% % Etiquetar elementos conectados
% % Neb: numero de elememtos
% % Lb: Matrix en donde guarda objetos encontrados
% %================================================================
 [Lbb Nebb] = bwlabel(roi_b);
% %================================================================
% % Calcular propiedades de los objetos de la imagen
% %================================================================
 propied_b= regionprops(Lbb , 'all');
% %===============================================================
% %hold on
 count_roi1b=0; % contador de objetos encontrados
% %========== Graficar las 'cajas' de frontera de los objetos ======
% % encuntra objetos y los enciera en una ventana de color verde (green)
 for n=1:size(propied_b,1)
 rectangle('Position',propied_b(n).BoundingBox,'EdgeColor','g','LineWidth',2);
 count_roi1b=count_roi1b+1;
 end
% %==========================Crear ventana Benignas=================
 pause (3)
% %=========== Buscar ?reas < 47 ====================================
 sroib=find([propied_b.Area]<47);
% %=========== Marcar ?reas < 77 ====================================
 count_roi2b=0;
% %==== encuntra objetos y los enciera en una ventana de color rojo (red)
 for n=1:size(sroib,2)
 rectangle('Position',propied_b(sroib(n)).BoundingBox,'EdgeColor','r','LineWidth',2);
 count_roi2b=count_roi2b+1;
 end
 pause (3)
% %===========Eliminar ?reas menores a < 77================================
% % elimina los objetos en color rojo.
 for n=1:size(sroib,2)
 d=round(propied_b(sroib(n)).BoundingBox);
 roi_b(d(2):d(2)+d(4),d(1):d(1)+d(3))=0; % elimina los objetos
 end
% %========== total objetos posiblemente benignos; total_roib============
 total_roib=count_roi1b-count_roi2b;
 % figure, imshow(roi_b);
% % title(['Objetos encontrados probablemente benignos: ',num2str(total_roib)])
% %*********************************************************************
% %**********************************************************************
% % paso 2)
% % procedimiento para quitar objetos mayores a >77 pixeles
% % para dejra solo obejtos probables de ser Malignos
% % en el rango de 0 a 77 pixeles
% %=====================================================================
 figure(4);subplot (3,2,1),imshow(roi_m); title('Imagen a discriminar ');
%*********************************************************************
% Etiquetar elementos conectados
% Neb: numero de elememtos
% Lb: Matrix en donde guarda objetos encontrados
%====================================================================
[Lbm Nebm] = bwlabel(roi_m);
%====================================================================
% Calcular propiedades de los objetos de la imagen
%====================================================================
propied_m= regionprops(Lbm , 'all');
%====================================================================
hold on
count_roi1m=0;
%============Graficar las 'cajas' de frontera de los objetos =========
% los encierra en color verde
for n=1:size(propied_m,1)
rectangle('Position',propied_m(n).BoundingBox,'EdgeColor','g','LineWidth',2)
count_roi1m=count_roi1m+1;
end
pause (3)
% ============ Buscar ?reas > a 77 ==================================
sroim=find([propied_m.Area]>77);
%============= Marcar ?reas > a 77 ==================================
count_roi2m=0;
for n=1:size(sroim,2)
rectangle('Position',propied_m(sroim(n)).BoundingBox,'EdgeColor','r','LineWidth',2)
count_roi2m=count_roi2m+1;
end
pause (3)
%==============Eliminar ?reas mayores a 77 ==========================
for n=1:size(sroim,2)
d=round(propied_m(sroim(n)).BoundingBox);
roi_m(d(2):d(2)+d(4),d(1):d(1)+d(3))=0;
end
total_roim=count_roi1m-count_roi2m;
figure (4);subplot (3,2,2),   imshow(roi_m);
title(['Total Objetos encontrados: ',num2str(total_roim)])
%********************************************************************
% paso 3)
% procedimiento para quitar objetos menores a 5 pixeles
% para quitar objetos que son ruido y fuera de escala
%===================================================================
roi_min = roi_m ;
figure(4);subplot (3,2,3), imshow(roi_min); title('(3)Imagen a discriminar ');
%******************************************************************
% Etiquetar elementos conectados
% Neb: numero de elememtos
% Lb: Matrix en donde guarda objetos encontrados
%==================================================================
[Lbmin Nebmin] = bwlabel(roi_min);
%==================================================================
% Calcular propiedades de los objetos de la imagen
%==================================================================
propied_min= regionprops(Lbmin , 'all');
%==================================================================
hold on
count_roi1min=0; % contador de objetos encontrados
%======== Graficar las 'cajas' de frontera de los objetos ===========
for n=1:size(propied_min,1)
rectangle('Position',propied_min(n).BoundingBox,'EdgeColor','g','LineWidth',2)
count_roi1min=count_roi1min+1;
end
pause (3)
% ======== Buscar ?reas < a 0.5 ======================================
sroimin=find([propied_min.Area]<0.5);
%========= Marcar ?reas < 5 =======================================
count_roi2min=0;
for n=1:size(sroimin,2)
rectangle('Position',propied_min(sroimin(n)).BoundingBox,'EdgeColor','r','LineWidth',2)
count_roi2min=count_roi2min+1;
end
%========= Eliminar ?reas menores a 5 ===========================
for n=1:size(sroimin,2)
d=round(propied_min(sroimin(n)).BoundingBox);
roi_min(d(2):d(2)+d(4),d(1):d(1)+d(3))=0;
end
total_roimin=count_roi1min-count_roi2min;
figure(4);subplot (3,2,4), imshow(roi_min);
title(['Objetos encontrados probablemente malignos:',num2str(total_roimin)]);
%=================================================================
% imagnes de salida seleccionadas
% Benignas: roi_b
% total objetos probables : total_roib
% Malignas: roi_min
% total objetos probables : total_roimin
%
%*****************VECTOR DE CARACTERSITICAS***********************
% SENALES BENINAS:
% Area (n) = areaIb(n)
% Perimetro (n) = perimIb(n)
% ecenrticidad (n) = eccentrIb(n)
% Areaconvexa (n) = areconvexIb(n)
% Solidez (n) = solidIb(n)
% SENALES MALIGNAS:
% Area (n) = areaIm(n)
% Perimetro (n) = perimIm(n)
% ecenrticidad (n) = eccentrIm(n)
% Areaconvexa (n) = areaconvexIm(n)
% solidez (n) = solidIm(n)
%==========================Resultado===============================
figure (4);
subplot (3,2,5), imshow(roi_b); title(['benignos problables =', num2str(total_roib)]);
subplot (3,2,6), imshow(roi_min); title(['malignos probables =', num2str(total_roimin)]);
%=========== VECTOR DE CARACTERISTICAS ===========================
%
% 1) Objetos probablemente benignos
%=================================================================
roi_bp = roi_b ;
[Lbbp Nebbp] = bwlabel(roi_bp);
propied_bp= regionprops(Lbbp,'all');
for n=1:size(propied_bp,1)
areaIb(n) = propied_bp(n).Area ;
perimIb(n) = propied_bp(n).Perimeter ;
eccentrIb(n) = propied_bp(n).Eccentricity ;
areaconvexIb(n) = propied_bp(n).ConvexArea ;
solidIb(n) = propied_bp(n).Solidity ;
end
%====================================================================
% 2) Objetos probablemente Malignos
%====================================================================
roi_mp = roi_min ;
[Lbmp Nebmp] = bwlabel(roi_mp);
propied_mp= regionprops(Lbmp,'all');
for n=1:size(propied_mp,1)
areaIm(n) = propied_mp(n).Area ;
perimIm(n) = propied_mp(n).Perimeter ;
eccentrIm(n) = propied_mp(n).Eccentricity ;
areaconvexIm(n) = propied_mp(n).ConvexArea ;
solidIm(n) = propied_mp(n).Solidity ;
end
%================== CLASIFICADOR =====================================
% clasificador implementado por arbol de deciciones
% dos ramas: solido, circular
% cada una con dos nodos de desicion:
% solidez y execntricidad
% limite_solb limite de decision de solidez en el clasificador B
% limite_execb limite de decision de excentricidad en el clasificador B
% limite_solm limite de decision de solidez en el clasificador M
% limite_execm limite de decision de excentricidad en el clasificador
%=================================================================
% calculos del lado de etiquetas benignos
%=================================================================
total_benignos = 0;
total_insertidumbreB = 0;
roi_bp = roi_b ;
[Lbbp Nebbp] = bwlabel(roi_bp);
propied_bp= regionprops(Lbbp,'all');
for n=1:size(propied_bp,1)
eccentrIb(n) = propied_bp(n).Eccentricity ;
if eccentrIb(n) <= limite_execb
benigno_exec(n)=1 ;
else
benigno_exec(n)=0 ;
end
solidIb(n) = propied_bp(n).Solidity ;
if solidIb(n) > limite_solb
benigno_sol(n) =1 ;
else
benigno_sol(n)= 0 ;
end
if ((benigno_exec(n)>=1) && (benigno_sol(n)>=1)) ;
benigno_true(n) =1 ;
total_benignos = total_benignos +1 ;
else
benigno_true(n)=0 ;
end
if ((benigno_exec(n)<=0) && (benigno_sol(n)<=0));
benigno_insertidumbre(n) = 1 ;
total_insertidumbreB = total_insertidumbreB + 1 ;
else
benigno_insertidumbre(n) = 0 ;
end
end
%=====================================================================
% calculos del lado de etiquetas malignos
%=====================================================================
total_malignos = 0;
total_insertidumbreM = 0;
roi_mp = roi_min ;
[Lbmp Nebmp] = bwlabel(roi_mp);
propied_mp= regionprops(Lbmp,'all');
for n=1:size(propied_mp,1)
eccentrIm(n) = propied_mp(n).Eccentricity ;
if eccentrIm(n) >= limite_execm
maligno_exec(n)=1 ;
else
maligno_exec(n)=0 ;
end 
solidIm(n) = propied_mp(n).Solidity ;
if solidIm(n) < limite_solm
maligno_sol(n) =1 ;
else
maligno_sol(n)=0 ;
end
if ((maligno_exec(n)>=1) && (maligno_sol(n)>=1)) ;
maligno_true(n)=1 ;
total_malignos = total_malignos + 1 ;
else
maligno_true(n)=0 ;
end
if ((maligno_exec(n)<=0) && (maligno_sol(n)<=0)) ;
maligno_insertidumbre(n)=1 ;
total_insertidumbreM = total_insertidumbreM + 1;
else
maligno_insertidumbre(n)=0 ;
end
end
figure (5);
subplot (1,3,1), imshow(imediana);
title ('Imagen de entrada');
subplot (1,3,2), imshow(roi_b);
ganglios= total_malignos+total_benignos+total_insertidumbreB;
title(['# de Ganglios detectados=', num2str(ganglios)]);
subplot (1,3,3), imshow(roi_min);
ganglios_afectados=total_malignos /total_insertidumbreB ;%+total_insertidumbreB;
title(['# de Ganglios afectados=', num2str(ganglios_afectados)]);
color=demosaic(ganglios_afectados,'bggr');
comparacion=imadd(roi_min,color);
figure (6);

imshow(comparacion,[]);
