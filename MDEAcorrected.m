function [delta, Info] = MDEA(Data, Stripesize, Rule, ST, EN, PLOT)
% MDEA  Robust Modified Diffusion Entropy Analysis.
%
%   delta = MDEA(Data, Stripesize, Rule, ST, EN, PLOT)
%   [delta, Info] = MDEA(...)
%
% This revised version preserves the logic of the original MDEA function:
%   1) normalize Data to [0,1]
%   2) detect events when the signal changes amplitude stripe
%   3) construct a diffusion trajectory according to Rule
%   4) estimate Shannon entropy versus log10 diffusion lag
%   5) estimate delta as the slope over the fractional fit interval [ST,EN]
%
% INPUTS
%   Data       : numeric time series vector.
%   Stripesize : stripe width after normalization to [0,1].
%   Rule       :  1  -> +1 at each event and cumulative sum
%                -1  -> random +/-1 at each event and cumulative sum
%                 0  -> random +/-1 state between events and cumulative sum
%   ST, EN     : fractional positions (0..1) selecting the linear-fit region.
%                Example: ST=0.2, EN=0.8.
%   PLOT       : 1 to show the signal and MDEA entropy fit; 0 otherwise.
%
% OUTPUTS
%   delta      : estimated scaling exponent. NaN if it cannot be estimated.
%   Info       : optional diagnostics structure.
%
% Main corrections relative to the previous implementation:
%   * protects against constant, NaN/Inf, empty, and too-short inputs
%   * validates all analysis parameters
%   * avoids indexing errors when no events are detected
%   * uses only actually computed displacements (no zero padding)
%   * RETAINS legitimate zero displacements in the entropy distribution
%   * permits windows ending exactly at the last sample
%   * fixes Rule=0 initialization of the first state
%   * fits only finite entropy points and requires at least two points
%   * makes plotting safe for short lag vectors
%
% Reference:
% Mahmoodi, Korosh, et al. "Complexity synchronization: a measure of
% interaction between the brain, heart and lungs." Scientific Reports 13.1
% (2023): 11433.

%% Defaults for outputs

delta = NaN;
Info = struct('NormalizedData', [], ...
              'Event', [], ...
              'StartEvent', [], ...
              'Diff', [], ...
              'Lag', [], ...
              'LogLag', [], ...
              'Entropy', [], ...
              'FitMask', [], ...
              'FitLine', [NaN NaN], ...
              'R2', NaN, ...
              'NumEvents', 0, ...
              'NumFitPoints', 0);

%% Validate inputs

if nargin ~= 6
    error('MDEA requires exactly 6 inputs: Data, Stripesize, Rule, ST, EN, PLOT.');
end

if ~isnumeric(Data) || ~isvector(Data) || isempty(Data)
    error('Data must be a nonempty numeric vector.');
end

Data = double(Data(:));

if any(~isfinite(Data))
    warning('MDEA:NonFiniteData', 'Data contains NaN or Inf. Returning delta = NaN.');
    return;
end

if ~isscalar(Stripesize) || ~isfinite(Stripesize) || Stripesize <= 0 || Stripesize > 1
    error('Stripesize must be a finite scalar in the interval (0,1].');
end

if ~isscalar(Rule) || ~ismember(Rule, [-1 0 1])
    error('Rule must be exactly 1, -1, or 0.');
end

if ~isscalar(ST) || ~isscalar(EN) || ~isfinite(ST) || ~isfinite(EN) || ...
        ST < 0 || EN > 1 || ST >= EN
    error('ST and EN must satisfy 0 <= ST < EN <= 1.');
end

if ~isscalar(PLOT) || ~ismember(PLOT, [0 1])
    error('PLOT must be 0 or 1.');
end

LengthData = numel(Data);
if LengthData < 20
    warning('MDEA:TooShort', 'Data is too short for a stable MDEA estimate. Returning delta = NaN.');
    return;
end

%% Normalize Data to [0,1] robustly

xmin = min(Data);
xmax = max(Data);
xrange = xmax - xmin;

if xrange <= eps(max(abs([xmin xmax])))
    warning('MDEA:ConstantData', 'Data is constant or numerically constant. Returning delta = NaN.');
    return;
end

Data = (Data - xmin) ./ xrange;
Info.NormalizedData = Data;

%% Extract stripe-transition events
% One event is recorded whenever two adjacent samples belong to different
% stripes. This intentionally preserves the event definition in the original
% MDEA function: a transition counts as one event regardless of how many
% stripe boundaries are crossed between the two samples.

stripe = floor(Data ./ Stripesize);

Event = zeros(LengthData, 1);
Event(1) = 1;  % preserve original diffusion initialization
Event(2:end) = double(diff(stripe) ~= 0);

% StartEvent is the set of genuine stripe-transition times; Event(1)=1 is
% an initialization point and is intentionally not included here.
StartEvent = find(Event(2:end) == 1) + 1;

Info.Event = Event;
Info.StartEvent = StartEvent;
Info.NumEvents = numel(StartEvent);

if isempty(StartEvent)
    warning('MDEA:NoEvents', 'No stripe-transition events were detected. Returning delta = NaN.');
    return;
end

%% Construct diffusion trajectory

switch Rule
    case 1
        Diff = cumsum(Event);

    case -1
        State0 = zeros(LengthData, 1);
        eventIdx = find(Event == 1);
        signs = ones(numel(eventIdx),1);
        signs(rand(numel(eventIdx),1) >= 0.5) = -1;
        State0(eventIdx) = signs;
        Diff = cumsum(State0);

    case 0
        % Assign a random +/-1 state at each event, then hold that state
        % between events. The original code did not initialize State00(1),
        % causing an unintended leading zero state; that is corrected here.
        State0 = zeros(LengthData, 1);
        eventIdx = find(Event == 1);
        signs = ones(numel(eventIdx),1);
        signs(rand(numel(eventIdx),1) >= 0.5) = -1;
        State0(eventIdx) = signs;

        State00 = zeros(LengthData, 1);
        State00(1) = State0(1);
        for ee = 2:LengthData
            if State0(ee) == 0
                State00(ee) = State00(ee-1);
            else
                State00(ee) = State0(ee);
            end
        end
        Diff = cumsum(State00);
end

Info.Diff = Diff;

%% Evaluate Shannon entropy of diffusion displacements

ll = floor(log(LengthData) / log(1.2)) - 5;
if ll < 2
    warning('MDEA:TooFewLags', 'Too few diffusion lags are available. Returning delta = NaN.');
    return;
end

% Preserve the original logarithmic lag construction.
Delh = floor(1.2 .^ (1:ll));
Delh = Delh(Delh >= 1 & Delh < LengthData);

if numel(Delh) < 2
    warning('MDEA:TooFewLags', 'Too few unique diffusion lags are available. Returning delta = NaN.');
    return;
end

DE = nan(1, numel(Delh));
Ndisp = zeros(1, numel(Delh));

for q = 1:numel(Delh)
    del = Delh(q);

    % Only use event starts for which idx0+del is a valid Diff index.
    % This avoids zero-padding HH and keeps genuine zero displacements.
    validStarts = StartEvent(StartEvent + del <= LengthData);
    Ndisp(q) = numel(validStarts);

    if isempty(validStarts)
        continue;
    end

    XF = Diff(validStarts + del) - Diff(validStarts);
    XF = round(XF);  % diffusion displacements are integer-valued here

    if isempty(XF)
        continue;
    end

    xminXF = min(XF);
    xmaxXF = max(XF);
    binEdges = (xminXF - 0.5):(xmaxXF + 0.5);

    % histcounts requires at least two edges. A degenerate distribution has
    % Shannon entropy zero, which is a valid result rather than an error.
    if numel(binEdges) < 2
        DE(q) = 0;
        continue;
    end

    counts = histcounts(XF, binEdges);
    counts = counts(counts > 0);

    if isempty(counts)
        continue;
    end

    Pc = counts ./ sum(counts);
    DE(q) = -sum(Pc .* log10(Pc));
end

de = log10(double(Delh));

Info.Lag = Delh;
Info.LogLag = de;
Info.Entropy = DE;
Info.NumDisplacements = Ndisp;

%% Select fit region robustly

nLag = numel(de);
Starr = max(1, round(ST * nLag));
endd = min(nLag, round(EN * nLag));

% Preserve the fractional-index interpretation of ST and EN, but make sure
% the selected interval is valid and includes at least two candidate points.
if Starr >= endd
    Starr = max(1, floor(ST*nLag) + 1);
    endd = min(nLag, ceil(EN*nLag));
end

candidateMask = false(1,nLag);
if Starr <= endd
    candidateMask(Starr:endd) = true;
end
fitMask = candidateMask & isfinite(DE) & isfinite(de);

Info.FitMask = fitMask;
Info.NumFitPoints = sum(fitMask);

if sum(fitMask) < 2
    warning('MDEA:InsufficientFitPoints', ...
        'Fewer than two finite entropy points are available in the fit region. Returning delta = NaN.');
    return;
end

%% Linear fit to estimate delta

FitLine = polyfit(de(fitMask), DE(fitMask), 1);
delta = FitLine(1);
Info.FitLine = FitLine;

fitY = polyval(FitLine, de(fitMask));
y = DE(fitMask);
SSE = sum((y - fitY).^2);
SST = sum((y - mean(y)).^2);
if SST > 0
    Info.R2 = 1 - SSE/SST;
elseif SSE == 0
    Info.R2 = 1;
end

%% Optional plots

if PLOT == 1
    figure('Color','w');

    subplot(1,2,1)
    plot(Data ./ Stripesize, 'LineWidth', 1)
    xlabel('t')
    ylabel('Normalized X(t) / stripe size')
    title('Signal and stripe index scale')
    grid on

    subplot(1,2,2)
    plot(de, DE, '+', 'MarkerSize', 7, 'LineWidth', 1.2)
    hold on
    plot(de(fitMask), polyval(FitLine,de(fitMask)), 'r--', 'LineWidth', 1.5)
    xlabel('log_{10}(l)')
    ylabel('S(l)')
    title(sprintf('MDEA: \\delta = %.3f, R^2 = %.3f', delta, Info.R2))
    legend('Entropy', 'Linear fit', 'Location', 'northwest')
    grid on
end

end
