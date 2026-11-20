function R = CS_reliability_test_scaling_series_Strength(X, Y, PLOT, varargin)
% Korosh Mahmoodi
% CS reliability test for two local scaling-exponent time series X and Y.
%
% PURPOSE
%   Given two scaling time series, e.g. MDEA delta_X(t) and delta_Y(t),
%   test whether their Complexity Synchronization (CS = correlation) is
%   reliable after accounting for overlap-induced autocorrelation.
%
% MAIN OUTPUTS
%   R.CS                 observed Pearson correlation between X and Y
%   R.N                  number of delta points
%   R.ac1_X, R.ac1_Y     lag-1 autocorrelation of X and Y
%   R.tau_X, R.tau_Y     integrated autocorrelation time estimates
%   R.Neff_lag1          effective N using lag-1 correction
%   R.Neff_int           effective N using integrated autocorrelation time
%   R.p_naive            ordinary p-value assuming independent samples
%   R.p_eff_lag1         p-value using lag-1 effective N
%   R.p_eff_int          p-value using integrated-autocorrelation effective N
%   R.p_circshift        surrogate p-value from circular shifts
%   R.p_phase            surrogate p-value from phase-randomized surrogates
%   R.CI_block           moving block bootstrap CI for CS
%   R.reliable           final YES/NO decision
%   R.reasons            reasons for the decision
%
% USAGE
%   R = CS_reliability_test_scaling_series(deltaX, deltaY, 1);  % plot
%   R = CS_reliability_test_scaling_series(deltaX, deltaY, 0);  % no plot
%

% PLOT input
%   PLOT = 1 creates diagnostic plots.
%   PLOT = 0 suppresses diagnostic plots.
%   If omitted or empty, PLOT defaults to 1.
% OPTIONAL NAME-VALUE PARAMETERS
%   'Alpha'        default 0.05     significance level
%   'NSurr'        default 2000     number of surrogates
%   'NBoot'        default 2000     number of block bootstrap samples
%   'MinNeff'      default 20       minimum acceptable effective sample size
%   'BlockLength'  default []       if empty, estimated from autocorrelation
%   'MaxLag'       default []       if empty, floor(N/4)
%   'Verbose'      default PLOT     print summary only when PLOT = 1
%   'Strength'     default 5        reliability level from 1 to 5
%   'ReliabilityStrength' []         alias for Strength
%
% NOTES
%   This code does NOT need Statistics Toolbox.
%   It is intended for short scaling series, N ~ 100 to 200.

%% ---------------- Parse inputs ----------------
if nargin < 3 || isempty(PLOT)
    PLOT = 1;
end
PLOT = logical(PLOT);

p = inputParser;
p.addParameter('Alpha', 0.05, @(z) isnumeric(z) && isscalar(z));
p.addParameter('NSurr', 2000, @(z) isnumeric(z) && isscalar(z));
p.addParameter('NBoot', 2000, @(z) isnumeric(z) && isscalar(z));
p.addParameter('MinNeff', 20, @(z) isnumeric(z) && isscalar(z));
p.addParameter('BlockLength', [], @(z) isempty(z) || (isnumeric(z) && isscalar(z)));
p.addParameter('MaxLag', [], @(z) isempty(z) || (isnumeric(z) && isscalar(z)));
p.addParameter('Verbose', PLOT, @(z) islogical(z) || isnumeric(z));
p.addParameter('Strength', 5, @(z) isnumeric(z) && isscalar(z));
p.addParameter('ReliabilityStrength', [], @(z) isempty(z) || (isnumeric(z) && isscalar(z)));
p.parse(varargin{:});
opt = p.Results;

% ReliabilityStrength is accepted as an alias so older code can call:
%   'ReliabilityStrength', Strength
if ~isempty(opt.ReliabilityStrength)
    opt.Strength = opt.ReliabilityStrength;
end
opt.Strength = round(opt.Strength);
opt.Strength = max(1, min(5, opt.Strength));

StrengthNames = {'Exploratory','Weak','Moderate','Strong','VeryStrict'};
StrengthName = StrengthNames{opt.Strength};

% If PLOT = 0, suppress all command-window output too.
% This overrides any 'Verbose' value passed in varargin.
if ~PLOT
    opt.Verbose = false;
end

X = X(:);
Y = Y(:);
ok = isfinite(X) & isfinite(Y);
X = X(ok);
Y = Y(ok);

N = numel(X);
if N < 10
    error('Too few valid points. Need at least about 10 delta points.');
end

% Demeaned versions for autocorrelation/surrogates
X0 = X - mean(X);
Y0 = Y - mean(Y);

if std(X0) == 0 || std(Y0) == 0
    error('One of the scaling time series has zero variance. CS is undefined.');
end

if isempty(opt.MaxLag)
    maxLag = max(1, floor(N/4));
else
    maxLag = min(opt.MaxLag, N-2);
end

%% ---------------- Observed CS and ordinary p-value ----------------
CS = localCorr(X, Y);
p_naive = localCorrP_fromN(CS, N);

%% ---------------- Autocorrelation and effective sample size ----------------
ac1_X = localLagCorr(X, 1);
ac1_Y = localLagCorr(Y, 1);

% Conservative lag-1 correction for correlation between two autocorrelated series
prod_ac = ac1_X * ac1_Y;
Neff_lag1 = N * (1 - prod_ac) / max(eps, (1 + prod_ac));
Neff_lag1 = max(3, min(N, Neff_lag1));
p_eff_lag1 = localCorrP_fromN(CS, Neff_lag1);

% Integrated autocorrelation time correction
[acf_X, tau_X] = localIntegratedAutocorr(X, maxLag);
[acf_Y, tau_Y] = localIntegratedAutocorr(Y, maxLag);
% For cross-correlation, use the larger tau as a conservative correction.
tau_pair = max([tau_X, tau_Y, 1]);
Neff_int = N / tau_pair;
Neff_int = max(3, min(N, Neff_int));
p_eff_int = localCorrP_fromN(CS, Neff_int);

%% ---------------- Choose block length ----------------
if isempty(opt.BlockLength)
    blockLength = max(3, ceil(2 * tau_pair));
    blockLength = min(blockLength, max(3, floor(N/3)));
else
    blockLength = max(2, round(opt.BlockLength));
    blockLength = min(blockLength, max(2, floor(N/2)));
end

%% ---------------- Circular-shift surrogates ----------------
% Preserves each time series exactly, including autocorrelation, but destroys
% zero-lag alignment by random circular shifts.
CS_circ = nan(opt.NSurr,1);
for b = 1:opt.NSurr
    shift = randi([1, N-1]);
    Ys = circshift(Y, shift);
    CS_circ(b) = localCorr(X, Ys);
end
p_circ = (1 + sum(abs(CS_circ) >= abs(CS))) / (opt.NSurr + 1);

%% ---------------- Phase-randomized surrogates ----------------
% Preserves approximate power spectrum/autocorrelation and destroys coupling.
CS_phase = nan(opt.NSurr,1);
for b = 1:opt.NSurr
    Xs = localPhaseRandomize(X0) + mean(X);
    Ys = localPhaseRandomize(Y0) + mean(Y);
    CS_phase(b) = localCorr(Xs, Ys);
end
p_phase = (1 + sum(abs(CS_phase) >= abs(CS))) / (opt.NSurr + 1);

%% ---------------- Moving block bootstrap confidence interval ----------------
CS_boot = nan(opt.NBoot,1);
for b = 1:opt.NBoot
    idx = localCircularBlockIndices(N, blockLength);
    CS_boot(b) = localCorr(X(idx), Y(idx));
end
CI_block = localPercentile(CS_boot, [2.5 97.5]);

%% ---------------- Decision rules with 5 reliability strengths ----------------
% The individual tests are:
%   passNeff  : enough effective samples after integrated autocorrelation correction
%   passP     : corrected p-value based on integrated-autocorrelation Neff
%   passCirc  : circular-shift surrogate test, preserving each series and overlap structure
%   passPhase : phase-randomized surrogate test, preserving approximate spectrum/autocorrelation
%   passCI    : moving-block bootstrap confidence interval does not include zero
%   passAbsCS : exploratory effect-size screen, |CS| >= 0.25
%
% ReliabilityStrength / Strength levels:
%   1 = Exploratory : |CS| >= 0.25 OR corrected p-value passes
%   2 = Weak        : Neff passes AND (corrected p-value OR bootstrap CI passes)
%   3 = Moderate    : Neff passes AND corrected p-value passes AND
%                     (circular-shift surrogate OR bootstrap CI passes)
%   4 = Strong      : Neff passes AND corrected p-value passes AND
%                     circular-shift surrogate passes AND bootstrap CI passes
%   5 = VeryStrict  : Neff passes AND corrected p-value passes AND
%                     circular-shift surrogate passes AND phase surrogate passes AND
%                     bootstrap CI passes

reasons = {};

passNeff  = Neff_int >= opt.MinNeff;
passP     = p_eff_int < opt.Alpha;
passCirc  = p_circ < opt.Alpha;
passPhase = p_phase < opt.Alpha;
passCI    = ~(CI_block(1) <= 0 && CI_block(2) >= 0);
passAbsCS = abs(CS) >= 0.25;

switch opt.Strength
    case 1
        reliable = passAbsCS || passP;
        ruleText = 'Strength 1 Exploratory: |CS| >= 0.25 OR corrected p-value passes.';

    case 2
        reliable = passNeff && (passP || passCI);
        ruleText = 'Strength 2 Weak: Neff passes AND (corrected p-value OR bootstrap CI passes).';

    case 3
        reliable = passNeff && passP && (passCirc || passCI);
        ruleText = 'Strength 3 Moderate: Neff passes AND corrected p-value passes AND (circular-shift surrogate OR bootstrap CI passes).';

    case 4
        reliable = passNeff && passP && passCirc && passCI;
        ruleText = 'Strength 4 Strong: Neff passes AND corrected p-value passes AND circular-shift surrogate passes AND bootstrap CI passes.';

    case 5
        reliable = passNeff && passP && passCirc && passPhase && passCI;
        ruleText = 'Strength 5 VeryStrict: Neff passes AND corrected p-value passes AND circular-shift surrogate passes AND phase surrogate passes AND bootstrap CI passes.';
end

reasons{end+1} = sprintf('Reliability level = %d (%s). %s', opt.Strength, StrengthName, ruleText);

if passNeff
    reasons{end+1} = sprintf('PASS: integrated-autocorrelation effective N = %.1f >= %.1f.', Neff_int, opt.MinNeff);
else
    reasons{end+1} = sprintf('FAIL: integrated-autocorrelation effective N = %.1f < %.1f.', Neff_int, opt.MinNeff);
end

if passP
    reasons{end+1} = sprintf('PASS: corrected p-value = %.4g < %.3g.', p_eff_int, opt.Alpha);
else
    reasons{end+1} = sprintf('FAIL: corrected p-value = %.4g >= %.3g.', p_eff_int, opt.Alpha);
end

if passCirc
    reasons{end+1} = sprintf('PASS: circular-shift surrogate p = %.4g < %.3g.', p_circ, opt.Alpha);
else
    reasons{end+1} = sprintf('FAIL: circular-shift surrogate p = %.4g >= %.3g.', p_circ, opt.Alpha);
end

if passPhase
    reasons{end+1} = sprintf('PASS: phase-randomized surrogate p = %.4g < %.3g.', p_phase, opt.Alpha);
else
    reasons{end+1} = sprintf('FAIL: phase-randomized surrogate p = %.4g >= %.3g.', p_phase, opt.Alpha);
end

if passCI
    reasons{end+1} = sprintf('PASS: block-bootstrap CI does not include zero: [%.3f, %.3f].', CI_block(1), CI_block(2));
else
    reasons{end+1} = sprintf('FAIL: block-bootstrap CI includes zero: [%.3f, %.3f].', CI_block(1), CI_block(2));
end

if passAbsCS
    reasons{end+1} = sprintf('PASS: exploratory effect-size screen |CS| = %.3f >= 0.25.', abs(CS));
else
    reasons{end+1} = sprintf('FAIL: exploratory effect-size screen |CS| = %.3f < 0.25.', abs(CS));
end

%% ---------------- Store output ----------------
R = struct;
R.CS = CS;
R.N = N;
R.ac1_X = ac1_X;
R.ac1_Y = ac1_Y;
R.acf_X = acf_X;
R.acf_Y = acf_Y;
R.tau_X = tau_X;
R.tau_Y = tau_Y;
R.tau_pair = tau_pair;
R.Neff_lag1 = Neff_lag1;
R.Neff_int = Neff_int;
R.p_naive = p_naive;
R.p_eff_lag1 = p_eff_lag1;
R.p_eff_int = p_eff_int;
R.NSurr = opt.NSurr;
R.NBoot = opt.NBoot;
R.CS_circ = CS_circ;
R.CS_phase = CS_phase;
R.p_circshift = p_circ;
R.p_phase = p_phase;
R.blockLength = blockLength;
R.CS_boot = CS_boot;
R.CI_block = CI_block;
R.alpha = opt.Alpha;
R.MinNeff = opt.MinNeff;
R.Strength = opt.Strength;
R.ReliabilityStrength = opt.Strength;
R.StrengthName = StrengthName;
R.passNeff = passNeff;
R.passP = passP;
R.passCirc = passCirc;
R.passPhase = passPhase;
R.passCI = passCI;
R.passAbsCS = passAbsCS;
R.reliable = reliable;
R.reasons = reasons;

%% ---------------- Print summary ----------------
if opt.Verbose
    fprintf('\n============================================================\n');
    fprintf('CS RELIABILITY TEST FOR TWO SCALING TIME SERIES\n');
    fprintf('============================================================\n');
    fprintf('N delta points                 : %d\n', N);
    fprintf('Reliability strength           : %d (%s)\n', opt.Strength, StrengthName);
    fprintf('Observed CS                    : %.4f\n', CS);
    fprintf('Lag-1 AC X, Y                  : %.4f, %.4f\n', ac1_X, ac1_Y);
    fprintf('Integrated tau X, Y            : %.2f, %.2f\n', tau_X, tau_Y);
    fprintf('Effective N, lag-1 correction  : %.2f\n', Neff_lag1);
    fprintf('Effective N, integrated AC     : %.2f\n', Neff_int);
    fprintf('p naive                        : %.4g\n', p_naive);
    fprintf('p effective lag-1              : %.4g\n', p_eff_lag1);
    fprintf('p effective integrated AC      : %.4g\n', p_eff_int);
    fprintf('p circular-shift surrogate     : %.4g\n', p_circ);
    fprintf('p phase-randomized surrogate   : %.4g\n', p_phase);
    fprintf('Block length used              : %d\n', blockLength);
    fprintf('Block-bootstrap 95%% CI         : [%.4f, %.4f]\n', CI_block(1), CI_block(2));
    fprintf('------------------------------------------------------------\n');
    if reliable
        fprintf('FINAL DECISION: RELIABLE CS\n');
    else
        fprintf('FINAL DECISION: NOT RELIABLE / USE CAUTION\n');
    end
    fprintf('------------------------------------------------------------\n');
    for i = 1:numel(reasons)
        fprintf('%s\n', reasons{i});
    end
    fprintf('============================================================\n\n');
end

%% ---------------- Plot diagnostics ----------------
if PLOT
    figure('Color','w','Position',[100 100 1200 720]);
    tiledlayout(2,3,'Padding','compact','TileSpacing','compact');

    nexttile; hold on; box on;
    plot(X,'-','LineWidth',1.3);
    plot(Y,'-','LineWidth',1.3);
    xlabel('Window index'); ylabel('\delta(t)');
    title(sprintf('Scaling series, CS = %.3f', CS));
    legend('X','Y','Location','best'); grid on;

    nexttile; hold on; box on;
    lags = 0:numel(acf_X)-1;
    plot(lags, acf_X, '-o', 'LineWidth',1.2);
    plot(lags, acf_Y, '-o', 'LineWidth',1.2);
    xlabel('Lag'); ylabel('Autocorrelation');
    title(sprintf('ACF: N_{eff}=%.1f', Neff_int));
    legend('X','Y','Location','best'); grid on;

    nexttile; hold on; box on;
    histogram(CS_circ, 40, 'Normalization','pdf');
    xline(CS, 'r', 'LineWidth',2);
    xline(-CS, 'r--', 'LineWidth',1.5);
    xlabel('Surrogate CS'); ylabel('Density');
    title(sprintf('Circular-shift null, p=%.3g', p_circ)); grid on;

    nexttile; hold on; box on;
    histogram(CS_phase, 40, 'Normalization','pdf');
    xline(CS, 'r', 'LineWidth',2);
    xline(-CS, 'r--', 'LineWidth',1.5);
    xlabel('Surrogate CS'); ylabel('Density');
    title(sprintf('Phase-randomized null, p=%.3g', p_phase)); grid on;

    nexttile; hold on; box on;
    histogram(CS_boot, 40, 'Normalization','pdf');
    xline(CS, 'r', 'LineWidth',2);
    xline(CI_block(1), 'k--', 'LineWidth',1.5);
    xline(CI_block(2), 'k--', 'LineWidth',1.5);
    xlabel('Bootstrap CS'); ylabel('Density');
    title(sprintf('Block bootstrap CI [%.2f, %.2f]', CI_block(1), CI_block(2))); grid on;

    nexttile; axis off;
    if reliable
        decisionText = 'FINAL: RELIABLE CS';
    else
        decisionText = 'FINAL: NOT RELIABLE / CAUTION';
    end
    txt = sprintf(['%s\n\n' ...
        'Strength = %d (%s)\nN = %d\nCS = %.3f\nN_eff = %.1f\n' ...
        'p_eff = %.3g\np_circ = %.3g\np_phase = %.3g\n' ...
        'CI = [%.3f, %.3f]\n\n%s'], ...
        decisionText, opt.Strength, StrengthName, N, CS, Neff_int, p_eff_int, p_circ, p_phase, ...
        CI_block(1), CI_block(2), strjoin(reasons, '\n'));
    text(0.02,0.98,txt,'Units','normalized','VerticalAlignment','top', ...
        'FontName','Arial','FontSize',11,'Interpreter','none');
end

end

%% ========================================================================
% LOCAL FUNCTIONS
% ========================================================================
function r = localCorr(x,y)
    x = x(:); y = y(:);
    ok = isfinite(x) & isfinite(y);
    x = x(ok); y = y(ok);
    if numel(x) < 3 || std(x)==0 || std(y)==0
        r = NaN; return;
    end
    x = x - mean(x);
    y = y - mean(y);
    r = sum(x.*y) / sqrt(sum(x.^2)*sum(y.^2));
end

function p = localCorrP_fromN(r, nEff)
    if ~isfinite(r) || ~isfinite(nEff) || nEff < 3
        p = NaN; return;
    end
    nEff = max(3, nEff);
    df = nEff - 2;
    if abs(r) >= 1
        p = 0;
    else
        tval = abs(r) * sqrt(df / max(eps, 1-r^2));
        % Two-tailed p-value for t distribution using betainc.
        p = betainc(df/(df + tval^2), df/2, 0.5);
    end
end

function ac = localLagCorr(x, lag)
    x = x(:);
    if numel(x) <= lag+2
        ac = NaN; return;
    end
    ac = localCorr(x(1:end-lag), x(1+lag:end));
end

function [acf, tau] = localIntegratedAutocorr(x, maxLag)
    x = x(:);
    x = x(isfinite(x));
    N = numel(x);
    maxLag = min(maxLag, N-2);
    acf = nan(maxLag+1,1);
    acf(1) = 1;
    for k = 1:maxLag
        acf(k+1) = localLagCorr(x,k);
    end

    % Initial positive sequence: sum until autocorrelation becomes <= 0.
    s = 0;
    for k = 1:maxLag
        if ~isfinite(acf(k+1)) || acf(k+1) <= 0
            break;
        end
        s = s + acf(k+1);
    end
    tau = 1 + 2*s;
    tau = max(1, tau);
end

function xs = localPhaseRandomize(x)
    x = x(:);
    N = numel(x);
    Xf = fft(x);
    Yf = Xf;

    if mod(N,2)==0
        pos = 2:(N/2);
        nyq = N/2 + 1;
        phases = 2*pi*rand(numel(pos),1);
        Yf(pos) = abs(Xf(pos)) .* exp(1i*phases);
        Yf(N-pos+2) = conj(Yf(pos));
        Yf(nyq) = Xf(nyq); % Nyquist unchanged
    else
        pos = 2:((N+1)/2);
        phases = 2*pi*rand(numel(pos),1);
        Yf(pos) = abs(Xf(pos)) .* exp(1i*phases);
        Yf(N-pos+2) = conj(Yf(pos));
    end
    Yf(1) = Xf(1); % mean component unchanged
    xs = real(ifft(Yf));
end

function idx = localCircularBlockIndices(N, blockLength)
    idx = zeros(N,1);
    pos = 1;
    while pos <= N
        startIdx = randi(N);
        block = mod((startIdx:startIdx+blockLength-1)-1, N) + 1;
        take = min(blockLength, N-pos+1);
        idx(pos:pos+take-1) = block(1:take);
        pos = pos + take;
    end
end

function q = localPercentile(x, pct)
    x = sort(x(isfinite(x)));
    if isempty(x)
        q = [NaN NaN]; return;
    end
    q = nan(size(pct));
    N = numel(x);
    for i = 1:numel(pct)
        pos = 1 + (N-1) * pct(i)/100;
        lo = floor(pos); hi = ceil(pos);
        if lo == hi
            q(i) = x(lo);
        else
            q(i) = x(lo) + (pos-lo)*(x(hi)-x(lo));
        end
    end
end
