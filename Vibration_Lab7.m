%Data1 Kp = 0.0409
fid1 = fopen('Lab_7_data.txt');
x1 = textscan(fid1,'%f%f%f%f','delimiter',';');
time1 = double(x1{:,2});
ref1 = double(x1{:,4});
fclose(fid1);
figure(1),plot(time1,ref1);
%Data2 Kp = 0.03
fid2 = fopen('Lab_7_data_03.txt');
x2 = textscan(fid2,'%f%f%f%f','delimiter',';');
time2 = double(x2{:,2});
ref2 = double(x2{:,4});
fclose(fid2);
figure(2),plot(time2,ref2);
%Data3 Kp = 0.055
fid3 = fopen('Lab_7_data_055.txt');
x3 = textscan(fid3,'%f%f%f%f','delimiter',';');
time3 = double(x3{:,2});
ref3 = double(x3{:,4});
fclose(fid3);
figure(3),plot(time3,ref3);
%Data4 Kd = 5
fid4 = fopen('Lab_7_data_kd.txt');
x4 = textscan(fid4,'%f%f%f%f','delimiter',';');
time4 = double(x4{:,2});
ref4 = double(x4{:,4});
fclose(fid4);
figure(4),plot(time4,ref4);
%Data5 Kd = 5
fid5 = fopen('Lab_7_data_kd5.txt');
x5 = textscan(fid5,'%f%f%f%f','delimiter',';');
time5 = double(x5{:,2});
ref5 = double(x5{:,4});
fclose(fid5);
figure(5),plot(time5,ref5);
%Data6 Kd = 10
fid6 = fopen('Lab_7_data_kd10.txt');
x6 = textscan(fid6,'%f%f%f%f','delimiter',';');
time6 = double(x6{:,2});
ref6 = double(x6{:,4});
fclose(fid6);
figure(6),plot(time6,ref6);