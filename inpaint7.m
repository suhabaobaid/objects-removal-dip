function [inpaintedImg,origImg,fillImg,Confidence,DataTerm,movie] = inpaint7(imgFilename,fillFilename,fillColor)
%INPAINT  Exemplar-based inpainting.


warning off MATLAB:divideByZero

[originalImg,fillImg,region_to_be_filled] = loadimgs(imgFilename,fillFilename,fillColor);
originalImg = double(originalImg);
origImg = originalImg;
indexedImage = img2ind(originalImg);
sz = [size(originalImg,1) size(originalImg,2)];
knownRegion = ~region_to_be_filled;


% Initialize confidence and data terms
% confidence of source_region is 1 and for 
% the unknown region as 0
% repmat - matlab function for repeat copy of arrays
Confidence = double(knownRegion);
DataTerm = repmat(-.1,sz);

% Initialize the iteration for the movie display
iteration = 1;

%Initialize the isophote values from the gradient of the image
%of each channel (RGB)
[Isophotex(:,:,3) Isophotey(:,:,3)] = gradient(originalImg(:,:,3));
[Isophotex(:,:,2) Isophotey(:,:,2)] = gradient(originalImg(:,:,2));
[Isophotex(:,:,1) Isophotey(:,:,1)] = gradient(originalImg(:,:,1));
Isophotex = sum(Isophotex,3)/(3*255); Isophotey = sum(Isophotey,3)/(3*255);
temp = Isophotex; Isophotex = -Isophotey; Isophotey = temp;  % Rotate gradient 90 degrees


% initialization of the movie image
if nargout==6
  movie(1).cdata=uint8(originalImg); 
  movie(1).colormap=[];
  origImg(1,1,:) = fillColor;
  iteration = 2;
end

% While the unknown region is not filled
% This will run till the whole region is
% assigned the intensity values
while any(region_to_be_filled(:))
  % Find contour & normalized gradients ofregion_to_be_filled
  region_to_be_filledDouble = double(region_to_be_filled); 
  
  % To find the central part of the convolution of the same size as the input.
  % It convolve with the laplace as the gradient to then find the isophote 
  % direction in order to run the windown in the direction of the isophote
  dR = find(conv2(region_to_be_filledDouble,[1,1,1;1,-8,1;1,1,1],'same')>0);
  
  [normalx,normaly] = gradient(double(~region_to_be_filled)); 
  normal = [normalx(dR(:)) normaly(dR(:))];
  normal = normr(normal);  
  
  %this is for infinity and not a number due to dividing by zero
  normal(~isfinite(normal))=0; 
  
  % Compute confidences along the fill front
  for k_distance=dR'
    Patchp = getpatch(sz,k_distance);
    q = Patchp(~(region_to_be_filled(Patchp)));
    Confidence(k_distance) = sum(Confidence(q))/numel(Patchp);
  end
  
  % Compute patch priorities = confidence term * data term
  DataTerm(dR) = abs(Isophotex(dR).*normal(:,1)+Isophotey(dR).*normal(:,2)) + 0.001;
  patch_priorities = Confidence(dR).* DataTerm(dR);
  
  % Find patch with maximum priority, Patchp
  [unused,ndx] = max(patch_priorities(:));
  p = dR(ndx(1));
  [Patchp,rows,cols] = getpatch(sz,p);
  toFill = region_to_be_filled(Patchp);
  
  % Find the patch the minimizes the error
  PatcPatchq = bestPatchexemplar(originalImg,originalImg(rows,cols,:),toFill',knownRegion);
  
  % Update the region_to_be_filled
  toFill = logical(toFill);                
  region_to_be_filled(Patchp(toFill)) = false;
  
  % Propagate confidence & isophote values from the boundary 
  % to the unknown region
  Confidence(Patchp(toFill))  = Confidence(p);
  Isophotex(Patchp(toFill)) = Isophotex(PatcPatchq(toFill));
  Isophotey(Patchp(toFill)) = Isophotey(PatcPatchq(toFill));
  
  % Copy image data from Patchq to Patchp
  % patchq is the best candidate patch and 
  % patchp is the target patch lying on the boundary
  % of the unknown region
  indexedImage(Patchp(toFill)) = indexedImage(PatcPatchq(toFill));
  originalImg(rows,cols,:) = ind2img(indexedImage(rows,cols),origImg);  

  % assigning the values for the movement of the movie
  if nargout==6
    ind2 = indexedImage;
    ind2(logical(region_to_be_filled)) = 1;          
    movie(iteration).cdata=uint8(ind2img(ind2,origImg)); 
    movie(iteration).colormap=[];
  end
  iteration = iteration+1;
end

inpaintedImg=originalImg;


%---------------------------------------------------------------------
% Scans over the entire image (with a sliding window 9x9)
% for the patchq with the lowest error which is 
% the best candidate patch. Calls a MEX function, implemented in C.
%---------------------------------------------------------------------
function Patchq = bestPatchexemplar(img,Ip,toFill,knownRegion)
m=size(Ip,1); mm=size(img,1); n=size(Ip,2); nn=size(img,2);
bestPatch = bestexemplarhelper(mm,nn,m,n,img,Ip,toFill,knownRegion);
Patchq = sub2ndx(bestPatch(1):bestPatch(2),(bestPatch(3):bestPatch(4))',mm);


%---------------------------------------------------------------------
% Returns the indices for a 9x9 patch centered at pixel p.
%---------------------------------------------------------------------
function [Patchp,rows,cols] = getpatch(sz,p)
w=4; p=p-1; y=floor(p/sz(1))+1; p=rem(p,sz(1)); x=floor(p)+1;
rows = max(x-w,1):min(x+w,sz(1));
cols = (max(y-w,1):min(y+w,sz(2)))';
Patchp = sub2ndx(rows,cols,sz(1));


%---------------------------------------------------------------------
% Converts the (rows,cols) subscript-style indices to Matlab index-style
% indices.
%---------------------------------------------------------------------
function N = sub2ndx(rows,cols,nTotalRows)
X = rows(ones(length(cols),1),:);
Y = cols(:,ones(1,length(rows)));
N = X+(Y-1)*nTotalRows;


%---------------------------------------------------------------------
% Converts an indexed image into an RGB image, using 'img' as a colormap
%---------------------------------------------------------------------
function img2 = ind2img(ind,img)
for i=3:-1:1, temp=img(:,:,i); img2(:,:,i)=temp(ind); end;


%---------------------------------------------------------------------
% Converts an RGB image into a indexed image, using the image itself as
% the colormap.
%---------------------------------------------------------------------
function ind = img2ind(img)
s=size(img); ind=reshape(1:s(1)*s(2),s(1),s(2));


%---------------------------------------------------------------------
% Loads the image and it's mask image having the fillRegion
% using 'fillColor' as a marker
% value for knowing which pixels are to be filled.
%---------------------------------------------------------------------
function [img,fillImg,region_to_be_filled] = loadimgs(imgFilename,fillFilename,fillColor)
img = imread(imgFilename); fillImg = imread(fillFilename);
region_to_be_filled = fillImg(:,:,1)==fillColor(1) & ...
    fillImg(:,:,2)==fillColor(2) & fillImg(:,:,3)==fillColor(3);

function [A] = normr(N)
    for ii=1:size(N,1)
        A(ii,:) = N(ii,:)/norm(N(ii,:));
    end