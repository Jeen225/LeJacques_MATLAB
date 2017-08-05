N = input('Enter an integer ');
[x,y] = meshgrid(linspace(0,4*pi,N),linspace(0,8*pi,N));
z = cos(x).*cos(y).*exp(-x.*y/100);
surfc(x,y,z);
shading interp;
xlabel('x');
ylabel('y');
zlabel('z');
axis equal %To maitain the aspect ratio on the axis