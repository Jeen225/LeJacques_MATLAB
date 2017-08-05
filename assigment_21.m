function assigment_21
clear;
part1;
part2;
end

function part1
l = [50 50];
r = [20 20];
a = [pi 0];
b = [0 pi];
Z_R =  [0;0;0];
DZ_R = [0;0;0];
pos = {[0;0],[5;5],[12;15],[20;25]};
W = [r(1) 0;0 r(2)];
C = [sin(a(1)+b(1)) -cos(a(1)+b(1)) -l(1)*cos(b(1)); 
    sin(a(2)+b(2)) -cos(a(2)+b(2)) -l(2)*cos(b(2));
    cos(a(1)+b(1)) sin(a(1)+b(1)) l(1)*sin(b(1));
    cos(a(2)+b(2)) sin(a(2)+b(2)) l(2)*sin(b(2))];
for i = 2:length(pos)
WR = W*(pos{i}-pos{i-1});
WR(3:4,:)=0; 
DZ_R(:,i) = pinv(C)*WR; 
Theta_dif = (DZ_R(3,i)/2)+DZ_R(3,i-1);
R = [cos(Theta_dif) sin(Theta_dif) 0;
    -sin(Theta_dif) cos(Theta_dif) 0;
    0 0 1];
Z_R(:,i) = Z_R(:,i-1)+inv(R)*DZ_R(:,i);
end
disp(Z_R);
end

function part2
load encoderCount.txt
l = [120 120];
r = [52 52];
a = [-pi/2 pi/2];
b = [pi 0];
N = 9750;
Z_R =  [0;0;0];
DZ_R = [0;0;0];
pos = 2*pi*encoderCount./N;
W = [r(1) 0;0 r(2)];
C = [sin(a(1)+b(1)) -cos(a(1)+b(1)) -l(1)*cos(b(1)); 
    sin(a(2)+b(2)) -cos(a(2)+b(2)) -l(2)*cos(b(2));
    cos(a(1)+b(1)) sin(a(1)+b(1)) l(1)*sin(b(1));
    cos(a(2)+b(2)) sin(a(2)+b(2)) l(2)*sin(b(2))];
for i = 2:length(pos)
WR = W*(pos(:,i)-pos(:,i-1));
WR(3:4,:)=0; 
DZ_R(:,i) = pinv(C)*WR; 
Theta_dif = (DZ_R(3,i)/2)+DZ_R(3,i-1);
R = [cos(Theta_dif) sin(Theta_dif) 0;
    -sin(Theta_dif) cos(Theta_dif) 0;
    0 0 1];
Z_R(:,i) = Z_R(:,i-1)+inv(R)*DZ_R(:,i);
end
x = Z_R(1,:);
y = Z_R(2,:);
plot(x,y,'--');
end