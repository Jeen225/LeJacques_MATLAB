function Exam2
clc;
clear;
Exam2_Q1;
Exam2_Q2;
Exam2_Q3;
end

function Exam2_Q1
t = linspace(0,20,500);
x = 1*exp(-t/5).*cos(4*t);
v = -1*4*exp(-t/5).*sin(4*t)-(1/5)*exp(-t/5).*cos(4*t);
figure(1),plot(t,x,t,v);
hold on;
x1 = find(abs(x)<0.25);
plot(t(x1),x(x1),'k.','markersize',10);
hold off;
end

function Exam2_Q2
[t,x] = meshgrid(linspace(0,5,500),linspace(0,1,500));
sum = 0;
    for n = 1:500
        sum = sum+((1/(2*n-1)).*exp(-(2*n-1)^2*pi^2*.25^2*t).*cos((2*n-1)*pi*x));
    end
T = 25+(40*sum/pi^2);
figure(2),surf(x,t,T);
shading interp;
xlabel('x (ft)');
ylabel('time (min)');
zlabel('Temperature(C)');
set(gca,'plotboxaspectratio',[1,1,2.5]);
colorbar;
end

function Exam2_Q3
load Test02Problem03.txt -ascii;
[x,y] = find(isnan(Test02Problem03));
fprintf('NaN appears %d times ',length(x))
x_1= linspace(0,2.5,300);
y_1= linspace(-5,5,400);
fprintf('The largest value of x for NaN is: %f ',x_1(max(x)))
fprintf('The largest value of y for NaN is: %f ',y_1(max(y)))
end