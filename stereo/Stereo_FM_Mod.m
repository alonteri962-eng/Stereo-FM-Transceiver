%% Stereo_FM_Mod.m
% Stereo FM Modulator
% Creates a stereo FM composite baseband and performs FM modulation
% Composite signal:
% s(t) = 0.9(L+R) + 0.1*sin(2*pi*19k*t) + 0.9(L-R)*sin(2*pi*38k*t)

clear; clc;

%% ===== User Parameters =====
wav_left   = 'piano.wav';      % Left channel
wav_right  = 'music.wav';      % Right channel
out_bin    = 'stereo_fm_modulated_output.bin';

Fs_audio   = 48e3;             % Audio sampling rate
Fs_target  = 200e3;            % Baseband processing rate
Fs_usrp    = 1e6;              % TX sample rate

f_delta    = 75e3;             % FM frequency deviation
pilot_f    = 19e3;             % Pilot tone
sub_f      = 38e3;             % Stereo subcarrier

audio_lpf  = 15e3;
Nfir       = 256;

carson_BW  = 2*(audio_lpf + f_delta);
carson_fc  = carson_BW/2;

make_plots = false;

%% ===== Load and preprocess audio =====
[L, FsL] = audioread(wav_left);
[R, FsR] = audioread(wav_right);

L = mean(L,2);
R = mean(R,2);

if FsL ~= Fs_audio, L = resample(L, Fs_audio, FsL); end
if FsR ~= Fs_audio, R = resample(R, Fs_audio, FsR); end

N = min(length(L), length(R));
L = L(1:N); R = R(1:N);

L = L / max(abs(L));
R = R / max(abs(R));

%% ===== Stereo baseband =====
LPR = L + R;
LMR = L - R;

t = (0:N-1).' / Fs_audio;
pilot = sin(2*pi*pilot_f*t);
sub   = sin(2*pi*sub_f*t);

composite = 0.9*LPR + 0.1*pilot + 0.9*(LMR .* sub);
composite = composite / max(abs(composite));

%% ===== Resample and FM modulate =====
comp_200 = resample(composite, Fs_target, Fs_audio);
phase = 2*pi*f_delta * cumsum(comp_200) / Fs_target;
iq_200 = exp(1j * phase);

%% ===== Upsample and filter =====
iq_up = resample(iq_200, Fs_usrp, Fs_target);
b_carson = fir1(Nfir, carson_fc/(Fs_usrp/2), 'low');
iq_final = filter(b_carson, 1, iq_up);

%% ===== Write to binary =====
wr_bin_iq(out_bin, iq_final, 'float32');
fprintf('Stereo FM IQ written to %s\n', out_bin);

%% ===== Optional plots =====
if make_plots
    figure
