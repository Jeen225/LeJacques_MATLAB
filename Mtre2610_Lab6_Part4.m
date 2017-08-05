load new_n_vals.txt -ascii;
load new_r_vals.txt -ascii;
load new_i_vals.txt -ascii;
figure(2),surfc(new_i_vals,new_r_vals,log(new_n_vals));
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