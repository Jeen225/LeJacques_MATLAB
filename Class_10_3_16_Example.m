%% * / and other operators are for matrices 
                  %%Figure(1);plot(x,y)will make a specific figure
                  %%clf will clear the figure
clear;
clc;
N = 2000;
t = linspace(0,20,N);
z = 0.1;
y = 1-exp(-z*t).*(z/((sqrt(1-z^2)))*(sin(t*sqrt(1-z^2)))+cos(t*sqrt(1-z^2)));
plot(t,y);
hold on
% count = 0;
% for i = 1:N
%   % if y(i)>1.2
%   %     count = count+1;
%   % end
%   g = y>1.2;
%   if y(i)>1.2
%       count = count+1;
%   end
% end
% count/N
% sum(g)/N
% plot(t,g)
m = y>1.2;
% for i = 1:N-1
% if m(i)~=m(i+1)
%     disp(t(i))
% end
% end
disp(' ');
%t((m(2:end)~= m(1:end-1)));
h = plot(t(m),y(m),'r.');

