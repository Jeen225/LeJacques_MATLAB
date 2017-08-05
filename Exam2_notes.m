%Review for exam
%indexing 
%Numerical x = [1 2 3; 4 5 6; 7 8 9] x(2,2:end) 5 6
%Logical x = [1 2 3; 4 5 6; 7 8 9] x(x<3 | x>6) 1 7 2 8 9
%Altering matrices x(r,c) = new value(can be a number a smaller matrix or
%an empty matrix to get rid of row or columns)
%Returning indices when searching matrices 
%   ex1 find(x == max(x))
%   ex2 find(abs(x) > 0.9) 
%   ex3 x = [1 2 3; 4 5 6; 7 8 9] find(x == 7) ans = 3 (linear index)
%   ex4 [row col] = find(x == 7) row = 3 col = 1
%Returning values when searching matrices
%   ex1 x(x==max(x))
%   ex2 x(find(abs(x)>0.9)) is equivalent to x(abs(x)>0.9)
%Arithmetic operators 
%   Elementwise .* ./ .^
%Plotting
%  xlabel('s') legend('s','s')
%  use meshgrid for surface plot
%  shading interp; colorbar; plot3(for non matrices)











