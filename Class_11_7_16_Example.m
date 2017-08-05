x = randi(1,1);
while abs(sin(x)+x-1)>2*eps 
    x = 1-sin(x);
end
disp('For sin(x) + x = 1: ');
disp(['The answer is x = ' num2str(x) ' rad']);