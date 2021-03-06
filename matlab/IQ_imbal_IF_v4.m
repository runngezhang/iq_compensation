close all
clear all
clc

% Choose how much amplitude and phase mismatch between local oscillator
% signals
ampl_mismatch_db = 1;  %[dB]
IQ_phase_mismatch = 2; %[degrees]


%% Some parameters
Fs2 = 16e6;
downrate = 200;
Fs = downrate * Fs2;
dT = 1/Fs;
RF_ampl = 2;
LOI_ampl = 1*10^(ampl_mismatch_db/20);
LOQ_ampl = 1;
RF_freq = 2.440e8;


%% Choose which sideband the LO downconverts

% For this sideband, output amplitude should be ~1/2
% LO_freq = RF_freq + 2.5e6;

% For this sideband, output amplitude should be ~0
 LO_freq = RF_freq - 2.5e6;


%% Create a complex bandpass FIR filter
Hlp = fir1(28,1e6/(Fs2/2));     % Lowpass prototype
N = length(Hlp)-1;
Fbp = 2.5e6/(Fs2/2);                              % Desired frequency shift
j = complex(0,1);
Hbp = Hlp.*exp(j*Fbp*pi*(0:N));

% View frequency response of filter
% fvtool(Hbp)

% Generate some tone at RF
N = 1e6;
t = 0:dT:(N-1)*dT;
MSK = RF_ampl * sin(2*pi*RF_freq*t);

%% Create LO with amplitude and phase mismatch
LOI = LOI_ampl * sin(2*pi*LO_freq*t)+LOI_ampl;
LOQ = LOQ_ampl * sin(2*pi*LO_freq*t + IQ_phase_mismatch + 90*pi/180)+LOQ_ampl;

%% Downconvert with LO
IFI = LOI .* MSK;
IFQ = LOQ .* MSK;

% Remove high frequency mixing content
[b,a] = butter(5,40e6/(Fs/2));
IFI_filt = filter(b,a,IFI);
IFQ_filt = filter(b,a,IFQ);

% Downsample to 16 MHz before further processing
Iout = IFI_filt(1:downrate:end);
Qout = IFQ_filt(1:downrate:end);
t = t(1:downrate:end);

%% Apply matlab I/Q compensation algorithm
% https://www.mathworks.com/help/comm/ref/comm.iqimbalancecompensator-system-object.html
M = 1/100;
% x = zeros(1,length(Iout));
% y = zeros(1,length(Iout));
% w = zeros(1,length(Iout));
% 
% for ii = 1:length(Iout)
%     x(ii) = Iout(ii) + j*Qout(ii);
%     y(ii) = x(ii) + w(ii)*conj(x(ii));
%     
%     w(ii+1) = w(ii) - M*y(ii)^2;
% end
% 
% IFI_filt = real(y);
% IFQ_filt = imag(y);
% 
iy = zeros(1,length(Iout));
qy = zeros(1,length(Iout));
wr = zeros(1,length(Iout));
wj = zeros(1,length(Iout));

for ii = 1:length(Iout)
    iy(ii) = Iout(ii) + wr(ii)*Iout(ii) + wj(ii)*Qout(ii);
    qy(ii) = Qout(ii) + wj(ii)*Iout(ii) - wr(ii)*Qout(ii);
    
    wr(ii+1) = wr(ii) - M*(iy(ii) + qy(ii))*(iy(ii)-qy(ii));
    wj(ii+1) = wj(ii) - M*(2*iy(ii)*qy(ii));
end

IFI_filt = iy;
IFQ_filt = qy;
%%
% Filter signal with complex bandpass filter    
Rcoeff = real(Hbp);
Icoeff = imag(Hbp);

x1 = conv(IFI_filt,Rcoeff,'same');
x2 = conv(IFQ_filt,Icoeff,'same');
Iout = x1 - x2;

x3 = conv(IFI_filt,Icoeff,'same');
x4 = conv(IFQ_filt,Rcoeff,'same');
Qout = x3 + x4;

% Plot the Q channel after the IQ compensation and filtering
plot(Iout)
figure;plot(Qout)
