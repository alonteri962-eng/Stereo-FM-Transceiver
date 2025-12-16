%% Mono_FM_Demod.m
% Mono FM Demodulator (.bin complex IQ -> audio)
% Pipeline: Read IQ -> discard transient -> FM demod (phase derivative)
%          -> LPF 15 kHz -> resample to 48 kHz -> normalize -> save WAV + (optional) MSE

clear; clc;

%% ===== User Parameters =====
in_bin      = 'fm_modulated_output.bin';
orig_wav    = 'piano2.wav';          % for MSE comparison (optional)
out_wav     = 'recovered_mono.wav';

Fs_rx       = 1e6;                   % sample rate of the recorded IQ file
Fs_audio    = 48e3;                  % target audio rate
audio_lpf   = 15e3;                  % audio LPF cutoff

N_discard   = 1000;                  % discard initial samples (filter transient)
Nfir        = 256;

make_plots  = false;

%% ===== 1) Read Complex IQ =====
iq = rd_bin_iq(in_bin, 'float32');

if length(iq) <= N_discard + 10
    error('IQ file too short or discard too large.');
end

iq = iq(N_discard+1:end);

%% ===== 2) FM Demod (phase derivative) =====
% angle difference (unwrap for stability)
phi = unwrap(angle(iq));
dphi = [0; diff(phi)];               % rad/sample
audio_bb = dphi * (Fs_rx/(2*pi));    % proportional to instantaneous freq deviation (Hz)

% Normalize to audio-ish range
audio_bb = audio_bb ./ (max(abs(audio_bb)) + eps);

%% ===== 3) LPF to 15 kHz =====
b_audio = fir1(Nfir, audio_lpf/(Fs_rx/2), 'low');
audio_filt = filter(b_audio, 1, audio_bb);

%% ===== 4) Resample to 48 kHz =====
audio_48 = resample(audio_filt, Fs_audio, Fs_rx);

%% ===== 5) Normalize and Save =====
audio_48 = audio_48 ./ (max(abs(audio_48)) + eps);
audiowrite(out_wav, audio_48, Fs_audio);
fprintf('Saved recovered audio to: %s\n', out_wav);

%% ===== 6) Optional: MSE vs Original =====
try
    [x0, Fs0] = audioread(orig_wav);
    x0 = mean(x0, 2);
    if Fs0 ~= Fs_audio
        x0 = resample(x0, Fs_audio, Fs0);
    end

    % Trim to common length and ignore early transient area
    Nmin = min(length(x0), length(audio_48));
    x0t  = x0(1:Nmin);
    yt   = audio_48(1:Nmin);

    skip = min(1000, floor(0.02*Fs_audio)); % ~20ms or 1000 samples
    if Nmin > skip + 10
        mse_val = mean((x0t(skip+1:end) - yt(skip+1:end)).^2);
        fprintf('MSE (after skip) = %.6f\n', mse_val);
    end
catch
    fprintf('Note: Could not compute MSE (missing orig_wav or read error).\n');
end

%% ===== Optional Plots =====
if make_plots
    figure; plot(audio_48); title('Recovered Audio (48 kHz)'); xlabel('n'); ylabel('Amplitude');
    figure; pwelch(audio_48, [], [], [], Fs_audio, 'centered'); title('Recovered Audio Spectrum');
end

%% ===== Local helper: read complex IQ =====
function iq = rd_bin_iq(filename, precision)
% Reads binary file of interleaved I,Q samples into complex vector
    fid = fopen(filename, 'rb');
    assert(fid > 0, 'Failed to open file for reading: %s', filename);

    data = fread(fid, inf, precision);
    fclose(fid);

    if mod(length(data), 2) ~= 0
        data = data(1:end-1);
    end

    I = data(1:2:end);
    Q = data(2:2:end);
    iq = complex(I, Q);
end
