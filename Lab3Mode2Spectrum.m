%Mode 1 FFT part, Spectrum
%Plot
freq1 = Lab3Mode2(:,1);
freq2 = Lab3Mode2S1(:,1);
a1rms = Lab3Mode1(:,2);
a2rms = Lab3Mode2S1(:,2);
plot(freq1(1:10),a1rms(1:10),'b');
hold on
plot(freq2(1:10),a2rms(1:10),'r');