function a=return_min(x)
[r,c] = size(x);
a  = x(1,1);  
    for i = 1:r
        for j = 1:c
           if a >= x(i,j)
               a = x(i,j);
           end
        end
    end
end