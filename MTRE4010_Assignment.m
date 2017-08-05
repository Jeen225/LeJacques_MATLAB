clc;clear;
Ja = 0.6;
Da = 0.1;
KtRa = 8;
Kb = 0.2;
J1 = 1.4;
D1 = 0.4;
Jl = 1300;
Dl = 140;
N1 = 50;
N2 = 1250;
Jm = Ja+J1+(N1/N2)^2*(Jl);
Dm = Da+D1+(N1/N2)^2*(Dl);
syms s;
G = tf([KtRa/Jm],[1 (Dm+KtRa*Kb)/Jm 0]);
[num,den] = tfdata(G,'v');
A = [0 1;0 -(Dm+KtRa*Kb)/Jm];
B = [0;KtRa/Jm];
C = [1 0];
D = 0;
%Controllability part
Cm = [B A*B];
if rank(Cm) ==2
disp('The system is controllable')
else
disp('The system is not controllable')   
end
%Observer Part
Om = [C;C*A];
if rank(Om)==2
    disp('The system is observable')
else
    disp('The system is not observable')
end
%Design of controller
syms k1 k2 ke s;
k = [k1 k2];
Ab = A-B*k;
S=s*[1 0 0;0 1 0;0 0 1];
Aic = [Ab B*ke;-C 0];
Det = det(S-Aic);
Zeta = -log(0.10)/sqrt(pi^2+(log(0.10))^2);
Wn = 4/(Zeta*0.5);
eq = s^2+2*Wn*Zeta*s+Wn^2==0;
pole = double(solve(eq));
pole(3) = 5*(-8);
chaEq = (s-pole(3))*(s^2+2*Wn*Zeta*s+Wn^2);
gains=solve(coeffs(Det,s)==coeffs(chaEq));
k1 = double(gains.k1);k2 = double(gains.k2);ke = double(gains.ke);
disp(['[k1 k2] = [',num2str(k1),',',num2str(k2),'] and Ke = ',num2str(ke)]);

