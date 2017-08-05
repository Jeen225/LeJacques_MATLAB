clear all;
clc;
a = arduino;
dist = [10,15,20,25,30,35,40,45,50,55,60];
for i = 1:length(dist)
    sprintf('Record data for %d cm. Press Enter',dist(i))
    pause;
    sum=0;
    for j = 1:10
       sum = sum+readVoltage(a,'A0'); 
    end
    voltAvg(i) = sum/10;
end

