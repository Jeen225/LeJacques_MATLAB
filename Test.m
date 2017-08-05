clear;
guess = 0;
count = 0;
val = floor(100*rand()) + 1;
disp('Guess the number 1-100');
while guess ~= val
guess = input('Guess the number: ');
if guess > val
disp('Too high!');
elseif guess < val
disp('Too low!');
else
disp('That''s it!');
end
count = count + 1;
end
disp(['It took you ' int2str(count) ' guesses.']);