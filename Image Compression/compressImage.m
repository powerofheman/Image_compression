function J=compressImage(I,Level)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INPUTS : I is the input image
%          Level is the extent of compression (1 to 256)
% OUTPUT:  J is the compressed image
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if length(size(I))>2
    I=rgb2gray(I);
end

H = imhist(I);
h = H / numel(I);
NumberOfIter = 1;
Thresholds = diffEvolution(h,Level,NumberOfIter);
Thres=[1 Thresholds+1 256];
J=0;
gray_level = zeros(1,length(Thres)-1);

for l=2:length(Thres)
    if sum(h(Thres(l-1):Thres(l)))~=0
        gray_level(l-1)=sum((h(Thres(l-1):Thres(l)))'.*double(Thres(l-1):Thres(l)))/sum(h(Thres(l-1):Thres(l)));
        J=J+gray_level(l-1)*(I>Thres(l-1) & I<=Thres(l));
    end
end

J=uint8(round(J));