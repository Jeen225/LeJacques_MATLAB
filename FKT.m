function FKT(theta)
    clc;  
    %Define the robot's joints variables and the D-H Convention parameters
    a = {[0,0,0] [0,0,0] [0,0,0] [0,0,0] [0,0,0] [-6.6,0,0] [8.2,0,0]};
    d = {[0,0,4.5] [0,0,0] [0,0,-15.47] [0,0,0] [0,0,16] [0,0,0] [0,0,0]};
    A = [90 90 90 90 90 90 -90];
    O = [90+theta(1) theta(2) theta(3) theta(4) 180+theta(5) -90+theta(6) 180+theta(7)];
    %Define H matrix for the base frame
    H07 = [1 0 0 0;0 1 0 0;0 0 1 0;0 0 0 1];
    %The goal of this for loop is to generate the H matrix of the end
    %effector's frame relative t the base frame.
    for i = 1:7 
        %Rotation theta about Z axis
        RotZ(i) = {trotz(O(i),'deg')};
        %Translation d about the Z axis
        TransZ(i) ={transl(d{i})};
        %Rotation alpha about X axis 
        Rotx(i) = {trotx(A(i),'deg')};
        %Translation a about X axis
        TransX(i) ={transl(a{i})};
        %Finding the H(i,i-1) matrix
        %We determine the H matrix of the current frame i with respect to the
        %previous frame i-1
        H(i) = {RotZ{i}*TransZ{i}*TransX{i}*Rotx{i}};
        %Finding the H(i,0) matrix
        %We determine the H matrix of the current frame i with respect to the
        %base frame 0.
        H07 = H07*H{i};
    end
    format short
    sprintf('Position: x= %.2fcm, y= %.2fcm, z= %.2fcm',H07(1,4),H07(2,4),H07(3,4))
end
