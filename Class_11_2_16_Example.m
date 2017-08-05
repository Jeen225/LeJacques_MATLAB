    clc;clear;
figure(1);clf;
axis([0,1,0,1]);
% [x,y] = ginput(10);
load points;
plot(x,y,'k*','MarkerSize',8);
p = polyfit(x,y,6);
hold on;
xFit = linspace(min(x),max(x),500);
f = polyval(p,xFit);
plot(xFit,f);
s=spline(x,y);
g=ppval(s,xFit);
plot(xFit,g);
%Error for polyfit
sum((y-polyval(p,x)).^2)
%Error for spline
sum((y-ppval(s,x)).^2)
