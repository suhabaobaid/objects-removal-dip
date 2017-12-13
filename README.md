**Object Removal by Exemplar-based Inpainting**

Files included:
- matlab functions: inpaint7.m , plotall.m
- c function: bestexemplarhelper.c
- original images: B0.png, coin.png
- fill region images: B1.png, B01.png, fill_coin_2.png, fill_image_coin.png

The codes attached are modified from a base source code
from the link: http://www.csee.wvu.edu/~xinl/source.html

In order to use the code follow the instructions:

1. compile the c code provided, in matlab type:
mex bestexemplarhelper.c

2. Run the main function code to get the exemplar-based results:
[inpainted_image, original_image,fill_region_image,confidence,data,mov] = inpaint7('B0.png','B1.png',[0 255 0]);


[0,255,0] -> the fill_region is marked with green
‘B0.png’ -> is an original image provided
‘B1.png’ -> is an fill_region image provided

Other pictures included can be used

3. Getting the results to be displayed
```
plotall;
close;
movie(mov);
```
