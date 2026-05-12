% MATLAB 
clc;
clear;
close all;

inputFile = 'QPMU_500ksps_5SOW_50fps.csv';

%% =========================================================
% SETTINGS
% =========================================================
Fs = 50;
windowSec = 6;
stepSec = 1;

%% =========================================================
% USER SELECTION
% =========================================================
fprintf('Select channel to analyze:\n');
fprintf('1 -> Frequency channel\n');
fprintf('2 -> Amplitude channel\n');
fprintf('3 -> Phase channel\n');
choice = input('Enter your choice (1/2/3): ');

if ~ismember(choice, [1 2 3])
    error('Invalid choice. Please run the code again and enter 1, 2, or 3.');
end

%% =========================================================
% 1) FILE READING
% =========================================================
delim = detect_delimiter(inputFile);

T = readtable(inputFile, ...
    'Delimiter', delim, ...
    'VariableNamingRule', 'preserve', ...
    'ReadVariableNames', true);

if isempty(T) || height(T) == 0
    error('File could not be read or is empty: %s', inputFile);
end

if width(T) < 15
    error('File does not contain enough columns.');
end

% QPMU file columns
Timestamp = T.('Timestamp');
Phase     = T.('INRIM_QPMU Voltage0 Diff Angle L1MagAng');
Amplitude = T.('INRIM_QPMU Voltage0 Magnitude L1MagAng');
Frequency = T.('INRIM_QPMU Frequency');

if ~iscell(Timestamp)
    Timestamp = num2cell(Timestamp);
end

Phase     = force_numeric(Phase);
Amplitude = force_numeric(Amplitude);
Frequency = force_numeric(Frequency);

nRows = min([numel(Timestamp), numel(Amplitude), numel(Frequency), numel(Phase)]);
Timestamp = Timestamp(1:nRows);
Amplitude = Amplitude(1:nRows);
Phase     = Phase(1:nRows);
Frequency = Frequency(1:nRows);

fprintf('File reading completed.\n');
fprintf('Total rows read: %d\n', nRows);

%% =========================================================
% 2) ANALYSIS BASED ON USER CHOICE
% =========================================================
switch choice

    case 1
        % -------------------------------------------------
        % FREQUENCY CHANNEL
        % -------------------------------------------------
        validMaskFreq = ~isnan(Frequency) & isfinite(Frequency);
        freq_raw = Frequency(validMaskFreq);
        ts_freq  = Timestamp(validMaskFreq);

        if numel(freq_raw) < 100
            error('Too few valid samples in frequency channel.');
        end

        [ResultTable, plotTime, plotFreq] = ...
            run_frequency_analysis_only(freq_raw, ts_freq, Fs, windowSec, stepSec);

        writetable(ResultTable, 'frequency_channel_results.csv');

        fprintf('Results saved to:\n');
        fprintf(' - frequency_channel_results.csv\n');

        validPlotMask = ~isnan(plotFreq);

        figure;
        scatter(plotTime(validPlotMask), plotFreq(validPlotMask), 20, 'filled');
        grid on;
        xlabel('Time (s)');
        ylabel('Detected Frequency (Hz)');
        title('Frequency Channel - Detected Frequency Over Time');

    case 2
        % -------------------------------------------------
        % AMPLITUDE CHANNEL
        % -------------------------------------------------
        validMaskAmp = ~isnan(Amplitude) & isfinite(Amplitude);
        amp_raw = Amplitude(validMaskAmp);
        ts_amp  = Timestamp(validMaskAmp);

        if numel(amp_raw) < 100
            error('Too few valid samples in amplitude channel.');
        end

        [ResultTable, plotTime, plotFreq, plotAmp] = ...
            run_amplitude_analysis(amp_raw, ts_amp, Fs, windowSec, stepSec);

        validMask = ~isnan(ResultTable.DetectedFrequency);
        ResultTable = ResultTable(validMask, :);
        plotTime = plotTime(validMask);
        plotFreq = plotFreq(validMask);
        plotAmp  = plotAmp(validMask);

        writetable(ResultTable, 'amplitude_channel_results.csv');

        fprintf('Results saved to:\n');
        fprintf(' - amplitude_channel_results.csv\n');

        figure;
        scatter(plotTime, plotFreq, 20, 'filled');
        grid on;
        xlabel('Time (s)');
        ylabel('Detected Frequency (Hz)');
        title('Amplitude Channel - Detected Frequency Over Time');

        figure;
        scatter(plotTime, plotAmp, 20, 'filled');
        grid on;
        xlabel('Time (s)');
        ylabel('SSO Amplitude');
        title('Amplitude Channel - SSO Amplitude Over Time');

    case 3
        % -------------------------------------------------
        % PHASE CHANNEL
        % -------------------------------------------------
        validMaskPhase = ~isnan(Phase) & isfinite(Phase);
        phase_raw = Phase(validMaskPhase);
        ts_phase  = Timestamp(validMaskPhase);

        if numel(phase_raw) < 100
            error('Too few valid samples in phase channel.');
        end

        phase_raw = unwrap(deg2rad(phase_raw));
        phase_raw = rad2deg(phase_raw);

        [ResultTable, plotTime, plotFreq, plotAmp] = ...
            run_amplitude_analysis(phase_raw, ts_phase, Fs, windowSec, stepSec);

        validMask = ~isnan(ResultTable.DetectedFrequency);
        ResultTable = ResultTable(validMask, :);
        plotTime = plotTime(validMask);
        plotFreq = plotFreq(validMask);
        plotAmp  = plotAmp(validMask);

        writetable(ResultTable, 'phase_channel_results.csv');

        fprintf('Results saved to:\n');
        fprintf(' - phase_channel_results.csv\n');

        figure;
        scatter(plotTime, plotFreq, 20, 'filled');
        grid on;
        xlabel('Time (s)');
        ylabel('Detected Frequency (Hz)');
        title('Phase Channel - Detected Frequency Over Time');

        figure;
        scatter(plotTime, plotAmp, 20, 'filled');
        grid on;
        xlabel('Time (s)');
        ylabel('Phase Oscillation Amplitude');
        title('Phase Channel - Oscillation Amplitude Over Time');
end

%% =========================================================
% FUNCTION 1: FREQUENCY CHANNEL
%% =========================================================
function [ResultTable, plotTimeFiltered, freqFiltered] = ...
    run_frequency_analysis_only(signal_raw, ts_raw, Fs, windowSec, stepSec)

N = numel(signal_raw);
t = (0:N-1).' / Fs;

x = signal_raw - median(signal_raw, 'omitnan');

winLen  = round(windowSec * Fs);
stepLen = round(stepSec * Fs);

if winLen > N
    error('Window length is longer than signal.');
end

timestampRows = {};
timeRows = [];
freqRows = [];

for startIdx = 1:stepLen:(N - winLen + 1)

    endIdx = startIdx + winLen - 1;

    xw  = x(startIdx:endIdx);
    tw  = t(startIdx:endIdx);
    tsw = ts_raw(startIdx:endIdx);

    centerIdxLocal  = round(numel(xw)/2);
    centerTimeSec   = tw(centerIdxLocal);
    centerTimestamp = tsw(centerIdxLocal);

    xw = xw(:);
    n = (0:length(xw)-1).';

    % 1) 0 Hz test
    xw0 = xw - mean(xw, 'omitnan');

    relStd   = std(xw0, 'omitnan') / (rms(xw) + eps);
    relRange = (max(xw0) - min(xw0)) / (rms(xw) + eps);

    isZeroStrong = (relStd < 0.03) && (relRange < 0.15);
    isZeroWeak   = (relStd < 0.05) && (relRange < 0.25);

    % 2) Fs/2 test
    altRef = (-1).^n;
    aNyq = (xw0' * altRef) / (altRef' * altRef);
    xNyq = aNyq * altRef;

    nyqScore = sum(xNyq.^2) / (sum(xw0.^2) + eps);

    isNyqStrong = nyqScore > 0.88;
    isNyqWeak   = nyqScore > 0.78;

    % 3) Ordinary frequency test
    xwDet = detrend(xw0, 1);

    w = hann(length(xwDet));
    X = fft(xwDet .* w, 2^nextpow2(numel(xwDet)));
    Nfft = numel(X);
    freq = (0:Nfft-1).' * (Fs / Nfft);
    mag  = abs(X) / sum(w);

    halfIdx  = 1:(floor(Nfft/2)+1);
    freqHalf = freq(halfIdx);
    magHalf  = mag(halfIdx);

    searchBand = (freqHalf >= 0.2) & (freqHalf <= (Fs/2 - 0.2));
    freqSearch = freqHalf(searchBand);
    magSearch  = magHalf(searchBand);

    peakFreq = NaN;
    peakScore = 0;

    if ~isempty(freqSearch)
        noiseFloor = median(magSearch, 'omitnan');
        noiseMAD   = mad(magSearch, 1);

        minPeakHeight = noiseFloor + 3 * noiseMAD;
        minPeakProm   = max(2 * noiseMAD, 0.03 * max(magSearch));

        pksDet = [];
        locsDet = [];

        if any(magSearch > minPeakHeight)
            warnState = warning('off', 'signal:findpeaks:largeMinPeakHeight');
            try
                [pksDet, locsDet] = findpeaks(magSearch, freqSearch, ...
                    'MinPeakHeight', minPeakHeight, ...
                    'MinPeakProminence', minPeakProm, ...
                    'MinPeakDistance', 0.4, ...
                    'SortStr', 'ascend');
            catch
                pksDet = [];
                locsDet = [];
            end
            warning(warnState);
        end

        if ~isempty(pksDet)
            [~, iBest] = max(pksDet);
            peakFreq = locsDet(iBest);

            c = cos(2*pi*peakFreq*n/Fs);
            s = sin(2*pi*peakFreq*n/Fs);
            A = [c s];
            beta = A \ xwDet;
            xFit = A * beta;

            peakScore = sum(xFit.^2) / (sum(xwDet.^2) + eps);
        end
    end

    if isZeroStrong && ~isNyqStrong && peakScore < 0.10
        fdet = 0;
    elseif isNyqStrong && ~isZeroStrong && peakScore < 0.10
        fdet = Fs/2;
    elseif ~isnan(peakFreq) && peakScore >= 0.10
        fdet = peakFreq;
    elseif isZeroWeak && ~isNyqWeak
        fdet = 0;
    elseif isNyqWeak && ~isZeroWeak
        fdet = Fs/2;
    else
        fdet = NaN;
    end

    timestampRows(end+1,1) = {normalize_timestamp(centerTimestamp)};
    timeRows(end+1,1)      = centerTimeSec;
    freqRows(end+1,1)      = fdet;
end

plotTimeFiltered  = timeRows;
freqFiltered      = freqRows;

ResultTable = table( ...
    string(timestampRows), ...
    freqFiltered, ...
    'VariableNames', {'Timestamp', 'DetectedFrequency'});
end

%% =========================================================
% FUNCTION 2: AMPLITUDE / PHASE CHANNEL
%% =========================================================
function [ResultTable, plotTimeFiltered, freqFiltered, ampFiltered] = ...
    run_amplitude_analysis(signal_raw, ts_raw, Fs, windowSec, stepSec)

N = numel(signal_raw);
t = (0:N-1).' / Fs;

% Detection için normalize edilmiş sinyal
x = (signal_raw - mean(signal_raw,'omitnan')) / std(signal_raw,'omitnan');

winLen  = round(windowSec * Fs);
stepLen = round(stepSec * Fs);

if winLen > N
    error('Window length is longer than signal.');
end

timestampRows = {};
timeRows = [];
freqRows = [];
ampRows = [];

for startIdx = 1:stepLen:(N - winLen + 1)

    endIdx = startIdx + winLen - 1;

    xw_raw = signal_raw(startIdx:endIdx);   
    xw     = x(startIdx:endIdx);           
    tw     = t(startIdx:endIdx);
    tsw    = ts_raw(startIdx:endIdx);

    centerIdxLocal  = round(numel(xw)/2);
    centerTimeSec   = tw(centerIdxLocal);
    centerTimestamp = tsw(centerIdxLocal);

    xw = xw(:);
    xw_raw = xw_raw(:);
    n = (0:length(xw)-1).';

    xw0 = xw - mean(xw, 'omitnan');

    % 1) 0 Hz test
    relStd   = std(xw0, 'omitnan') / (rms(xw) + eps);
    relRange = (max(xw0) - min(xw0)) / (rms(xw) + eps);

    isZeroStrong = (relStd < 0.02) && (relRange < 0.10);
    isZeroWeak   = (relStd < 0.04) && (relRange < 0.20);

    % 2) Fs/2 test
    altRef = (-1).^n;
    aNyq = (xw0' * altRef) / (altRef' * altRef);
    xNyq = aNyq * altRef;

    nyqScore = sum(xNyq.^2) / (sum(xw0.^2) + eps);

    isNyqStrong = nyqScore > 0.82;
    isNyqWeak   = nyqScore > 0.72;

    % Nyquist amplitude 
    aNyq_raw = (xw_raw' * altRef) / (altRef' * altRef);
    nyqAmp = abs(aNyq_raw);

    % 3) Ordinary frequency test
    xwDet = detrend(xw0, 1);

    w = hann(length(xwDet));
    X = fft(xwDet .* w, 2^nextpow2(numel(xwDet)));
    Nfft = numel(X);
    freq = (0:Nfft-1).' * (Fs / Nfft);
    mag  = abs(X) / sum(w);

    halfIdx  = 1:(floor(Nfft/2)+1);
    freqHalf = freq(halfIdx);
    magHalf  = mag(halfIdx);

    searchBand = (freqHalf >= 0.2) & (freqHalf <= (Fs/2 - 0.2));
    freqSearch = freqHalf(searchBand);
    magSearch  = magHalf(searchBand);

    peakFreq = NaN;
    peakScore = 0;

    if ~isempty(freqSearch)
        noiseFloor = median(magSearch, 'omitnan');
        noiseMAD   = mad(magSearch, 1);

        minPeakHeight = noiseFloor + 4 * noiseMAD;
        minPeakProm   = max(3 * noiseMAD, 0.05 * max(magSearch));

        pksDet = [];
        locsDet = [];

        if any(magSearch > minPeakHeight)
            warnState = warning('off', 'signal:findpeaks:largeMinPeakHeight');
            try
                [pksDet, locsDet] = findpeaks(magSearch, freqSearch, ...
                    'MinPeakHeight', minPeakHeight, ...
                    'MinPeakProminence', minPeakProm, ...
                    'MinPeakDistance', 0.5, ...
                    'SortStr', 'ascend');
            catch
                pksDet = [];
                locsDet = [];
            end
            warning(warnState);
        end

        if ~isempty(pksDet)
            [~, iBest] = max(pksDet);
            peakFreq = locsDet(iBest);

            c = cos(2*pi*peakFreq*n/Fs);
            s = sin(2*pi*peakFreq*n/Fs);
            A = [c s];
            beta = A \ xwDet;
            xFit = A * beta;

            peakScore = sum(xFit.^2) / (sum(xwDet.^2) + eps);
        end
    end

    % Final decision
    if isZeroStrong && ~isNyqStrong && peakScore < 0.10
        fdet = 0;
        Adet = 0;

    elseif isNyqStrong && ~isZeroStrong && peakScore < 0.10
        fdet = Fs/2;
        Adet = nyqAmp;

    elseif ~isnan(peakFreq) && peakScore >= 0.10
        fdet = peakFreq;

        % Raw pencere üzerinde FFT magnitude
        Lraw = length(xw_raw);
        Yraw = fft(xw_raw) / Lraw / sqrt(2);

        nuniques = ceil((Lraw + 1) / 2);
        Yraw = Yraw(1:nuniques);

        if nuniques > 2
            Yraw(2:end-1) = 2 * Yraw(2:end-1);
        end

        if mod(Lraw,2) ~= 0
            Yraw(end) = 2 * Yraw(end);
        end

        fraw = (0:nuniques-1).' * (Fs / Lraw);
        magRaw = abs(Yraw) * sqrt(2);

        [~, idxClosest] = min(abs(fraw - fdet));
        Adet = magRaw(idxClosest);

    elseif isZeroWeak && ~isNyqWeak
        fdet = 0;
        Adet = 0;

    elseif isNyqWeak && ~isZeroWeak
        fdet = Fs/2;
        Adet = nyqAmp;

    else
        fdet = NaN;
        Adet = NaN;
    end

    timestampRows(end+1,1) = {normalize_timestamp(centerTimestamp)};
    timeRows(end+1,1)      = centerTimeSec;
    freqRows(end+1,1)      = fdet;
    ampRows(end+1,1)       = Adet;
end

plotTimeFiltered  = timeRows;
freqFiltered      = freqRows;
ampFiltered       = ampRows;

ResultTable = table( ...
    string(timestampRows), ...
    freqFiltered, ...
    ampFiltered, ...
    'VariableNames', {'Timestamp', 'DetectedFrequency', 'SSO_Amplitude'});
end

%% =========================================================
% HELPERS
%% =========================================================
function out = normalize_timestamp(in)
if iscell(in)
    in = in{1};
end

if ismissing(in)
    out = "";
elseif isdatetime(in)
    out = string(in);
elseif isstring(in)
    out = in;
elseif ischar(in)
    out = string(in);
elseif isnumeric(in)
    if isnan(in)
        out = "";
    else
        out = string(in);
    end
else
    out = string(in);
end
end

function x = force_numeric(x)
if isnumeric(x)
    x = double(x);
elseif iscell(x)
    x = str2double(string(x));
else
    x = str2double(string(x));
end
x = x(:);
end

function delim = detect_delimiter(filename)
fid = fopen(filename, 'r');
if fid == -1
    error('Cannot open file: %s', filename);
end
firstLine = fgetl(fid);
fclose(fid);

candidates = {',',';','\t'};
counts = zeros(size(candidates));

for i = 1:numel(candidates)
    counts(i) = count(string(firstLine), candidates{i});
end

[~, idx] = max(counts);
delim = candidates{idx};
end
