clear all;
clc;
a = arduino('COM4','Uno');
x = (0:99);
y1 = zeros(1,100);
%Coefficients 17.9083*x^2 -75.6321*x + 88.5092 
 while(1)
     figure(1);
     y1(1:end-1)=y1(2:end);
     y1(100)=readVoltage(a,'A0');
     plot(x,y1,'r*');
     axis([0 100 0 5]);
     title('Voltage');
     drawnow;
 end