clc; clear all;
%Define the robot's joints variables 
syms theta O1 O2 O3 O4 O5 O6 O7
theta = [O1 O2 O3 O4 O5 O6 O7]; 
%D-H Convention parameters
a = {[0,0,0] [0,0,0] [0,0,0] [0,0,0] [0,0,0] [-6.6,0,0] [8.2,0,0]};
d = {[0,0,4.5] [0,0,0] [0,0,-15.47] [0,0,0] [0,0,16] [0,0,0] [0,0,0]};
A = [pi/2 pi/2 pi/2 pi/2 pi/2 pi/2 -pi/2];
O = [pi/2+theta(1) theta(2) theta(3) theta(4) pi+theta(5) -pi/2+theta(6) pi+theta(7)];
%Define H matrix for the base frame, Zi and Oi
H0i = {[1 0 0 0;0 1 0 0;0 0 1 0;0 0 0 1]};
Z = {[0;0;1]};
dO={[0;0;0]};
    
for i = 1:7 
    %Rotation theta about Z axis
    RotZ(i) = {trotz(O(i))};
    %Translation d about the Z axis
    TransZ(i) ={transl(d{i})};
    %Rotation alpha about X axis    
    Rotx(i) = {trotx(A(i))};
    %Rotation a about X axis
    TransX(i) ={transl(a{i})};
    %Finding the H(i,i-1) matrix
    %We determine the H matrix of the current frame i with respect to the
    %previous frame i-1
    H(i) = {vpa(RotZ{i}*TransZ{i}*TransX{i}*Rotx{i},2)};
    %Finding the H(i,0) matrix
    %We determine the H matrix of the current frame i with respect to the
    %base frame 0.
    %Special case for frame 1 where the H matrix is just multiplied by the
    %identity matrix (H00)
    if i > 1
        H0i(i) = {vpa(H0i{i-1}*H{i},2)};
    end
    if i == 1
        H0i(i) = {vpa(H0i*H{i},2)};
    end
    %Obtain Z(i,0) O(i,0)
    Z(i+1) = {vpa(H0i{i}(1:3,3),2)};
    dO(i+1) = {vpa(H0i{i}(1:3,4),2)};
end
   
for i = 1:7
    %Define Jv(i) and Jw(i) for revolute joint i 
    JV(i)={vpa(cross(Z{i},(dO{:,8}-dO{:,i})),2)};
    JW(i) = {vpa(Z{i},2)};
end
JV = cat(2,JV{:});
JW = cat(2,JW{:});
%Define the Jacobian Matrix
J = vertcat(JV,JW);
% Finding some singularities
singularities = 0;
iterations = 0;
angles = [-pi/2 -pi/3 -pi/4 -pi/6 0 pi/6 pi/4 pi/3 pi/2];
while singularities ~= 5
   iterations = iterations+1
   thet1 = angles(randi([1,7])); 
   thet2 = angles(randi([1,7]));
   thet3 = angles(randi([1,7]));
   thet4 = angles(randi([1,7]));
   thet5 = angles(randi([1,7]));
   thet6 = angles(randi([1,7]));
   thet7 = angles(randi([1,7]));
   temp = vpa(subs(J,theta,[thet1 thet2 thet3 thet4 thet5 thet6 thet7]),2);
   if rank(temp) < 6
       singul(singularities+1) = {temp};
       singangles(singularities+1) = {[thet1 thet2 thet3 thet4 thet5 thet6 thet7]};
       singularities=singularities+1;
   end
   %sprintf('Iteration = %d, Singularities found = %d',iterations,singularities); 
end
