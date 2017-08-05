function test3
clc;clear;
problem1;
problem2;
problem3;
end

function problem1
x = linspace(-pi,pi,10);
y = sin(x);
figure(1),clf,plot(x,y,'*');
hold on;
xlabel('x');
ylabel('y');
xFit = linspace(min(x),max(x),500);
p = polyfit(x,y,5);
yFit = polyval(p,xFit);
plot(xFit,yFit);
p1 = p;
p1(end) = p1(end)-0.5;
s = roots(p1);
disp(s(abs(s)<pi));
end
function problem2
x = linspace(0,pi,500);
y = sin(x);
dx = x(2)-x(1);
for i = 1:length(x)-1
    ydiff(i) = (y(i+1)-y(i))/dx; 
end
xdiff = x(2:end);
figure(2),clf,plot(x,y);
hold on;
xlabel('x');
ylabel('sin(x)');
xmax = xdiff(ydiff==0);
plot(xmax,y(x==xmax),'*','MarkerSize',10);
disp(['The maximum value of x is approximatively ',num2str(xmax)]);
end

function problem3
r1 = 500;r2=1000;r3=200;
v1 = linspace(0,5,1000);
syms v2 v3 I;
for i = 1:length(v1)
   eq1 = (1/r1+2/r2)*v1(i)-1/r2*v2-1/r2*v3==0;
   eq2 = -(1/r2)*v1(i)-(1/r2)*v2+(1/r3+2/r2)*v3==0;
   eq3 = -v1(i)/r2+(2*v2)/r2-v3/r2==I;
   s(i) = solve(eq1,eq2,eq3);
   v2s(i)=double(s(i).v2);v3s(i)=double(s(i).v3);Is(i) = double(s(i).I);
end
b=Is((v1<5)&(v2s<5)&(v3s<5));
disp(['The maximum curent is ' num2str(max(b)),'A it happens for V1 = ',num2str(v1(b==max(b))),'V, V2 = ',num2str(v2s(b==max(b))), 'and V3 = ',num2str(v3s(b==max(b))),'V. ']);
end
