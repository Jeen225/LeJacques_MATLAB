function wheelSpeed = assigment_20(wheelConf,pos,zheta_i)
wheelConf = load(wheelConf); 
a = wheelConf(1,:);
b = wheelConf(2,:);
l =  wheelConf(3,:);
r =  wheelConf(4,:);
theta = atan(pos(2)/pos(1));
R = [cos(theta) sin(theta) 0;-sin(theta) cos(theta) 0; 0 0 1];
zheta_r = R*zheta_i;
C = [sind(a(1)+b(1)) -cosd(a(1)+b(1)) -l(1)*cosd(b(1)); 
    sind(a(2)+b(2)) -cosd(a(2)+b(2)) -l(2)*cosd(b(2));
    cosd(a(1)+b(1)) sind(a(1)+b(1)) l(1)*sind(b(1));
    cosd(a(2)+b(2)) sind(a(2)+b(2)) l(2)*sind(b(2))];
S=C*zheta_r;
wheelSpeed = [S(1)/r(1) S(2)/r(2)];
end