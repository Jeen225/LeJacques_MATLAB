%Find Homogeneous matrix
syms o1;                   %Define symbols here
RotZ = trotz(o1);          %Rotation in Z with theta
TransZ =transl([0,0,1]); %Translation in Z with d
Rotx = trotx(0);          %Rotation in x with alpha
TransX =transl([0,0,0]); %Translation in x with a 
H = RotZ*TransZ*TransX*Rotx;
vpa(H,2)
