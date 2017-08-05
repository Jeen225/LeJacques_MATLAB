clc; clear all;
a = arduino('com3', 'uno', 'Libraries', 'Servo');
s = servo(a, 'D3');
x = (0:99);
y1 = zeros(1,100);
y2 = zeros(1,100);
while(1)
        writePosition(s, 1);
        y1(1:end-1)=y1(2:end);
        y2(1:end-1)=y2(2:end);
        y1(100)=readVoltage(a,'A0');
        y2(100)=readVoltage(a,'A1');
        figure(1),plot(x,y1,'r*',x,y2,'k*');
        axis([0 100 0 5]);
        drawnow;
end