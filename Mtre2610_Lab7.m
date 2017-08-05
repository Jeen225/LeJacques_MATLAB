clc;
clear;
im0 = imread('folders01.JPG');
R =im0(:,:,1); 
G =im0(:,:,2);
B =im0(:,:,3);
[c,r]=meshgrid(1:size(im0,2),1:size(im0,1));
figure(1),imshow(im0);
axis on;
[x,y]=ginput(4);
xc = sum(x)/length(x);
yc = sum(y)/length(y);
for j = 1:4
   if j<4
      m(j) = (y(j+1)-y(j))/(x(j+1)-x(j));
      b(j) = y(j)-m(j)*x(j);
   end
   if j == 4
      m(j) = (y(1)-y(j))/(x(1)-x(j));
      b(j) = y(j)-m(j)*x(j);
   end
   if yc<m(j)*xc+b(j)
    R(r>m(j)*c+b(j))=0;
    G(r>m(j)*c+b(j))=0;
    B(r>m(j)*c+b(j))=0;
  end
  if yc>m(j)*xc+b(j)
    R(r<m(j)*c+b(j))=0;
    G(r<m(j)*c+b(j))=0;
    B(r<m(j)*c+b(j))=0;
  end
end
im0_new(:,:,1)=R;
im0_new(:,:,2)=G;
im0_new(:,:,3)=B; 
figure(1),imshow(im0_new);
Rh = hist(double(R(R>0)),255);
Gh = hist(double(G(G>0)),255);
Bh = hist(double(B(B>0)),255);
figure(2);
p1 = subplot(3,1,1);bar(Rh,10);
set(get(gca,'children'),'facecolor',[1 0 0])
set(get(gca,'children'),'edgecolor',[1 0 0])
p2 =subplot(3,1,2);bar(Gh,10);
set(get(gca,'children'),'facecolor',[0 1 0])
set(get(gca,'children'),'edgecolor',[0 1 0])
p3 =subplot(3,1,3);bar(Bh,10);
set(get(gca,'children'),'facecolor',[0 0 1])
set(get(gca,'children'),'edgecolor',[0 0 1])
linkaxes([p1,p2,p3],'xy')
Rm = mean(double(R(R>0)));
Gm = mean(double(G(G>0)));
Bm = mean(double(B(B>0)));
disp([Rm Gm Bm]);


