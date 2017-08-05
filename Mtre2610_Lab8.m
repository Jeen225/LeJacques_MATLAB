clear; 
load im30;
figure(3); clf;
imshow(im30);
hold on; 
axis on;
[c,r] = imfindcircles(im30,[30 45],'Sensitivity',0.94,'EdgeThreshold',0.055);
viscircles(c,r);
[x,y]=ginput(2);
f = sqrt((x(1)-x(2))^2+(y(1)-y(2))^2);
dist = 0;
for i = 1:length(c)
    for j = 1:length(c)
        dist(i,j) = (sqrt((c(i,1)-c(j,1))^2+(c(i,2)-c(j,2))^2))/f;
    end
end
disp(['The smallest distance between two balls is ' num2str(min(min(dist(dist>0)))) ' ft']);
disp(['The largest distance between two balls is ' num2str(max(max(dist(dist>0)))) ' ft']);
% clear;
% v = VideoReader('wiffleBalls.mov');
% numFrames = get(v, 'NumberOfFrames');
% FPS = get(v, 'FrameRate' );
% vid = read(v);
% for i = 1:numFrames
%     F=vid(:,:,:,i);
%     imshow(F);
%     hold on;
%     axis on;
%     [c,r] = imfindcircles(F,[25 50],'Sensitivity',0.925,'EdgeThreshold',0.05);
%     viscircles(c,r);
%     drawnow;
%     
% end
v = VideoReader('wiffleBalls.mov');
numFrames = get(v, 'NumberOfFrames');
FPS = get(v, 'FrameRate' );
vid = read(v);
speed = 0;
time = linspace(0,numFrames/FPS,46);
[prev_c,prev_r] = imfindcircles(vid(:,:,:,1),[30 45],'Sensitivity',0.94,'EdgeThreshold',0.055);
for i = 2:numFrames
    F=vid(:,:,:,i);
    figure(1),imshow(F);
    hold on;
    axis on;
    [c,r] = imfindcircles(F,[30 45],'Sensitivity',0.94,'EdgeThreshold',0.055);
    viscircles(c,r);
    drawnow;
    for k = 1:length(c)
    for j = 1:length(c)
        dist(k,j) = (sqrt((c(k,1)-prev_c(j,1))^2+(c(k,2)-prev_c(j,2))^2))/f;
    end
    end
    pos_change = min(dist);
    max_change = max(pos_change);
    speed(i) = max_change*FPS;
    prev_c = c;
end
figure(2);clf;
s=spline(time,speed);
sfit=ppval(s,linspace(min(time),max(time),500));
plot(linspace(min(time),max(time),500),sfit,'k')
xlabel('Time (s)');
ylabel('Speed (ft/s)');



