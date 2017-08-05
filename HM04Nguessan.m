function HM04Nguessan
clear;
clc;
HM4_Problem_1;
HM4_Problem_2;
HM4_Problem_3;
HM4_Problem_4;
x5 = input('Enter 10 integers under the form [a b c d e f g h i j] ');
HM4_Problem_5(x5);
HM4_Problem_6;
HM4_Problem_7;
disp('Problem 8');
h=input('What is the water level: ');
sprintf('The volume of water inside the tank is %d ft^3',HM4_Problem_8(h))
h = linspace(0,7,250);
figure(8),plot(h,HM4_Problem_8(h));
xlabel('Water Level (ft)');
ylabel('Volume of water inside the tank ft^3');

end

%Homework Problem 1
function HM4_Problem_1
    disp('Problem 1');
    x1 = randi([3 12],4);
    disp(x1);
    S1 = sum(sum(x1),2);
    disp(S1)
    x1(2:3,2:3)=0;
    disp(x1);
end

%Homework Problem 2
function HM4_Problem_2
    disp('Problem 2');
    count = 0;
    N2 = 1500000;
    x2 = linspace(0,1,N2);
    y2 = linspace(0,1,N2);
    for i = 1:N2
        point_check = (x2(randi([1 N2])))^2+(y2(randi([1 N2])))^2;
        if point_check<=1
            count = count+1;
        end
    end
    Area = count/N2
    pi = Area*4
    %figure(2),plot(x2,s2);
end

%Homework Problem 3
function HM4_Problem_3
    disp('Problem 3');
    y3=1:1000000;
    g3=y3((y3.^2.5)<1000000);
    sprintf('The number of positive integers for which i^2.5 is less than 1,000,000 is: %d',numel(g3))
end

%Homework Problem 4
function HM4_Problem_4
    disp('Problem 4');
    disp('Please enter the coefficients of the polynomial: Ax^3+Bx^2+Cx+D')
    t4 = linspace(0,2,250);
    A = input('Enter A: ');
    B = input('Enter B: ');
    C = input('Enter C: ');
    D = input('Enter D: ');
    p = [A B C D];
    p4 = polyval(p,t4);
    figure(4),plot(t4,p4);
    sprintf('Maximum value of Polynomial on 0<x<2 = %d',max(p4))
    sprintf('Minimum value of Polynomial on 0<x<2 = %d',min(p4))
end

%Homework Problem 5
function [Positive_Even, Positive_Odd, Negative_Even, Negativr_Odd]=HM4_Problem_5(x)
pos = x(x>0);
neg = x(x<0);
Positive_Even = pos(find(mod(pos,2)==0))
Positive_Odd = pos(find(mod(pos,2)==1))
Negative_Even = neg(find(mod(neg,2)==0))
Negativr_Odd = neg(find(mod(neg,2)==1))
end

%Homework Problem 6
function HM4_Problem_6
    disp('Problem 6');
    x6 = 0:pi/256:2*pi;
    y6 = 2*sin(x6)-3*cos(2*x6);
    for i = 1:16
        x_point(:,i)=(x6(x6 == i*pi/8));
        y_point(:,i) = y6((x6 == i*pi/8));
    end
    figure(6),plot(x6,y6,'linewidth',2);
    hold on;
    figure(6),plot(x_point,y_point,'k^','MarkerSize',10);
end

%Homework Problem 7
function HM4_Problem_7
    disp('Problem 7');
    a7 = linspace(0,pi/2,250);
    x7 = 40^2*sin(2*a7)/32.2; %Maximum Range Equation
    y7 = 40^2*((sin(a7)).^2)/(2*32.2); %Peak height 
    figure(7),plotyy(a7,x7,a7,y7);
    legend('Maximum Range','Peak Height');
    xlabel('Angle(rad)');
end

%Homework Problem 8
function V8 = HM4_Problem_8(x)
    N8 = numel(x);
    r8 = 2;
    H8 = 7;
    for i = 1:N8
    if x(i) < r8
        V8(i) = (1/3)*pi*x(i).^2*(3*r8-x(i)); 
    end
    if (x(i)>=r8)&&(x(i)<H8-r8)
        V8(i) = (2/3)*pi*r8^3+pi*(r8^2)*(x(i)-r8);
    end
    if (x(i)>=H8-r8)&&(x(i)<=H8)
        V8(i) =(4/3)*pi*(r8^3)+(pi*(r8^2)*(H8-2*r8))-(1/3)*(pi*(H8-x(i))^2)*(3*r8-H8+x(i));
    end
     end
end
