%% Mono_FM_Mod.m
% Mono FM Modulator (Audio -> Complex Baseband FM -> .bin)
% Pipeline: Read WAV -> resample to 200 kHz -> LPF 15 kHz -> FM mod (phase integration)
%          -> resample to 1 MHz -> Carson LPF -> write complex IQ to binary

clear; clc;

%% ===== User Parameters =====
in_wav      = 'piano2.wav';          % input mono wav (change path if needed)
out_bin     = 'fm_modulated_output.bin';

Fs_target   = 200e3;                 % 200 kHz (baseband processing rate)
Fs_usrp     = 1e6;                   % 1 MHz (TX rate / USRP-like)
f_delta     = 75e3;                  % frequency deviation (Hz)
audio_lpf   = 15e3;                  % audio LPF cutoff (Hz)

carson_BW   = 2*(audio_lpf + f_delta);     % Carson BW (Hz)
carson_fc   = carson_BW/2;                 % cutoff ~ BW/2
discard_info = true;

make_plots  = false;                 % set true if you want plots

%% ===== 1) Read Audio (Mono) =====
[x, Fs_in] = audioread(in_wav);
x = mean(x, 2);                       % force mono if stereo input

% Normalize audio to avoid excessive deviation
x = x ./ (max(abs(x)) + eps);

%% ===== 2) Resample to 200 kHz =====
x200 = resample(x, Fs_target, Fs_in);

%% ===== 3) LPF to 15 kHz (audio bandwidth) =====
Nfir = 256;
b_audio = fir1(Nfir, audio_lpf/(Fs_target/2), 'low');
x_filt = filter(b_audio, 1, x200);

%% ===== 4) FM Modulation (Complex Baseband) =====
% y(t) = exp(j*2*pi*f_delta * integral{x(t) dt})
% discrete: phase[n] = 2*pi*f_delta * cumsum(x[n]) / Fs
phase = 2*pi*f_delta * cumsum(x_filt) / Fs_target;
y_fm  = exp(1j * phase);

%% ===== 5) Resample to 1 MHz =====
y_up = resample(y_fm, Fs_usrp, Fs_target);

%% ===== 6) Carson LPF after upsampling =====
% Keep FM occupied bandwidth limited (Carson rule)
b_carson = fir1(Nfir, carson_fc/(Fs_usrp/2), 'low');
y_final  = filter(b_carson, 1, y_up);

%% ===== 7) Write Complex IQ to Binary =====
wr_bin_iq(out_bin, y_final, 'float32');

if discard_info
    fprintf('Wrote complex IQ to: %s\n', out_bin);
    fprintf('Fs_target = %.0f Hz, Fs_usrp = %.0f Hz, f_delta = %.0f Hz\n', Fs_target, Fs_usrp, f_delta);
    fprintf('Carson BW ≈ %.0f Hz (cutoff %.0f Hz)\n', carson_BW, carson_fc);
end

%% ===== Optional Plots =====
if make_plots
    figure; plot(real(y_final)); title('FM IQ (Real) - Time Domain'); xlabel('n'); ylabel('Amplitude');
    figure; pwelch(y_final, [], [], [], Fs_usrp, 'centered'); title('FM IQ - Spectrum');
end

%% ===== Local helper: write complex IQ =====
function wr_bin_iq(filename, iq, precision)
% Writes complex vector iq to binary as interleaved I,Q (little-endian)
% precision: 'float32' recommended
    fid = fopen(filename, 'wb');
    assert(fid > 0, 'Failed to open file for writing: %s', filename);

    iq = iq(:);
    data = [real(iq).'; imag(iq).'];  % 2 x N
    data = data(:);                  % interleaved

    fwrite(fid, data, precision);
    fclose(fid);
end
