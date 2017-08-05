clc;
clear;
x = linspace(0,12,1000);
dx = (x(end)-x(1))/length(x);
w = 12.5*x;
figure(1),clf,hold on, plot(x,w,'LineWidth',10);
xlabel('x (ft)')
ylabel('w (lbf)')
for i = 1:length(x)
    weight = ones(i,1);
    weight(1) = 0.5; weight(end) = 0.5;
    v0 = 300;
    v(i) = v0-w(1:i)*weight*dx;
    M(i) = v(1:i)*weight*dx;
end
for i = 1:length(x)-1
    vdiff(i) = (M(i+1)-M(i))/dx; 
end
for i = 1:length(x)-1
    wdiff(i) = -(v(i+1)-v(i))/dx;
end
va = 300-6.25*x.^2;
Ma = 300*x-(25/12)*x.^3;
figure(1),clf,hold on, plot(x,w,'LineWidth',12);
plot(x(2:end),wdiff,'LineWidth',5);
xlabel('x (ft)')
ylabel('w (lbf)')
legend('Given','Numerical Differentiation');
figure(2),clf,hold on,plot(x,v,'LineWidth',12);
plot(x(2:end),vdiff,'LineWidth',7);
plot(x,va,'c','LineWidth',2);
xlabel('x (ft)')
ylabel('V (lbf)')
legend('Numerical Integration','Numerical Differentiation','Analytical');
figure(3),clf,hold on,plot(x,M,'LineWidth',12);
plot(x,Ma,'LineWidth',5);
xlabel('x (ft)')
ylabel('M (lbf.ft)')
legend('Numerical Integration','Analytical');
