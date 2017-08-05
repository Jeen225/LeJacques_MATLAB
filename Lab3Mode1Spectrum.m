%Mode 1 FFT part, Spectrum
%Plot
freq1 = Lab3Mode1(:,1);
freq2 = Lab3Mode1S1(:,1);
a1rms = Lab3Mode1(:,2);
a2rms = Lab3Mode1S1(:,2);
plot(freq1(1:10),a1rms(1:10),'b');
hold on
plot(freq2(1:10),a2rms(1:10),'r');
max_acc1 = max(a1rms)
max_acc2 = max(a2rms)
%Interpolation
%new_freq1 = interp(freq1,5  );
%new_freq2 = interp(freq2,5);
%new_a1rms = interp(a1rms,5);
%new_a2rms = interp(a2rms,5);
%plot(new_freq1(1:50),new_a1rms(1:50));
%hold on
%plot(new_freq2(1:50),new_a2rms(1:50));
