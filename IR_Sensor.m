clear all;
clc;
a = arduino;
x = (0:99);
y1 = zeros(1,100);
y2 = zeros(1,100);
%Coefficients 17.9083*x^2 -75.6321*x + 88.5092 
 while(1)
     figure(1);
     y1(1:end-1)=y1(2:end);
     y2(1:end-1)=y2(2:end);
     y1(100)=readVoltage(a,'A0');
     y2(100)=17.9083*(y1(100))^2-75.6321*(y1(100))+88.5092;
     subplot(2,1,1)
     plot(x,y1,'r*');
     axis([0 100 0 5]);
     title('Voltage');
     subplot(2,1,2)
     plot(x,y2,'r*');
     axis([0 100 0 60]);
     title('Distance');
     drawnow;
 end