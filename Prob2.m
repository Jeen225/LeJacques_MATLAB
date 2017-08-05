load data1.txt -ascii;
s = 0;
disp('Loop Method ')
for i = 1:numel(data1)
  s = s+data1(i);  
end
disp(s);
disp('Sum command method')
a=sum(data1);
disp(a);

