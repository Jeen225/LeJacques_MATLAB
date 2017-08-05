clear;
clc;
clf;
load n_vals.txt -ascii;
load r_vals.txt -ascii;
load i_vals.txt -ascii;
figure(1),surfc(i_vals,r_vals,log(n_vals));
shading interp;
view(0,90);
axis equal;
[x, y] = ginput(2);
if x(1) > x(2)
    temp_x = x(2);
    x(2) = x(1);    
    x(1) = temp_x;
end
if y(1) > y(2)
    temp_y = y(2);
    y(2) = y(1);
    y(1) = temp_y;
end
fid=fopen('Points.txt','wt');
for i = 1:length(x)
    fprintf(fid,'%f %f ',x(i),y(i));
end
fclose(fid);