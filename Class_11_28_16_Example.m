clear,clc;
% a = linspace(0,2,100);
% x = ones(length(a));
% for i = 1:length(x)
%     temp =0;
%     while abs(x(i)-temp)>eps
%         temp = x(i);
%         x(i) = (3-sin(2*x(i))+exp(-a(i)*x(i)))/4;
%     end
% end
% figure(1),clf,plot(a,x);
% xlabel('a');
% ylabel('x');
t = linspace(0,10,500);
i = 3e-3*exp(-0.5*t);
c = 500e-6;
dt = t(2)-t(1);
for a = 1:length(t)
    weight = ones(a,1);
    weight(1) = 0.5; weight(end) = 0.5;
    v(a) = i(1:a)*weight*dt*(1/c);
end
figure(2),clf,plot(t,v);