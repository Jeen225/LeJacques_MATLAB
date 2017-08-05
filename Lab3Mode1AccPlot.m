%Lab 3 Mode 1
%Plot
time1 = Lab3Mode1S2(:,1);
time2 = Lab3Mode1S3(:,1);
acceleration1 = Lab3Mode1S2(:,2);
acceleration2 = Lab3Mode1S3(:,2);
%Interplation
new_acceleration1 = interp(acceleration1,5);
new_acceleration2 = interp(acceleration2,5);
new_time1 = interp(time1,5);
new_time2 = interp(time2,5);
plot(new_time1(1:250),new_acceleration1(1:250),'b')
hold on
plot(new_time2(1:250),new_acceleration2(1:250),'r')
%Finding Offset
%offset1 = mean(new_acceleration1);
%offset2 = mean(new_acceleration2);
%acc1 = new_acceleration1-offset1;
%acc2 = new_acceleration2-offset2;
%plot(new_time1(1:250),acc1(1:250),'b')
%hold on
%plot(new_time2(1:250),acc2(1:250),'r')
