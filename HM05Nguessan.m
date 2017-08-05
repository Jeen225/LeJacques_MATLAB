function HM05Nguessan
clc;
clear;
HM05_Problem1;
HM05_Problem2;
HM05_Problem3;
end

function HM05_Problem1
disp('Problem 1');
[z1, y1] = meshgrid(linspace(-0.05,0.05,1000),linspace(-0.08,0.08,1000));
M_z=-120*cosd(45);
M_y=-120*sind(45);
S = -((M_z*y1)/(1584E-08))+((M_y*z1)/(736E-08));
S(abs(y1)<=.07 & abs(z1)<=.04 )=NaN;
figure(1),surf(z1,y1,S);
set(gca,'plotboxaspectratio',[0.1,0.16,.25]);
%view([0 90]);
shading interp;
xlabel('z (m)');
ylabel('y (m)');
zlabel('Normal Stress (Pa)');
colorbar;
end

function HM05_Problem2
disp('Problem 2');
[x2, y2] = meshgrid(linspace(0,2,500),linspace(0,3,500));
H = 3;
W = 2;
Tc = 50;
Th =75;
sum_2=0;
for n = 1:500
    if n <= 151
    s =((((-1)^(n+1)+1)/n)*sin(n*pi*x2/W)).*((sinh(n*pi*y2/W))/(sinh(n*pi*H/W)));
    end
    if n>151
    s =((((-1)^(n+1)+1)/n)*sin(n*pi*x2/W)).*exp((y2-H)*n);
    end
    sum_2 = sum_2 + s;
end
T = Tc+(2*(Th-Tc)/pi)*sum_2;
figure(2),surf(x2,y2,T);
shading interp;
xlabel('x');
ylabel('y');
zlabel('Temperature (F)');
view([-90 -135 270]);
figure(3),contour(x2,y2,T,50);
axis equal;
colorbar;
end

function HM05_Problem3
fid = fopen('peopleData.csv');
x = textscan(fid,'%s',11,'delimiter',',');
y = textscan (fid, '%s%s%s%s%s%s%d%s%s%s%s', 'delimiter' , ',');
first = y{1};
last = y{2};
state = y{6};
email = y{10};
istates = unique(state);
for i = 1:length(istates)
istates{i,2} = sum(strcmp(state,istates(i)));
end
[~,I] = sort([istates{:,2}]);
istates = istates(I,:);
figure(4),bar(sort([istates{:,2}]));
set(gca,'xtick',1:47,'xticklabel',char(istates(:,1)));
gmail_indexes = strfind(email,'gmail'); 
gmail_indexes = find(~cellfun(@isempty,gmail_indexes));
fprintf('The number of people with Gmail addresses: %d \n',length(gmail_indexes));
fprintf('There are: \n');
for i = 1:length(gmail_indexes)
    fprintf('%s %s \n',char(first(gmail_indexes(i))),char(last(gmail_indexes(i))));
end
end
