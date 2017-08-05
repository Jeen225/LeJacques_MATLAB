[x,y] = meshgrid(linspace(-10,10,50),linspace(-10,10,50));
a = 5;b = 2; c = 3;
z_pos = real(sqrt((1-x.^2/a^2-y.^2/b^2)*c^2));
surf(x,y,z_pos);
hold on;surf(x,y,-z_pos);