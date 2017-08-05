%Lab 3 Mode 2
%Plot
time1 = Lab3Mode2S2(:,1);
time2 = Lab3Mode2S3(:,1);
acceleration1 = Lab3Mode2S2(:,2);
acceleration2 = Lab3Mode2S3(:,2);
%Interplation
new_acceleration1 = interp(acceleration1,5);
new_acceleration2 = interp(acceleration2,5);
new_time1 = interp(time1,5);
new_time2 = interp(time2,5);
plot(new_time1(1:250),new_acceleration1(1:250),'b')
hold on
plot(new_time2(1:250),new_acceleration2(1:250),'r')
