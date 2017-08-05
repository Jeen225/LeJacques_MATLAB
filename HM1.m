P1 = [1 7 2 9 10 12 15];
roots(P1)
P2 = [1 9 8 9 12 15 20];
roots(P2)
P3 = P1+P2;
P4 = P1-P2;
P5 = conv(P1,P2);
disp(P3);
disp(P4);
disp(P5);
syms s;
P6 = (s+7)*(s+3)*(s+5)*(s+8)*(s+9)*(s+10);
numP6=numden(P6);
numP6=sym2poly(numP6);         
disp(numP6);
G1 = 20*(s+2)*(s+3)*(s+6)*(s+8)...
/(s*(s+7)*(s+9)*(s+10)*(s+15));
[numG1,denG1]=numden(G1);
numG1=sym2poly(numG1);
denG1=sym2poly(denG1);
G1tf=tf(numG1,denG1)
G1zpk=zpk(G1tf)
G2=(s^4+17*s^3+99*s^2+223*s+140)...
    /(s^5+32*s^4+363*s^3+2092*s^2+5052*s+4320);
[numG2,denG2]=numden(G2);
numG2=sym2poly(numG2);
denG2=sym2poly(denG2);
G2tf=tf(numG2,denG2)
G2zpk=zpk(G2tf)
G3tf= G1tf+G2tf
G3zpk=G1zpk+G2zpk
G4tf= G1tf-G2tf
G4zpk=G1zpk-G2zpk
G5tf= G1tf*G2tf
G5zpk=G1zpk*G2zpk
%G6 partial fraction expansion 
numG6=[5 10];
denG6=[1 8 15 0];
[rG6,pG6]=residue(numG6,denG6)
%G7 partial fraction expansion 
numG7=[5 10];
denG7=[1 6 9 0];
[rG7,pG7]=residue(numG7,denG7)
%G8 partial fraction expansion 
numG8=[5 10];
denG8=[1 6 34 0];
[rG8,pG8]=residue(numG8,denG8)

