function HM06Nguessan
clc;
clear;
HM06_Problem1;
HM06_Problem2;
HM06_Problem3;
HM06_Problem4;
end

function HM06_Problem1
load spring.mat;
plot(x,F,'k*','MarkerSize',8);
hold on;
m_top = 0;
m_bottom = 0;
for i =1:length(x)
   m_top = m_top+x(i)*F(i);
   m_bottom = m_bottom+(x(i))^2;
end
m = m_top/m_bottom;
% S = 0;
% S_top = (F(1)-m*x(1))^2;
% S_bottom = (F(1)-mean(F))^2;
% for j = 2:length(x)
%     S_top(j) = S_top(j-1)+(F(j)-m*x(j))^2;
%     S_bottom(j) = S_bottom(j-1)+(F(j)-mean(F))^2;
%     S(j) = S_top(j)/S_bottom(j);
%     r(j) = sqrt(1-S(j));
% end

end

function HM06_Problem2

end

function HM06_Problem3

end

function HM06_Problem4

end