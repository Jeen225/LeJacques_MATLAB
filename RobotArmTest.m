close all
clear
clc
 
 
 L(1) = Link([0 7.50 0 0],'modified')
 L(2) = Link([0 0 0 -pi/2],'modified')
 L(3) = Link([0 14.75 .0 pi/2],'modified')
 L(4) = Link([0  .0 .0 -pi/2],'modified')
 L(5) = Link([0  15.5 .0 -pi/2],'modified')
 L(6) = Link([0 .0 0 pi/2],'modified')
 L(7) = Link([0 0 08.5 -pi/2],'modified')
%  L(8) = Link([0 0 .0 pi/2],'modified')
 
 
 elink = SerialLink(L,'name','elink')
 elink.teach()