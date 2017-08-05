function review
clc;
problem1;
problem2;
problem3;
problem4;
problem5;
problem6;
problem7;
end

function problem1
t = linspace(0,1,100);
i = (exp(t/2))-9*exp(-9*t)/2+9;
dt = t(2)-t(1);
v = 3*(i(2:end)-i(1:end-1))/dt;
figure(1),plot(t(1:end-1),v);
end

function problem2
z =0.1;
t = linspace(0,20,500);
y = 1-exp(-z*t).*((z/sqrt(1-z^2)*sin(t*sqrt(1-z^2))+cos(t*sqrt(1-z^2))));
figure(2),plot(t,y);hold on;
plot(t(y>1.2),y(y>1.2),'.');
disp(['The percentage of y values above 1.2 is ',num2str(size(y(y>1.2))*100/size(y)),'%']);
disp(['Maximum y happens at t = ', num2str(max(t(y>1.2))),'s ']);
disp(['The average of y values above 1.2 is ',num2str(mean(y(y>1.2)))]);
end

function problem3
x = linspace(0,12,100);
dx = x(2)-x(1);
M = 300*x-25/12*x.^3;
v = (M(2:end)-M(1:end-1))/dx;
w = -(v(2:end)-v(1:end-1))/dx;
figure(3),plot(x(1:end-2),w);
end

function problem4
[x,y]=meshgrid(linspace(-5,5,500),linspace(0,3,500));
z = sin(x).*cos(y);
z(y<sqrt(4-x.^2))=NaN;
figure(4),surf(x,y,z);
shading interp;
axis equal;
end

function problem5
N = input('Enter size of array: ');
x = linspace(0,2*pi,N);
y = sin(2.1*x)+cos(4.3*x);
disp(['The maximum y value is: ',num2str(max(y))]);
end

function problem6
l =[3,2.5,3.25]; 
s = 5.679373E-8;
C =[9,1,.5];
T =[500,300,300];
syms j1 j2 j3;
F12 = l(1)+l(2)-l(3)/(2*l(1));
F13 = l(1)+l(3)-l(2)/(2*l(1));
F21 = l(2)+l(1)-l(3)/(2*l(2));
F23 = l(2)+l(3)-l(1)/(2*l(2));
F31 = l(3)+l(1)-l(2)/(2*l(3));
F32 = l(3)+l(2)-l(1)/(2*l(3));
eq1= C(1)*(s*T(1)^4-j1)==F12*(j1-j2)+F13*(j1-j3);
eq2= C(2)*(s*T(2)^4-j2)==F21*(j2-j1)+F23*(j2-j3);
eq3= C(3)*(s*T(3)^4-j1)==F31*(j3-j1)+F32*(j3-j2);
s = solve(eq1,eq2,eq3);
disp(['J1 = ',num2str(double(s.j1)),'J2 = ',num2str(double(s.j2)),'J3 = ',num2str(double(s.j3))]);
end

function problem7
rows = 5000; cols = 4000;
A = zeros(rows,cols);
A(randperm(rows*cols,rows*cols/2)) = 1;
A(randi(rows),randi(cols)) = rand;
disp(A((A>0)&(A<1)));
[r,c]=find((A>0)&(A<1));
disp(['The random number is at row: ',num2str(r),' column: ',num2str(c)]);
end