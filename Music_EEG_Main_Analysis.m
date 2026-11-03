%% Music EEG: main manuscript analysis
% Run this script with the required EEG files and MATLAB dependencies available.
% Dependencies: MDEAcorrected.m, read_set_file.m,
% CS_reliability_test_scaling_series_Strength.m, Signal Processing Toolbox.
% Primary settings: stripe width 0.18; 6.4 s windows; 50% overlap.
% Results are written to a timestamped folder under Downloads.

M = unifiedMusicMain("main");
final_statistical_validation(M);
fprintf('Main analysis complete: %s\n', M);

%% Local functions

function unifiedAssemble(M,S)
D=fullfile(M,'UNIFIED_PUBLICATION');if ~isfolder(D),mkdir(D);end
F=fullfile(D,'SUPPLEMENTARY');if ~isfolder(F),mkdir(F);end
orig=fullfile(S,'FINAL_SUPPLEMENTARY_FIGURES');
labels={'S01_MDEA_SCALING','S02_STRIPE_VALIDATION','S03_SURVIVAL_FITS', ...
 'S04_MATCHED_STRIPE_CS','S05_RENEWAL_DEPENDENCE_AGING','S06_RENEWAL_CONTROLS'};
for k=1:6
 if k==4,src=fullfile(M,'UNIFIED_VALIDATION','S04_MATCHED_STRIPE_CS');
 else,src=fullfile(orig,labels{k});end
 for ext={'.pdf','.jpg','.fig'}
  file=[src ext{1}];
  assert(isfile(file),'Missing required figure: %s',file);
  copyfile(file,fullfile(F,[labels{k} ext{1}]));
 end
end
pdf=fullfile(F,'ALL_SUPPLEMENTARY_FIGURES.pdf');if isfile(pdf),delete(pdf);end
for k=1:6
 f=figure('Visible','off','Color','w','Units','pixels','Position',[100 100 1800 1100]);
 im=imread(fullfile(F,[labels{k} '.jpg']));ax=axes(f,'Position',[.015 .015 .97 .97]);
 image(ax,im);axis(ax,'image');axis(ax,'off');
 exportgraphics(f,pdf,'ContentType','image','Resolution',600,'Append',k>1);close(f);
end
fid=fopen(fullfile(D,'RUN_LOCATIONS_AND_METHODS.txt'),'w');
fprintf(fid,'Primary and matched stripe sweep: %s\nV15 estimator/renewal: %s\n',M,S);
fprintf(fid,'Main: 6.4 seconds / 50%% overlap, local per-window normalization, stripe 0.18.\n');
fprintf(fid,'All nine geometries remain secondary sensitivity; matched stripes 0.15, 0.18, 0.20.\n');
fprintf(fid,'S04 uses identical primary CS analysis and all nine geometries.\n');
fprintf(fid,'Supplement S01-S03 and S05-S06 use V15 estimator/renewal diagnostics.\n');
fprintf(fid,'The two figure families share an export format, not identical estimands.\n');
fprintf(fid,'Main figures remain in primary FIGURES/MAIN.\n');fclose(fid);
end

function OUT = unifiedMusicMain(purpose)
if nargin<1, purpose="main"; end
%% MUSIC2 CORRECTED MAHMOODI MDEA: EEG .SET -> delta(t) -> CS + PLV + SPECTRAL CONTROLS + FULL ROBUSTNESS
% Requires MDEAcorrected.m (Korosh Mahmoodi's corrected six-input function),
% read_set_file.m and CS_reliability_test_scaling_series_Strength.m.
% Primary scaling estimates use MDEAcorrected(EEGwindow,0.18,1,0.2,0.8,0).
% CENTRAL/PRIMARY SZ=0.18 is used for the main CS results.
% Stripe-size selection and renewal validation are handled by the separate supplementary pipeline.
% SZ=0.18 is justified from estimator diagnostics, not from task significance counts;
% report the full sensitivity range and do not describe 0.18 as a unique mathematical optimum.
% Only illustrative pilot MDEA figures use PLOT=1.
% MDEAcorrected internally min-max normalizes EACH input window to [0,1].
% No MDEAGPT, musicMDEAwindow reconstruction, demeaning, or custom entropy.
% PRIMARY: 6.4 s / 50% overlap. Nine geometries remain for sensitivity only.
% PAPER TASK EFFECT = signed DeltaCS = CS(task)-CS(rest); no Delta|CS| task analysis.
% PAPER LABELS/ROBUSTNESS TABLES use DeltaCS nomenclature consistently; excluded controls are not indexed.
% Listening-reference and temporal-HF/EMG-proxy analyses are intentionally excluded.
% NOTE: the corrected MDEA recommends ~30,000 samples; these 512-Hz
% windows contain ~1,638 / 3,277 / 4,915 samples. Interpret with caution.

%% MUSIC2: RECOMPUTE MDEA SCALING TRAJECTORIES FROM ICA-PRUNED .SET EEG
% Standalone read_set_file.m (NO EEGLAB). Pilot -> approve -> PARFOR.
% Corrected MDEAcorrected.m must be available as an independent file on MATLAB path.
% Corrected MDEA's normalization, one-event-per-stripe-change rule,
% event-started diffusion sampling, base-10 entropy, and ST/EN indexing
% are preserved by calling MDEAcorrected directly.
close all; clc;
assert(exist('read_set_file','file')==2, 'Put read_set_file.m on the MATLAB path.');
assert(exist('MDEAcorrected','file')==2, 'Put MDEAcorrected.m on the MATLAB path (first line must declare function [delta, Info] = MDEAcorrected(...)).');
fprintf('CORRECTED MDEA FUNCTION: %s\n',which('MDEAcorrected'));
assert(nargout('MDEAcorrected')>=2, 'MDEAcorrected must return [delta, Info].');
assert(exist('CS_reliability_test_scaling_series_Strength','file')==2, ...
    'Put CS_reliability_test_scaling_series_Strength.m on MATLAB path.');
assert(exist('butter','file')==2 && exist('filtfilt','file')==2 && exist('hilbert','file')==2, ...
    'PLV comparison requires butter, filtfilt, and hilbert (Signal Processing Toolbox).');
home=getenv('USERPROFILE'); if isempty(home),home=getenv('HOME');end
root=fullfile(home,'Downloads');
if ~isfolder(root)
    root=fullfile(home,'OneDrive','Downloads');
end
if ~isfolder(root)
    error('Downloads folder not found. Edit root on line 29 to your real Downloads path.');
end
% Do NOT assume an old DOD SAFE folder still exists or was extracted twice.
% Search likely locations for the actual .set files; ask ONCE only if absent.
searchRoots={root,fullfile(home,'Desktop'),fullfile(home,'Documents'), ...
    fullfile(home,'OneDrive','Desktop'),fullfile(home,'OneDrive','Documents')};
eegFolder='';
for ri=1:numel(searchRoots)
    if ~isfolder(searchRoots{ri}),continue;end
    candidates=dir(fullfile(searchRoots{ri},'**','D*_B*_T*_ICApruned.set'));
    if ~isempty(candidates)
        folders=unique(string({candidates.folder}));
        counts=zeros(numel(folders),1);
        for ci=1:numel(folders)
            counts(ci)=sum(strcmp(string({candidates.folder}),folders(ci)));
        end
        [bestCount,best]=max(counts);
        if bestCount>=10
            eegFolder=char(folders(best));
            break;
        end
    end
end
if isempty(eegFolder)
    eegFolder=uigetdir(root,'Select folder containing the D*_B*_T*_ICApruned.set EEG files');
    if isequal(eegFolder,0),error('EEG folder not selected.');end
end
files=dir(fullfile(eegFolder,'D*_B*_T*_ICApruned.set'));
assert(~isempty(files),'No matching .set files in selected folder: %s',eegFolder);
[~,ord]=sort({files.name}); files=files(ord);
RawEEGFiles=files; % IMMUTABLE source list: downstream Frontal14 reuses variable 'files' for XLSX
fprintf('FOUND EEG FOLDER: %s\nRECORDINGS: %d\n',eegFolder,numel(files));


% FIXED CORRECTED-MDEA PARAMETERS (not the reconstructed MDEAGPT method).
P=struct();
% Randomize illustrative examples on every run; numerical analyses remain deterministic
% because their inferential routines use the fixed Robust/Omnibus/Sweep seeds below.
rng('shuffle');
P.WindowSeconds=6.4; P.Overlap=.50; % PRIMARY geometry and pilot
P.StripeWidth=.18; % CENTRAL/PRIMARY stripe; fraction of min-max normalized [0,1] window
P.Rule=1; P.ST=.20; P.EN=.80; P.BatchPlot=0; P.PilotPlot=1;
P.MinimumPilotFiniteFraction=0.80;
P.PilotFiles=1; P.PilotChannels={'F3','Cz','O1'};
P.PlotDPI=600; P.PaperDPI=600; P.MaxWorkers=[]; P.SaveXLSX=true;
P.Provenance='USER-SUPPLIED MDEAcorrected.m; input EEG window; CENTRAL/PRIMARY stripesize=0.18; rule=1; ST=0.2; EN=0.8; batch PLOT=0; pilot PLOT=1';
P.SweepWindowSeconds=[3.2 6.4 9.6]; % all three durations treated symmetrically
P.SweepOverlaps=[0 .50 .75];
P.SweepMaxFiles=4; P.SweepMaxWindowsPerFile=24; % contiguous, centered pilot segment
P.SweepChannels={'FT7','F3','C3','O1'};
P.SweepNSurrogates=100; P.SweepSeed=240924;
P.RunSensitivitySweep=true;
P.RunFullCohortRobustness=true; % all recordings, five-group networks, all nine geometries
P.RobustNSurrogates=2000; % final paper analysis; finite-shift exact null below
P.RobustSeed=240924; P.RobustMinShiftSeconds=30;
P.RobustMinSamples=8; P.RobustAlpha=.05; % short nonoverlap windows retained; surrogate p may be unresolved
P.RunListeningReference=false;      % intentionally excluded from paper analysis
P.RunSignedCSControl=false;         % signed CS is now the PRIMARY analysis below, not a sensitivity control
P.RunTemporalHFProxy=false;         % intentionally excluded from paper analysis
P.TemporalHFHz=[30 45];             % retained only for backward-compatible unused helper code
P.OmnibusPermutations=2000; P.OmnibusSeed=260925; % musician-level paired network test
% DISABLED: supplementary stripe sensitivity is handled by the separate pipeline.
% Central/primary stripe 0.18 is REUSED from the nine-geometry main run, not recomputed.
P.RunStripeSensitivity=strcmpi(string(purpose),"supplement"); % S04 only in supplementary run
P.StripeSweep=[.15 .18 .20]; % predeclared matched robustness, not tuned by significance
P.StripeSweepWindowSeconds=6.4; P.StripeSweepOverlap=.50;
% Stripe choice is diagnosed numerically, NOT by task p-values: fit R2,
% finite-delta fraction, event density/count, and delta-trajectory variability.
P.GeneratePaperFigures=strcmpi(string(purpose),"main");
P.EssentialFiguresOnly=true;
% Random observed-example selection for paper Figures 2 and 3.
% A fresh seed is generated on every run, so the displayed MDEA example and
% scaling-trajectory/CS example are randomly selected from eligible observed data.
% The examples are illustrative only and are not used for inferential statistics.
P.RandomizeObservedExamples=true;
P.RandomExampleSeed=mod(floor(posixtime(datetime('now'))*1e6),2^32-1);
rng(P.RandomExampleSeed,'twister'); % publication pack only: no exhaustive per-geometry/per-task figure pages

% Conventional EEG benchmark: frequency-specific Phase-Locking Value (PLV).
% PLV is computed from the same five A/F/M/P/O regional EEG signals and the
% same physical windows used by each CS geometry. It is NOT computed from
% delta(t). Standard bands are pre-specified rather than selected by results.
P.RunPLVComparison=true;
P.PLVBands=[4 8; 8 13; 13 30];
P.PLVBandNames={'Theta','Alpha','Beta'};
P.PLVFilterOrder=2; % butter(...,'bandpass'); forward-backward filtfilt

% Additional conventional EEG connectivity controls from the earlier benchmark.
% Numerical spectral controls retained (no supplementary figures): magnitude-squared coherence,
% absolute imaginary coherence, and debiased wPLI (dwPLI), all in 8-30 Hz.
% manuscript 9.6-s / 75%%-overlap geometry, 2-s Hann-tapered segments, 50%%
% segment overlap, and require at least five segments. dwPLI is NOT clamped;
% finite-sample debiased estimates may be negative.
P.RunSpectralComparators=true;
P.SpectralBandHz=[8 30];
P.SpectralWindowSeconds=9.6;
P.SpectralWindowOverlap=.75;
P.SpectralSegmentSec=2;
P.SpectralSegmentOverlap=.50;
P.MinSpectralSegments=5;


stamp=datestr(now,'yyyymmdd_HHMMSS'); OUT=fullfile(root,['Music2_CORRECTED_MDEA_' stamp]);
mkdir(OUT); pilotDir=fullfile(OUT,'PILOT'); mkdir(pilotDir);
figDir=fullfile(OUT,'FIGURES'); mkdir(figDir);
mkdir(fullfile(figDir,'MAIN'));
mkdir(fullfile(figDir,'MAIN','JPG_600DPI'));
mkdir(fullfile(figDir,'MAIN','VECTOR_PDF'));
matDir=fullfile(OUT,'MAT_TRAJECTORIES'); mkdir(matDir);
xlsDir=fullfile(OUT,'DELTA_XLSX_FOR_CS'); mkdir(xlsDir);
diary(fullfile(OUT,'RUN_LOG.txt'));diary on;
fprintf('EEG: %s\nOUT: %s\nFiles: %d\n',eegFolder,OUT,numel(files));
fid=fopen(fullfile(OUT,'WHERE_OUTPUT_IS_SAVED.txt'),'w');
fprintf(fid,'EEG source: %s\nOutput folder: %s\n',eegFolder,OUT);fclose(fid);
fprintf('Corrected MDEAcorrected.m is the ONLY scaling estimator; window min-max normalization is inside MDEA.\n');
fprintf('IMPORTANT: 4-file window sweep is exploratory numerical QC, not full-cohort physiological validation.\n');
music2_mdea_selftest(P,OUT); % numerical smoke tests before expensive batch
if P.RunSensitivitySweep
    music2_window_overlap_sweep(files,P,OUT);
end

%% PILOT: corrected MDEA plots (PLOT=1); all other MDEA calls use PLOT=0
approved=false; iteration=0;
while ~approved
    iteration=iteration+1;
    fprintf('\nPILOT %d: CORRECTED MDEA, stripe=%.3g of [0,1], Rule=%d, ST=%.2f, EN=%.2f\n', ...
        iteration,P.StripeWidth,P.Rule,P.ST,P.EN);
    pilotIter=fullfile(pilotDir,sprintf('ITER_%02d',iteration)); mkdir(pilotIter);
    nPilot=min(P.PilotFiles,numel(files));
    pilotOrder=randperm(numel(files),nPilot);
    for pf=1:nPilot
        f=pilotOrder(pf);
        fn=fullfile(files(f).folder,files(f).name);
        [data,fs,~,loc,~]=read_set_file(fn);
        assert(size(data,3)==1,'Expected continuous EEG: %s',files(f).name);
        labels=string({loc.labels}); labels=labels(:);
        nwin=round(P.WindowSeconds*fs);
        assert(size(data,2)>=nwin,'Short EEG file: %s',files(f).name);
        availablePilot=[];
        for pc=1:numel(P.PilotChannels)
            hit=find(strcmpi(labels,P.PilotChannels{pc}),1);
            if ~isempty(hit),availablePilot(end+1)=hit;end %#ok<AGROW>
        end
        availablePilot=unique(availablePilot,'stable');
        if isempty(availablePilot),continue;end
        availablePilot=availablePilot(randperm(numel(availablePilot)));
        for c=1:numel(availablePilot)
            ch=availablePilot(c);
            maxStart=size(data,2)-nwin+1;
            startSample=randi(maxStart);
            w=double(data(ch,startSample:startSample+nwin-1,1));
            % THIS is the actual user's MDEA plotting its own signal/entropy.
            figBefore=findall(groot,'Type','figure');
            [delta,~]=musicCorrectedMDEAwindow(w,P,1);
            figAfter=findall(groot,'Type','figure');
            newFigs=figAfter(~ismember(figAfter,figBefore));
            if isempty(newFigs)
                warning('No corrected-MDEA pilot figure for %s %s (delta=%g).',files(f).name,labels(ch),delta);
                continue;
            end
            base=fullfile(pilotIter,sprintf('%s_%s',erase(files(f).name,'.set'),labels(ch)));
            for kk=1:numel(newFigs)
                fig=newFigs(kk);
                sgtitle(fig,sprintf('CORRECTED MDEA | %s | %s | fs=%g Hz | delta=%.4g', ...
                    files(f).name,labels(ch),fs,delta),'Interpreter','none');
                % Match pilot/MDEA figure typography to the publication figures.
                music2_apply_paper_typography(fig);
                exportgraphics(fig,[base '.png'],'Resolution',P.PlotDPI);
                exportgraphics(fig,[base '.pdf'],'ContentType','vector');
            end
            save([base '.mat'],'w','fs','delta','P');
        end
    end
    save(fullfile(pilotIter,'PILOT_SETTINGS.mat'),'P');
    fprintf('\nPILOT FIGURES: %s\n',pilotIter);
    [pilotResult,~]=processEEGfile(fullfile(files(1).folder,files(1).name),P);
    pilotFlags=isfinite(pilotResult.Trajectories{:,2:end});
    pilotValid=mean(pilotFlags(:));
    fprintf('Pilot finite delta fraction (all channels/windows): %.3f\n',pilotValid);
    if pilotValid<P.MinimumPilotFiniteFraction
        warning('Only %.1f%% pilot delta values finite. Corrected MDEA recommends ~30,000 samples; current window is %d samples.', ...
            100*pilotValid,nwin);
    end
    choice=questdlg('Accept CORRECTED MDEA and these window settings for ALL EEG files?', ...
        'Corrected MDEA pilot approval','Approve','Change minimum finite fraction','Cancel','Approve');
    if isempty(choice)||strcmp(choice,'Cancel')
        error('MDEA batch cancelled. Pilot figures remain saved.');
    elseif strcmp(choice,'Approve')
        approved=true;
    else
        P.MinimumPilotFiniteFraction=askNumber('Minimum finite fraction (0-1)',P.MinimumPilotFiniteFraction,0,1);
    end
end
assert(P.StripeWidth==.18 && P.Rule==1 && P.ST==.2 && P.EN==.8 && P.BatchPlot==0 && P.PilotPlot==1, ...
    'Required corrected MDEA settings were modified.');
assert(all(P.SweepWindowSeconds>=3.2 & P.SweepWindowSeconds<=9.6), ...
    'Window sweep must stay within 3.2-9.6 seconds.');
assert(ismember(P.WindowSeconds,P.SweepWindowSeconds), ...
    'Illustrative pilot window must belong to full nine-geometry grid.');
save(fullfile(OUT,'APPROVED_PARAMETERS.mat'),'P','eegFolder');
fid=fopen(fullfile(OUT,'PARAMETER_PROVENANCE.txt'),'w');
fprintf(fid,'%s\n',P.Provenance);
fprintf(fid,'MDEA file resolved: %s\n',which('MDEAcorrected'));
fprintf(fid,'Pilot window %.6g sec; overlap %.6g; min-max normalization INSIDE corrected MDEA\n', ...
    P.WindowSeconds,P.Overlap);
fprintf(fid,'All PRIMARY batch calls: MDEAcorrected(EEGwindow,%.2f,1,0.2,0.8,0). Pilot sample plots: PLOT=1.\n',P.StripeWidth);
fprintf(fid,'Corrected MDEA recommends ~30000 samples; geometry windows may be shorter.\n');
fclose(fid);

%% MAIN PAPER ANALYSIS: NINE EQUAL-STATUS MDEA GEOMETRIES
% Primary paper figures/inference use 6.4 s / 50%; nine geometries retained as sensitivity.
mainPDF=fullfile(figDir,'MAIN','MAIN_FIGURES.pdf');
if P.RunFullCohortRobustness
    % Figure M1: observed MDEA method example (raw signal/event/entropy-fit panels generated by MDEAcorrected).
    if P.GeneratePaperFigures
        music2_export_mdea_method_figure(RawEEGFiles,P,mainPDF);
    end
    music2_full_cohort_robustness(RawEEGFiles,P,OUT,'',mainPDF);
end
% Only the main entrypoint exports main-paper figures.
if P.GeneratePaperFigures
    assert(isfile(mainPDF),'Main-figure PDF was not created.');
    music2_write_figure_index(figDir,mainPDF);
end
if P.RunStripeSensitivity
    music2_stripe_sensitivity(RawEEGFiles,P,OUT,'');
    unified_matched_stripe_figures(OUT,P);
end
if P.GeneratePaperFigures
    fprintf('MAIN FIGURES: %s\n',mainPDF);
else
    fprintf('SUPPLEMENT numerical source: %s\n',OUT);
end
diary off;

% Its helper functions remain below for provenance, but no privileged-window
% statistics, paper figures or delta XLSX are generated by this script.


end % unifiedMusicMain

function v=askNumber(label,old,lo,hi)
 s=strtrim(input(sprintf('%s [%.6g]: ',label,old),'s'));
 if isempty(s),v=old;return;end
 v=str2double(s);assert(isfinite(v)&&v>lo&&v<=hi,'Invalid value for %s',label);
end
function closeWaitbar(h)
 if isgraphics(h),close(h);end
end
function s=fmtTime(sec)
 sec=max(0,round(sec));s=sprintf('%02d:%02d:%02d',floor(sec/3600),mod(floor(sec/60),60),mod(sec,60));
end
function [A,err]=processEEGfile(path,P)
 err='';[~,fname,~]=fileparts(path);
 tok=regexp(fname,'^D(\d+)_B(\d+)_T(\d+)_ICApruned$','tokens','once','ignorecase');
 assert(~isempty(tok),'Unexpected file name: %s',fname);
 d=str2double(tok{1});m=str2double(tok{2});task=str2double(tok{3});
 [data,fs,~,loc,~]=read_set_file(path);
 assert(size(data,3)==1,'Expected continuous single-trial EEG.');
 assert(isfinite(fs)&&fs>0,'Invalid fs.');
 assert(isstruct(loc)&&isfield(loc,'labels'),'Missing EEG channel labels.');
 labels=string({loc.labels});labels=labels(:);
 win=round(P.WindowSeconds*fs);step=max(1,round(win*(1-P.Overlap)));
 starts=1:step:(size(data,2)-win+1);assert(~isempty(starts),'EEG shorter than window.');
 t=(0:size(data,2)-1)/fs; %#ok<NASGU> % requested seconds convention
 timeSec=((starts-1)+(win-1)/2)/fs;
 delta=nan(numel(starts),size(data,1));r2=delta;nevents=delta;
 for ch=1:size(data,1)
     x=double(data(ch,:,1));
     for wi=1:numel(starts)
         [delta(wi,ch),D]=musicCorrectedMDEAwindow(x(starts(wi):starts(wi)+win-1),P);
         r2(wi,ch)=D.R2;nevents(wi,ch)=D.NumEvents;
     end
 end
 T=table(timeSec(:),'VariableNames',{'t'});
 for ch=1:numel(labels)
     label=matlab.lang.makeValidName(char(labels(ch)));
     if ismember(label,T.Properties.VariableNames),label=sprintf('%s_%d',label,ch);end
     T.(label)=delta(:,ch);
 end
 A=struct('SourceFile',[fname '.set'], ...
     'OutputFile',sprintf('D%d_T%d_M%d_delta_9600ms.xlsx',d,task,m), ...
     'Trajectories',T,'Labels',labels,'Fs',fs,'WindowStarts',starts, ...
     'TimeSeconds',timeSec,'R2',r2,'EventCount',nevents, ...
     'nChannels',numel(labels),'nWindows',numel(starts));
end
function [delta,D]=musicCorrectedMDEAwindow(w,P,plotFlag)
% The ONLY scaling estimator is the user's corrected event-started MDEAcorrected.m.
% Its Info structure supplies real fit R2 and stripe-transition event counts.
% Every diffusion displacement starts at a detected stripe-transition event.
if nargin<3,plotFlag=0;end
w=double(w(:));
D=struct('R2',NaN,'NumEvents',0,'events',zeros(numel(w),1));
delta=NaN;
if numel(w)<16 || any(~isfinite(w)) || max(w)==min(w)
    return;
end
try
    [delta,Info]=MDEAcorrected(w,P.StripeWidth,P.Rule,P.ST,P.EN,plotFlag);
    if isstruct(Info)
        if isfield(Info,'R2'), D.R2=Info.R2;end
        if isfield(Info,'NumEvents'), D.NumEvents=Info.NumEvents;end
        if isfield(Info,'Event') && ~isempty(Info.Event)
            D.events=Info.Event(:);
        end
    end
catch ME
    % Do not substitute another estimator if corrected MDEA cannot fit a window.
    if plotFlag==1
        warning('MDEAcorrected failed for sample plot: %s',ME.message);
    else
        persistent warned
        if isempty(warned),warned=false;end
        if ~warned
            warning('MDEAcorrected failed on a window: %s. Returning NaN.',ME.message);
            warned=true;
        end
    end
    delta=NaN;
end
if ~isscalar(delta)||~isreal(delta)||~isfinite(delta),delta=NaN;end
end

function progressWaitbar(k,wb,clock0,n)
 persistent completed
 if isempty(k),completed=0;return;end
 if isempty(completed),completed=0;end
 completed=completed+1;elapsed=toc(clock0);eta=elapsed/max(completed,1)*(n-completed);
 msg=sprintf('MDEA %d/%d | elapsed %s | ETA %s',completed,n,fmtTime(elapsed),fmtTime(eta));
 fprintf('%s: %s\n',msg,num2str(k));
 if isgraphics(wb),waitbar(completed/n,wb,msg);end
end

function X = select_paper_cs_example(Results,EEGGroupNames,Alpha)
% Select a REAL auditory-centered example for the explanatory CS figure.
% and choose the reliable/significant example with |CS| closest to 0.80.
X=table();
if isempty(Results), return; end

isBrain = ismember(Results.Feature1,EEGGroupNames) & ismember(Results.Feature2,EEGGroupNames);
% Results contains symmetric maps; keep one orientation robustly by indices.
isUnique = Results.Feature1_Index < Results.Feature2_Index;
Q=Results(isBrain & isUnique & isfinite(Results.CS),:);
if isempty(Q), return; end

targetCS=0.80;
isAud = strcmp(Q.Feature1,'Auditory') | strcmp(Q.Feature2,'Auditory');
A=Q(isAud,:);

% Prefer a temporal-centered example near |CS| = 0.80 so Figure 1 remains
% aligned with the auditory-system interpretation after hemispheric splitting.
if isempty(A), A=Q; end

sig=A.Reliable & isfinite(A.p_eff_int) & A.p_eff_int < Alpha;
if any(sig)
    C=A(sig,:);
elseif any(A.Reliable)
    C=A(A.Reliable,:);
else
    C=A;
end
[~,ix]=min(abs(abs(C.CS)-targetCS));
X=C(ix,:);
end

function plot_paper_cs_example(X,MapStore,EEGGroupNames,CorrelationMethod)
subject=char(string(X.Subject(1)));
task=char(string(X.Task(1)));
f1=char(string(X.Feature1(1)));
f2=char(string(X.Feature2(1)));
cs=X.CS(1); p=X.p_eff_int(1);
m=find(strcmp({MapStore.Subject},subject) & strcmp({MapStore.Task},task),1);
if isempty(m), error('Selected CS example not found in MapStore.'); end
labels=cellstr(string(MapStore(m).groupLabels1));
i1=find(strcmp(labels,f1),1); i2=find(strcmp(labels,f2),1);
if isempty(i1)||isempty(i2), error('Selected CS-example groups are missing from MapStore.'); end
x=MapStore(m).G(i1,:)'; y=MapStore(m).G(i2,:)';
if isfield(MapStore,'timeVec') && ~isempty(MapStore(m).timeVec), tt=MapStore(m).timeVec(:); else, tt=(1:min(numel(x),numel(y)))'; end
n=min([numel(tt),numel(x),numel(y)]); tt=tt(1:n); x=x(1:n); y=y(1:n);
ok=isfinite(tt)&isfinite(x)&isfinite(y); tt=tt(ok); x=x(ok); y=y(ok);
ax=axes; hold(ax,'on'); box(ax,'on');
plot(ax,tt,x,'LineWidth',2.4); plot(ax,tt,y,'LineWidth',2.4);
xlabel(ax,'Slice #'); ylabel(ax,'Scaling exponent \delta(t)');
legend(ax,{display_group_name(f1),display_group_name(f2)},'Interpreter','none','Location','best','FontSize',28);
title(ax,sprintf('Scaling-exponent time series   CS = %.3f, p %s',cs,format_pvalue(p)),'FontWeight','bold','FontSize',18);
end

function s=format_pvalue(p)
if ~isfinite(p), s='= n/a';
elseif p<0.001, s='< 0.001';
else, s=sprintf('= %.3f',p);
end
end


function plot_t00_reference_network_v25(Results,t0,EEGGroups)
pairs=nchoosek(1:numel(EEGGroups),2); np=size(pairs,1); w=nan(np,1);
for e=1:np
 a=EEGGroups{pairs(e,1)}; b=EEGGroups{pairs(e,2)};
 z=Results(strcmp(Results.Task,t0) & ((strcmp(Results.Feature1,a)&strcmp(Results.Feature2,b)) | (strcmp(Results.Feature1,b)&strcmp(Results.Feature2,a))),:);
 v=z.CS(isfinite(z.CS)); w(e)=mean(v,'omitnan');
end
th=linspace(pi/2,pi/2+2*pi,numel(EEGGroups)+1); th(end)=[]; pos=[cos(th(:)) sin(th(:))];
ax=axes; hold(ax,'on'); axis(ax,'equal'); axis(ax,'off'); title(ax,'Rest: within-brain functional Complexity Synchronization','FontWeight','bold','FontSize',18);
for e=1:np
 i=pairs(e,1); j=pairs(e,2); if ~isfinite(w(e)),continue;end
 lw=.35+7.65*min(abs(w(e)),1); if w(e)<0,col=[.88 .08 .08];else,col=[0 0 0];end
 plot(ax,pos([i j],1),pos([i j],2),'-','Color',col,'LineWidth',lw);
 mid=mean(pos([i j],:),1);
 if abs(pos(i,1)-pos(j,1))<.15, mid(2)=mid(2)+.22; elseif abs(pos(i,2)-pos(j,2))<.15, mid(1)=mid(1)+.28; end
 text(ax,mid(1),mid(2),sprintf('%.2f',w(e)),'FontSize',24,'HorizontalAlignment','center','BackgroundColor','w','Margin',1);
end
scatter(ax,pos(:,1),pos(:,2),110,'filled','MarkerFaceColor',[0.95 0.05 0.50],'MarkerEdgeColor','k','LineWidth',1,'Tag','KMNetworkNode');
for i=1:numel(EEGGroups)
 p=1.19*pos(i,:); if abs(pos(i,2))<.20,p(2)=p(2)+.12;end
 text(ax,p(1),p(2),short_one(EEGGroups{i}),'FontSize',24,'FontWeight','bold','HorizontalAlignment','center');
end
xlim(ax,[-1.58 1.72]); ylim(ax,[-1.45 1.45]);
add_vertical_thickness_key(ax,[0 .25 .50 .75 1],1,'|CS|',[1.28 .82]);
end

function q=bh_fdr_vector_v25(p)
q=nan(size(p));ii=find(isfinite(p));if isempty(ii),return;end
[ps,o]=sort(p(ii));m=numel(ps);a=ps(:).*m./(1:m)';
a=flipud(cummin(flipud(a)));a=min(a,1);q(ii(o))=a;
end

function S = summarize_channel_coverage_qc(C, groupNames, taskList)
% All-trial and per-task coverage summaries; do not conflate file counts
% with independent musicians (Subject is a participant-context identifier).
S = table();
if isempty(C), return; end
for g = 1:numel(groupNames)
    group = groupNames{g};
    for t = 0:numel(taskList)
        if t == 0
            task = 'ALL';
            ix = strcmp(C.EEGGroup,group);
        else
            task = taskList{t};
            ix = strcmp(C.EEGGroup,group) & strcmp(C.Task,task);
        end
        R = C(ix,:);
        if isempty(R), continue; end
        counts = double(R.FoundChannels);
        included = logical(R.Included);
        good = counts(included);
        if isempty(good)
            medianGood = NaN; minGood = NaN; maxGood = NaN;
        else
            medianGood = median(good);
            minGood = min(good); maxGood = max(good);
        end
        row = table({task},{group},R.ExpectedChannels(1),R.RequiredChannels(1), ...
            height(R),numel(unique(R.Subject)),sum(included),sum(~included), ...
            median(counts),min(counts),max(counts),medianGood,minGood,maxGood, ...
            'VariableNames',{'Task','EEGGroup','NominalChannels','MinimumRequired', ...
            'NFiles','NUniqueParticipantContexts','NIncludedFiles','NExcludedFiles', ...
            'MedianFound','MinFound','MaxFound','MedianIncluded','MinIncluded','MaxIncluded'});
        S = [S;row]; %#ok<AGROW>
    end
end
end

function write_frontal14_reporting_notes(outputFolder, C, S)
% Reporting notes, not an automatic inference about the reasons for absent edges.
path = fullfile(outputFolder,'FRONTAL14_METHODS_AND_QC_NOTES.txt');
fid = fopen(path,'w');
if fid < 0, warning('Could not write coverage notes: %s',path); return; end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'FINAL FIVE-NODE MUSIC-FUNCTIONAL ANALYSIS: METHODS AND QC NOTES\n');
fprintf(fid,'=========================================\n\n');
fprintf(fid,'Node definitions: A=6, F=14, M=11, P=13, O=7 (51 nominal electrodes).\n');
fprintf(fid,'F: AF3 AF4 AF7 AF8 AFz F1 F2 F3 F4 F5 F6 F7 F8 Fz.\n');
fprintf(fid,'Each node is retained only if at least max(2,ceil(0.30*nominal channels))\n');
fprintf(fid,'columns are found and its averaged trajectory has finite values.\n');
fprintf(fid,'Actual per-file membership is in BrainCS_analysis.xlsx / ChannelCoverage.\n');
fprintf(fid,'Summary by group and task is in CoverageSummary and CSV.\n');
fprintf(fid,'An absent A edge in an individual network can reflect missing/invalid group\n');
fprintf(fid,'coverage; inspect ChannelCoverage before attributing the reason.\n\n');
fprintf(fid,'Primary comparisons are each musical task versus Rest; no direct task-discrimination tests are reported.\n');
fprintf(fid,'WeightedNetworkT0 and M1M2_Similarity_T0; do not use raw file count.\n');
fprintf(fid,'One musician appears in two dyads; dyad and participant-context\n');
fprintf(fid,'observations should not automatically be described as independent people.\n\n');
fprintf(fid,'Statistical interpretation: complete-case Friedman omnibus and paired\n');
fprintf(fid,'Rest-referenced contrasts answer different questions. Report both.\n');
fprintf(fid,'FDR for edges is across six task contrasts within each connection,\n');
fprintf(fid,'with no additional all-edge correction in this run; state the family explicitly.\n');
fprintf(fid,'Frontal grouping was refined after examining exploratory results;\n');
fprintf(fid,'do not describe it as a prospectively frozen confirmatory parcellation.\n');
fprintf(fid,'Dyadic fingerprint convergence compares WITHIN-brain networks of partners;\n');
fprintf(fid,'it is not direct interbrain Complexity Synchronization.\n\n');
fprintf(fid,'QC: total group x file rows = %d; excluded rows = %d.\n',height(C),sum(~C.Included));
for i=1:height(S)
 if strcmp(S.Task{i},'ALL')
  fprintf(fid,'%s: nominal=%d, required=%d, found median=%g range=[%g,%g], included=%d/%d files.\n', ...
   S.EEGGroup{i},S.NominalChannels(i),S.MinimumRequired(i),S.MedianFound(i), ...
   S.MinFound(i),S.MaxFound(i),S.NIncludedFiles(i),S.NFiles(i));
 end
end
end

function [G, groupLabelsOut, groupSourceLabels, groupCounts, timeVec, coverageTable, hasAmplColumn, hasUsableAmpl] = ...
    read_km_multimodal_scaling_series(filename, EEGGroupNames, ExtraGroupNames, ...
    MinChannelsPerGroupAbsolute, MinFractionChannelsPerGroup)

    T = readtable(filename, 'VariableNamingRule', 'preserve');
    varNames = T.Properties.VariableNames;
    lowerNames = lower(varNames);

    timeVec = [];
    tIdx = find(strcmpi(varNames, 't') | strcmpi(varNames, 'time'), 1);
    if ~isempty(tIdx) && isnumeric(T{:,tIdx})
        timeVec = double(T{:,tIdx});
    end

    % Music amplitude is OPTIONAL and is detected strictly from the header.
    amplIdx = find(strcmpi(varNames,'Ampl') | strcmpi(varNames,'Amp') | strcmpi(varNames,'Amplitude'),1);
    hasAmplColumn = ~isempty(amplIdx);
    hasUsableAmpl = hasAmplColumn && isnumeric(T{:,amplIdx}) && any(isfinite(double(T{:,amplIdx}))) ...
        && std(double(T{:,amplIdx}),'omitnan') > 0;

    nEEG = numel(EEGGroupNames);
    nTime = height(T);
    Gtmp = nan(nEEG, nTime);
    srcTmp = cell(nEEG,1);
    cntTmp = zeros(nEEG,1);

    expectedCounts = functional_group_expected_counts(EEGGroupNames);
    requiredCounts = max(MinChannelsPerGroupAbsolute, ceil(MinFractionChannelsPerGroup .* expectedCounts));

    reserved = ismember(lowerNames, {'t','time','pitch','ampl','amp','amplitude','ecg','resp','respiration'});
    colGroups = cell(size(varNames));
    for c = 1:numel(varNames)
        if reserved(c) || ~isnumeric(T{:,c})
            colGroups{c} = 'Other';
        else
            colGroups{c} = get_channel_group(varNames{c});
        end
    end

    for g = 1:nEEG
        idx = strcmp(colGroups, EEGGroupNames{g});
        cntTmp(g) = sum(idx);
        srcTmp{g} = strjoin(varNames(idx), ', ');
        if cntTmp(g) >= requiredCounts(g)
            X = double(T{:,idx});
            Gtmp(g,:) = mean(X, 2, 'omitnan')';
        end
    end

    keepEEG = cntTmp >= requiredCounts(:) & any(isfinite(Gtmp),2);
    G = Gtmp(keepEEG,:);
    groupLabelsOut = EEGGroupNames(keepEEG)';
    groupSourceLabels = srcTmp(keepEEG);
    groupCounts = cntTmp(keepEEG);

    coverageTable = table(EEGGroupNames(:), expectedCounts(:), cntTmp(:), requiredCounts(:), ...
        cntTmp(:)./expectedCounts(:), keepEEG(:), srcTmp(:), ...
        'VariableNames', {'EEGGroup','ExpectedChannels','FoundChannels','RequiredChannels', ...
        'CoverageFraction','Included','SourceLabels'});

    for e = 1:numel(ExtraGroupNames)
        nm = ExtraGroupNames{e};
        switch nm
            case 'ECG'
                idx = find(strcmpi(varNames,'ECG'),1);
            case 'RESP'
                idx = find(strcmpi(varNames,'RESP') | strcmpi(varNames,'Respiration'),1);
            case 'Ampl'
                idx = amplIdx;
            otherwise
                idx = [];
        end
        if ~isempty(idx) && isnumeric(T{:,idx})
            x = double(T{:,idx})';
            if any(isfinite(x)) && std(x,'omitnan') > 0
                G(end+1,:) = x; %#ok<AGROW>
                groupLabelsOut{end+1,1} = nm; %#ok<AGROW>
                groupSourceLabels{end+1,1} = varNames{idx}; %#ok<AGROW>
                groupCounts(end+1,1) = 1; %#ok<AGROW>
            end
        end
    end
end

function expectedCounts = functional_group_expected_counts(EEGGroupNames)
    expectedCounts = zeros(1,numel(EEGGroupNames));
    for i = 1:numel(EEGGroupNames)
        switch EEGGroupNames{i}
            case 'Auditory',              expectedCounts(i)=6;
            case 'Frontal-Executive',     expectedCounts(i)=14;
            case 'Sensorimotor',          expectedCounts(i)=11;
            case 'Parietal',              expectedCounts(i)=13;
            case 'Occipital',             expectedCounts(i)=7;
            otherwise,                    expectedCounts(i)=1;
        end
    end
end

function save_single_km_subject_maps(dataFolder, subjectName, taskName, dyadName, participantName, CSmap, Relmap, Pmap, Neffmap, groupLabels, groupSourceLabels, groupCounts, G, timeVec)
    outName = fullfile(dataFolder, sprintf('%s_%s_within_subject_KM_multimodal_maps.mat', subjectName, taskName));
    save(outName, 'CSmap', 'Relmap', 'Pmap', 'Neffmap', 'groupLabels', 'groupSourceLabels', 'groupCounts', 'G', 'timeVec', 'subjectName', 'dyadName', 'participantName', 'taskName');
end

function statusText = parallel_status_string(UseParallel)
    if UseParallel
        statusText = 'PARFOR';
    else
        statusText = 'serial FOR';
    end
end


function [CS, reliable, p_eff_int, Neff_int, N, p_circshift, p_phase, CI_low, CI_high] = ...
    run_one_subject_pair(p, G, nG, PLOT, NSurr, NBoot, Alpha, MinNeff, Strength, SkipSelfPairs, UseDeltaDiffForCS, CorrelationMethod)

    [g1, g2] = ind2sub([nG, nG], p);

    CS = NaN;
    reliable = false;
    p_eff_int = NaN;
    Neff_int = NaN;
    N = NaN;
    p_circshift = NaN;
    p_phase = NaN;
    CI_low = NaN;
    CI_high = NaN;

    % Do not test a feature against itself. It would trivially give CS = 1.
    if SkipSelfPairs && g1 == g2
        return;
    end

    [CS, reliable, p_eff_int, Neff_int, N, p_circshift, p_phase, CI_low, CI_high] = ...
        run_one_group_pair(p, G, G, nG, PLOT, NSurr, NBoot, Alpha, MinNeff, Strength, UseDeltaDiffForCS, CorrelationMethod);

end

function [CS, reliable, p_eff_int, Neff_int, N, p_circshift, p_phase, CI_low, CI_high] = ...
    run_one_group_pair(p, G1, G2, nG1, PLOT, NSurr, NBoot, Alpha, MinNeff, Strength, UseDeltaDiffForCS, CorrelationMethod)

    % Convert linear index to group indices.
    [g1, g2] = ind2sub([nG1, size(G2,1)], p);

    x = G1(g1,:)';
    y = G2(g2,:)';

    ok = isfinite(x) & isfinite(y);
    x = x(ok);
    y = y(ok);

    CS = NaN;
    reliable = false;
    p_eff_int = NaN;
    Neff_int = NaN;
    N = numel(x);
    p_circshift = NaN;
    p_phase = NaN;
    CI_low = NaN;
    CI_high = NaN;

    if numel(x) < 10 || std(x)==0 || std(y)==0
        return;
    end

    % Optional first-difference analysis.
    % This computes CS on changes in scaling exponent rather than on the
    % raw, slowly varying delta(t) trajectories:
    %   ddelta(t) = delta(t+1) - delta(t)
    % It reduces overlap-driven autocorrelation and slow common trends.
    if UseDeltaDiffForCS
        x = diff(x);
        y = diff(y);

        ok = isfinite(x) & isfinite(y);
        x = x(ok);
        y = y(ok);
        N = numel(x);

        if numel(x) < 10 || std(x)==0 || std(y)==0
            return;
        end
    end

    delta1 = x;
    delta2 = y;

    % Spearman CS is Pearson CS after rank transformation.
    % This makes the reliability test evaluate rank-based CS as well.
    if strcmpi(CorrelationMethod, 'Spearman')
        [delta1, delta2] = paired_rank_transform(delta1, delta2);
    end

    R = CS_reliability_test_scaling_series_Strength( ...
        delta1, delta2, PLOT, ...
        'NSurr', NSurr, ...
        'NBoot', NBoot, ...
        'Alpha', Alpha, ...
        'MinNeff', MinNeff, ...
        'Strength', Strength);

    CS = R.CS;
    reliable = R.reliable;
    p_eff_int = R.p_eff_int;
    Neff_int = R.Neff_int;
    N = R.N;
    p_circshift = R.p_circshift;
    p_phase = R.p_phase;
    CI_low = R.CI_block(1);
    CI_high = R.CI_block(2);

end

function [X, labels] = read_channel_scaling_series(filename)

    T = readtable(filename, 'VariableNamingRule', 'preserve');

    labels = cell(height(T),1);

    % Try to get channel labels from first nonnumeric/text column.
    gotLabels = false;
    for c = 1:width(T)
        col = T{:,c};
        if iscell(col) || isstring(col) || iscategorical(col)
            labels = cellstr(string(col));
            gotLabels = true;
            break;
        end
    end

    if ~gotLabels
        for i = 1:height(T)
            labels{i} = sprintf('Ch%d', i);
        end
    end

    % Numeric columns are scaling windows.
    isNumCol = false(1,width(T));
    for c = 1:width(T)
        isNumCol(c) = isnumeric(T{:,c});
    end

    X = T{:,isNumCol};
    X = double(X);

    if isempty(X)
        error('No numeric scaling columns found in %s', filename);
    end

    % Expected orientation:
    % rows = EEG channels
    % columns = scaling time windows.
    if size(X,1) < 2 || size(X,2) < 10
        warning('Unusual size in %s: rows=%d, columns=%d', filename, size(X,1), size(X,2));
    end

end

function [G, groupLabelsOut, groupChannelLabels, groupCounts] = ...
    average_scaling_by_channel_group(X, labels, GroupNames, MinChannelsPerGroup)

    nGroups = numel(GroupNames);
    nTime = size(X,2);

    Gtmp = nan(nGroups, nTime);
    groupChannelLabelsTmp = cell(nGroups,1);
    groupCountsTmp = zeros(nGroups,1);

    channelGroups = cell(size(labels));
    for i = 1:numel(labels)
        channelGroups{i} = get_channel_group(labels{i});
    end

    for g = 1:nGroups
        idx = strcmp(channelGroups, GroupNames{g});

        groupCountsTmp(g) = sum(idx);
        groupChannelLabelsTmp{g} = strjoin(labels(idx), ', ');

        if groupCountsTmp(g) >= MinChannelsPerGroup
            Gtmp(g,:) = mean(X(idx,:), 1, 'omitnan');
        end
    end

    keep = groupCountsTmp >= MinChannelsPerGroup & any(isfinite(Gtmp),2);

    G = Gtmp(keep,:);
    groupLabelsOut = GroupNames(keep)';
    groupChannelLabels = groupChannelLabelsTmp(keep);
    groupCounts = groupCountsTmp(keep);

end

function groupName = get_channel_group(label)

    % Five-node music-functional model:
    % Auditory / Frontal-Executive / Sensorimotor / Parietal / Occipital.
    L = upper(strtrim(char(label)));
    L = erase(L, ' '); L = erase(L, '-'); L = erase(L, '_');
    if contains(L,'.')
        parts = split(L,'.'); L = parts{1};
    end

    Auditory = {'FT7','FT8','T7','T8','TP7','TP8'};
    FrontalExecutive = {'AF3','AF4','AF7','AF8','AFZ','F1','F2','F3','F4','F5','F6','F7','F8','FZ'};
    Sensorimotor = {'FC1','FC2','FC3','FC4', ...
                    'C1','C2','C3','C4','C5','C6','CZ'};
    Parietal = {'CP1','CP2','CP3','CP4', ...
                'P1','P2','P3','P4','P5','P6','P7','P8','PZ'};
    Occipital = {'PO3','PO4','PO7','PO8','O1','O2','OZ'};

    if ismember(L,Auditory),                   groupName='Auditory';
    elseif ismember(L,FrontalExecutive),       groupName='Frontal-Executive';
    elseif ismember(L,Sensorimotor),           groupName='Sensorimotor';
    elseif ismember(L,Parietal),               groupName='Parietal';
    elseif ismember(L,Occipital),              groupName='Occipital';
    else,                                      groupName='Other';
    end
end

function save_single_channelgroup_maps(dataFolder, dyadName, taskName, ...
    CSmap, Relmap, Pmap, Neffmap, ...
    groupLabels1, groupLabels2, ...
    groupChannelLabels1, groupChannelLabels2, ...
    groupCounts1, groupCounts2, G1, G2)

    outName = fullfile(dataFolder, sprintf('%s_%s_channel_group_maps.mat', dyadName, taskName));

    save(outName, ...
        'CSmap', 'Relmap', 'Pmap', 'Neffmap', ...
        'groupLabels1', 'groupLabels2', ...
        'groupChannelLabels1', 'groupChannelLabels2', ...
        'groupCounts1', 'groupCounts2', ...
        'G1', 'G2');

end

% make_table_page was removed from this figures-only version.

function Mfull = map_to_full_group_matrix(M, labels1, labels2, GroupNames)

    % Expand a possibly smaller group-pair map into the full 5 x 5
    % GroupNames order. This is needed when one participant is missing
    % one or more channel groups.
    nG = numel(GroupNames);
    Mfull = nan(nG,nG);

    labels1 = cellstr(string(labels1));
    labels2 = cellstr(string(labels2));

    for r = 1:numel(labels1)
        rr = find(strcmp(GroupNames, labels1{r}), 1);
        if isempty(rr)
            continue;
        end

        for c = 1:numel(labels2)
            cc = find(strcmp(GroupNames, labels2{c}), 1);
            if isempty(cc)
                continue;
            end

            if r <= size(M,1) && c <= size(M,2)
                Mfull(rr,cc) = M(r,c);
            end
        end
    end

end

function [MeanCS, MeanAbsCS, FracPositive, FracReliable, NMaps] = average_maps_from_store(MapStore, GroupNames, taskFilter)

    nG = numel(GroupNames);
    nMaps = numel(MapStore);

    CSstack = nan(nG,nG,nMaps);
    Relstack = nan(nG,nG,nMaps);
    used = false(nMaps,1);

    for m = 1:nMaps
        % Only average maps from the same task/context.
        if ~strcmp(MapStore(m).Task, taskFilter)
            continue;
        end

        used(m) = true;
        CSstack(:,:,m) = map_to_full_group_matrix(MapStore(m).CSmap, ...
            MapStore(m).groupLabels1, MapStore(m).groupLabels2, GroupNames);
        Relstack(:,:,m) = map_to_full_group_matrix(double(MapStore(m).Relmap), ...
            MapStore(m).groupLabels1, MapStore(m).groupLabels2, GroupNames);
    end

    CSstack = CSstack(:,:,used);
    Relstack = Relstack(:,:,used);

    MeanCS = mean(CSstack, 3, 'omitnan');
    MeanAbsCS = mean(abs(CSstack), 3, 'omitnan');
    NMaps = sum(isfinite(CSstack), 3);
    FracPositive = sum(CSstack > 0, 3) ./ max(1, NMaps);
    FracPositive(NMaps == 0) = NaN;
    FracReliable = sum(Relstack == 1, 3) ./ max(1, NMaps);
    FracReliable(NMaps == 0) = NaN;

end


function T = map_to_table(MeanCS, MeanAbsCS, FracPositive, FracReliable, NMaps, GroupNames, subjectName, taskName)

    nG = numel(GroupNames);
    nRows = nG*nG;

    Feature1 = cell(nRows,1);
    Feature2 = cell(nRows,1);
    meanVals = nan(nRows,1);
    meanAbsVals = nan(nRows,1);
    fracPosVals = nan(nRows,1);
    fracVals = nan(nRows,1);
    nVals = nan(nRows,1);

    row = 0;
    for r = 1:nG
        for c = 1:nG
            row = row + 1;
            Feature1{row} = GroupNames{r};
            Feature2{row} = GroupNames{c};
            meanVals(row) = MeanCS(r,c);
            meanAbsVals(row) = MeanAbsCS(r,c);
            fracPosVals(row) = FracPositive(r,c);
            fracVals(row) = FracReliable(r,c);
            nVals(row) = NMaps(r,c);
        end
    end

    T = table();
    T.Subject = repmat({subjectName}, nRows, 1);
    T.Task = repmat({taskName}, nRows, 1);
    T.Feature1 = Feature1;
    T.Feature2 = Feature2;
    T.Mean_CS = meanVals;
    T.MeanAbs_CS = meanAbsVals;
    T.Frac_Positive = fracPosVals;
    T.Frac_Reliable = fracVals;
    T.Num_Maps = nVals;

end

function plot_four_metric_networks(MeanCS,MeanAbsCS,FracPositive,FracReliable,GroupNames,plotTitle)
% Network replacement for the former four CS heatmaps.
% No color intensity or colorbar is used. Thickness is the metric magnitude.
tl=tiledlayout(1,4,'TileSpacing','compact','Padding','compact');
title(tl,plotTitle,'Interpreter','none','FontWeight','bold','FontSize',18);
ax=nexttile; plot_cs_network_matrix(ax,MeanCS,GroupNames,1.0,'Mean CS (signed)',false,'value');
ax=nexttile; plot_cs_network_matrix(ax,MeanAbsCS,GroupNames,1.0,'Mean |CS| (magnitude)',true,'value');
ax=nexttile; plot_cs_network_matrix(ax,FracPositive,GroupNames,1.0,'Fraction positive CS',true,'percent');
ax=nexttile; plot_cs_network_matrix(ax,FracReliable,GroupNames,1.0,'Reliability fraction R',true,'percent');
% Match the Main-network style: one compact vertical thickness key at the right.
add_vertical_thickness_key(ax,[0 .25 .50 .75 1.00],1.0,'value',[1.28 .82]);
end

function plot_cs_network_matrix(ax,M,GroupNames,maxScale,plotTitle,forcePositive,textMode)
% Generic undirected network for a symmetric CS/summary matrix.
% Positive edges are black; negative edges are red. No intensity encoding.
% Fractions are printed as percentages so they cannot be mistaken for CS=1.
if nargin<6,forcePositive=false;end
if nargin<7||isempty(textMode),textMode='value';end
figAncestor=ancestor(ax,'figure');
if ~isempty(figAncestor) && isappdata(figAncestor,'KM_IndividualNetworkPages') && getappdata(figAncestor,'KM_IndividualNetworkPages')
    edgeValueFS=12;   % half of the 24-pt value font on Supplement pp.12-end
else
    edgeValueFS=24;
end
n=numel(GroupNames);
th=linspace(pi/2,pi/2+2*pi,n+1);th(end)=[];xy=[cos(th(:)) sin(th(:))];
hold(ax,'on');axis(ax,'equal');axis(ax,'off');
for i=1:n-1
 for j=i+1:n
  if i>size(M,1)||j>size(M,2),continue;end
  v=M(i,j);if ~isfinite(v),continue;end
  mag=min(abs(v),maxScale);lw=.20+7.80*(mag/maxScale);
  if ~forcePositive && v<0,col=[.88 .08 .08];else,col=[0 0 0];end
  plot(ax,xy([i j],1),xy([i j],2),'-','Color',col,'LineWidth',lw);
  mid=mean(xy([i j],:),1);
  if abs(xy(i,1)-xy(j,1))<.15
      mid(2)=mid(2)+.22;
  elseif abs(xy(i,2)-xy(j,2))<.15
      mid(1)=mid(1)+.28;
  end
  if strcmpi(textMode,'percent')
      edgeLabel=sprintf('%.0f%%',100*v);
  else
      edgeLabel=sprintf('%.2f',v);
  end
  text(ax,mid(1),mid(2),edgeLabel,'FontSize',edgeValueFS,'FontWeight','bold', ...
      'HorizontalAlignment','center','BackgroundColor','w','Margin',0.5);
 end
end
scatter(ax,xy(:,1),xy(:,2),70,'filled','MarkerFaceColor',[0.95 0.05 0.50],'MarkerEdgeColor','k','Tag','KMNetworkNode');
for i=1:n
 text(ax,1.18*xy(i,1),1.18*xy(i,2),short_one(GroupNames{i}), ...
  'HorizontalAlignment','center','FontWeight','bold','FontSize',24);
end
title(ax,plotTitle,'Interpreter','none','FontSize',20,'FontWeight','bold');xlim(ax,[-1.55 1.55]);ylim(ax,[-1.60 1.60]);
end

function add_vertical_thickness_key(ax,vals,maxVal,labelText,anchor)
% Compact vertical stack of line-thickness samples.
x0=anchor(1); y0=anchor(2); yl=ylim(ax); xl=xlim(ax); yr=yl(2)-yl(1); xr=xl(2)-xl(1);
dy=.095*yr; seg=.10*xr;
text(ax,x0,y0+.08*yr,labelText,'FontSize',24,'FontWeight','bold','HorizontalAlignment','center');
for ii=1:numel(vals)
 v=vals(ii); lw=.25+3.75*min(abs(v)/maxVal,1); yy=y0-(ii-1)*dy;
 plot(ax,[x0-seg/2 x0+seg/2],[yy yy],'-k','LineWidth',lw);
 text(ax,x0+seg*.65,yy,sprintf('%g',v),'FontSize',16,'FontWeight','bold','HorizontalAlignment','left','VerticalAlignment','middle');
end
end

function add_axes_thickness_key(ax,vals,maxScale,keyLabel,origin)
% Compact in-axis line-thickness scale. maxScale corresponds to maximum line width.
if nargin<5,origin=[-1.25 1.30];end
x0=origin(1);y0=origin(2);dx=.34;
text(ax,x0-.10,y0,keyLabel,'FontSize',18,'FontWeight','bold','HorizontalAlignment','right');
for k=1:numel(vals)
 lw=.20+3.80*(min(abs(vals(k)),maxScale)/maxScale);
 xa=x0+(k-1)*dx;
 plot(ax,[xa xa+.18],[y0 y0],'-','Color','k','LineWidth',lw,'Clipping','off');
 text(ax,xa+.22,y0,sprintf('%.2g',vals(k)),'FontSize',16,'FontWeight','bold','HorizontalAlignment','left','VerticalAlignment','middle','Clipping','off');
end
end

function add_network_thickness_key(figHandle,vals,maxScale,keyLabel)
% Figure-level thickness legend, used for Supplement multi-panel pages.
if isempty(figHandle)||~isgraphics(figHandle),return;end
ax=axes(figHandle,'Position',[.30 .012 .40 .035],'Visible','off');hold(ax,'on');xlim(ax,[0 1]);ylim(ax,[0 1]);
text(ax,-.03,.62,[keyLabel ' thickness:'],'FontWeight','bold','HorizontalAlignment','right','FontSize',20);
for k=1:numel(vals)
 x=(k-1)/(max(1,numel(vals)-1));lw=.20+7.80*(min(abs(vals(k)),maxScale)/maxScale);
 plot(ax,[x x+.09],[.62 .62],'-','Color','k','LineWidth',lw,'Clipping','off');
 text(ax,x+.045,.12,sprintf('%.2g',vals(k)),'HorizontalAlignment','center','FontSize',18);
end
end

function plot_four_metric_heatmaps(MeanCS, MeanAbsCS, FracPositive, FracReliable, NMaps, GroupNames, plotTitle, CLimCS)

    tl = tiledlayout(1,4,'TileSpacing','none','Padding','compact');
    title(tl, plotTitle, 'Interpreter','none', 'FontWeight','bold');

    nexttile;
    plot_metric_heatmap(MeanCS, NMaps, GroupNames, ...
        'Mean CS (signed)', CLimCS, 'value');

    nexttile;
    plot_metric_heatmap(MeanAbsCS, NMaps, GroupNames, ...
        'Mean |CS| (magnitude)', [0 max(abs(CLimCS))], 'value');

    nexttile;
    plot_metric_heatmap(FracPositive, NMaps, GroupNames, ...
        'Fraction positive CS', [0 1], 'percent');

    nexttile;
    plot_metric_heatmap(FracReliable, NMaps, GroupNames, ...
        'Reliability fraction R', [0 1], 'percent');

end

function plot_metric_heatmap(M, NMaps, GroupNames, plotTitle, climVals, textMode)

    imagesc(M);
    colorbar;
    clim(climVals);
    axis square;

    xticks(1:numel(GroupNames));
    xticklabels(short_group_names(GroupNames));
    xtickangle(35);
    yticks(1:numel(GroupNames));
    yticklabels(short_group_names(GroupNames));

    xlabel('Feature / group 2');
    ylabel('Feature / group 1');
    title(plotTitle, 'Interpreter','none');

    for r = 1:numel(GroupNames)
        for c = 1:numel(GroupNames)
            if isfinite(M(r,c))
                if strcmpi(textMode, 'percent')
                    txt = sprintf('%.0f%%', 100*M(r,c));
                else
                    txt = sprintf('%.2f', M(r,c));
                end
                text(c,r,txt, ...
                    'HorizontalAlignment','center', ...
                    'VerticalAlignment','middle', ...
                    'FontWeight','bold', ...
                    'FontSize',20, ...
                    'Color','k');
            end
        end
    end

end


function R = select_unique_eeg_result_rows(Results,EEGGroupNames)
% Return exactly one row per available undirected EEG-group connection.
% Results stores symmetric matrix entries, so Feature1_Index < Feature2_Index
% is essential for distribution counts and any row-level EEG-edge summaries.
R=Results([],:);
if isempty(Results),return;end
f1=cellstr(string(Results.Feature1)); f2=cellstr(string(Results.Feature2));
isEEG=ismember(f1,EEGGroupNames) & ismember(f2,EEGGroupNames);
keep=isEEG & Results.Feature1_Index < Results.Feature2_Index & isfinite(Results.CS);
R=Results(keep,:);
end

function A = audit_unique_eeg_pair_table(P,tasks,G)
% One row per participant-context x task, documenting how many unique
% unique undirected EEG edges are actually available.  Duplicate rows are a
% hard error because they would invalidate row-count diagnostics.
A=table(); if isempty(P),return;end
canon=canonical_functional_pairs(G); canonNames=strcat(canon(:,1),{'--'},canon(:,2));
if any(~ismember(P.Pair,canonNames))
 error('QC failure: FunctionalPairSubject contains a non-canonical EEG pair.');
end
keys=strcat(P.Subject,{'|'},P.Task,{'|'},P.Pair);
if numel(unique(keys))~=numel(keys)
 error('QC failure: duplicate Subject-Task-Pair rows remain in FunctionalPairSubject.');
end
subs=unique(P.Subject,'stable');
for s=1:numel(subs)
 for t=1:numel(tasks)
  Q=P(strcmp(P.Subject,subs{s})&strcmp(P.Task,tasks{t}),:);
  if isempty(Q),continue;end
  n=numel(unique(Q.Pair));
  nExpected=nchoosek(numel(G),2);
  A=[A;table(Q.Dyad(1),Q.Participant(1),Q.Subject(1),{tasks{t}},n,n==nExpected, ...
    'VariableNames',{'Dyad','Participant','Subject','Task','NUniqueEEGEdges','HasAllEdges'})]; %#ok<AGROW>
 end
end
if any(A.NUniqueEEGEdges>nchoosek(numel(G),2))
 error('QC failure: too many unique EEG edges detected for the configured network.');
end
end

function Stats = compute_cs_distribution_stats(Results,EEGGroupNames)

    % Build distribution summary rows for all CS and for reliable-only CS,
    % both pooled across all tasks and separately for each task.
    Stats = table();

    if isempty(Results) || ~ismember('CS', Results.Properties.VariableNames)
        return;
    end

    % IMPORTANT: Results contains symmetric map entries.  Distributional
    % figures/statistics must use the UNIQUE UNDIRECTED EEG connections only.
    R = select_unique_eeg_result_rows(Results,EEGGroupNames);

    % R is a filtered subset of Results, so every logical mask in this function
    assert(height(R) == numel(R.CS), 'Internal QC error: filtered EEG table has inconsistent column lengths.');
    tasks = unique(R.Task, 'stable');

    Stats = append_cs_stats_row(Stats, R.CS, R.Reliable, 'ALL_TASKS', 'All_CS');
    Stats = append_cs_stats_row(Stats, R.CS(R.Reliable), true(sum(R.Reliable),1), 'ALL_TASKS', 'Reliable_CS');

    for i = 1:numel(tasks)
        taskName = tasks{i};
        idx = strcmp(R.Task, taskName);
        Stats = append_cs_stats_row(Stats, R.CS(idx), R.Reliable(idx), taskName, 'All_CS');
        Stats = append_cs_stats_row(Stats, R.CS(idx & R.Reliable), true(sum(idx & R.Reliable),1), taskName, 'Reliable_CS');
    end

end

function Stats = append_cs_stats_row(Stats, csVals, reliableVals, taskName, subsetName)

    csVals = csVals(:);
    csVals = csVals(isfinite(csVals));

    row = table();
    row.Task = {taskName};
    row.Subset = {subsetName};
    row.N = numel(csVals);

    if isempty(csVals)
        row.Min_CS = NaN;
        row.Q05_CS = NaN;
        row.Q25_CS = NaN;
        row.Median_CS = NaN;
        row.Q75_CS = NaN;
        row.Q95_CS = NaN;
        row.Max_CS = NaN;
        row.Mean_CS = NaN;
        row.Std_CS = NaN;
        row.MeanAbs_CS = NaN;
        row.MedianAbs_CS = NaN;
        row.Q95Abs_CS = NaN;
        row.Frac_Positive = NaN;
        row.Frac_Reliable = NaN;
    else
        qs = local_percentile(csVals, [5 25 50 75 95]);
        absQs = local_percentile(abs(csVals), [50 95]);
        row.Min_CS = min(csVals);
        row.Q05_CS = qs(1);
        row.Q25_CS = qs(2);
        row.Median_CS = qs(3);
        row.Q75_CS = qs(4);
        row.Q95_CS = qs(5);
        row.Max_CS = max(csVals);
        row.Mean_CS = mean(csVals,'omitnan');
        row.Std_CS = std(csVals,'omitnan');
        row.MeanAbs_CS = mean(abs(csVals),'omitnan');
        row.MedianAbs_CS = absQs(1);
        row.Q95Abs_CS = absQs(2);
        row.Frac_Positive = mean(csVals > 0,'omitnan');

        if nargin >= 3 && ~isempty(reliableVals)
            reliableVals = reliableVals(:);
            reliableVals = reliableVals(isfinite(reliableVals));
            if isempty(reliableVals)
                row.Frac_Reliable = NaN;
            else
                row.Frac_Reliable = mean(logical(reliableVals));
            end
        else
            row.Frac_Reliable = NaN;
        end
    end

    if isempty(Stats)
        Stats = row;
    else
        Stats = [Stats; row]; %#ok<AGROW>
    end

end

function [xr, yr] = paired_rank_transform(x, y)

    % Rank-transform paired vectors for Spearman correlation.
    % Ties receive average ranks. NaNs are removed pairwise before ranking.
    x = x(:);
    y = y(:);
    ok = isfinite(x) & isfinite(y);
    x = x(ok);
    y = y(ok);
    xr = local_tied_rank(x);
    yr = local_tied_rank(y);

end

function rho = local_spearman_corr(x, y)

    [xr, yr] = paired_rank_transform(x, y);
    if numel(xr) < 3 || std(xr) == 0 || std(yr) == 0
        rho = NaN;
        return;
    end
    C = corrcoef(xr, yr);
    rho = C(1,2);

end

function r = local_tied_rank(x)

    % Toolbox-free tied rank implementation.
    x = x(:);
    [xs, order] = sort(x);
    n = numel(x);
    rSorted = nan(n,1);
    i = 1;
    while i <= n
        j = i;
        while j < n && xs(j+1) == xs(i)
            j = j + 1;
        end
        rSorted(i:j) = (i + j) / 2;
        i = j + 1;
    end
    r = nan(n,1);
    r(order) = rSorted;

end

function q = local_percentile(x, pct)

    x = sort(x(isfinite(x)));
    q = nan(size(pct));
    if isempty(x)
        return;
    end

    N = numel(x);
    for i = 1:numel(pct)
        pos = 1 + (N-1) * pct(i)/100;
        lo = floor(pos);
        hi = ceil(pos);
        if lo == hi
            q(i) = x(lo);
        else
            q(i) = x(lo) + (pos-lo) * (x(hi)-x(lo));
        end
    end

end

function plot_cs_distribution_overview(Results, EEGGroupNames, Strength)

    R = select_unique_eeg_result_rows(Results,EEGGroupNames);
    csAll = R.CS;
    csAll = csAll(isfinite(csAll));
    csRel = R.CS(R.Reliable & isfinite(R.CS));

    tl = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    title(tl, sprintf('Unique undirected EEG-edge CS distribution, Strength = %d', Strength), 'FontWeight','bold');

    nexttile; hold on; box on;
    histogram(csAll, 30); xlim([-1 1]);
    xline(0,'k--','LineWidth',1.2);
    xlabel('CS'); ylabel('Count');
    title(sprintf('Unique EEG connections only, N = %d', numel(csAll)));
    grid on;

    nexttile; hold on; box on;
    histogram(abs(csAll), 30); xlim([0 1]);
    xlabel('|CS|'); ylabel('Count');
    title(sprintf('Magnitude |CS|, median = %.3f', median(abs(csAll),'omitnan')));
    grid on;

    nexttile; hold on; box on;
    histogram(csRel, 30); xlim([-1 1]);
    xline(0,'k--','LineWidth',1.2);
    xlabel('Reliable CS'); ylabel('Count');
    title(sprintf('Reliable-only CS, N = %d', numel(csRel)));
    grid on;

    nexttile; hold on; box on;
    plot_task_strip(R, false);
    title('CS distribution by task');

end

function plot_cs_distribution_by_task(Results, taskList, EEGGroupNames, Strength)

    R = select_unique_eeg_result_rows(Results,EEGGroupNames);

    nT = numel(taskList);
    nRows = 2;
    nCols = max(3, ceil(nT/nRows));

    tl = tiledlayout(nRows,nCols,'TileSpacing','compact','Padding','compact');
    title(tl, sprintf('Unique undirected EEG-edge CS histograms by task, Strength = %d', Strength), 'FontWeight','bold');

    for i = 1:nT
        taskName = taskList{i};
        idx = strcmp(R.Task, taskName) & isfinite(R.CS);
        cs = R.CS(idx);
        rel = R.Reliable(idx);

        nexttile; hold on; box on;
        histogram(cs, 20);
        xline(0,'k--','LineWidth',1.1);
        xlim([-1 1]); % show full signed CS distribution, including positive values above 0.5
        xlabel('CS'); ylabel('Count');
        title(sprintf('%s: N=%d, rel=%d', task_display_label(taskName), numel(cs), sum(rel)));
        grid on;
    end

    % Fill any unused tiles with a compact reliable-only strip plot.
    if nT < nRows*nCols
        nexttile; hold on; box on;
        plot_task_strip(R, true);
        title('Reliable CS by task');
    end

end

function plot_task_strip(Results, reliableOnly)

    tasks = unique(Results.Task, 'stable');
    hold on;

    for i = 1:numel(tasks)
        idx = strcmp(Results.Task, tasks{i}) & isfinite(Results.CS);
        if reliableOnly
            idx = idx & Results.Reliable;
        end

        y = Results.CS(idx);
        if isempty(y)
            continue;
        end

        % Deterministic small jitter without using random numbers.
        jitter = linspace(-0.18,0.18,numel(y))';
        if numel(y) == 1
            jitter = 0;
        end
        x = i + jitter;
        plot(x, y, '.', 'MarkerSize', 12);

        medVal = median(y,'omitnan');
        q = local_percentile(y, [25 75]);
        plot([i-0.25 i+0.25], [medVal medVal], 'k-', 'LineWidth', 2);
        plot([i i], [q(1) q(2)], 'k-', 'LineWidth', 1.5);
    end

    xlim([0.5 numel(tasks)+0.5]);
    ylim([-1 1]); % Full Spearman range: do not clip task-wise CS observations.
    yticks(-1:0.25:1);
    xticks(1:numel(tasks));
    xticklabels(task_display_labels(tasks));
    yline(0,'k--','LineWidth',1.1);
    xlabel('Condition');
    ylabel('CS');
    grid on;

end



function [LagRows, BestCSmap, BestLagmap, Relmap, BestAbsCSmap] = ...
    compute_lagged_music_cs_subject(G, groupLabels, subjectName, dyadName, taskName, participantName, ...
    AmplFeatureNames, TargetFeatureNames, LagRange, UseDeltaDiffForCS, ...
    PLOT, NSurr, NBoot, Alpha, MinNeff, Strength, MinLaggedN, CorrelationMethod, ...
    UseBlockBootstrapLagSignificance, BlockBootstrapPerms, BlockBootstrapSize, PearsonWhitenAROrder)

    %#ok<INUSD> PLOT, NSurr, NBoot, Alpha, MinNeff, Strength are kept in the
    % signature for compatibility with older calls, but the lagged music-CS
    % reliability is now Piotr-style block-bootstrap significance.

    nG = size(G,1);
    BestCSmap = nan(nG,nG);
    BestLagmap = nan(nG,nG);
    Relmap = false(nG,nG);
    BestAbsCSmap = nan(nG,nG);
    LagRows = table();

    labels = cellstr(string(groupLabels));
    musicIdx = find(ismember(labels, AmplFeatureNames));
    targetIdx = find(ismember(labels, TargetFeatureNames));

    if isempty(musicIdx) || isempty(targetIdx)
        return;
    end

    for ti = 1:numel(targetIdx)
        gTarget = targetIdx(ti);
        for mi = 1:numel(musicIdx)
            gMusic = musicIdx(mi);

            if gTarget == gMusic
                continue;
            end

            target = G(gTarget,:)';
            music  = G(gMusic,:)';

            % 1) Spearman lagged CS on raw delta(t), unless the user explicitly
            % is raw delta, so UseDeltaDiffForCS=false at the top of the file.
            [bestCS, bestLag, bestN, allLagCS] = ...
                find_best_lagged_cs(target, music, LagRange, UseDeltaDiffForCS, MinLaggedN, CorrelationMethod);

            if ~isfinite(bestCS)
                continue;
            end

            [xBest, yBest] = align_target_music_at_lag(target, music, bestLag, UseDeltaDiffForCS);
            ok = isfinite(xBest) & isfinite(yBest);
            xBest = xBest(ok);
            yBest = yBest(ok);

            % 2) Moving block bootstrap significance for the selected best lag.
            % This preserves short-range autocorrelation within resampled blocks.
            p_block = NaN;
            block_size_used = NaN;
            reliable = false;
            if UseBlockBootstrapLagSignificance && numel(xBest) >= MinLaggedN && std(xBest) > 0 && std(yBest) > 0
                [p_block, block_size_used] = block_bootstrap_pval_pair( ...
                    xBest, yBest, CorrelationMethod, BlockBootstrapPerms, BlockBootstrapSize);
                reliable = isfinite(p_block) && p_block < Alpha;
            end

            % 3) AR(1)-prewhitened Pearson robustness check at the same best lag.
            pearson_ar1 = NaN;
            pearson_ar1_p = NaN;
            pearson_ar1_N = NaN;
            if numel(xBest) >= max(MinLaggedN, PearsonWhitenAROrder+5) && std(xBest) > 0 && std(yBest) > 0
                [pearson_ar1, pearson_ar1_p, pearson_ar1_N] = ...
                    ar_prewhitened_pearson_pair(xBest, yBest, PearsonWhitenAROrder);
            end

            BestCSmap(gTarget,gMusic) = bestCS;
            BestCSmap(gMusic,gTarget) = bestCS;
            BestAbsCSmap(gTarget,gMusic) = abs(bestCS);
            BestAbsCSmap(gMusic,gTarget) = abs(bestCS);
            BestLagmap(gTarget,gMusic) = bestLag;
            BestLagmap(gMusic,gTarget) = -bestLag;
            Relmap(gTarget,gMusic) = reliable;
            Relmap(gMusic,gTarget) = reliable;

            NewRow = table();
            NewRow.Dyad = {dyadName};
            NewRow.Task = {taskName};
            NewRow.Participant = {participantName};
            NewRow.Subject = {subjectName};
            NewRow.TargetFeature = labels(gTarget);
            NewRow.MusicFeature = labels(gMusic);
            NewRow.TargetIndex = gTarget;
            NewRow.MusicIndex = gMusic;
            NewRow.BestLag_TargetMinusMusic = bestLag;
            NewRow.BestLagMeaning = {lag_meaning(bestLag)};
            NewRow.BestLaggedCS = bestCS;
            NewRow.BestLaggedAbsCS = abs(bestCS);
            NewRow.N = bestN;
            NewRow.Reliable = reliable;
            NewRow.p_block_bootstrap = p_block;
            NewRow.BlockSizeUsed = block_size_used;
            NewRow.Pearson_AR1_Whitened = pearson_ar1;
            NewRow.Pearson_AR1_p = pearson_ar1_p;
            NewRow.Pearson_AR1_N = pearson_ar1_N;
            NewRow.Neff_int = NaN;
            NewRow.p_eff_int = NaN;
            NewRow.p_circshift = NaN;
            NewRow.p_phase = NaN;
            NewRow.CI_low = NaN;
            NewRow.CI_high = NaN;
            NewRow.LagRange = {mat2str(LagRange)};
            NewRow.AllLagCS = {mat2str(allLagCS,4)};
            % Explicit pre-specified lag values. Keep these as numeric columns
            % so they can be averaged across participants without parsing text.
            [NewRow.CS_LagMinus2, NewRow.N_LagMinus2] = fixed_lag_value(allLagCS, LagRange, -2, target, music, UseDeltaDiffForCS);
            [NewRow.CS_LagMinus1, NewRow.N_LagMinus1] = fixed_lag_value(allLagCS, LagRange, -1, target, music, UseDeltaDiffForCS);
            [NewRow.CS_Lag0,      NewRow.N_Lag0]      = fixed_lag_value(allLagCS, LagRange,  0, target, music, UseDeltaDiffForCS);
            [NewRow.CS_LagPlus1,  NewRow.N_LagPlus1]  = fixed_lag_value(allLagCS, LagRange,  1, target, music, UseDeltaDiffForCS);
            [NewRow.CS_LagPlus2,  NewRow.N_LagPlus2]  = fixed_lag_value(allLagCS, LagRange,  2, target, music, UseDeltaDiffForCS);
            NewRow.CorrelationMethod = {CorrelationMethod};
            NewRow.LagSignificanceMethod = {'moving_block_bootstrap'};
            NewRow.RobustnessMethod = {sprintf('Pearson_AR%d_prewhitened', PearsonWhitenAROrder)};

            if isempty(LagRows)
                LagRows = NewRow;
            else
                LagRows = [LagRows; NewRow]; %#ok<AGROW>
            end
        end
    end
end

function [bestCS, bestLag, bestN, allLagCS] = ...
    find_best_lagged_cs(target, music, LagRange, UseDeltaDiffForCS, MinLaggedN, CorrelationMethod)

    allLagCS = nan(size(LagRange));
    allLagN = zeros(size(LagRange));

    for i = 1:numel(LagRange)
        lag = LagRange(i);
        [x, y] = align_target_music_at_lag(target, music, lag, UseDeltaDiffForCS);
        ok = isfinite(x) & isfinite(y);
        x = x(ok);
        y = y(ok);
        allLagN(i) = numel(x);

        if numel(x) >= MinLaggedN && std(x) > 0 && std(y) > 0
            if strcmpi(CorrelationMethod, 'Spearman')
                allLagCS(i) = local_spearman_corr(x,y);
            else
                C = corrcoef(x,y);
                allLagCS(i) = C(1,2);
            end
        end
    end

    if all(~isfinite(allLagCS))
        bestCS = NaN;
        bestLag = NaN;
        bestN = NaN;
        return;
    end

    [~, idx] = max(abs(allLagCS));
    bestCS = allLagCS(idx);
    bestLag = LagRange(idx);
    bestN = allLagN(idx);
end

function [targetLagged, musicAligned] = align_target_music_at_lag(target, music, lag, UseDeltaDiffForCS)

    target = target(:);
    music = music(:);

    % Do NOT remove NaNs jointly here, because compressing missing samples
    % would change the temporal spacing and can create artificial lag shifts.
    if UseDeltaDiffForCS
        target = diff(target);
        music = diff(music);
    end

    N = min(numel(target), numel(music));
    target = target(1:N);
    music = music(1:N);

    if lag > 0
        % Positive lag: music comes first; target follows.
        targetLagged = target(1+lag:end);
        musicAligned = music(1:end-lag);
    elseif lag < 0
        % Negative lag: target comes first; music follows.
        L = abs(lag);
        targetLagged = target(1:end-L);
        musicAligned = music(1+L:end);
    else
        targetLagged = target;
        musicAligned = music;
    end
end

function txt = lag_meaning(lag)
    if lag > 0
        txt = sprintf('target follows music by %d window(s)', lag);
    elseif lag < 0
        txt = sprintf('target leads Ampl by %d window(s)', abs(lag));
    else
        txt = 'zero lag';
    end
end


function [p_val, b_size] = block_bootstrap_pval_pair(x, y, c_type, num_perms, b_size_opt)

    x = x(:);
    y = y(:);
    valid_idx = isfinite(x) & isfinite(y);
    x_c = x(valid_idx);
    y_c = y(valid_idx);
    N = numel(x_c);

    if N < 10
        p_val = NaN;
        b_size = NaN;
        return;
    end

    if isnumeric(b_size_opt)
        b_size = round(b_size_opt);
    elseif strcmpi(b_size_opt, 'auto')
        lag_x = get_acf_cutoff_lag_local(x_c, c_type);
        lag_y = get_acf_cutoff_lag_local(y_c, c_type);
        b_size = 2 * max([lag_x, lag_y, 1]);
    else
        b_size = max(1, round(N^(1/3)));
    end
    b_size = max(1, min(b_size, floor(N/2)));

    if strcmpi(c_type, 'Spearman')
        r_obs = local_spearman_corr(x_c, y_c);
    else
        C = corrcoef(x_c, y_c);
        r_obs = C(1,2);
    end

    if ~isfinite(r_obs)
        p_val = NaN;
        return;
    end

    num_overlapping_blocks = N - b_size + 1;
    num_blocks_needed = ceil(N / b_size);
    null_dist = nan(num_perms, 1);

    % Fixed x, block-resampled y. This breaks cross-series alignment while
    % preserving local autocorrelation structure of y within blocks.
    for ib = 1:num_perms
        start_idx = randi(num_overlapping_blocks, num_blocks_needed, 1);
        y_star = zeros(num_blocks_needed * b_size, 1);

        for k = 1:num_blocks_needed
            idx = start_idx(k);
            y_star((k-1)*b_size + 1 : k*b_size) = y_c(idx : idx+b_size-1);
        end
        y_star = y_star(1:N);

        if strcmpi(c_type, 'Spearman')
            null_dist(ib) = local_spearman_corr(x_c, y_star);
        else
            Cb = corrcoef(x_c, y_star);
            null_dist(ib) = Cb(1,2);
        end
    end

    null_dist = null_dist(isfinite(null_dist));
    if isempty(null_dist)
        p_val = NaN;
    else
        p_val = mean(abs(null_dist) >= abs(r_obs));
        % Avoid exact zero p-values with finite bootstrap samples.
        p_val = max(p_val, 1/(numel(null_dist)+1));
    end
end

function lag = get_acf_cutoff_lag_local(series, c_type)

    series = series(:);
    series = series(isfinite(series));
    N = numel(series);
    if N < 10
        lag = 1;
        return;
    end

    if strcmpi(c_type, 'Spearman') || strcmpi(c_type, 'Kendall')
        z = local_tied_rank(series);
    else
        z = series;
    end

    z = z - mean(z,'omitnan');
    denom = sum(z.^2);
    if denom <= 0 || ~isfinite(denom)
        lag = 1;
        return;
    end

    maxLag = min(N-2, max(5, floor(N/3)));
    acf = nan(maxLag,1);
    for L = 1:maxLag
        acf(L) = sum(z(1:end-L).*z(1+L:end)) / denom;
    end

    conf_limit = 1.96 / sqrt(N);
    first_insignificant = find(abs(acf) < conf_limit, 1, 'first');

    if isempty(first_insignificant)
        lag = max(1, floor(N/10));
    else
        lag = first_insignificant;
    end
end

function [r, p, N_eff] = ar_prewhitened_pearson_pair(x, y, ar_order)

    x = x(:);
    y = y(:);
    ok = isfinite(x) & isfinite(y);
    x = x(ok);
    y = y(ok);

    if nargin < 3 || isempty(ar_order)
        ar_order = 1;
    end

    if ar_order ~= 1
        warning('This script currently implements toolbox-free AR(1) pre-whitening. Using AR(1).');
        ar_order = 1;
    end

    N = numel(x);
    if N < 8 || std(x)==0 || std(y)==0
        r = NaN; p = NaN; N_eff = NaN; return;
    end

    % Estimate AR(1) separately for each series, then correlate innovations.
    phi_x = estimate_ar1_phi(x);
    phi_y = estimate_ar1_phi(y);

    rx = x(2:end) - phi_x * x(1:end-1);
    ry = y(2:end) - phi_y * y(1:end-1);

    ok = isfinite(rx) & isfinite(ry);
    rx = rx(ok);
    ry = ry(ok);
    N_eff = numel(rx);

    if N_eff < 4 || std(rx)==0 || std(ry)==0
        r = NaN; p = NaN; return;
    end

    C = corrcoef(rx, ry);
    r = C(1,2);

    % Parametric Pearson p-value using t statistic; tcdf is usually available
    % in base/statistics installations. If unavailable, return NaN p-value.
    try
        tval = r * sqrt((N_eff - 2) / max(eps, 1 - r^2));
        p = 2 * (1 - tcdf(abs(tval), N_eff - 2));
    catch
        p = NaN;
    end
end

function phi = estimate_ar1_phi(x)

    x = x(:);
    x = x - mean(x,'omitnan');
    x0 = x(1:end-1);
    x1 = x(2:end);
    denom = sum(x0.^2);
    if denom <= 0 || ~isfinite(denom)
        phi = 0;
    else
        phi = sum(x1 .* x0) / denom;
    end

    % Keep the AR coefficient stable.
    phi = max(min(phi, 0.99), -0.99);
end

function [MeanBestCS, MeanBestAbsCS, FracReliable, MeanBestLag, NMaps] = ...
    average_lagged_maps_from_store(LagMapStore, LagGroupNames, taskFilter)

    nG = numel(LagGroupNames);
    nMaps = numel(LagMapStore);

    CSstack = nan(nG,nG,nMaps);
    Absstack = nan(nG,nG,nMaps);
    Relstack = nan(nG,nG,nMaps);
    Lagstack = nan(nG,nG,nMaps);
    used = false(nMaps,1);

    for m = 1:nMaps
        if ~strcmp(LagMapStore(m).Task, taskFilter)
            continue;
        end
        used(m) = true;

        CSstack(:,:,m) = map_to_full_group_matrix(LagMapStore(m).BestCSmap, ...
            LagMapStore(m).groupLabels, LagMapStore(m).groupLabels, LagGroupNames);
        Absstack(:,:,m) = map_to_full_group_matrix(LagMapStore(m).BestAbsCSmap, ...
            LagMapStore(m).groupLabels, LagMapStore(m).groupLabels, LagGroupNames);
        Relstack(:,:,m) = map_to_full_group_matrix(double(LagMapStore(m).Relmap), ...
            LagMapStore(m).groupLabels, LagMapStore(m).groupLabels, LagGroupNames);
        Lagstack(:,:,m) = map_to_full_group_matrix(LagMapStore(m).BestLagmap, ...
            LagMapStore(m).groupLabels, LagMapStore(m).groupLabels, LagGroupNames);
    end

    CSstack = CSstack(:,:,used);
    Absstack = Absstack(:,:,used);
    Relstack = Relstack(:,:,used);
    Lagstack = Lagstack(:,:,used);

    MeanBestCS = mean(CSstack,3,'omitnan');
    MeanBestAbsCS = mean(Absstack,3,'omitnan');
    NMaps = sum(isfinite(CSstack),3);
    FracReliable = sum(Relstack == 1,3) ./ max(1,NMaps);
    FracReliable(NMaps == 0) = NaN;
    MeanBestLag = mean(Lagstack,3,'omitnan');
end

function T = lagged_map_to_table(MeanCS, MeanAbsCS, FracReliable, MeanLag, NMaps, GroupNames, taskName)

    nG = numel(GroupNames);
    T = table();
    row = 0;

    for r = 1:nG
        for c = 1:nG
            if ~isfinite(MeanAbsCS(r,c))
                continue;
            end
            row = row + 1;
            T.Task{row,1} = taskName;
            T.Feature1{row,1} = GroupNames{r};
            T.Feature2{row,1} = GroupNames{c};
            T.MeanBestCS(row,1) = MeanCS(r,c);
            T.MeanBestAbsCS(row,1) = MeanAbsCS(r,c);
            T.FracReliable(row,1) = FracReliable(r,c);
            T.MeanBestLag(row,1) = MeanLag(r,c);
            T.NumMaps(row,1) = NMaps(r,c);
        end
    end
end

function plot_lagged_music_summary_heatmaps(MeanCS, MeanAbsCS, FracReliable, MeanLag, NMaps, GroupNames, taskName, CLimCS, LagRange)

    tl = tiledlayout(1,4,'TileSpacing','none','Padding','compact');
    title(tl, sprintf('%s: lagged Ampl-to-brain/physiology raw-delta CS summary', taskName), ...
        'Interpreter','none', 'FontWeight','bold');

    nexttile;
    plot_metric_heatmap(MeanCS, NMaps, GroupNames, ...
        'Best lagged CS (signed)', CLimCS, 'value');

    nexttile;
    plot_metric_heatmap(MeanAbsCS, NMaps, GroupNames, ...
        'Best lagged |CS|', [0 max(abs(CLimCS))], 'value');

    nexttile;
    plot_metric_heatmap(FracReliable, NMaps, GroupNames, ...
        'Best-lag block-bootstrap reliability', [0 1], 'percent');

    nexttile;
    plot_metric_heatmap(MeanLag, NMaps, GroupNames, ...
        sprintf('Best lag within restricted window [%d,%d]', min(LagRange), max(LagRange)), [min(LagRange) max(LagRange)], 'value');
end

function plot_lagged_network_from_matrix(CSmap, Relmap, Lagmap, GroupNames, plotTitle, threshold, reliableOnly, reliabilityThreshold)

    cla; hold on; axis equal off;
    nG = numel(GroupNames);
    theta = linspace(pi/2, pi/2 - 2*pi, nG+1);
    theta(end) = [];
    x = cos(theta);
    y = sin(theta);

    M = CSmap;
    R = Relmap;
    L = Lagmap;

    % ------------------------------------------------------------------
    % Directional lag-network drawing
    % ------------------------------------------------------------------
    % Lag convention used by the code:
    %   lag > 0 : row/target feature follows column/music feature
    %             therefore column/music leads row/target.
    %   lag < 0 : row/target feature leads column/music feature.
    %
    % Arrow convention in this plot:
    %   arrow points from leader --> follower.
    %
    % Link thickness is proportional to abs(CS).  A fixed global reference
    % is used so that different pages are visually comparable, instead of
    % rescaling each page independently.
    % ------------------------------------------------------------------

    edgeR = [];
    edgeC = [];
    edgeW = [];
    edgeCS = [];
    edgeLag = [];
    edgeSrc = [];
    edgeDst = [];

    for r = 1:nG
        for c = r+1:nG

            % For a pair r--c, use the stronger available lagged CS entry.
            vals = [M(r,c), M(c,r)];
            rels = [R(r,c), R(c,r)];

            % Convert the second direction to the same r/c pair convention.
            % If L(c,r) is positive, r leads c; therefore for the r,c pair
            % its equivalent lag is -L(c,r).
            lags = [L(r,c), -L(c,r)];

            if all(~isfinite(vals))
                continue;
            end

            [~, idx] = max(abs(vals));
            csVal = vals(idx);
            relVal = rels(idx);
            lagVal = lags(idx);

            if ~isfinite(csVal) || abs(csVal) < threshold
                continue;
            end
            if reliableOnly
                if ~isfinite(relVal) || relVal < reliabilityThreshold
                    continue;
                end
            end

            % Direction based on lag sign.
            % lag > 0: c leads r.  lag < 0: r leads c.
            if isfinite(lagVal) && lagVal > 0
                src = c;
                dst = r;
            elseif isfinite(lagVal) && lagVal < 0
                src = r;
                dst = c;
            else
                src = r;
                dst = c;   % zero-lag: draw a line without arrow head
            end

            edgeR(end+1) = r; %#ok<AGROW>
            edgeC(end+1) = c; %#ok<AGROW>
            edgeW(end+1) = abs(csVal); %#ok<AGROW>
            edgeCS(end+1) = csVal; %#ok<AGROW>
            edgeLag(end+1) = lagVal; %#ok<AGROW>
            edgeSrc(end+1) = src; %#ok<AGROW>
            edgeDst(end+1) = dst; %#ok<AGROW>
        end
    end

    % Draw directed arrows first, then nodes on top.
    edgeColor = [0 0 0];
    for e = 1:numel(edgeR)
        src = edgeSrc(e);
        dst = edgeDst(e);
        lw = cs_to_linewidth(edgeW(e));

        if isfinite(edgeLag(e)) && edgeLag(e) ~= 0
            draw_sharp_network_arrow(x(src), y(src), x(dst), y(dst), lw, edgeColor);
        else
            draw_network_line_no_arrow(x(src), y(src), x(dst), y(dst), lw, edgeColor);
        end

        xm = mean([x(edgeR(e)), x(edgeC(e))]);
        ym = mean([y(edgeR(e)), y(edgeC(e))]);
        text(xm, ym, sprintf('|CS|=%.2f\nL=%g', edgeW(e), edgeLag(e)), ...
            'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
            'FontSize',28, 'FontWeight','bold', 'BackgroundColor','w', ...
            'Margin',1);
    end

    % Draw nodes.
    plot(x, y, 'o', 'MarkerSize', 20, 'LineWidth', 1.7, ...
        'MarkerFaceColor','auto', 'MarkerEdgeColor','k');
    sn = short_group_names(GroupNames);
    for i = 1:nG
        text(1.18*x(i), 1.18*y(i), sn{i}, ...
            'HorizontalAlignment','center', 'FontWeight','bold', 'FontSize',18);
    end

    if reliableOnly
        title(sprintf('%s | directed by lag | |CS| >= %.2f, R >= %.2f', plotTitle, threshold, reliabilityThreshold), ...
            'Interpreter','none', 'FontSize',20);
    else
        title(sprintf('%s | directed by lag | |CS| >= %.2f', plotTitle, threshold), ...
            'Interpreter','none', 'FontSize',20);
    end

    text(0, -1.30, 'Sharp arrow: leader \rightarrow follower   |   Line width \propto |CS|', ...
        'HorizontalAlignment','center', 'FontSize',20, 'FontWeight','bold');

    xlim([-1.35 1.35]);
    ylim([-1.35 1.35]);
end

function lw = cs_to_linewidth(absCS)
    % Fixed global width scale for comparable network pages.
    % |CS|=0.10 is visible but thin; |CS|=0.50 is very thick.
    LWmin = 0.9;
    LWmax = 9.0;
    CSref = 0.50;
    w = max(0, min(absCS / CSref, 1));
    lw = LWmin + (LWmax - LWmin) * w;
end

function draw_sharp_network_arrow(x1, y1, x2, y2, lw, edgeColor)
    % Draw a publication-style arrow with a sharp triangular head.
    % This avoids MATLAB graph/quiver arrowheads that can look like pins.

    dx = x2 - x1;
    dy = y2 - y1;
    d = hypot(dx, dy);
    if d <= eps
        return;
    end

    ux = dx / d;
    uy = dy / d;
    px = -uy;
    py = ux;

    nodeRadiusStart = 0.16;
    nodeRadiusEnd   = 0.20;

    sx = x1 + nodeRadiusStart * ux;
    sy = y1 + nodeRadiusStart * uy;
    tipx = x2 - nodeRadiusEnd * ux;
    tipy = y2 - nodeRadiusEnd * uy;

    headLen = min(0.12 + 0.010*lw, 0.22);
    headWid = min(0.045 + 0.006*lw, 0.11);

    basex = tipx - headLen * ux;
    basey = tipy - headLen * uy;

    % Line stops at the base of the triangular head.
    plot([sx basex], [sy basey], '-', 'Color', edgeColor, 'LineWidth', lw);

    % Sharp filled triangular arrowhead.
    hx = [tipx, basex + headWid*px, basex - headWid*px];
    hy = [tipy, basey + headWid*py, basey - headWid*py];
    patch(hx, hy, edgeColor, 'EdgeColor', edgeColor, 'LineWidth', 0.5);
end

function draw_network_line_no_arrow(x1, y1, x2, y2, lw, edgeColor)
    % Zero-lag link: no leader/follower direction is implied.
    dx = x2 - x1;
    dy = y2 - y1;
    d = hypot(dx, dy);
    if d <= eps
        return;
    end
    ux = dx / d;
    uy = dy / d;
    nodeRadius = 0.17;
    sx = x1 + nodeRadius * ux;
    sy = y1 + nodeRadius * uy;
    ex = x2 - nodeRadius * ux;
    ey = y2 - nodeRadius * uy;
    plot([sx ex], [sy ey], '-', 'Color', edgeColor, 'LineWidth', lw);
end



function Stats = compute_lag_direction_stats(LagResults, reliabilityThreshold)

    % Summarize optimal lag clustering and directionality for every
    % TargetFeature--MusicFeature pair.
    % Lag convention used throughout the script:
    %   lag > 0 : target follows music, i.e. Ampl leads target
    %   lag < 0 : target leads Ampl
    Stats = table();
    if isempty(LagResults)
        return;
    end

    tasks = unique(LagResults.Task, 'stable');
    row = 0;
    for t = 1:numel(tasks)
        taskName = tasks{t};
        taskIdx = strcmp(LagResults.Task, taskName);
        targets = unique(LagResults.TargetFeature(taskIdx), 'stable');
        musicFeatures = unique(LagResults.MusicFeature(taskIdx), 'stable');

        for a = 1:numel(targets)
            for b = 1:numel(musicFeatures)
                idx = taskIdx & strcmp(LagResults.TargetFeature, targets{a}) & strcmp(LagResults.MusicFeature, musicFeatures{b});
                if ~any(idx)
                    continue;
                end
                T = LagResults(idx,:);
                lags = T.BestLag_TargetMinusMusic;
                cs = T.BestLaggedCS;
                absCS = T.BestLaggedAbsCS;
                rel = logical(T.Reliable);
                lags = lags(isfinite(lags));
                if isempty(lags)
                    continue;
                end

                row = row + 1;
                Stats.Task{row,1} = taskName;
                Stats.TargetFeature{row,1} = targets{a};
                Stats.MusicFeature{row,1} = musicFeatures{b};
                Stats.N(row,1) = height(T);
                Stats.NReliable(row,1) = sum(rel);
                Stats.FracReliable(row,1) = mean(rel);
                Stats.MeanBestLag(row,1) = mean(T.BestLag_TargetMinusMusic,'omitnan');
                Stats.MedianBestLag(row,1) = median(T.BestLag_TargetMinusMusic,'omitnan');
                Stats.StdBestLag(row,1) = std(T.BestLag_TargetMinusMusic,'omitnan');
                Stats.FracMusicLeads(row,1) = mean(T.BestLag_TargetMinusMusic > 0,'omitnan');
                Stats.FracTargetLeads(row,1) = mean(T.BestLag_TargetMinusMusic < 0,'omitnan');
                Stats.FracZeroLag(row,1) = mean(T.BestLag_TargetMinusMusic == 0,'omitnan');
                Stats.MeanBestCS(row,1) = mean(cs,'omitnan');
                Stats.MeanBestAbsCS(row,1) = mean(absCS,'omitnan');
                Stats.MedianBestAbsCS(row,1) = median(absCS,'omitnan');

                relIdx = rel & isfinite(T.BestLag_TargetMinusMusic);
                if any(relIdx)
                    Stats.ReliableMeanLag(row,1) = mean(T.BestLag_TargetMinusMusic(relIdx),'omitnan');
                    Stats.ReliableMedianLag(row,1) = median(T.BestLag_TargetMinusMusic(relIdx),'omitnan');
                    Stats.ReliableFracMusicLeads(row,1) = mean(T.BestLag_TargetMinusMusic(relIdx) > 0,'omitnan');
                    Stats.ReliableFracTargetLeads(row,1) = mean(T.BestLag_TargetMinusMusic(relIdx) < 0,'omitnan');
                    Stats.ReliableMeanAbsCS(row,1) = mean(absCS(relIdx),'omitnan');
                else
                    Stats.ReliableMeanLag(row,1) = NaN;
                    Stats.ReliableMedianLag(row,1) = NaN;
                    Stats.ReliableFracMusicLeads(row,1) = NaN;
                    Stats.ReliableFracTargetLeads(row,1) = NaN;
                    Stats.ReliableMeanAbsCS(row,1) = NaN;
                end

                Stats.PassesFocusReliability(row,1) = Stats.FracReliable(row,1) >= reliabilityThreshold;
            end
        end
    end
end

function FocusStats = compute_focus_lag_pair_stats(LagResults, FocusLagPairs, reliabilityThreshold)

    FocusStats = table();
    if isempty(LagResults) || isempty(FocusLagPairs)
        return;
    end

    row = 0;
    for k = 1:size(FocusLagPairs,1)
        targetName = FocusLagPairs{k,1};
        musicName  = FocusLagPairs{k,2};
        idx = strcmp(LagResults.TargetFeature, targetName) & strcmp(LagResults.MusicFeature, musicName);
        if ~any(idx)
            continue;
        end
        T = LagResults(idx,:);
        rel = logical(T.Reliable);
        row = row + 1;
        FocusStats.TargetFeature{row,1} = targetName;
        FocusStats.MusicFeature{row,1} = musicName;
        FocusStats.Pair{row,1} = sprintf('%s <- %s', targetName, musicName);
        FocusStats.N(row,1) = height(T);
        FocusStats.FracReliable(row,1) = mean(rel);
        FocusStats.MeanBestAbsCS(row,1) = mean(T.BestLaggedAbsCS,'omitnan');
        FocusStats.MedianBestAbsCS(row,1) = median(T.BestLaggedAbsCS,'omitnan');
        FocusStats.MeanBestCS(row,1) = mean(T.BestLaggedCS,'omitnan');
        FocusStats.MeanBestLag(row,1) = mean(T.BestLag_TargetMinusMusic,'omitnan');
        FocusStats.MedianBestLag(row,1) = median(T.BestLag_TargetMinusMusic,'omitnan');
        FocusStats.FracMusicLeads(row,1) = mean(T.BestLag_TargetMinusMusic > 0,'omitnan');
        FocusStats.FracTargetLeads(row,1) = mean(T.BestLag_TargetMinusMusic < 0,'omitnan');
        FocusStats.FracZeroLag(row,1) = mean(T.BestLag_TargetMinusMusic == 0,'omitnan');
        FocusStats.PassesFocusReliability(row,1) = FocusStats.FracReliable(row,1) >= reliabilityThreshold;

        relIdx = rel & isfinite(T.BestLag_TargetMinusMusic);
        if any(relIdx)
            FocusStats.ReliableMeanBestAbsCS(row,1) = mean(T.BestLaggedAbsCS(relIdx),'omitnan');
            FocusStats.ReliableMeanLag(row,1) = mean(T.BestLag_TargetMinusMusic(relIdx),'omitnan');
            FocusStats.ReliableFracMusicLeads(row,1) = mean(T.BestLag_TargetMinusMusic(relIdx) > 0,'omitnan');
            FocusStats.ReliableFracTargetLeads(row,1) = mean(T.BestLag_TargetMinusMusic(relIdx) < 0,'omitnan');
        else
            FocusStats.ReliableMeanBestAbsCS(row,1) = NaN;
            FocusStats.ReliableMeanLag(row,1) = NaN;
            FocusStats.ReliableFracMusicLeads(row,1) = NaN;
            FocusStats.ReliableFracTargetLeads(row,1) = NaN;
        end
    end

    if ~isempty(FocusStats)
        FocusStats = sortrows(FocusStats, {'PassesFocusReliability','FracReliable','MeanBestAbsCS'}, {'descend','descend','descend'});
    end
end


function AR1Stats = compute_ar1_robustness_focus_stats(LagResults, FocusLagPairs, alpha, reliabilityThreshold)

    % Summarize, for each focus music->target pair, both:
    %   1) raw-delta Spearman best-lag CS with moving-block bootstrap p-values
    %   2) AR(1)-prewhitened Pearson correlation at the same best lag
    % This table answers whether a link survives after autocorrelation is removed.

    AR1Stats = table();
    if isempty(LagResults) || isempty(FocusLagPairs)
        return;
    end

    row = 0;
    for k = 1:size(FocusLagPairs,1)
        targetName = FocusLagPairs{k,1};
        musicName  = FocusLagPairs{k,2};
        idx = strcmp(LagResults.TargetFeature, targetName) & strcmp(LagResults.MusicFeature, musicName);
        if ~any(idx)
            continue;
        end
        T = LagResults(idx,:);

        row = row + 1;
        AR1Stats.TargetFeature{row,1} = targetName;
        AR1Stats.MusicFeature{row,1} = musicName;
        AR1Stats.Pair{row,1} = sprintf('%s <- %s', targetName, musicName);
        AR1Stats.N(row,1) = height(T);

        % Main result: Spearman raw-delta lagged CS with block-bootstrap significance.
        relBlock = isfinite(T.p_block_bootstrap) & T.p_block_bootstrap < alpha;
        AR1Stats.Spearman_MeanBestCS(row,1) = mean(T.BestLaggedCS,'omitnan');
        AR1Stats.Spearman_MeanBestAbsCS(row,1) = mean(T.BestLaggedAbsCS,'omitnan');
        AR1Stats.Spearman_MedianBestAbsCS(row,1) = median(T.BestLaggedAbsCS,'omitnan');
        AR1Stats.Spearman_BlockBoot_R(row,1) = mean(relBlock,'omitnan');
        AR1Stats.Spearman_MeanBestLag(row,1) = mean(T.BestLag_TargetMinusMusic,'omitnan');
        AR1Stats.Spearman_FracMusicLeads(row,1) = mean(T.BestLag_TargetMinusMusic > 0,'omitnan');
        AR1Stats.Spearman_FracTargetLeads(row,1) = mean(T.BestLag_TargetMinusMusic < 0,'omitnan');
        AR1Stats.Spearman_FracZeroLag(row,1) = mean(T.BestLag_TargetMinusMusic == 0,'omitnan');

        % Robustness check: AR(1)-prewhitened Pearson at the SAME best lag.
        hasAR = isfinite(T.Pearson_AR1_Whitened);
        arSig = hasAR & isfinite(T.Pearson_AR1_p) & T.Pearson_AR1_p < alpha;
        AR1Stats.AR1Pearson_MeanR(row,1) = mean(T.Pearson_AR1_Whitened,'omitnan');
        AR1Stats.AR1Pearson_MeanAbsR(row,1) = mean(abs(T.Pearson_AR1_Whitened),'omitnan');
        AR1Stats.AR1Pearson_MedianAbsR(row,1) = median(abs(T.Pearson_AR1_Whitened),'omitnan');
        AR1Stats.AR1Pearson_Reliability(row,1) = mean(arSig,'omitnan');
        AR1Stats.AR1Pearson_NValid(row,1) = sum(hasAR);

        % Directional consistency after AR(1) whitening: sign agreement between
        % raw-delta Spearman best-lag CS and AR(1)-whitened Pearson residual CS.
        signOK = hasAR & isfinite(T.BestLaggedCS) & sign(T.BestLaggedCS) == sign(T.Pearson_AR1_Whitened);
        AR1Stats.AR1Pearson_FracSignAgreement(row,1) = mean(signOK,'omitnan');

        AR1Stats.PassesBlockBootstrap(row,1) = AR1Stats.Spearman_BlockBoot_R(row,1) >= reliabilityThreshold;
        AR1Stats.SurvivesAR1Pearson(row,1) = AR1Stats.AR1Pearson_Reliability(row,1) >= reliabilityThreshold;

        if AR1Stats.SurvivesAR1Pearson(row,1)
            verdict = 'survives AR(1) whitening';
        elseif AR1Stats.AR1Pearson_Reliability(row,1) >= 0.25
            verdict = 'weak/partial AR(1) support';
        else
            verdict = 'does not survive AR(1) whitening';
        end
        AR1Stats.Verdict{row,1} = verdict;
    end

    if ~isempty(AR1Stats)
        AR1Stats = sortrows(AR1Stats, ...
            {'SurvivesAR1Pearson','AR1Pearson_Reliability','Spearman_BlockBoot_R','Spearman_MeanBestAbsCS'}, ...
            {'descend','descend','descend','descend'});
    end
end

function plot_ar1_robustness_summary(AR1Stats, reliabilityThreshold, alpha)

    if isempty(AR1Stats)
        text(0.5,0.5,'No AR(1) robustness statistics available','HorizontalAlignment','center');
        axis off;
        return;
    end

    S = sortrows(AR1Stats, {'AR1Pearson_Reliability','Spearman_BlockBoot_R','Spearman_MeanBestAbsCS'}, {'descend','descend','descend'});
    nShow = min(14, height(S));
    S = S(1:nShow,:);
    labels = short_focus_pair_labels(S.Pair);

    tl = tiledlayout(2,2,'TileSpacing','none','Padding','compact');
    title(tl, sprintf('Raw \delta Spearman lagged CS vs AR(1)-whitened Pearson robustness, alpha = %.2f', alpha), 'FontWeight','bold');

    nexttile; hold on; box on;
    y = 1:nShow;
    barh(y, [S.Spearman_MeanBestAbsCS S.AR1Pearson_MeanAbsR], 'grouped');
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xlabel('Mean magnitude');
    title('Effect size: raw \delta Spearman vs AR(1) Pearson');
    legend({'Spearman best |CS|','AR(1) Pearson |r|'}, 'Location','best','FontSize',28);
    grid on;

    nexttile; hold on; box on;
    barh(y, [S.Spearman_BlockBoot_R S.AR1Pearson_Reliability], 'grouped');
    xline(reliabilityThreshold,'k--','LineWidth',1.2);
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xlabel('Reliability fraction');
    title(sprintf('Reliability: threshold R >= %.2f', reliabilityThreshold));
    legend({'Block bootstrap R','AR(1) Pearson R'}, 'Location','best','FontSize',28);
    xlim([0 1]);
    grid on;

    nexttile; hold on; box on;
    barh(y, S.Spearman_MeanBestLag);
    xline(0,'k--','LineWidth',1.1);
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xlabel('Mean best lag');
    title('+ lag: Ampl leads target');
    grid on;

    nexttile; hold on; box on;
    barh(y, S.AR1Pearson_FracSignAgreement);
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xlabel('Fraction sign agreement');
    title('Sign agreement: Spearman CS vs AR(1) Pearson');
    xlim([0 1]);
    grid on;

end

function labels = short_focus_pair_labels(pairNames)
    pairNames = cellstr(string(pairNames));
    labels = pairNames;
    labels = strrep(labels,'Frontal-L','FL'); labels = strrep(labels,'Frontal-R','FR');
    labels = strrep(labels,'Temporal-L','TL'); labels = strrep(labels,'Temporal-R','TR');
    labels = strrep(labels,'Central-L','CL'); labels = strrep(labels,'Central-R','CR'); labels = strrep(labels,'Central','C');
    labels = strrep(labels,'Parietal-L','PL'); labels = strrep(labels,'Parietal-R','PR');
    labels = strrep(labels,'Occipital-L','OL'); labels = strrep(labels,'Occipital-R','OR');
    labels = strrep(labels, 'Sensorimotor', 'SM');
    labels = strrep(labels, 'Frontal-Executive', 'FE');
    labels = strrep(labels, 'Parietal', 'PI');
    labels = strrep(labels, 'Occipital', 'Occ');
    labels = strrep(labels, 'Auditory', 'Aud');
end

function plot_lag_direction_summary(Stats, reliabilityThreshold)

    if isempty(Stats)
        text(0.5,0.5,'No lag-direction statistics available','HorizontalAlignment','center');
        axis off;
        return;
    end

    % Show the top pairs ranked by reliability and magnitude.
    S = sortrows(Stats, {'FracReliable','MeanBestAbsCS'}, {'descend','descend'});
    nShow = min(12, height(S));
    S = S(1:nShow,:);
    labels = strcat(short_feature_label(S.TargetFeature), {' <- '}, short_feature_label(S.MusicFeature));

    tl = tiledlayout(2,2,'TileSpacing','none','Padding','compact');
    title(tl, sprintf('Lag distribution and directionality summary (focus R >= %.2f)', reliabilityThreshold), 'FontWeight','bold');

    % Use numeric Y positions rather than categorical Y data. Some different
    % task/music combinations can produce identical text labels, and MATLAB
    % bar/barh requires categorical X/Y values to be unique. Numeric positions
    % allow duplicate labels safely while preserving every row in the summary.
    y = 1:nShow;

    nexttile; hold on; box on;
    barh(y, S.MeanBestAbsCS);
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xlabel('Mean best |CS|');
    title('Lagged coupling magnitude');
    grid on;

    nexttile; hold on; box on;
    barh(y, S.FracReliable);
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xline(reliabilityThreshold,'k--','LineWidth',1.2);
    xlabel('Reliability fraction');
    title('Reliability across subjects');
    grid on;

    nexttile; hold on; box on;
    barh(y, S.MeanBestLag);
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xline(0,'k--','LineWidth',1.2);
    xlabel('Mean best lag');
    title('Lag clustering: + means Ampl leads target');
    grid on;

    nexttile; hold on; box on;
    X = [S.FracMusicLeads, S.FracTargetLeads, S.FracZeroLag];
    barh(y, X, 'stacked');
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xlabel('Fraction of subjects');
    legend({'Music leads','Target leads','Zero lag'}, 'Location','bestoutside','FontSize',28);
    title('Directionality of best lag');
    grid on;
end

function plot_focus_lag_pair_summary(FocusStats, reliabilityThreshold)

    if isempty(FocusStats)
        text(0.5,0.5,'No focused lag-pair statistics available','HorizontalAlignment','center');
        axis off;
        return;
    end

    S = FocusStats;
    nShow = min(14, height(S));
    S = S(1:nShow,:);
    labels = S.Pair;

    tl = tiledlayout(2,2,'TileSpacing','none','Padding','compact');
    title(tl, 'Focused music--physiology/brain lagged raw-delta CS pairs', 'FontWeight','bold');

    % Numeric Y positions make the plot robust to duplicate pair labels.
    y = 1:nShow;

    nexttile; hold on; box on;
    barh(y, S.MeanBestAbsCS);
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xlabel('Mean best |CS|');
    title('Effect size');
    grid on;

    nexttile; hold on; box on;
    barh(y, S.FracReliable);
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xline(reliabilityThreshold,'k--','LineWidth',1.2);
    xlabel('Reliability fraction');
    title(sprintf('Robust links: R >= %.2f', reliabilityThreshold));
    grid on;

    nexttile; hold on; box on;
    barh(y, S.MeanBestLag);
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xline(0,'k--','LineWidth',1.2);
    xlabel('Mean best lag');
    title('+ lag: Ampl leads target');
    grid on;

    nexttile; hold on; box on;
    X = [S.FracMusicLeads, S.FracTargetLeads, S.FracZeroLag];
    barh(y, X, 'stacked');
    set(gca,'YTick',y,'YTickLabel',labels,'YDir','reverse');
    xlabel('Fraction of subjects');
    legend({'Music leads','Target leads','Zero lag'}, 'Location','bestoutside','FontSize',28);
    title('Directionality split');
    grid on;
end

function txt = format_duration_hms(secondsValue)
    % Convert seconds to a compact HH:MM:SS string for the progress bar.
    if ~isfinite(secondsValue) || secondsValue < 0
        txt = '--:--:--';
        return;
    end
    totalSeconds = max(0, round(secondsValue));
    hh = floor(totalSeconds / 3600);
    mm = floor(mod(totalSeconds, 3600) / 60);
    ss = mod(totalSeconds, 60);
    txt = sprintf('%02d:%02d:%02d', hh, mm, ss);
end

function safe_close_waitbar(h)
    % Close the waitbar safely if the script stops because of an error or
    % the user interrupts execution.
    try
        if ~isempty(h) && isgraphics(h)
            close(h);
        end
    catch
    end
end

function out = short_feature_label(in)
    in = cellstr(string(in));
    out = in;
    for i = 1:numel(in)
        switch in{i}
            case 'Frontal-L', out{i}='FL';
            case 'Frontal-R', out{i}='FR';
            case 'Temporal-L', out{i}='TL';
            case 'Temporal-R', out{i}='TR';
            case 'Central-L', out{i}='CL';
            case 'Central-R', out{i}='CR';
            case 'Central', out{i}='C';
            case 'Parietal-L', out{i}='PL';
            case 'Parietal-R', out{i}='PR';
            case 'Parietal', out{i}='PAR';
            case 'Occipital-L', out{i}='OL';
            case 'Occipital-R', out{i}='OR';
            case 'Occipital', out{i}='OCC';
            case 'Auditory'
                out{i} = 'AUD';
            case 'Sensorimotor'
                out{i} = 'SM';
            case 'Frontal-Executive'
                out{i} = 'FE';
            case 'Parietal'
                out{i} = 'PAR';
            case 'Occipital'
                out{i} = 'OCC';
        end
    end
end

function B = summarize_brain_only_map(CSmap, Relmap, groupLabels, EEGGroupNames)
    brainIdx = find(ismember(groupLabels, EEGGroupNames));
    B.NumBrainGroups = numel(brainIdx);
    B.NumBrainPairs = 0;
    B.MeanBrainCS = NaN;
    B.MeanAbsBrainCS = NaN;
    B.MedianAbsBrainCS = NaN;
    B.FracReliableBrainPairs = NaN;
    if numel(brainIdx) < 2, return; end

    M = CSmap(brainIdx,brainIdx);
    R = Relmap(brainIdx,brainIdx);
    mask = triu(true(size(M)),1) & isfinite(M);
    vals = M(mask);
    rel = R(mask);
    B.NumBrainPairs = numel(vals);
    if isempty(vals), return; end
    B.MeanBrainCS = mean(vals,'omitnan');
    B.MeanAbsBrainCS = mean(abs(vals),'omitnan');
    B.MedianAbsBrainCS = median(abs(vals),'omitnan');
    B.FracReliableBrainPairs = mean(rel,'omitnan');
end

function [coord, nPairsUsed] = compute_rolling_brain_coordination_index(G, groupLabels, EEGGroupNames, windowPoints, windowMode, minSamplesPerPair, minPairs)
    % Time-resolved network coordination from functional EEG scaling series.
    % For each local window (trailing by default), compute Spearman correlation for every
    % available EEG-group pair and average their absolute correlations.
    labels = cellstr(string(groupLabels));
    brainIdx = find(ismember(labels, EEGGroupNames));
    T = size(G,2);
    coord = nan(1,T);
    nPairsUsed = nan(1,T);
    if numel(brainIdx) < 3 || T < 3
        return;
    end

    windowPoints = max(3, round(windowPoints));

    for tt = 1:T
        if strcmpi(windowMode,'centered')
            halfW = floor(windowPoints/2);
            a = max(1, tt-halfW);
            b = min(T, tt+halfW);
        else
            % Default/primary: trailing (causal) local network state.
            a = max(1, tt-windowPoints+1);
            b = tt;
        end
        vals = [];
        for ii = 1:numel(brainIdx)-1
            for jj = ii+1:numel(brainIdx)
                x = G(brainIdx(ii),a:b)';
                y = G(brainIdx(jj),a:b)';
                ok = isfinite(x) & isfinite(y);
                x = x(ok); y = y(ok);
                if numel(x) >= minSamplesPerPair && std(x)>0 && std(y)>0
                    r = local_spearman_corr(x,y);
                    if isfinite(r)
                        vals(end+1,1) = abs(r); %#ok<AGROW>
                    end
                end
            end
        end
        nPairsUsed(tt) = numel(vals);
        if numel(vals) >= minPairs
            coord(tt) = mean(vals,'omitnan');
        end
    end
end

function [csVal, nVal] = fixed_lag_value(allLagCS, LagRange, wantedLag, target, music, UseDeltaDiffForCS)
    idx = find(LagRange == wantedLag, 1);
    if isempty(idx)
        csVal = NaN;
        nVal = NaN;
        return;
    end
    csVal = allLagCS(idx);
    [x,y] = align_target_music_at_lag(target, music, wantedLag, UseDeltaDiffForCS);
    ok = isfinite(x) & isfinite(y);
    nVal = sum(ok);
end

function FixedRows = lag_rows_to_fixed_lag_table(LagRows, LagRange, FixedLagValues)
    FixedRows = table();
    if isempty(LagRows), return; end
    for r = 1:height(LagRows)
        for k = 1:numel(FixedLagValues)
            lag = FixedLagValues(k);
            col = lag_column_name(lag);
            ncol = ['N_' col(4:end)];  % CS_LagX -> N_LagX
            if ~ismember(col, LagRows.Properties.VariableNames)
                continue;
            end
            row = table();
            row.Dyad = LagRows.Dyad(r);
            row.Task = LagRows.Task(r);
            row.Participant = LagRows.Participant(r);
            row.Subject = LagRows.Subject(r);
            row.TargetFeature = LagRows.TargetFeature(r);
            row.MusicFeature = LagRows.MusicFeature(r);
            row.Lag = lag;
            row.LagMeaning = {lag_meaning(lag)};
            row.CS = LagRows.(col)(r);
            row.AbsCS = abs(row.CS);
            if ismember(ncol, LagRows.Properties.VariableNames)
                row.N = LagRows.(ncol)(r);
            else
                row.N = NaN;
            end
            row.CorrelationMethod = LagRows.CorrelationMethod(r);
            FixedRows = [FixedRows; row]; %#ok<AGROW>
        end
    end
end

function name = lag_column_name(lag)
    switch lag
        case -2, name = 'CS_LagMinus2';
        case -1, name = 'CS_LagMinus1';
        case 0,  name = 'CS_Lag0';
        case 1,  name = 'CS_LagPlus1';
        case 2,  name = 'CS_LagPlus2';
        otherwise, error('Unsupported fixed lag: %g', lag);
    end
end

function Stats = aggregate_fixed_lag_by_task(FixedRows, taskList)
    Stats = table();
    if isempty(FixedRows), return; end
    targets = unique(FixedRows.TargetFeature, 'stable');
    lags = unique(FixedRows.Lag, 'sorted');
    for t = 1:numel(taskList)
        task = taskList{t};
        for g = 1:numel(targets)
            target = targets{g};
            for k = 1:numel(lags)
                lag = lags(k);
                idx = strcmp(FixedRows.Task,task) & strcmp(FixedRows.TargetFeature,target) & FixedRows.Lag==lag & isfinite(FixedRows.CS);
                x = FixedRows.CS(idx);
                n = numel(x);
                if n == 0, continue; end
                if n > 1
                    sem = std(x,'omitnan')/sqrt(n);
                    semAbs = std(abs(x),'omitnan')/sqrt(n);
                else
                    sem = NaN; semAbs = NaN;
                end
                row = table({task},{target},lag,n,mean(x,'omitnan'),sem,mean(abs(x),'omitnan'),semAbs, ...
                    mean(x>0,'omitnan'), ...
                    'VariableNames', {'Task','TargetFeature','Lag','NSubjects','MeanCS','SEM_CS','MeanAbsCS','SEM_AbsCS','FracPositive'});
                Stats = [Stats; row]; %#ok<AGROW>
            end
        end
    end
end

function plot_brain_music_paper_summary(BrainTaskStats, FixedLagTaskStats, EEGGroupNames, IncludeECG, IncludeRESP, BrainNetworkCoordName)
    tl = tiledlayout(2,2,'TileSpacing','none','Padding','compact');
    title(tl, 'Trial-specific brain coordination and music-amplitude coupling to network organization', 'FontWeight','bold');

    % Panel A: static brain-only CS by experimental trial.
    nexttile; hold on; box on;
    x = 1:height(BrainTaskStats);
    errorbar(x, BrainTaskStats.MeanAbsBrainCS, BrainTaskStats.SEM_AbsBrainCS, 'o-','LineWidth',1.3);
    set(gca,'XTick',x,'XTickLabel',BrainTaskStats.Task); grid on;
    xlabel('Trial / experiment'); ylabel('Mean |CS| among EEG functional groups');
    title('A. Brain-only complexity coordination');

    % Panel B: mean dynamic rolling network coordination by trial.
    nexttile; hold on; box on;
    errorbar(x, BrainTaskStats.MeanDynamicBrainNetworkCoord, BrainTaskStats.SEM_DynamicBrainNetworkCoord, 'o-','LineWidth',1.3);
    set(gca,'XTick',x,'XTickLabel',BrainTaskStats.Task); grid on;
    xlabel('Trial / experiment'); ylabel('Mean rolling network coordination');
    title('B. Dynamic brain-network coordination state');

    % Panel C: Ampl -> derived network coordination at pre-specified lags.
    musicTasks = unique(FixedLagTaskStats.Task,'stable');
    lags = unique(FixedLagTaskStats.Lag,'sorted');
    Hnet = nan(numel(musicTasks),numel(lags));
    for j=1:numel(musicTasks)
        for k=1:numel(lags)
            idx = strcmp(FixedLagTaskStats.TargetFeature,BrainNetworkCoordName) & ...
                  strcmp(FixedLagTaskStats.Task,musicTasks{j}) & FixedLagTaskStats.Lag==lags(k);
            if any(idx), Hnet(j,k)=FixedLagTaskStats.MeanCS(find(idx,1)); end
        end
    end
    nexttile;
    imagesc(Hnet); colorbar; caxis([-0.5 0.5]);
    set(gca,'XTick',1:numel(lags),'XTickLabel',compose('%+d',lags), ...
        'YTick',1:numel(musicTasks),'YTickLabel',musicTasks);
    xlabel('Lag in delta windows (+ = network follows Ampl)');
    ylabel('Music trial');
    title('C. Ampl vs brain-network coordination');

    % Panel D: zero-lag regional/physiology music coupling.
    targets = EEGGroupNames;
    if IncludeECG, targets{end+1}='ECG'; end
    if IncludeRESP, targets{end+1}='RESP'; end
    Z = nan(numel(targets),numel(musicTasks));
    for i=1:numel(targets)
        for j=1:numel(musicTasks)
            idx = strcmp(FixedLagTaskStats.TargetFeature,targets{i}) & strcmp(FixedLagTaskStats.Task,musicTasks{j}) & FixedLagTaskStats.Lag==0;
            if any(idx), Z(i,j)=FixedLagTaskStats.MeanCS(find(idx,1)); end
        end
    end
    nexttile;
    imagesc(Z); colorbar; caxis([-0.5 0.5]);
    set(gca,'XTick',1:numel(musicTasks),'XTickLabel',musicTasks, ...
        'YTick',1:numel(targets),'YTickLabel',short_target_labels(targets));
    xlabel('Music trial'); ylabel('Target');
    title('D. Ampl-target CS at lag 0');
end

function plot_network_music_shortlag_summary(NetStats, BrainNetworkCoordName)
    if isempty(NetStats)
        text(0.5,0.5,'No network-level music statistics available','HorizontalAlignment','center');
        axis off; return;
    end
    tasks = unique(NetStats.Task,'stable');
    lags = unique(NetStats.Lag,'sorted');
    tl = tiledlayout(1,2,'TileSpacing','none','Padding','compact');
    title(tl, sprintf('Music amplitude vs %s at pre-specified short lags', BrainNetworkCoordName), ...
        'Interpreter','none','FontWeight','bold');

    nexttile; hold on; box on;
    for t=1:numel(tasks)
        y = nan(size(lags)); e = nan(size(lags));
        for k=1:numel(lags)
            idx = strcmp(NetStats.Task,tasks{t}) & NetStats.Lag==lags(k);
            if any(idx)
                r=find(idx,1); y(k)=NetStats.MeanCS(r); e(k)=NetStats.SEM_CS(r);
            end
        end
        errorbar(lags,y,e,'o-','LineWidth',1.2,'DisplayName',tasks{t});
    end
    yline(0,'k--'); xline(0,'k:'); grid on;
    xlabel('Lag in delta windows (+ = network follows Ampl)');
    ylabel('Mean signed CS');
    title('Signed coupling by experiment');
    legend('Location','best','FontSize',28);

    nexttile; hold on; box on;
    for t=1:numel(tasks)
        y = nan(size(lags)); e = nan(size(lags));
        for k=1:numel(lags)
            idx = strcmp(NetStats.Task,tasks{t}) & NetStats.Lag==lags(k);
            if any(idx)
                r=find(idx,1); y(k)=NetStats.MeanAbsCS(r); e(k)=NetStats.SEM_AbsCS(r);
            end
        end
        errorbar(lags,y,e,'o-','LineWidth',1.2,'DisplayName',tasks{t});
    end
    xline(0,'k:'); grid on;
    xlabel('Lag in delta windows (+ = network follows Ampl)');
    ylabel('Mean |CS|');
    title('Coupling magnitude by experiment');
    legend('Location','best','FontSize',28);
end

function out = short_target_labels(targets)
    out = cell(size(targets));
    for i=1:numel(targets), out{i}=short_target_label(targets{i}); end
end

function out = short_target_label(name)
    switch name
        case 'Frontal-L', out='FL';
        case 'Frontal-R', out='FR';
        case 'Temporal-L', out='TL';
        case 'Temporal-R', out='TR';
        case 'Central-L', out='CL';
        case 'Central-R', out='CR';
        case 'Central', out='C';
        case 'Parietal-L', out='PL';
        case 'Parietal-R', out='PR';
        case 'Occipital-L', out='OL';
        case 'Occipital-R', out='OR';
        case 'Auditory', out='AUD';
        case 'Sensorimotor', out='SM';
        case 'Frontal-Executive', out='FE';
        case 'Parietal', out='PAR';
        case 'Occipital', out='OCC';
        otherwise, out=name;
    end
end

function BrainTaskStats = aggregate_brain_summary_by_task(BrainSummary, taskList, TrialClassification)
    BrainTaskStats = table();
    for i = 1:numel(taskList)
        task = taskList{i};
        idx = strcmp(BrainSummary.Task, task) & isfinite(BrainSummary.MeanAbsBrainCS);
        x = BrainSummary.MeanAbsBrainCS(idx);
        xr = BrainSummary.FracReliableBrainPairs(idx);
        xs = BrainSummary.MeanBrainCS(idx);
        xn = BrainSummary.MeanBrainNetworkCoord(idx);
        n = numel(x);
        if n > 1
            semAbs = std(x,'omitnan')/sqrt(n);
            semSigned = std(xs,'omitnan')/sqrt(n);
            semRel = std(xr,'omitnan')/sqrt(n);
            semNet = std(xn,'omitnan')/sqrt(sum(isfinite(xn)));
        else
            semAbs = NaN; semSigned = NaN; semRel = NaN; semNet = NaN;
        end
        cat = task_category_label(TrialClassification, task);
        row = table({task},{cat},n,mean(xs,'omitnan'),semSigned,mean(x,'omitnan'),semAbs, ...
            mean(xr,'omitnan'),semRel,mean(xn,'omitnan'),semNet, ...
            'VariableNames', {'Task','TaskCategory','NSubjects','MeanBrainCS','SEM_BrainCS', ...
            'MeanAbsBrainCS','SEM_AbsBrainCS','MeanFracReliableBrainPairs','SEM_FracReliableBrainPairs', ...
            'MeanDynamicBrainNetworkCoord','SEM_DynamicBrainNetworkCoord'});
        BrainTaskStats = [BrainTaskStats; row]; %#ok<AGROW>
    end
end

function T = extract_brain_music_zero_lag(Results, EEGGroupNames)
    T = table();
    if isempty(Results), return; end
    idx = ismember(Results.Feature1, EEGGroupNames) & strcmp(Results.Feature2,'Ampl');
    if any(idx)
        T = Results(idx,:);
    end
end

function plot_brain_cs_by_task(BrainTaskStats)
    if isempty(BrainTaskStats)
        text(0.5,0.5,'No brain-only task statistics available','HorizontalAlignment','center');
        axis off; return;
    end
    x = 1:height(BrainTaskStats);
    labels = task_display_labels(BrainTaskStats.Task);
    tl = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    title(tl,'Brain-only CS across trials (same EEG-only definition for every trial)','FontWeight','bold');

    nexttile; hold on; box on;
    h=errorbar(x, BrainTaskStats.MeanAbsBrainCS, BrainTaskStats.SEM_AbsBrainCS, 'o','LineWidth',1.2,'MarkerSize',7);fill_errorbar_marker(h);
    set(gca,'XTick',x,'XTickLabel',labels); xtickangle(25);
    ylabel('Mean |CS| among functional EEG groups');
    title('Brain complexity coordination by trial'); grid on;

    nexttile; hold on; box on;
    h=errorbar(x, BrainTaskStats.MeanFracReliableBrainPairs, BrainTaskStats.SEM_FracReliableBrainPairs, 'o','LineWidth',1.2,'MarkerSize',7);fill_errorbar_marker(h);
    set(gca,'XTick',x,'XTickLabel',labels); xtickangle(25);
    ylabel('Fraction reliable EEG-group pairs'); ylim([0.5 1]); % FINAL: Supplement page 11 right panel starts at 0.5
    title('Reliability of brain CS by trial'); grid on;
end

function plotTitle = make_analysis_title(taskName, trialLabel, UseDeltaDiffForCS)
    if UseDeltaDiffForCS
        metricName = 'dDelta-CS';
    else
        metricName = 'raw-delta CS';
    end
    plotTitle = sprintf('%s: within-subject functional brain %s across participants', ...
        task_display_label(taskName), metricName);
end

function label = task_category_label(TrialClassification, taskName)
    label = 'Unclassified';
    if isempty(TrialClassification), return; end
    idx = strcmp(TrialClassification.Task, taskName);
    if any(idx)
        label = TrialClassification.TaskCategory{find(idx,1)};
    end
end

function TrialClassification = build_trial_classification(FileTrialInfo, taskList)
    TrialClassification = table();
    for i = 1:numel(taskList)
        task = taskList{i};
        idx = strcmp(FileTrialInfo.Task, task);
        n = sum(idx);
        nAmpl = sum(FileTrialInfo.HasAmplColumn(idx));
        if n == 0
            cat = 'NoFiles';
        elseif nAmpl == n
            cat = 'TaskCondition';
        elseif nAmpl == 0
            cat = 'TaskCondition';
        else
            cat = 'MIXED_CheckInput';
        end
        nUsable = sum(FileTrialInfo.HasUsableAmpl(idx));
        row = table({task}, n, nAmpl, n-nAmpl, nUsable, nAmpl/max(1,n), {cat}, ...
            'VariableNames', {'Task','NFiles','NAmplPresent','NAmplAbsent','NUsableAmpl', ...
            'FractionAmplPresent','TaskCategory'});
        TrialClassification = [TrialClassification; row]; %#ok<AGROW>
    end
end

function [A1,A2,A3,A4,AN,labelsOut] = subset_present_features(A1,A2,A3,A4,AN,labelsIn)
    % Remove features that have no observations for the current task. This
    % prevents a blank Ampl row/column from appearing in no-music trials.
    present = any(AN > 0, 1) | any(AN > 0, 2)';
    if ~any(present)
        present = true(1,numel(labelsIn));
    end
    A1 = A1(present,present);
    A2 = A2(present,present);
    A3 = A3(present,present);
    A4 = A4(present,present);
    AN = AN(present,present);
    labelsOut = labelsIn(present);
end

function out = ternary_text(tf, a, b)
    if tf, out = a; else, out = b; end
end

function shortNames = short_group_names(GroupNames)
    shortNames = GroupNames;
    for i = 1:numel(GroupNames)
        shortNames{i} = short_one(GroupNames{i});
    end
end


function save_paper_figure_600(fig, folderName, fileName, fontScale)
    % Main figures use 1.30x typography. Supplementary Figures S1--S8
    if nargin < 4 || isempty(fontScale), fontScale = 1.00; end
    standardize_supplement_figure(fig);
    fill_all_circle_markers(fig);
    add_listen_right_margin(fig);
    % High-resolution working copy.
    if ~exist(folderName,'dir'), mkdir(folderName); end
    exportgraphics(fig, fullfile(folderName,fileName), 'Resolution',600);
end

function save_frontiers_figure(fig, folderName, stem, fontScale)
    % Main figures use publication scaling. Every Supplement figure uses the
    % same absolute typography standard as the page-2 heat-map panels.
    if nargin < 4 || isempty(fontScale), fontScale = 1.00; end
    standardize_supplement_figure(fig);
    fill_all_circle_markers(fig);
    add_listen_right_margin(fig);
    % Frontiers-ready individual figure files.
    % with JPEG/TIFF accepted and high-resolution/vector source useful.
    if ~exist(folderName,'dir'), mkdir(folderName); end
    exportgraphics(fig,fullfile(folderName,[stem '.tif']),'Resolution',300);
    exportgraphics(fig,fullfile(folderName,[stem '.jpg']),'Resolution',600);
    exportgraphics(fig,fullfile(folderName,[stem '.pdf']),'ContentType','vector');
end

function T = build_functional_pair_subject_table(Results, EEGGroupNames)
    T = table();
    if isempty(Results), return; end
    f1 = cellstr(string(Results.Feature1));
    f2 = cellstr(string(Results.Feature2));
    isEEG = ismember(f1,EEGGroupNames) & ismember(f2,EEGGroupNames);
    % Keep one orientation only because Results contains symmetric maps.
    keep = isEEG & Results.Feature1_Index < Results.Feature2_Index & isfinite(Results.CS);
    R = Results(keep,:);
    if isempty(R), return; end
    T = table(R.Dyad,R.Task,R.Participant,R.Subject,R.Feature1,R.Feature2, ...
        strcat(R.Feature1,{'--'},R.Feature2),R.CS,abs(R.CS),R.Reliable, ...
        'VariableNames',{'Dyad','Task','Participant','Subject','Feature1','Feature2','Pair','CS','AbsCS','Reliable'});
end

function S = aggregate_functional_pairs_by_task(T, taskList, EEGGroupNames)
    S = table();
    if isempty(T), return; end
    pairs = canonical_functional_pairs(EEGGroupNames);
    for p=1:size(pairs,1)
        pairName = [pairs{p,1} '--' pairs{p,2}];
        for t=1:numel(taskList)
            idx = strcmp(T.Pair,pairName) & strcmp(T.Task,taskList{t}) & isfinite(T.CS);
            x = T.CS(idx); a = T.AbsCS(idx); r = T.Reliable(idx);
            if isempty(x), continue; end
            n=numel(x);
            sem = NaN; semAbs=NaN;
            if n>1
                sem=std(x,'omitnan')/sqrt(n);
                semAbs=std(a,'omitnan')/sqrt(n);
            end
            row=table({taskList{t}},{pairs{p,1}},{pairs{p,2}},{pairName},n, ...
                mean(x,'omitnan'),sem,mean(a,'omitnan'),semAbs,mean(r,'omitnan'), ...
                'VariableNames',{'Task','Feature1','Feature2','Pair','NSubjects','MeanCS','SEM_CS','MeanAbsCS','SEM_AbsCS','FracReliable'});
            S=[S;row]; %#ok<AGROW>
        end
    end
end

function P = canonical_functional_pairs(EEGGroupNames)
    P={};
    k=0;
    for i=1:numel(EEGGroupNames)-1
        for j=i+1:numel(EEGGroupNames)
            k=k+1; P{k,1}=EEGGroupNames{i}; P{k,2}=EEGGroupNames{j}; %#ok<AGROW>
        end
    end
end

function S = repeated_measures_functional_pair_tests(T, taskList, EEGGroupNames)
    % Friedman omnibus test for each functional connection across trials.
    % Uses only subjects having that pair in every compared task.
    S=table();
    if isempty(T), return; end
    pairs=canonical_functional_pairs(EEGGroupNames);
    for p=1:size(pairs,1)
        pairName=[pairs{p,1} '--' pairs{p,2}];
        sub=unique(T.Subject(strcmp(T.Pair,pairName)),'stable');
        X=nan(numel(sub),numel(taskList));
        for i=1:numel(sub)
            for t=1:numel(taskList)
                idx=strcmp(T.Pair,pairName)&strcmp(T.Subject,sub{i})&strcmp(T.Task,taskList{t})&isfinite(T.AbsCS);
                if any(idx), X(i,t)=mean(T.AbsCS(idx),'omitnan'); end
            end
        end
        complete=all(isfinite(X),2);
        Xc=X(complete,:);
        n=sum(complete);
        pval=NaN; chi2=NaN;
        if n>=3 && size(Xc,2)>=3
            [pval,tbl]=friedman(Xc,1,'off');
            try chi2=tbl{2,5}; catch, chi2=NaN; end
        end
        row=table({pairName},{pairs{p,1}},{pairs{p,2}},n,chi2,pval, ...
            'VariableNames',{'Pair','Feature1','Feature2','NComplete','FriedmanChi2','P_Friedman'});
        S=[S;row]; %#ok<AGROW>
    end
    if ~isempty(S)
        S.KendallW = S.FriedmanChi2 ./ (S.NComplete .* max(1,numel(taskList)-1));
        S.Q_FDR_BH = bh_fdr_local(S.P_Friedman);
        S.SignificantFDR = S.Q_FDR_BH < 0.05;
    end
end

function q = bh_fdr_local(p)
    p=p(:); q=nan(size(p));
    ok=isfinite(p); pv=p(ok); m=numel(pv);
    if m==0, return; end
    [ps,ord]=sort(pv);
    qs=ps.*m./(1:m)';
    for i=m-1:-1:1, qs(i)=min(qs(i),qs(i+1)); end
    qs=min(qs,1);
    tmp=nan(m,1); tmp(ord)=qs; q(ok)=tmp;
end

function plot_paper_global_task_reorganization(B)
    if isempty(B), axis off; text(.5,.5,'No brain task statistics','HorizontalAlignment','center'); return; end
    x=1:height(B);
    tl=tiledlayout(2,2,'TileSpacing','none','Padding','compact');
    title(tl,'Task-dependent reorganization of within-brain functional complexity coordination','FontWeight','bold');
    nexttile; errorbar(x,B.MeanAbsBrainCS,B.SEM_AbsBrainCS,'o-','LineWidth',1.5); grid on; box on;
    set(gca,'XTick',x,'XTickLabel',B.Task); ylabel('Mean |CS|'); title('A. Global functional brain coordination');
    nexttile; errorbar(x,B.MeanDynamicBrainNetworkCoord,B.SEM_DynamicBrainNetworkCoord,'o-','LineWidth',1.5); grid on; box on;
    set(gca,'XTick',x,'XTickLabel',B.Task); ylabel('Rolling coordination'); title('B. Dynamic network coordination');
    nexttile; errorbar(x,B.MeanFracReliableBrainPairs,B.SEM_FracReliableBrainPairs,'o-','LineWidth',1.5); grid on; box on;
    set(gca,'XTick',x,'XTickLabel',B.Task); ylabel('Reliable-pair fraction'); title('C. Reliability of functional coupling');
    nexttile; errorbar(x,B.MeanBrainCS,B.SEM_BrainCS,'o-','LineWidth',1.5); yline(0,'k--'); grid on; box on;
    set(gca,'XTick',x,'XTickLabel',B.Task); ylabel('Signed mean CS'); title('D. Direction of coordination');
end

function plot_paper_functional_pair_heatmap(S, taskList, EEGGroupNames)
    pairs=canonical_functional_pairs(EEGGroupNames);
    H=nan(size(pairs,1),numel(taskList)); R=H;
    labels=cell(size(pairs,1),1);
    for p=1:size(pairs,1)
        labels{p}=[short_one(pairs{p,1}) '-' short_one(pairs{p,2})];
        pairName=[pairs{p,1} '--' pairs{p,2}];
        for t=1:numel(taskList)
            idx=strcmp(S.Pair,pairName)&strcmp(S.Task,taskList{t});
            if any(idx), H(p,t)=S.MeanAbsCS(find(idx,1)); R(p,t)=S.FracReliable(find(idx,1)); end
        end
    end
    tl=tiledlayout(1,2,'TileSpacing','none','Padding','compact');
    title(tl,'Functional connections across experimental trials','FontWeight','bold');
    nexttile; imagesc(H); colorbar; set(gca,'XTick',1:numel(taskList),'XTickLabel',taskList,'YTick',1:numel(labels),'YTickLabel',labels);
    xlabel('Trial'); ylabel('Functional connection'); title('A. Mean |CS|');
    nexttile; imagesc(R,[0 1]); colorbar; set(gca,'XTick',1:numel(taskList),'XTickLabel',taskList,'YTick',1:numel(labels),'YTickLabel',labels);
    xlabel('Trial'); ylabel('Functional connection'); title('B. Fraction reliable');
end

function plot_paper_task_networks(S, taskList, EEGGroupNames)
    n=numel(taskList); nr=2; nc=ceil(n/nr);
    tl=tiledlayout(nr,nc,'TileSpacing','none','Padding','compact');
    title(tl,'Functional complexity networks by experimental trial','FontWeight','bold');
    theta=linspace(pi/2,pi/2+2*pi,numel(EEGGroupNames)+1); theta(end)=[];
    xy=[cos(theta(:)) sin(theta(:))];
    for t=1:n
        nexttile; hold on; axis equal off;
        task=taskList{t};
        for i=1:numel(EEGGroupNames)-1
            for j=i+1:numel(EEGGroupNames)
                pairName=[EEGGroupNames{i} '--' EEGGroupNames{j}];
                idx=strcmp(S.Pair,pairName)&strcmp(S.Task,task);
                if any(idx)
                    rr=find(idx,1); w=S.MeanAbsCS(rr); rel=S.FracReliable(rr);
                    if isfinite(w)
                        lw=0.5+6*w;
                        if rel>=0.5
                            plot(xy([i j],1),xy([i j],2),'-','LineWidth',lw);
                        else
                            plot(xy([i j],1),xy([i j],2),'--','LineWidth',max(.5,lw*.65));
                        end
                    end
                end
            end
        end
        scatter(xy(:,1),xy(:,2),90,'filled','MarkerFaceColor',[0.95 0.05 0.50],'MarkerEdgeColor','k','Tag','KMNetworkNode');
        for i=1:numel(EEGGroupNames), text(1.16*xy(i,1),1.16*xy(i,2),short_one(EEGGroupNames{i}),'HorizontalAlignment','center','FontWeight','bold'); end
        title(task_display_label(task)); xlim([-1.4 1.4]); ylim([-1.4 1.4]);
    end
end

function plot_paper_pair_effects(S, RM, taskList, EEGGroupNames)
    pairs=canonical_functional_pairs(EEGGroupNames);
    nP=size(pairs,1);
    H=nan(nP,numel(taskList)); labels=cell(nP,1);
    for p=1:nP
        pairName=[pairs{p,1} '--' pairs{p,2}]; labels{p}=[short_one(pairs{p,1}) '-' short_one(pairs{p,2})];
        for t=1:numel(taskList)
            idx=strcmp(S.Pair,pairName)&strcmp(S.Task,taskList{t});
            if any(idx), H(p,t)=S.MeanAbsCS(find(idx,1)); end
        end
    end
    nexttile(tiledlayout(1,1,'TileSpacing','none','Padding','compact')); hold on; box on;
    for p=1:nP, h=plot(1:numel(taskList),H(p,:),'o','LineWidth',1.0,'MarkerSize',9);fill_line_marker(h); end
    set(gca,'XTick',1:numel(taskList),'XTickLabel',task_display_labels(taskList)); grid on;
    % Supplement Figure S1: move Rest and Listen inward from the y-axis/box.
    xlim(gca,[0.45 numel(taskList)+0.75]);
    xlabel('Trial'); ylabel('Mean |CS|'); title('Task trajectories of the 10 functional brain connections');
    lgd=legend(labels,'Location','northeast'); lgd.FontSize=28; lgd.Box='on';
    if ~isempty(RM)
        sig=RM.Pair(RM.SignificantFDR);
        if ~isempty(sig)
            subtitle(['FDR-significant Friedman effects: ' strjoin(sig,', ')]);
        else
            subtitle('No connection-level Friedman effect survives FDR correction');
        end
    end
end


function [x,y,subs] = matched_pair_values(T,pairName,taskA,taskB)
    subs=unique(T.Subject(strcmp(T.Pair,pairName)),'stable'); x=[]; y=[]; keepSubs={};
    for i=1:numel(subs)
        ia=strcmp(T.Pair,pairName)&strcmp(T.Subject,subs{i})&strcmp(T.Task,taskA)&isfinite(T.AbsCS);
        ib=strcmp(T.Pair,pairName)&strcmp(T.Subject,subs{i})&strcmp(T.Task,taskB)&isfinite(T.AbsCS);
        if any(ia)&&any(ib)
            x(end+1,1)=mean(T.AbsCS(ia),'omitnan'); %#ok<AGROW>
            y(end+1,1)=mean(T.AbsCS(ib),'omitnan'); %#ok<AGROW>
            keepSubs{end+1,1}=subs{i}; %#ok<AGROW>
        end
    end
    subs=keepSubs;
end

function S = repeated_measures_global_brain_tests(B, taskList)
    S=table();
    if isempty(B), return; end
    metrics={'MeanAbsBrainCS','FracReliableBrainPairs','MeanBrainNetworkCoord'};
    labels={'MeanAbsBrainCS','FracReliableBrainPairs','DynamicBrainNetworkCoord'};
    for m=1:numel(metrics)
        [X,subs]=matched_global_matrix(B,taskList,metrics{m}); %#ok<ASGLU>
        n=size(X,1); pv=NaN; chi2=NaN; W=NaN;
        if n>=3
            [pv,tbl]=friedman(X,1,'off');
            try chi2=tbl{2,5}; catch, chi2=NaN; end
            if isfinite(chi2), W=chi2/(n*(numel(taskList)-1)); end
        end
        row=table({labels{m}},n,chi2,pv,W,'VariableNames',{'Outcome','NComplete','FriedmanChi2','P_Friedman','KendallW'});
        S=[S;row]; %#ok<AGROW>
    end
    S.Q_FDR_BH=bh_fdr_local(S.P_Friedman); S.SignificantFDR=S.Q_FDR_BH<0.05;
end

function [X,subs] = matched_global_matrix(B,taskList,metric)
    subs=unique(B.Subject,'stable'); X=nan(numel(subs),numel(taskList));
    for i=1:numel(subs)
        for t=1:numel(taskList)
            idx=strcmp(B.Subject,subs{i})&strcmp(B.Task,taskList{t})&isfinite(B.(metric));
            if any(idx), X(i,t)=mean(B.(metric)(idx),'omitnan'); end
        end
    end
    keep=all(isfinite(X),2); X=X(keep,:); subs=subs(keep);
end

function [x,y] = matched_global_pair(B,taskA,taskB,metric)
    subs=unique(B.Subject,'stable'); x=[]; y=[];
    for i=1:numel(subs)
        ia=strcmp(B.Subject,subs{i})&strcmp(B.Task,taskA)&isfinite(B.(metric));
        ib=strcmp(B.Subject,subs{i})&strcmp(B.Task,taskB)&isfinite(B.(metric));
        if any(ia)&&any(ib)
            x(end+1,1)=mean(B.(metric)(ia),'omitnan'); %#ok<AGROW>
            y(end+1,1)=mean(B.(metric)(ib),'omitnan'); %#ok<AGROW>
        end
    end
end

function rrb = rank_biserial_paired(d)
    d=d(isfinite(d)&d~=0); if isempty(d), rrb=NaN; return; end
    r=tiedrank(abs(d)); Wp=sum(r(d>0)); Wm=sum(r(d<0)); den=Wp+Wm;
    if den>0, rrb=(Wp-Wm)/den; else, rrb=NaN; end
end

function plot_paper_global_task_reorganization_inference(Braw,Bavg,RM,PH,taskList)
    tl=tiledlayout(2,2,'TileSpacing','none','Padding','compact');
    title(tl,'Task-dependent reorganization of within-brain complexity coordination: matched-subject inference','FontWeight','bold');
    outcomes={'MeanAbsBrainCS','FracReliableBrainPairs','MeanBrainNetworkCoord'};
    avgMean={'MeanAbsBrainCS','MeanFracReliableBrainPairs','MeanDynamicBrainNetworkCoord'};
    avgSem={'SEM_AbsBrainCS','SEM_FracReliableBrainPairs','SEM_DynamicBrainNetworkCoord'};
    ttl={'A. Global functional coordination','B. Reliable functional-pair fraction','C. Dynamic network coordination'};
    yl={'Mean |CS|','Reliable-pair fraction','Rolling coordination'};
    for m=1:3
        nexttile; hold on; box on; grid on;
        subs=unique(Braw.Subject,'stable');
        for i=1:numel(subs)
            yy=nan(1,numel(taskList));
            for t=1:numel(taskList)
                q=strcmp(Braw.Subject,subs{i})&strcmp(Braw.Task,taskList{t})&isfinite(Braw.(outcomes{m}));
                if any(q), yy(t)=mean(Braw.(outcomes{m})(q),'omitnan'); end
            end
            plot(1:numel(taskList),yy,'-','LineWidth',0.45,'HandleVisibility','off');
        end
        errorbar(1:height(Bavg),Bavg.(avgMean{m}),Bavg.(avgSem{m}),'o-','LineWidth',2.2);
        set(gca,'XTick',1:numel(taskList),'XTickLabel',task_display_labels(taskList)); ylabel(yl{m}); title(ttl{m});
        rmLabels={'MeanAbsBrainCS','FracReliableBrainPairs','DynamicBrainNetworkCoord'};
        rr=find(strcmp(RM.Outcome,rmLabels{m}),1);
        if ~isempty(rr), subtitle(sprintf('Friedman q=%.3g, Kendall W=%.2f, complete N=%d',RM.Q_FDR_BH(rr),RM.KendallW(rr),RM.NComplete(rr))); end
    end
    nexttile; axis off;
    text(0,.95,'FDR-significant matched post-hoc contrasts','FontWeight','bold','VerticalAlignment','top');
    y=.84;
    if isempty(PH)||~any(PH.SignificantFDR)
        text(0,y,'None after BH-FDR across the global post-hoc family.','VerticalAlignment','top');
    else
        R=PH(PH.SignificantFDR,:); [~,o]=sort(R.Q_FDR_AllPostHoc); R=R(o,:);
        for i=1:min(height(R),12)
            txt=sprintf('%s: %s -> %s, Delta=%.3f, r_{rb}=%.2f, q=%.3g, N=%d',R.Outcome{i},R.TaskA{i},R.TaskB{i},R.MeanDiff_BminusA(i),R.RankBiserial(i),R.Q_FDR_AllPostHoc(i),R.NMatched(i));
            text(0,y,txt,'Interpreter','tex','FontSize',18,'VerticalAlignment','top'); y=y-.07;
        end
    end
end

function plot_paper_functional_pair_heatmap_inference(S,RM,taskList,EEGGroupNames)
    pairs=canonical_functional_pairs(EEGGroupNames); nP=size(pairs,1);
    H=nan(nP,numel(taskList)); labels=cell(nP,1);
    for p=1:nP
        pairName=[pairs{p,1} '--' pairs{p,2}]; labels{p}=[short_one(pairs{p,1}) '-' short_one(pairs{p,2})];
        for t=1:numel(taskList)
            idx=strcmp(S.Pair,pairName)&strcmp(S.Task,taskList{t}); if any(idx), H(p,t)=S.MeanAbsCS(find(idx,1)); end
        end
    end
    tl=tiledlayout(1,2,'TileSpacing','none','Padding','compact'); title(tl,'The 10 functional connections: task profile and omnibus inference','FontWeight','bold');
    nexttile; imagesc(H); colorbar; set(gca,'XTick',1:numel(taskList),'XTickLabel',taskList,'YTick',1:nP,'YTickLabel',labels); xlabel('Trial'); ylabel('Connection'); title('A. Mean |CS|');
    nexttile; axis off; text(0,.98,'Friedman tests across Rest-Listen','FontWeight','bold','VerticalAlignment','top'); y=.89;
    for p=1:nP
        rr=find(strcmp(RM.Pair,[pairs{p,1} '--' pairs{p,2}]),1);
        if isempty(rr), continue; end
        mark=''; if RM.SignificantFDR(rr), mark=' *'; end
        text(0,y,sprintf('%-9s  N=%2d   W=%.2f   p=%.3g   q=%.3g%s',labels{p},RM.NComplete(rr),RM.KendallW(rr),RM.P_Friedman(rr),RM.Q_FDR_BH(rr),mark),'FontName','FixedWidth','FontSize',20); y=y-.075;
    end
    text(0,.05,'* survives BH-FDR across the 6 omnibus connection tests','FontSize',18);
end

function plot_paper_task_networks_compact(S,taskList,EEGGroupNames)
    % Draw seven mini-networks inside the current tile using inset axes.
    parent=gca; axis(parent,'off'); pos=parent.Position; delete(parent);
    n=numel(taskList); cols=4; rows=2;
    for t=1:n
        r=floor((t-1)/cols); c=mod(t-1,cols);
        ax=axes('Position',[pos(1)+c*pos(3)/cols, pos(2)+(rows-1-r)*pos(4)/rows, pos(3)/cols*.92, pos(4)/rows*.88]); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');
        theta=linspace(pi/2,pi/2+2*pi,numel(EEGGroupNames)+1); theta(end)=[]; xy=[cos(theta(:)) sin(theta(:))];
        for i=1:numel(EEGGroupNames)-1, for j=i+1:numel(EEGGroupNames)
            pairName=[EEGGroupNames{i} '--' EEGGroupNames{j}]; idx=strcmp(S.Pair,pairName)&strcmp(S.Task,taskList{t});
            if any(idx), rr=find(idx,1); w=S.MeanAbsCS(rr); rel=S.FracReliable(rr); if isfinite(w), ls='--'; if rel>=.5, ls='-'; end; plot(ax,xy([i j],1),xy([i j],2),ls,'LineWidth',.5+5*w); end, end
        end, end
        scatter(ax,xy(:,1),xy(:,2),60,'filled','MarkerFaceColor',[0.95 0.05 0.50],'MarkerEdgeColor','k'); for i=1:numel(EEGGroupNames), text(ax,1.18*xy(i,1),1.18*xy(i,2),short_one(EEGGroupNames{i}),'HorizontalAlignment','center','FontSize',20,'FontWeight','bold'); end
        title(ax,task_display_label(taskList{t})); xlim(ax,[-1.4 1.4]); ylim(ax,[-1.4 1.4]);
    end
end

function plot_paper_pair_effects_compact(S,RM,taskList,EEGGroupNames)
    pairs=canonical_functional_pairs(EEGGroupNames); hold on; box on; grid on; labels=cell(size(pairs,1),1);
    for p=1:size(pairs,1)
        pairName=[pairs{p,1} '--' pairs{p,2}]; labels{p}=[short_one(pairs{p,1}) '-' short_one(pairs{p,2})]; y=nan(1,numel(taskList));
        for t=1:numel(taskList), idx=strcmp(S.Pair,pairName)&strcmp(S.Task,taskList{t}); if any(idx), y(t)=S.MeanAbsCS(find(idx,1)); end, end
        plot(1:numel(taskList),y,'-o','LineWidth',1.0);
    end
    set(gca,'XTick',1:numel(taskList),'XTickLabel',task_display_labels(taskList)); xlabel('Trial'); ylabel('Mean |CS|'); title('All 10 functional-connection trajectories'); lgd=legend(labels,'Location','northeast'); lgd.FontSize=28; lgd.Box='on';
    if ~isempty(RM), subtitle(sprintf('%d/10 connections survive omnibus BH-FDR',sum(RM.SignificantFDR))); end
end

function s=short_one(s)
    switch s
        case 'Auditory', s='A';
        case 'Frontal-Executive', s='F';
        case 'Sensorimotor', s='M';
        case 'Parietal', s='P';
        case 'Occipital', s='O';
        case 'Frontal-L',   s='FL';
        case 'Frontal-R',   s='FR';
        case 'Temporal-L',  s='TL';
        case 'Temporal-R',  s='TR';
        case 'Central-L',   s='CL';
        case 'Central-R',   s='CR';
        case 'Central',     s='C';
        case 'Parietal-L',  s='PL';
        case 'Parietal-R',  s='PR';
        case 'Parietal',    s='PAR';
        case 'Occipital-L', s='OL';
        case 'Occipital-R', s='OR';
        case 'Occipital',   s='OCC';
    end
end


function T=build_t0_global_contrasts(B,t0,tasks)
T=table(); vars={'MeanAbsBrainCS','MeanBrainNetworkCoord','FracReliableBrainPairs'};
labs={'GlobalAbsCS','DynamicNetworkCoord','ReliablePairFraction'};
for m=1:numel(vars)
 if ~ismember(vars{m},B.Properties.VariableNames), continue; end
 for k=1:numel(tasks)
  tk=tasks{k}; if strcmp(tk,t0), continue; end
  [a,b]=pairvals(B,t0,tk,vars{m}); [p,rb,md,mn,lo,hi]=dstat(a,b);
  T=[T;table(labs(m),{t0},{tk},numel(a),mn,md,lo,hi,p,rb,'VariableNames',{'Metric','Baseline','Task','NPaired','MeanDelta','MedianDelta','CI95_Low','CI95_High','P_Wilcoxon','RankBiserial'})]; %#ok<AGROW>
 end
end
end

function T=build_t0_pair_contrasts(P,t0,tasks,G)
T=table(); pp=canonical_functional_pairs(G);
for j=1:size(pp,1)
 pn=[pp{j,1} '--' pp{j,2}]; Q=P(strcmp(P.Pair,pn),:);
 for k=1:numel(tasks)
  tk=tasks{k}; if strcmp(tk,t0), continue; end
  [a,b]=pairvals(Q,t0,tk,'AbsCS'); [p,rb,md,mn,lo,hi]=dstat(a,b);
  T=[T;table({pn},pp(j,1),pp(j,2),{t0},{tk},numel(a),mn,md,lo,hi,p,rb,'VariableNames',{'Pair','Feature1','Feature2','Baseline','Task','NPaired','MeanDelta','MedianDelta','CI95_Low','CI95_High','P_Wilcoxon','RankBiserial'})]; %#ok<AGROW>
 end
end
end

function T=add_fdr_by_metric(T)
T.Q_FDR=nan(height(T),1); T.SignificantFDR=false(height(T),1);
for u=unique(T.Metric,'stable')'
 idx=strcmp(T.Metric,u{1}); T.Q_FDR(idx)=bh_fdr_local(T.P_Wilcoxon(idx));
end
T.SignificantFDR=T.Q_FDR<.05;
end

function T=add_fdr_by_connection(T)
T.Q_FDR=nan(height(T),1); T.SignificantFDR=false(height(T),1);
for u=unique(T.Pair,'stable')'
 idx=strcmp(T.Pair,u{1}); T.Q_FDR(idx)=bh_fdr_local(T.P_Wilcoxon(idx));
end
T.SignificantFDR=T.Q_FDR<.05;
end

function [a,b]=pairvals(T,t0,t1,v)
a=[]; b=[]; if isempty(T),return;end
ss=intersect(unique(T.Subject(strcmp(T.Task,t0)),'stable'),unique(T.Subject(strcmp(T.Task,t1)),'stable'),'stable');
for i=1:numel(ss)
 q0=strcmp(T.Subject,ss{i})&strcmp(T.Task,t0); q1=strcmp(T.Subject,ss{i})&strcmp(T.Task,t1);
 x=T.(v)(q0); y=T.(v)(q1); x=x(isfinite(x)); y=y(isfinite(y));
 if ~isempty(x)&&~isempty(y), a(end+1,1)=mean(x,'omitnan'); b(end+1,1)=mean(y,'omitnan'); end %#ok<AGROW>
end
end

function [p,rb,md,mn,lo,hi]=dstat(a,b)
d=b-a; d=d(isfinite(d)); n=numel(d); p=NaN;rb=NaN;md=NaN;mn=NaN;lo=NaN;hi=NaN;
if n==0,return;end
md=median(d);mn=mean(d);
if n>=2
 try
     p = signrank(d);
 catch
     p = NaN;
 end
 z = d(d~=0);
 if ~isempty(z)
     r = tiedrank(abs(z));
     rb = (sum(r(z>0))-sum(r(z<0)))/sum(r);
 end
 bb = nan(2000,1);
 for k=1:2000
     ii = randi(n,n,1);
     bb(k) = mean(d(ii));
 end
 ci = prctile(bb,[2.5 97.5]);
 lo = ci(1);
 hi = ci(2);
end
end

function S=summarize_t0_global_changes(B,t0,tasks)
S=table();vars={'MeanAbsBrainCS','MeanBrainNetworkCoord','FracReliableBrainPairs'};labs={'GlobalAbsCS','DynamicNetworkCoord','ReliablePairFraction'};
for m=1:numel(vars)
 if ~ismember(vars{m},B.Properties.VariableNames),continue;end
 for k=1:numel(tasks)
  tk=tasks{k};
  if strcmp(tk,t0), n=sum(strcmp(B.Task,t0)&isfinite(B.(vars{m}))); mn=0;se=0;
  else,[a,b]=pairvals(B,t0,tk,vars{m});d=b-a;n=numel(d);mn=mean(d,'omitnan');se=std(d,'omitnan')/sqrt(max(n,1));end
  S=[S;table(labs(m),{tk},n,mn,se,'VariableNames',{'Metric','Task','NPaired','MeanDelta','SEMDelta'})]; %#ok<AGROW>
 end
end
end

function S=summarize_t0_pair_changes(P,t0,tasks,G)
S=table();pp=canonical_functional_pairs(G);
for j=1:size(pp,1)
 pn=[pp{j,1} '--' pp{j,2}];Q=P(strcmp(P.Pair,pn),:);
 for k=1:numel(tasks)
  tk=tasks{k};
  if strcmp(tk,t0),n=sum(strcmp(Q.Task,t0));mn=0;se=0;
  else,[a,b]=pairvals(Q,t0,tk,'AbsCS');d=b-a;n=numel(d);mn=mean(d,'omitnan');se=std(d,'omitnan')/sqrt(max(n,1));end
  S=[S;table({pn},{tk},n,mn,se,'VariableNames',{'Pair','Task','NPaired','MeanDelta','SEMDelta'})]; %#ok<AGROW>
 end
end
end

function plot_t0_global_main(S,C)
ref=C.Baseline{find(~cellfun(@isempty,C.Baseline),1)}; refLab=task_display_label(ref);
mets={'GlobalAbsCS','DynamicNetworkCoord','ReliablePairFraction'};
ttl={'A. Global functional coordination','B. Dynamic network coordination','C. Reliable-pair fraction'};
tl=tiledlayout(1,3,'TileSpacing','loose','Padding','compact');
title(tl,sprintf('Within-brain complexity coordination relative to %s',refLab),'FontWeight','bold','FontSize',18);
for m=1:3
 nexttile;hold on;box on;grid on;Q=S(strcmp(S.Metric,mets{m}),:);x=1:height(Q);h=errorbar(x,Q.MeanDelta,Q.SEMDelta,'o','LineWidth',1.5,'MarkerSize',7);fill_errorbar_marker(h);yline(0,'k--');
 set(gca,'XTick',x,'XTickLabel',task_display_labels(Q.Task));ylabel(sprintf('%s from %s',char(916),refLab),'FontSize',30);xlabel('Condition','FontSize',30);title(ttl{m},'FontSize',15,'FontWeight','bold');yl=ylim;yr=max(eps,yl(2)-yl(1));
 % Publication rule: annotate only FDR-significant contrasts; show the effect value with *.
 for i=1:height(Q)
  z=C(strcmp(C.Metric,mets{m})&strcmp(C.Task,Q.Task{i}),:);if isempty(z)||~z.SignificantFDR(1),continue;end
  yy=Q.MeanDelta(i)+Q.SEMDelta(i)+.035*yr;
  text(i,yy,sprintf('%+.3f',Q.MeanDelta(i)), ...
      'HorizontalAlignment','center','FontSize',20,'FontWeight','bold','Interpreter','none');
  text(i+.08,yy+.012*yr,'*','HorizontalAlignment','left','VerticalAlignment','bottom', ...
      'FontSize',20,'FontWeight','bold','Interpreter','none');
 end
 % Extra 0.02 at the upper end of each of the three MAIN Figure 4 panels.
 yl=ylim(gca); ylim(gca,[yl(1) yl(2)+0.02]);
end
end

function plot_t0_pair_heatmap(S,C,tasks,G)
% Figure 5 remains a matrix because it carries the connection-level
% inferential summary. Each cell now prints the actual mean DeltaCS value
% in addition to n, q_FDR and rank-biserial r.
ref=C.Baseline{find(~cellfun(@isempty,C.Baseline),1)}; refLab=task_display_label(ref); pp=canonical_functional_pairs(G);tt=tasks(~strcmp(tasks,ref));H=nan(size(pp,1),numel(tt));Q=H;N=H;lab=cell(size(pp,1),1);
for j=1:size(pp,1)
 pn=[pp{j,1} '--' pp{j,2}];lab{j}=[short_one(pp{j,1}) '-' short_one(pp{j,2})];
 for k=1:numel(tt)
  a=S(strcmp(S.Pair,pn)&strcmp(S.Task,tt{k}),:);b=C(strcmp(C.Pair,pn)&strcmp(C.Task,tt{k}),:);
  if ~isempty(a),H(j,k)=a.MeanDelta(1);N(j,k)=a.NPaired(1);end;if ~isempty(b),Q(j,k)=b.Q_FDR(1);end
 end
end
imagesc(H);colorbar;c=max(abs(H(:)),[],'omitnan');if isfinite(c)&&c>0,caxis([-c c]);end
set(gca,'XTick',1:numel(tt),'XTickLabel',task_display_labels(tt),'YTick',1:numel(lab),'YTickLabel',lab);xlabel(sprintf('Condition vs %s',refLab));ylabel('Functional connection');title(sprintf('%s-referenced change in functional complexity coordination',refLab),'FontSize',18,'FontWeight','bold');
for j=1:size(H,1)
    for k=1:size(H,2)
        b=C(strcmp(C.Pair,[pp{j,1} '--' pp{j,2}]) & strcmp(C.Task,tt{k}),:);
        if isfinite(H(j,k))
            isSig = isfinite(Q(j,k)) && Q(j,k)<.05;
            text(k,j-.08,sprintf('%.2f',H(j,k)), ...
                'HorizontalAlignment','center','FontSize',24,'FontWeight','bold','Interpreter','none');
            if isSig
                text(k+.10,j-.10,'*','HorizontalAlignment','left','VerticalAlignment','bottom', ...
                    'FontSize',24,'FontWeight','bold','Interpreter','none');
            end
        end
        % No q/r text is printed in the figure. FDR significance is encoded only
        % by the asterisk appended to the displayed mean DeltaCS value above.
    end
end
end

function plot_t0_change_networks(S,C,tasks,G)
tt=tasks(~strcmp(tasks,'T01'));tl=tiledlayout(2,3,'TileSpacing','none','Padding','compact');title(tl,'Functional-network change relative to Rest','FontWeight','bold');
th=linspace(pi/2,pi/2+2*pi,numel(G)+1);th(end)=[];xy=[cos(th(:)) sin(th(:))];
for k=1:numel(tt)
 nexttile;hold on;axis equal off;
 for i=1:numel(G)-1
     for j=i+1:numel(G)
         pn=[G{i} '--' G{j}];
         a=S(strcmp(S.Pair,pn)&strcmp(S.Task,tt{k}),:);
         b=C(strcmp(C.Pair,pn)&strcmp(C.Task,tt{k}),:);
         if isempty(a) || ~isfinite(a.MeanDelta(1))
             continue;
         end
         d=a.MeanDelta(1);
         lw=.5+10*abs(d);
         ls='--';
         if ~isempty(b) && b.SignificantFDR(1)
             ls='-';
         end
         plot(xy([i j],1),xy([i j],2),ls,'LineWidth',lw);
         text(mean(xy([i j],1)),mean(xy([i j],2)),sprintf('%.2f',d),'FontSize',16,'HorizontalAlignment','center');
     end
 end
 scatter(xy(:,1),xy(:,2),80,'filled','MarkerFaceColor',[0.95 0.05 0.50],'MarkerEdgeColor','k');for i=1:numel(G),text(1.18*xy(i,1),1.18*xy(i,2),short_one(G{i}),'HorizontalAlignment','center','FontWeight','bold');end
 title([task_display_label(tt{k}) ' - Coord']);xlim([-1.45 1.45]);ylim([-1.45 1.45]);
end
end


function W=build_weighted_network_metrics(P,tasks,G)
W=table(); if isempty(P),return;end
subs=unique(P.Subject,'stable');
for s=1:numel(subs)
 for t=1:numel(tasks)
  Q=P(strcmp(P.Subject,subs{s}) & strcmp(P.Task,tasks{t}),:); if isempty(Q),continue;end
  A=nan(numel(G)); edge=[];
  for i=1:numel(G)-1
   for j=i+1:numel(G)
    pn=[G{i} '--' G{j}]; z=Q(strcmp(Q.Pair,pn),:);
    if ~isempty(z),v=mean(z.AbsCS,'omitnan');A(i,j)=v;A(j,i)=v;edge(end+1)=v;end %#ok<AGROW>
   end
  end
  edge=edge(isfinite(edge)); if numel(edge)<3,continue;end
  ns=nan(1,numel(G));
  for i=1:numel(G),q=A(i,:);ns(i)=mean(q(isfinite(q)),'omitnan');end
  row=table(Q.Dyad(1),Q.Task(1),Q.Participant(1),Q.Subject(1),mean(edge),std(edge),numel(edge), ...
   'VariableNames',{'Dyad','Task','Participant','Subject','MeanEdgeWeight','EdgeWeightSD','NEdges'});
  for i=1:numel(G),row.(['Strength_' matlab.lang.makeValidName(G{i})])=ns(i);end
  % In the Frontal-14 model there is one pooled Auditory node.  For backward compatibility
  % with existing tables the variable is still named TemporalHubStrength,
  % but its value is now exactly the node strength of Auditory.
  ia=find(strcmp(G,'Auditory'),1);
  if isempty(ia), row.TemporalHubStrength=NaN; else, row.TemporalHubStrength=ns(ia); end
  W=[W;row]; %#ok<AGROW>
 end
end
end

function T=build_weighted_network_t0_contrasts(W,t0,tasks,G)
T=table(); if isempty(W),return;end
metrics=[{'MeanEdgeWeight','EdgeWeightSD','TemporalHubStrength'},arrayfun(@(i)['Strength_' matlab.lang.makeValidName(G{i})],1:numel(G),'UniformOutput',false)];
for m=1:numel(metrics)
 if ~ismember(metrics{m},W.Properties.VariableNames),continue;end
 for k=1:numel(tasks)
  tk=tasks{k};if strcmp(tk,t0),continue;end
  [a,b]=pairvals(W,t0,tk,metrics{m});[p,rb,md,mn,lo,hi]=dstat(a,b);
  T=[T;table(metrics(m),{t0},{tk},numel(a),mn,md,lo,hi,p,rb,'VariableNames',{'Metric','Baseline','Task','NPaired','MeanDelta','MedianDelta','CI95_Low','CI95_High','P_Wilcoxon','RankBiserial'})]; %#ok<AGROW>
 end
end
T=add_fdr_by_metric(T);
end

function S=build_m1m2_network_similarity(P,tasks,G)
S=table();if isempty(P),return;end
dyads=unique(P.Dyad,'stable');pp=canonical_functional_pairs(G);
for d=1:numel(dyads)
 for t=1:numel(tasks)
  Q=P(strcmp(P.Dyad,dyads{d}) & strcmp(P.Task,tasks{t}),:);if isempty(Q),continue;end
  v1=nan(size(pp,1),1);v2=v1;
  for p=1:size(pp,1)
   pn=[pp{p,1} '--' pp{p,2}];
   a=Q(strcmpi(Q.Participant,'M1')&strcmp(Q.Pair,pn),:);b=Q(strcmpi(Q.Participant,'M2')&strcmp(Q.Pair,pn),:);
   if ~isempty(a),v1(p)=mean(a.AbsCS,'omitnan');end;if ~isempty(b),v2(p)=mean(b.AbsCS,'omitnan');end
  end
  ok=isfinite(v1)&isfinite(v2);if sum(ok)<3,continue;end
  x=v1(ok);y=v2(ok);cs=dot(x,y)/(norm(x)*norm(y)+eps);rs=corr(x,y,'Type','Spearman','Rows','complete');
  nd=norm(x-y)/(norm(x)+norm(y)+eps);mad=mean(abs(x-y),'omitnan');
  S=[S;table(dyads(d),tasks(t),sum(ok),cs,rs,nd,mad,'VariableNames',{'Dyad','Task','NCommonEdges','CosineSimilarity','SpearmanEdgeSimilarity','NormalizedEuclideanDistance','MeanAbsEdgeDifference'})]; %#ok<AGROW>
 end
end
end

function T=build_similarity_t0_contrasts(S,t0,tasks)
T=table();if isempty(S),return;end
metrics={'CosineSimilarity','SpearmanEdgeSimilarity','NormalizedEuclideanDistance','MeanAbsEdgeDifference'};
for m=1:numel(metrics)
 for k=1:numel(tasks)
  tk=tasks{k};if strcmp(tk,t0),continue;end
  dd=intersect(unique(S.Dyad(strcmp(S.Task,t0)),'stable'),unique(S.Dyad(strcmp(S.Task,tk)),'stable'),'stable');a=[];b=[];
  for j=1:numel(dd)
   x=S.(metrics{m})(strcmp(S.Dyad,dd{j})&strcmp(S.Task,t0));y=S.(metrics{m})(strcmp(S.Dyad,dd{j})&strcmp(S.Task,tk));
   x=x(isfinite(x));y=y(isfinite(y));if ~isempty(x)&&~isempty(y),a(end+1,1)=mean(x);b(end+1,1)=mean(y);end %#ok<AGROW>
  end
  [p,rb,md,mn,lo,hi]=dstat(a,b);
  T=[T;table(metrics(m),{t0},{tk},numel(a),mn,md,lo,hi,p,rb,'VariableNames',{'Metric','Baseline','Task','NPairedDyads','MeanDelta','MedianDelta','CI95_Low','CI95_High','P_Wilcoxon','RankBiserial'})]; %#ok<AGROW>
 end
end
T=add_fdr_by_metric(T);
end

function plot_t0_change_networks_solid(S,C,tasks,G)
tt=tasks(~strcmp(tasks,'T01'));tl=tiledlayout(2,3,'TileSpacing','none','Padding','compact');title(tl,'Weighted functional-network change relative to Rest','FontWeight','bold');
th=linspace(pi/2,pi/2+2*pi,numel(G)+1);th(end)=[];xy=[cos(th(:)) sin(th(:))];
for k=1:numel(tt)
 nexttile;hold on;axis equal off;
 for i=1:numel(G)-1
  for j=i+1:numel(G)
   pn=[G{i} '--' G{j}];a=S(strcmp(S.Pair,pn)&strcmp(S.Task,tt{k}),:);if isempty(a)||~isfinite(a.MeanDelta(1)),continue;end
   d=a.MeanDelta(1);mag=min(abs(d),0.30);lw=0.6+8*(mag/0.30);
   if d<0,col=[0.85 0.10 0.10];else,g=0.82-0.72*(mag/0.30);col=[g g g];end
   plot(xy([i j],1),xy([i j],2),'-','LineWidth',lw,'Color',col);
   text(mean(xy([i j],1)),mean(xy([i j],2)),sprintf('%.2f',d),'FontSize',16,'HorizontalAlignment','center');
  end
 end
 scatter(xy(:,1),xy(:,2),85,'filled','MarkerFaceColor',[0.95 0.05 0.50],'MarkerEdgeColor','k','Tag','KMNetworkNode');
 for i=1:numel(G),text(1.18*xy(i,1),1.18*xy(i,2),short_one(G{i}),'HorizontalAlignment','center','FontWeight','bold');end
 title([task_display_label(tt{k}) ' - Coord']);xlim([-1.45 1.45]);ylim([-1.45 1.45]);
end
end

function plot_weighted_network_measures(T,tasks,G)
ref=T.Baseline{find(~cellfun(@isempty,T.Baseline),1)};refLab=task_display_label(ref);tt=tasks(~strcmp(tasks,ref));mets={'MeanEdgeWeight','EdgeWeightSD','TemporalHubStrength'};labs={'Global weighted coordination','Edge-weight heterogeneity','Auditory hub strength'};
tl=tiledlayout(1,3,'TileSpacing','loose','Padding','compact');title(tl,sprintf('Weighted network measures: change from %s',refLab),'FontWeight','bold','FontSize',18);
for m=1:3
 nexttile;hold on;box on;grid on;Q=T(strcmp(T.Metric,mets{m}),:);x=1:numel(tt);y=nan(size(x));lo=y;hi=y;
 for k=1:numel(tt),z=Q(strcmp(Q.Task,tt{k}),:);if ~isempty(z),y(k)=z.MeanDelta(1);lo(k)=z.CI95_Low(1);hi(k)=z.CI95_High(1);end,end
 h=errorbar(x,y,y-lo,hi-y,'o','LineWidth',1.4,'MarkerSize',7);fill_errorbar_marker(h);yline(0,'k--');set(gca,'XTick',x,'XTickLabel',task_display_labels(tt));ylabel(sprintf('%s from %s',char(916),refLab),'FontSize',30);xlabel('Condition','FontSize',30);title(labs{m},'FontSize',15,'FontWeight','bold');
end
end

function plot_m1m2_similarity(S,T,tasks)
tl=tiledlayout(2,2,'TileSpacing','none','Padding','compact');title(tl,'M1/M2 similarity of within-brain functional-network fingerprints','FontWeight','bold');
metrics={'CosineSimilarity','SpearmanEdgeSimilarity','NormalizedEuclideanDistance'};labs={'Cosine similarity','Spearman similarity of 10 edges','Normalized Euclidean distance'};
for m=1:3
 nexttile;hold on;box on;grid on;mu=nan(1,numel(tasks));se=mu;
 for k=1:numel(tasks),x=S.(metrics{m})(strcmp(S.Task,tasks{k}));x=x(isfinite(x));if ~isempty(x),mu(k)=mean(x);se(k)=std(x)/sqrt(numel(x));end,end
 errorbar(1:numel(tasks),mu,se,'o-','LineWidth',1.4);set(gca,'XTick',1:numel(tasks),'XTickLabel',task_display_labels(tasks));title(labs{m});xlabel('Condition');
end
nexttile; axis off;
end


function R=build_network_reconfiguration(P,t0,tasks,G)
R=table(); if isempty(P),return;end
subs=unique(P.Subject,'stable'); pp=canonical_functional_pairs(G);
for s=1:numel(subs)
    q0=P(strcmp(P.Subject,subs{s}) & strcmp(P.Task,t0),:);
    if isempty(q0),continue;end
    v0=edge_vector_from_pair_table(q0,pp);
    for k=1:numel(tasks)
        tk=tasks{k}; if strcmp(tk,t0),continue;end
        q1=P(strcmp(P.Subject,subs{s}) & strcmp(P.Task,tk),:);
        if isempty(q1),continue;end
        v1=edge_vector_from_pair_table(q1,pp);
        ok=isfinite(v0)&isfinite(v1);
        if sum(ok)<3,continue;end
        a=v0(ok); b=v1(ok);
        eu=norm(b-a);
        neu=eu/(norm(a)+norm(b)+eps);
        mad=mean(abs(b-a),'omitnan');
        cs=dot(a,b)/(norm(a)*norm(b)+eps);
        rs=corr(a,b,'Type','Spearman','Rows','complete');
        R=[R;table(q1.Dyad(1),q1.Participant(1),q1.Subject(1),{t0},{tk},sum(ok),eu,neu,mad,cs,rs, ...
          'VariableNames',{'Dyad','Participant','Subject','Baseline','Task','NMatchedEdges','EuclideanReconfiguration','NormalizedReconfiguration','MeanAbsEdgeChange','CosineToReference','SpearmanToReference'})]; %#ok<AGROW>
    end
end
end

function v=edge_vector_from_pair_table(Q,pp)
v=nan(size(pp,1),1);
for p=1:size(pp,1)
    pn=[pp{p,1} '--' pp{p,2}];
    z=Q(strcmp(Q.Pair,pn),:);
    if ~isempty(z),v(p)=mean(z.AbsCS,'omitnan');end
end
end

function S=summarize_network_reconfiguration(R,tasks)
S=table(); if isempty(R),return;end
if ismember('Baseline',R.Properties.VariableNames),ref=R.Baseline{1};else,ref='T00';end
tt=tasks(~strcmp(tasks,ref)); metrics={'NormalizedReconfiguration','MeanAbsEdgeChange','CosineToReference','SpearmanToReference'};
for m=1:numel(metrics)
 for k=1:numel(tt)
  x=R.(metrics{m})(strcmp(R.Task,tt{k}));x=x(isfinite(x));if isempty(x),continue;end
  n=numel(x);mu=mean(x);med=median(x);se=std(x)/sqrt(n);[lo,hi]=simple_boot_ci(x,2000);
  S=[S;table({ref},metrics(m),tt(k),n,mu,med,se,lo,hi,'VariableNames',{'Baseline','Metric','Task','N','Mean','Median','SEM','CI95_Low','CI95_High'})]; %#ok<AGROW>
 end
end
end

function [lo,hi]=simple_boot_ci(x,B)
x=x(:); n=numel(x);
if n<2,lo=NaN;hi=NaN;return;end
z=nan(B,1);
for b=1:B
    ii=randi(n,n,1); z(b)=mean(x(ii),'omitnan');
end
z=sort(z); lo=z(max(1,round(.025*B))); hi=z(min(B,round(.975*B)));
end

function plot_t0_change_networks_v17(S,C,tasks,G)
ref=C.Baseline{find(~cellfun(@isempty,C.Baseline),1)}; wantedTasks=tasks(~strcmp(tasks,ref));
tl=tiledlayout(2,ceil(numel(wantedTasks)/2),'TileSpacing','none','Padding','compact');
title(tl,'Weighted functional-network change relative to Rest','FontWeight','bold','FontSize',18);
th=linspace(pi/2,pi/2+2*pi,numel(G)+1); th(end)=[]; xy=[cos(th(:)) sin(th(:))]; maxD=.30;
for k=1:numel(wantedTasks)
 tk=wantedTasks{k}; ax=nexttile(k); hold(ax,'on'); axis(ax,'equal'); axis(ax,'off');
 for i=1:numel(G)-1
  for j=i+1:numel(G)
   pn=[G{i} '--' G{j}]; a=S(strcmp(S.Pair,pn)&strcmp(S.Task,tk),:); if isempty(a)||~isfinite(a.MeanDelta(1)),continue;end
   d=a.MeanDelta(1); lw=.35+7.65*(min(abs(d),maxD)/maxD); if d<0,col=[.88 .08 .08];else,col=[0 0 0];end
   cRow=C(strcmp(C.Pair,pn)&strcmp(C.Task,tk),:); isSig=false;
   if ~isempty(cRow)
    if ismember('SignificantFDR',C.Properties.VariableNames),isSig=logical(cRow.SignificantFDR(1));
    elseif ismember('Q_FDR',C.Properties.VariableNames)&&isfinite(cRow.Q_FDR(1)),isSig=cRow.Q_FDR(1)<.05;end
   end
   plot(ax,xy([i j],1),xy([i j],2),'-','LineWidth',lw,'Color',col);
   mid=mean(xy([i j],:),1); if abs(xy(i,1)-xy(j,1))<.15,mid(2)=mid(2)+.22;elseif abs(xy(i,2)-xy(j,2))<.15,mid(1)=mid(1)+.28;end
   text(ax,mid(1),mid(2),sprintf('%.2f',d), ...
       'HorizontalAlignment','center','FontSize',22,'BackgroundColor','w','Margin',.5,'Interpreter','none');
   if isSig
       text(ax,mid(1)+.07,mid(2)+.05,'*','HorizontalAlignment','left','VerticalAlignment','bottom', ...
           'FontSize',22,'FontWeight','bold','Interpreter','none');
   end
  end
 end
 scatter(ax,xy(:,1),xy(:,2),95,'filled','MarkerFaceColor',[0.95 0.05 0.50],'MarkerEdgeColor','k','Tag','KMNetworkNode');
 for i=1:numel(G)
  p=1.19*xy(i,:); if abs(xy(i,2))<.20,p(2)=p(2)+.12;end
  text(ax,p(1),p(2),short_one(G{i}),'HorizontalAlignment','center','FontWeight','bold','FontSize',24);
 end
 title(ax,sprintf('%s - Rest',task_display_label(tk)),'FontSize',20,'FontWeight','bold'); xlim(ax,[-1.55 1.72]); ylim(ax,[-1.55 1.55]);
 % One shared scale only, at the right of the top-right panel.
 if k==3, add_vertical_thickness_key(ax,[0 .10 .20 .30],maxD,'|\DeltaCS|',[1.30 .82]); end
end
end

function plot_network_reconfiguration_v17(R,S,tasks)
if ismember('Baseline',R.Properties.VariableNames),ref=R.Baseline{1};else,ref='T00';end;refLab=task_display_label(ref);tt=tasks(~strcmp(tasks,ref));
tl=tiledlayout(1,3,'TileSpacing','loose','Padding','compact');title(tl,sprintf('Whole-network reconfiguration away from %s',refLab),'FontWeight','bold','FontSize',18);
mets={'NormalizedReconfiguration','MeanAbsEdgeChange','CosineToReference'};labs={sprintf('Normalized network distance from %s',refLab),sprintf('Mean absolute edge change from %s',refLab),sprintf('Cosine similarity to %s',refLab)};
for m=1:3
 nexttile;hold on;box on;grid on;mu=nan(1,numel(tt));se=mu;
 for k=1:numel(tt),x=R.(mets{m})(strcmp(R.Task,tt{k}));x=x(isfinite(x));if ~isempty(x),mu(k)=mean(x);se(k)=std(x)/sqrt(numel(x));end,end
 h=errorbar(1:numel(tt),mu,se,'o','LineWidth',1.4,'MarkerSize',7);fill_errorbar_marker(h);set(gca,'XTick',1:numel(tt),'XTickLabel',task_display_labels(tt));title(labs{m},'FontSize',15,'FontWeight','bold');xlabel('Condition','FontSize',30);
end
end

function plot_m1m2_similarity_v17(S,T,tasks,t0)
tl=tiledlayout(1,3,'TileSpacing','loose','Padding','compact');
title(tl,'Dyadic convergence of M1/M2 within-brain functional-network fingerprints','FontWeight','bold','FontSize',18);
metrics={'CosineSimilarity','SpearmanEdgeSimilarity','NormalizedEuclideanDistance'};
labs={'Cosine similarity','Spearman similarity of 10 edges','Normalized Euclidean distance'};
for m=1:3
    nexttile; hold on; box on; grid on;
    mu=nan(1,numel(tasks)); se=mu;
    for k=1:numel(tasks)
        x=S.(metrics{m})(strcmp(S.Task,tasks{k})); x=x(isfinite(x));
        if ~isempty(x),mu(k)=mean(x);se(k)=std(x)/sqrt(numel(x));end
    end
    h=errorbar(1:numel(tasks),mu,se,'o','LineWidth',1.5,'MarkerSize',7);fill_errorbar_marker(h);
    set(gca,'XTick',1:numel(tasks),'XTickLabel',task_display_labels(tasks));
    title(labs{m},'FontSize',15,'FontWeight','bold'); xlabel('Condition','FontSize',30);
    ylabel(labs{m},'FontSize',46);

    % Put reference-based q/effect-size information above every non-reference condition.
    yl=ylim; yr=max(eps,yl(2)-yl(1));
    for k=1:numel(tasks)
        if strcmp(tasks{k},t0), continue; end
        z=T(strcmp(T.Metric,metrics{m})&strcmp(T.Task,tasks{k}),:);
        if isempty(z),continue;end
        if ~z.SignificantFDR(1),continue;end
        yy=mu(k)+se(k)+(.045 + .055*mod(k,2))*yr;
        text(k,yy,sprintf('%+.3f',z.MeanDelta(1)), ...
            'HorizontalAlignment','center','FontSize',20,'FontWeight','bold','Interpreter','none');
        text(k+.08,yy+.012*yr,'*','HorizontalAlignment','left','VerticalAlignment','bottom', ...
            'FontSize',20,'FontWeight','bold','Interpreter','none');
    end
end
end


function standardize_supplement_figure(figHandle)
% Uniform typography for ALL Supplement figures.
% Reference style: the four heat-map panels at the top of Supplement page 2.
% Use absolute sizes rather than multiplicative scaling so figures created by
% different plotting functions end with the same visual hierarchy.
if isempty(figHandle) || ~isgraphics(figHandle), return; end

% Axes: same tick/label hierarchy everywhere. Single-panel figures use the
% common 18-pt figure title; multi-panel axes use compact 10-pt panel titles.
axs=findall(figHandle,'Type','axes');
% Exclude invisible helper axes (e.g., network thickness keys) from panel count.
visMask=false(size(axs));
for jj=1:numel(axs), try, visMask(jj)=strcmpi(axs(jj).Visible,'on'); catch, end, end
nDataAxes=sum(visMask);
isDiag911 = isappdata(figHandle,'KM_DiagnosticPages9to11') && getappdata(figHandle,'KM_DiagnosticPages9to11');
doubleAxisLabels = isappdata(figHandle,'KM_DoubleAxisLabelSize') && getappdata(figHandle,'KM_DoubleAxisLabelSize');
firstPageDoubleAgain = isappdata(figHandle,'KM_FirstPageDoubleAgain') && getappdata(figHandle,'KM_FirstPageDoubleAgain');
axisLabelFS = 15.6; % 1.2x previous 13-pt axis labels
for ii=1:numel(axs)
    try
        if isDiag911
            axs(ii).FontSize=13.2;
        else
            axs(ii).FontSize=13.2;
        end
        axs(ii).LineWidth=0.8;
        if isprop(axs(ii),'Title') && isgraphics(axs(ii).Title)
            if isDiag911
                axs(ii).Title.FontSize=16.8;
            else
                axs(ii).Title.FontSize=16.8;
            end
            axs(ii).Title.FontWeight='bold';
        end
        if isprop(axs(ii),'XLabel') && isgraphics(axs(ii).XLabel)
            axs(ii).XLabel.FontSize=axisLabelFS;
            axs(ii).XLabel.FontWeight='normal';
        end
        if isprop(axs(ii),'YLabel') && isgraphics(axs(ii).YLabel)
            axs(ii).YLabel.FontSize=axisLabelFS;
            axs(ii).YLabel.FontWeight='normal';
        end
        if isprop(axs(ii),'ZLabel') && isgraphics(axs(ii).ZLabel)
            axs(ii).ZLabel.FontSize=15.6;
            axs(ii).ZLabel.FontWeight='normal';
        end
    catch
    end
end

% Tiled-layout / figure-level titles: slightly above panel titles.
txt=findall(figHandle,'Type','text');
for ii=1:numel(txt)
    try
        str=string(txt(ii).String);
        % Preserve small numeric annotations inside heatmaps/networks.
        if txt(ii).Parent==figHandle
            txt(ii).FontSize=14;
        elseif txt(ii).FontSize>18
            txt(ii).FontSize=14;
        end
        if contains(str,'within-subject','IgnoreCase',true) || ...
           contains(str,'across trials','IgnoreCase',true) || ...
           contains(str,'distribution','IgnoreCase',true) || ...
           contains(str,'histograms','IgnoreCase',true)
            txt(ii).FontSize=14;
        end
    catch
    end
end

% Legends and colorbars use the same readable supporting-text size.
legs=findall(figHandle,'Type','legend');
for ii=1:numel(legs), try, legs(ii).FontSize=13.2; catch, end, end
cbs=findall(figHandle,'Type','colorbar');
for ii=1:numel(cbs), try, cbs(ii).FontSize=12; catch, end, end

force_network_node_pink(figHandle);
if isappdata(figHandle,'KM_CoherentQCStyle') && getappdata(figHandle,'KM_CoherentQCStyle')
    frontal14_apply_coherent_qc_style(figHandle);
end
drawnow;
% Mark as already publication-formatted so later export helpers do not scale it.
setappdata(figHandle,'PublicationTypographyApplied',true);
setappdata(figHandle,'KM_FontScaleApplied',true);
end


function scale_figure_fonts(figHandle, scaleFactor)
% Scale all figure text-bearing objects by a multiplicative factor.
% Used for Supplement pages 2-7 only; 1/1.3 reverses the prior oversizing.
objs=findall(figHandle,'-property','FontSize');
for jj=1:numel(objs)
    try
        fs=objs(jj).FontSize;
        if isnumeric(fs) && isscalar(fs) && isfinite(fs)
            objs(jj).FontSize=max(1,fs*scaleFactor);
        end
    catch
        % Some graphics objects expose FontSize but do not permit assignment.
    end
end
end


function out=task_display_label(task)
% Human-readable task label for figures; raw T-codes remain in tables/files.
t=char(string(task));
switch t
    case 'T00', out='Rest';
    case 'T01', out='Coord';
    case 'T02', out='C&R';
    case 'T03', out='Fam';
    case 'T04', out='Unfam';
    case 'T05', out='Imp';
    case 'T06', out='Listen';
    otherwise, out=t;
end
end

function out=task_display_labels(tasks)
cc=cellstr(string(tasks)); out=cell(size(cc));
for ii=1:numel(cc), out{ii}=task_display_label(cc{ii}); end
end

function out=display_group_name(g)
g=char(string(g));
switch g
    case 'Frontal-Executive', out='Frontal-Executive';
    case 'Parietal', out='Parietal';
    otherwise, out=g;
end
end

function shrink_colorbar_height(cb,fraction)
% Shorten a vertical colorbar while preserving its vertical center.
try
    drawnow;
    p=cb.Position;
    newH=p(4)*fraction;
    p(2)=p(2)+(p(4)-newH)/2;
    p(4)=newH;
    cb.Position=p;
catch
end
end

function apply_publication_typography_once(figHandle,scaleFactor)
    % Prevent accidental repeated scaling when one figure is exported in
    if isempty(figHandle) || ~isgraphics(figHandle), return; end
    if isappdata(figHandle,'PublicationTypographyApplied'), return; end
    if abs(scaleFactor-1.0) > 1e-12
        apply_publication_typography(figHandle,scaleFactor);
    end
    setappdata(figHandle,'PublicationTypographyApplied',true);
end


function apply_publication_typography(figHandle,scaleFactor)
% Scale ALL visible typography in a completed figure exactly once.
% This includes axes ticks, labels, titles, legends, colorbars, annotations,
% and free text. It is applied after plotting so explicit FontSize settings
% are scaled as well as inherited defaults.
if isempty(figHandle) || ~isgraphics(figHandle), return; end
if isappdata(figHandle,'KM_FontScaleApplied') && getappdata(figHandle,'KM_FontScaleApplied'), return; end
objs=findall(figHandle,'-property','FontSize');
for ii=1:numel(objs)
    try
        fs=objs(ii).FontSize;
        if isnumeric(fs) && isscalar(fs) && isfinite(fs), objs(ii).FontSize=scaleFactor*fs; end
    catch
    end
end
setappdata(figHandle,'KM_FontScaleApplied',true);
drawnow;
end


function fill_errorbar_marker(h)
% Fill circular markers using the object's own line color.
try
    if isgraphics(h) && isprop(h,'Marker') && strcmp(h.Marker,'o')
        h.MarkerFaceColor=h.Color;
    end
catch
end
end

function fill_line_marker(h)
% Fill circular markers on ordinary line objects using their own color.
try
    if isgraphics(h) && isprop(h,'Marker') && strcmp(h.Marker,'o')
        h.MarkerFaceColor=h.Color;
    end
catch
end
end

function fill_all_circle_markers(figHandle)
if isempty(figHandle)||~isgraphics(figHandle),return;end
objs=findall(figHandle,'-property','Marker');
for ii=1:numel(objs)
    try
        if strcmp(objs(ii).Marker,'o') && isprop(objs(ii),'MarkerFaceColor')
            if isprop(objs(ii),'Color')
                objs(ii).MarkerFaceColor=objs(ii).Color;
            elseif isprop(objs(ii),'CData')
                objs(ii).MarkerFaceColor='flat';
            end
        end
    catch
    end
end
end


function force_network_node_pink(figHandle)
if isempty(figHandle) || ~isgraphics(figHandle), return; end
nodes=findall(figHandle,'Tag','KMNetworkNode');
for ii=1:numel(nodes)
    try
        nodes(ii).MarkerFaceColor=[0.95 0.05 0.50];
        nodes(ii).MarkerEdgeColor='k';
        if isprop(nodes(ii),'CData')
            nodes(ii).CData=[0.95 0.05 0.50];
        end
    catch
    end
end
drawnow;
end

function add_listen_right_margin(figHandle)
% VISUAL ONLY: add an empty right-hand x-axis column after Listen, without
% changing any data coordinates, tick locations, results, or statistics.
% Run at every export point so MAIN/SUPPLEMENT and individual figure files
% receive exactly the same spacing. Exclude heatmaps and non-task axes.
axs=findall(figHandle,'Type','axes');
for ii=1:numel(axs)
    ax=axs(ii);
    try
        if ~strcmpi(ax.Visible,'on'), continue; end
        if ~isempty(findall(ax,'Type','image')), continue; end
        ticks=ax.XTick;
        if isempty(ticks), continue; end
        labs=cellstr(string(ax.XTickLabel));
        if numel(labs)~=numel(ticks), continue; end
        labs=strtrim(labs);
        last=find(strcmpi(labs,'Listen'),1,'last');
        if isempty(last) || last~=numel(ticks), continue; end
        lastX=ticks(last);
        if ~isfinite(lastX), continue; end
        lim=xlim(ax);
        % For the seven-condition plots, this yields xlim [0.45 7.75].
        if numel(ticks)>1
            step=median(diff(ticks));
        else
            step=1;
        end
        if ~isfinite(step)||step<=0, step=1; end
        rightEdge=lastX+0.75*step;
        if lim(2)<rightEdge, xlim(ax,[lim(1) rightEdge]); end
    catch
        % Nonstandard/legend axes must not prevent figure export.
    end
end
end

function append_pdf_page_v22(figHandle,pdfFile)
% Guard against empty or extensionless paths before any exportgraphics call.
if nargin<2 || isempty(pdfFile) || (isstring(pdfFile) && strlength(pdfFile)==0)
    error('MUSIC_EEG:MissingPDFPath', ...
        'append_pdf_page_v22 requires a nonempty PDF path with a filename.');
end
pdfFile=char(pdfFile);
[~,~,pdfExt]=fileparts(pdfFile);
if isempty(pdfExt),pdfFile=[pdfFile '.pdf'];end
% Main and Supplement use the same absolute publication typography and filled-marker guard.
standardize_supplement_figure(figHandle);
fill_all_circle_markers(figHandle);
force_network_node_pink(figHandle);
add_listen_right_margin(figHandle);
parent=fileparts(pdfFile);
if ~exist(parent,'dir'), mkdir(parent); end
music2_apply_paper_typography(figHandle);
drawnow;
% One vector PDF plus 600-dpi JPG per paper figure; combined PDFs are also appended.
persistent pageCounts
if isempty(pageCounts),pageCounts=containers.Map('KeyType','char','ValueType','double');end
if isKey(pageCounts,pdfFile),pageCounts(pdfFile)=pageCounts(pdfFile)+1;
else,pageCounts(pdfFile)=1;end
[~,collection]=fileparts(pdfFile);
base=fullfile(parent,sprintf('%s_%02d',collection,pageCounts(pdfFile)));
% IMPORTANT: append to the combined PDF BEFORE exporting the same figure to
% standalone files. Some MATLAB releases can invalidate complex tiled-layout
% figure handles after repeated exportgraphics calls. This ordering avoids the
% observed 'Input was not a valid graphics object' failure on the Append call.
if exist(pdfFile,'file')==2
    music2_apply_paper_typography(figHandle);
   exportgraphics(figHandle,pdfFile,'ContentType','vector','Append',true);
else
    exportgraphics(figHandle,pdfFile,'ContentType','vector');
end
if ~isgraphics(figHandle)
    error('FIGURE_HANDLE_INVALIDATED','Figure handle became invalid while creating combined PDF: %s',pdfFile);
end
exportgraphics(figHandle,[base '.pdf'],'ContentType','vector');
if ~isgraphics(figHandle)
    error('FIGURE_HANDLE_INVALIDATED','Figure handle became invalid after standalone PDF export: %s',[base '.pdf']);
end
exportgraphics(figHandle,[base '.jpg'],'Resolution',600);
% Also place clean publication copies in dedicated format folders.
if contains(upper(parent),[filesep 'MAIN'])
    jpgDir=fullfile(parent,'JPG_600DPI'); vecDir=fullfile(parent,'VECTOR_PDF');
else
    jpgDir=fullfile(parent,'JPG_600DPI'); vecDir=fullfile(parent,'VECTOR_PDF');
end
if ~exist(jpgDir,'dir'),mkdir(jpgDir);end; if ~exist(vecDir,'dir'),mkdir(vecDir);end
copyfile([base '.jpg'],fullfile(jpgDir,[sprintf('%s_%02d',collection,pageCounts(pdfFile)) '.jpg']));
copyfile([base '.pdf'],fullfile(vecDir,[sprintf('%s_%02d',collection,pageCounts(pdfFile)) '.pdf']));
if exist(pdfFile,'file')~=2
    error('PDF_EXPORT_FAILED','PDF was not created: %s',pdfFile);
end
end

%% ===== Frontal-14 manuscript reporting visualizations (descriptive) =====
function plot_frontal14_coverage_qc(S,tasks,G)
% Each cell: INCLUDED / ALL participant-condition files; group coverage
% is not a measure of independent subjects or electrode quality.
nt=numel(tasks);ng=numel(G);frac=nan(ng,nt);numer=zeros(ng,nt);denom=zeros(ng,nt);
for g=1:ng
 for t=1:nt
  r=S(strcmp(S.EEGGroup,G{g}) & strcmp(S.Task,tasks{t}),:);
  if ~isempty(r) && r.NFiles(1)>0
   numer(g,t)=r.NIncludedFiles(1);denom(g,t)=r.NFiles(1);
   frac(g,t)=numer(g,t)/denom(g,t);
  end
 end
end
imagesc(frac,[0 1]);colormap(gca,parula);cb=colorbar;cb.Label.String='Fraction meeting minimum coverage';
set(gca,'XTick',1:nt,'XTickLabel',task_display_labels(tasks), ...
 'YTick',1:ng,'YTickLabel',{'A (6 nominal)','F (14 nominal)','M (11 nominal)','V (20 nominal)'},'FontSize',17);
xlabel('Condition');ylabel('Functional scalp group');
title('Usable regional coverage by condition (included / available files)','FontWeight','bold');
for g=1:ng
 for t=1:nt
  if denom(g,t)>0
   text(t,g,sprintf('%d/%d',numer(g,t),denom(g,t)), ...
    'HorizontalAlignment','center','FontWeight','bold','FontSize',18, ...
    'Color',ternary_fig_color(frac(g,t)<0.45));
  end
 end
end
end

function c=ternary_fig_color(darkBackground)
if darkBackground,c=[1 1 1];else,c=[0 0 0];end
end

function plot_frontal14_matched_n(C,tasks,G)
pp=canonical_functional_pairs(G);tt=tasks(~strcmp(tasks,'T00'));
H=nan(size(pp,1),numel(tt));labs=cell(size(pp,1),1);
for p=1:size(pp,1)
 pn=[pp{p,1} '--' pp{p,2}];labs{p}=[short_one(pp{p,1}) '-' short_one(pp{p,2})];
 for t=1:numel(tt)
  r=C(strcmp(C.Pair,pn)&strcmp(C.Task,tt{t}),:);
  if ~isempty(r),H(p,t)=r.NPaired(1);end
 end
end
imagesc(H,[0 max(1,max(H(:),[],'omitnan'))]);colormap(gca,parula);colorbar;
set(gca,'XTick',1:numel(tt),'XTickLabel',task_display_labels(tt), ...
 'YTick',1:numel(labs),'YTickLabel',labs,'FontSize',17);
xlabel('Task versus Rest');ylabel('Functional connection');
title('Matched participant-context records contributing to each paired edge test','FontWeight','bold');
for p=1:size(H,1)
 for t=1:size(H,2)
  if isfinite(H(p,t)),text(t,p,sprintf('%d',H(p,t)), ...
   'HorizontalAlignment','center','FontSize',20,'FontWeight','bold','Color', ...
   ternary_fig_color(H(p,t)<.45*max(H(:),[],'omitnan')));end
 end
end
end

function plot_frontal14_edge_forest(C,tasks,G)
% Display ALL 60 task-by-edge comparisons, not only selected discoveries.
pp=canonical_functional_pairs(G);tt=tasks(~strcmp(tasks,'T00'));
tl=tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
title(tl,'All paired connection changes from Rest: mean and 95% bootstrap CI','FontWeight','bold');
for t=1:numel(tt)
 ax=nexttile;hold(ax,'on');box(ax,'on');grid(ax,'on');xline(ax,0,'k--');
 for p=1:size(pp,1)
  pn=[pp{p,1} '--' pp{p,2}];r=C(strcmp(C.Pair,pn)&strcmp(C.Task,tt{t}),:);
  if isempty(r)||~isfinite(r.MeanDelta(1)),continue;end
  x=r.MeanDelta(1);lo=r.CI95_Low(1);hi=r.CI95_High(1);
  if r.SignificantFDR(1),clr=[.10 .35 .75];else,clr=[.45 .45 .45];end
  if all(isfinite([lo hi])),plot(ax,[lo hi],[p p],'-','Color',clr,'LineWidth',2);end
  plot(ax,x,p,'o','MarkerFaceColor',clr,'MarkerEdgeColor',clr,'MarkerSize',7);
  text(ax,.285,p,sprintf('n=%d%s',r.NPaired(1),ternary_star(r.SignificantFDR(1))), ...
   'FontSize',12,'VerticalAlignment','middle');
 end
 set(ax,'YTick',1:size(pp,1),'YTickLabel',arrayfun(@(p) ...
  [short_one(pp{p,1}) '-' short_one(pp{p,2})],(1:size(pp,1))','UniformOutput',false), ...
  'YDir','reverse','FontSize',14);
 xlim(ax,[-.30 .38]);ylim(ax,[.5 size(pp,1)+.5]);
 title(ax,task_display_label(tt{t}));xlabel(ax,'Mean change in |CS|');
end
end

function s=ternary_star(tf)
if tf,s=' *';else,s='';end
end

function plot_frontal14_paired_global(B,C,t0,tasks)
% Paired points show participant-context records, not independent dyads.
metrics={'MeanAbsBrainCS','MeanBrainNetworkCoord'};
labs={'Global mean |CS|','Dynamic network coordination'};
% Find actual task IDs using labels, not assumed numeric ordering.
tt={};for k=1:numel(tasks)
 name=lower(task_display_label(tasks{k}));
 if ~strcmp(tasks{k},t0) && (contains(name,'call')||contains(name,'c&r')||contains(name,'imp'))
  tt{end+1}=tasks{k}; %#ok<AGROW>
 end
end
if isempty(tt),tt=tasks(~strcmp(tasks,t0));end
nrow=numel(metrics);ncol=numel(tt);
tl=tiledlayout(nrow,ncol,'TileSpacing','compact','Padding','compact');
title(tl,'Matched participant-context changes relative to Rest','FontWeight','bold');
for m=1:nrow
 for k=1:ncol
  ax=nexttile;hold(ax,'on');box(ax,'on');grid(ax,'on');
  [a,b]=pairvals(B,t0,tt{k},metrics{m});
  for i=1:numel(a)
   plot(ax,[1 2],[a(i) b(i)],'-o','Color',[.68 .68 .68], ...
    'MarkerSize',4,'MarkerFaceColor',[.68 .68 .68]);
  end
  if ~isempty(a),plot(ax,[1 2],[mean(a) mean(b)],'-o', ...
   'LineWidth',2.5,'MarkerSize',8,'Color',[.05 .30 .75], ...
   'MarkerFaceColor',[.05 .30 .75]);end
  set(ax,'XTick',[1 2],'XTickLabel',{'Rest',task_display_label(tt{k})},'FontSize',14);
  xlim(ax,[.75 2.25]);ylabel(ax,labs{m});
  metric={'GlobalAbsCS','DynamicNetworkCoord'};r=C(strcmp(C.Metric,metric{m})&strcmp(C.Task,tt{k}),:);
  if ~isempty(r),title(ax,sprintf('%s: n=%d, q=%.3g',task_display_label(tt{k}),r.NPaired(1),r.Q_FDR(1)));end
 end
end
end

function plot_frontal14_paired_dyads(S,C,t0,task)
% Only the eight (or other actual count) dyads with both conditions.
metric='NormalizedEuclideanDistance';
if ~any(strcmp(S.Task,task))
 candidates=unique(S.Task,'stable');
 for k=1:numel(candidates)
  nm=lower(task_display_label(candidates{k}));
  if contains(nm,'call')||contains(nm,'c&r'),task=candidates{k};break;end
 end
end
ids=intersect(unique(S.Dyad(strcmp(S.Task,t0)),'stable'), ...
 unique(S.Dyad(strcmp(S.Task,task)),'stable'),'stable');
a=[];b=[];kept={};
for i=1:numel(ids)
 r0=S(strcmp(S.Dyad,ids{i})&strcmp(S.Task,t0),:);
 r1=S(strcmp(S.Dyad,ids{i})&strcmp(S.Task,task),:);
 x=r0.(metric);y=r1.(metric);x=x(isfinite(x));y=y(isfinite(y));
 if ~isempty(x)&&~isempty(y),a(end+1)=mean(x);b(end+1)=mean(y);kept{end+1}=ids{i};end %#ok<AGROW>
end
hold on;box on;grid on;
for i=1:numel(a)
 plot([1 2],[a(i) b(i)],'-o','Color',[.55 .55 .55], ...
  'MarkerFaceColor',[.55 .55 .55],'MarkerSize',6,'LineWidth',1.4);
 text(2.05,b(i),kept{i},'FontSize',12,'Interpreter','none');
end
if ~isempty(a),plot([1 2],[mean(a) mean(b)],'-o','Color',[.05 .30 .75], ...
 'LineWidth',3,'MarkerSize',10,'MarkerFaceColor',[.05 .30 .75]);end
set(gca,'XTick',[1 2],'XTickLabel',{'Rest',task_display_label(task)},'FontSize',17);
xlim([.7 2.55]);ylabel('Normalized distance between partners'' within-brain networks');
r=C(strcmp(C.Metric,metric)&strcmp(C.Task,task),:);
if ~isempty(r)
 title(sprintf('Dyadic network-fingerprint distance: n=%d dyads, q=%.3g', ...
  r.NPairedDyads(1),r.Q_FDR(1)),'FontWeight','bold');
else
 title('Dyadic network-fingerprint distance','FontWeight','bold');
end
end


function [R,S] = build_common_edge_global_sensitivity(P,t0,tasks,G)
% Participant-context paired global |CS| using the identical set of edges in
% Rest and task. This directly tests whether primary global effects survive
% when network composition is held fixed within each paired contrast.
R=table(); S=table(); if isempty(P),return;end
pp=canonical_functional_pairs(G); subs=unique(P.Subject,'stable');
for i=1:numel(subs)
 q0=P(strcmp(P.Subject,subs{i})&strcmp(P.Task,t0),:); if isempty(q0),continue;end
 v0=edge_vector_from_pair_table(q0,pp);
 for k=1:numel(tasks)
  tk=tasks{k}; if strcmp(tk,t0),continue;end
  q1=P(strcmp(P.Subject,subs{i})&strcmp(P.Task,tk),:); if isempty(q1),continue;end
  v1=edge_vector_from_pair_table(q1,pp); ok=isfinite(v0)&isfinite(v1); n=sum(ok);
  if n<3,continue;end
  a=mean(v0(ok),'omitnan'); b=mean(v1(ok),'omitnan');
  R=[R;table(q1.Dyad(1),q1.Participant(1),q1.Subject(1),{t0},{tk},n,a,b,b-a,n==size(pp,1), ...
    'VariableNames',{'Dyad','Participant','Subject','Baseline','Task','NCommonEdges','RestMeanAbsCS','TaskMeanAbsCS','Delta','AllEdges'})]; %#ok<AGROW>
 end
end
S=summarize_sensitivity_rows(R,'Delta','CommonEdges');
% Also report the stricter complete-network subset as a separate sensitivity family.
R6=R(R.AllEdges,:); S6=summarize_sensitivity_rows(R6,'Delta','AllEdges');
S=[S;S6];
end

function [R,S] = build_fmv_global_sensitivity(P,t0,tasks,G)
% Global sensitivity based on all six non-auditory F/M/P/O edges. These edges do not
% depend on Auditory coverage and therefore hold network composition fixed.
R=table();S=table(); if isempty(P),return;end
wanted={'Frontal-Executive--Sensorimotor','Frontal-Executive--Parietal','Frontal-Executive--Occipital', ...
        'Sensorimotor--Parietal','Sensorimotor--Occipital','Parietal--Occipital'};
nWanted=numel(wanted);
if ~all(ismember(wanted,unique(P.Pair)))
 warning('Non-auditory sensitivity: not all configured F/M/P/O pairs are present.');
end
subs=unique(P.Subject,'stable');
for i=1:numel(subs)
 for k=1:numel(tasks)
  tk=tasks{k};if strcmp(tk,t0),continue;end
  q0=P(strcmp(P.Subject,subs{i})&strcmp(P.Task,t0)&ismember(P.Pair,wanted),:);
  q1=P(strcmp(P.Subject,subs{i})&strcmp(P.Task,tk)&ismember(P.Pair,wanted),:);
  if numel(unique(q0.Pair))~=nWanted || numel(unique(q1.Pair))~=nWanted,continue;end
  a=mean(q0.AbsCS,'omitnan');b=mean(q1.AbsCS,'omitnan');
  R=[R;table(q1.Dyad(1),q1.Participant(1),q1.Subject(1),{t0},{tk},nWanted,a,b,b-a, ...
    'VariableNames',{'Dyad','Participant','Subject','Baseline','Task','NEdges','RestMeanAbsCS','TaskMeanAbsCS','Delta'})]; %#ok<AGROW>
 end
end
S=summarize_sensitivity_rows(R,'Delta','NonAuditoryEdges');
end

function S=summarize_sensitivity_rows(R,deltaVar,label)
S=table();if isempty(R),return;end
tasks=unique(R.Task,'stable');
for k=1:numel(tasks)
 q=R(strcmp(R.Task,tasks{k}),:); d=q.(deltaVar); d=d(isfinite(d));
 if isempty(d),continue;end
 a=zeros(size(d));b=d;[p,rb,md,mn,lo,hi]=dstat(a,b);
 S=[S;table({label},tasks(k),numel(d),mn,md,lo,hi,p,rb, ...
  'VariableNames',{'Sensitivity','Task','NPaired','MeanDelta','MedianDelta','CI95_Low','CI95_High','P_Wilcoxon','RankBiserial'})]; %#ok<AGROW>
end
if ~isempty(S)
 S.Q_FDR=bh_fdr_local(S.P_Wilcoxon); S.SignificantFDR=S.Q_FDR<.05;
end
end

function [R,S] = build_dyad_common_edge_sensitivity(P,t0,tasks,G)
% For each dyad/task, Rest and task partner distances are calculated on the
% same edge set shared by M1 and M2 in BOTH conditions.
R=table();S=table();if isempty(P),return;end
pp=canonical_functional_pairs(G);dyads=unique(P.Dyad,'stable');
for d=1:numel(dyads)
 q0=P(strcmp(P.Dyad,dyads{d})&strcmp(P.Task,t0),:);
 if isempty(q0),continue;end
 r1=edge_vector_from_pair_table(q0(strcmpi(q0.Participant,'M1'),:),pp);
 r2=edge_vector_from_pair_table(q0(strcmpi(q0.Participant,'M2'),:),pp);
 for k=1:numel(tasks)
  tk=tasks{k};if strcmp(tk,t0),continue;end
  q1=P(strcmp(P.Dyad,dyads{d})&strcmp(P.Task,tk),:);if isempty(q1),continue;end
  t1=edge_vector_from_pair_table(q1(strcmpi(q1.Participant,'M1'),:),pp);
  t2=edge_vector_from_pair_table(q1(strcmpi(q1.Participant,'M2'),:),pp);
  ok=isfinite(r1)&isfinite(r2)&isfinite(t1)&isfinite(t2);n=sum(ok);if n<3,continue;end
  a=r1(ok);b=r2(ok);c=t1(ok);e=t2(ok);
  d0=norm(a-b)/(norm(a)+norm(b)+eps); d1=norm(c-e)/(norm(c)+norm(e)+eps);
  m0=mean(abs(a-b),'omitnan'); m1=mean(abs(c-e),'omitnan');
  R=[R;table(dyads(d),{t0},{tk},n,d0,d1,d1-d0,m0,m1,m1-m0,n==size(pp,1), ...
   'VariableNames',{'Dyad','Baseline','Task','NCommonEdgesAcrossBothConditions','RestNormalizedDistance','TaskNormalizedDistance','DeltaNormalizedDistance','RestMeanAbsEdgeDifference','TaskMeanAbsEdgeDifference','DeltaMeanAbsEdgeDifference','AllEdges'})]; %#ok<AGROW>
 end
end
metrics={'DeltaNormalizedDistance','DeltaMeanAbsEdgeDifference'};labels={'NormalizedEuclideanDistance','MeanAbsEdgeDifference'};
for m=1:numel(metrics)
 tasks2=unique(R.Task,'stable');
 for k=1:numel(tasks2)
  q=R(strcmp(R.Task,tasks2{k}),:);d=q.(metrics{m});d=d(isfinite(d));if isempty(d),continue;end
  [p,rb,md,mn,lo,hi]=dstat(zeros(size(d)),d);
  S=[S;table(labels(m),tasks2(k),numel(d),mn,md,lo,hi,p,rb, ...
   'VariableNames',{'Metric','Task','NPairedDyads','MeanDelta','MedianDelta','CI95_Low','CI95_High','P_Wilcoxon','RankBiserial'})]; %#ok<AGROW>
 end
end
if ~isempty(S)
 S.Q_FDR=nan(height(S),1);S.SignificantFDR=false(height(S),1);
 for u=unique(S.Metric,'stable')'
  ix=strcmp(S.Metric,u{1});S.Q_FDR(ix)=bh_fdr_local(S.P_Wilcoxon(ix));
 end
 S.SignificantFDR=S.Q_FDR<.05;
end
end

function write_reviewer_qc_notes(folder,A,C,F,D)
p=fullfile(folder,'REVIEWER_QC_README.txt');fid=fopen(p,'w');if fid<0,return;end
fprintf(fid,'FIVE-NODE MUSIC-FUNCTIONAL REVIEWER-QC ANALYSIS\n\n');
fprintf(fid,'S9/S10 distributions are generated from one orientation of the ten unique EEG edges only.\n');
fprintf(fid,'The unique-edge audit hard-stops if duplicate Subject-Task-Pair rows or more edges than allowed by the configured network are detected.\n');
fprintf(fid,'Global same-edge sensitivity recomputes Rest/task means on the identical edge intersection for each context.\n');
fprintf(fid,'Non-auditory sensitivity uses all six F/M/P/O edges, eliminating dependence on Auditory coverage.\n');
fprintf(fid,'Dyadic same-edge sensitivity uses the identical edge set shared by both partners in Rest and task.\n');
fprintf(fid,'Repeated musician VERIFIED as D02_M2 = D09_M1. Code runs both single-context exclusions, a unique-participant-collapsed analysis, and dyad-level identity sensitivities.\n\n');
fprintf(fid,'Unique-edge rows: %d participant-context/task records.\n',height(A));
if ~isempty(C),fprintf(fid,'Common-edge global sensitivity rows: %d summary contrasts.\n',height(C));end
if ~isempty(F),fprintf(fid,'Non-auditory global sensitivity rows: %d summary contrasts.\n',height(F));end
if ~isempty(D),fprintf(fid,'Dyadic same-edge sensitivity rows: %d summary contrasts.\n',height(D));end
fclose(fid);
end

function plot_reviewer_global_sensitivities(primary,C,F,tasks)
% Four panels: primary global, same-edge global, all-edge complete-network subset, and
% F/M/P/O-only global. Together these isolate edge-composition/coverage effects.
tl=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
title(tl,'Reviewer robustness: global coordination under fixed edge composition','FontWeight','bold');
nexttile;plot_sensitivity_panel_from_primary(primary,'GlobalAbsCS','Primary global |CS|');
nexttile;plot_sensitivity_panel(C,'CommonEdges','Same edges in Rest and task');
nexttile;plot_sensitivity_panel(C,'AllEdges','All-10-edge matched subset');
nexttile;plot_sensitivity_panel(F,'NonAuditoryEdges','F/M/P/O-only (6 fixed edges)');
end

function plot_sensitivity_panel_from_primary(T,metric,ttl)
Q=T(strcmp(T.Metric,metric),:);x=1:height(Q);hold on;box on;grid on;yline(0,'k--');
if isempty(Q),title(ttl);return;end
lo=Q.MeanDelta-Q.CI95_Low;hi=Q.CI95_High-Q.MeanDelta;errorbar(x,Q.MeanDelta,lo,hi,'o','LineWidth',1.4,'MarkerSize',7);
set(gca,'XTick',x,'XTickLabel',task_display_labels(Q.Task));xtickangle(25);ylabel('\Delta mean |CS|');title(ttl);
for i=1:height(Q),if Q.SignificantFDR(i),text(i,Q.CI95_High(i),'*','HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',20,'FontWeight','bold');end,end
end

function plot_sensitivity_panel(T,sens,ttl)
Q=T(strcmp(T.Sensitivity,sens),:);x=1:height(Q);hold on;box on;grid on;yline(0,'k--');
if isempty(Q),title(ttl);return;end
lo=Q.MeanDelta-Q.CI95_Low;hi=Q.CI95_High-Q.MeanDelta;errorbar(x,Q.MeanDelta,lo,hi,'o','LineWidth',1.4,'MarkerSize',7);
set(gca,'XTick',x,'XTickLabel',task_display_labels(Q.Task));xtickangle(25);ylabel('\Delta mean |CS|');title(ttl);
for i=1:height(Q),if Q.SignificantFDR(i),text(i,Q.CI95_High(i),'*','HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',20,'FontWeight','bold');end,end
end

function plot_unique_eeg_edge_audit(A,tasks)
% A complete five-node network contains 10 unique undirected EEG edges.
mu=nan(1,numel(tasks));nAll=nan(1,numel(tasks));nrec=nan(1,numel(tasks)); nExpected=nchoosek(5,2);
for k=1:numel(tasks)
 q=A(strcmp(A.Task,tasks{k}),:);if isempty(q),continue;end
 mu(k)=mean(q.NUniqueEEGEdges);nAll(k)=sum(q.HasAllEdges);nrec(k)=height(q);
end
tl=tiledlayout(1,2,'TileSpacing','compact','Padding','compact');title(tl,'Integrity audit: ten unique undirected EEG connections only','FontWeight','bold');
nexttile;bar(1:numel(tasks),mu);ylim([0 nExpected+.5]);yline(nExpected,'k--');set(gca,'XTick',1:numel(tasks),'XTickLabel',task_display_labels(tasks));xtickangle(25);ylabel('Mean unique EEG edges / context');title('Available unique edges');grid on;
nexttile;bar(1:numel(tasks),nAll); ymax=max(nrec(isfinite(nrec))); if isempty(ymax),ymax=10;end; ylim([0 max(10,ymax+1)]);set(gca,'XTick',1:numel(tasks),'XTickLabel',task_display_labels(tasks));xtickangle(25);ylabel('Contexts with all 10 edges');title('Complete five-node fingerprints');grid on;
for k=1:numel(tasks),if isfinite(nAll(k)),text(k,nAll(k),sprintf('%d/%d',nAll(k),nrec(k)),'HorizontalAlignment','center','VerticalAlignment','bottom');end,end
end

function plot_dyad_common_edge_sensitivity(R,S,task)
q=R(strcmp(R.Task,task),:);hold on;box on;grid on;
for i=1:height(q)
 plot([1 2],[q.RestNormalizedDistance(i) q.TaskNormalizedDistance(i)],'-o','LineWidth',1.2);
 text(2.04,q.TaskNormalizedDistance(i),q.Dyad{i},'FontSize',10,'Interpreter','none');
end
set(gca,'XTick',[1 2],'XTickLabel',{'Rest',task_display_label(task)});xlim([.8 2.45]);ylabel('Normalized partner network distance');
z=S(strcmp(S.Metric,'NormalizedEuclideanDistance')&strcmp(S.Task,task),:);
if isempty(z),title('Dyadic same-edge sensitivity');else,title(sprintf('Dyadic same-edge sensitivity: n=%d, q=%.3g',z.NPairedDyads(1),z.Q_FDR(1)),'FontWeight','bold');end
end

function [T,status] = frontal14_repeated_context_sensitivity(B,P,ids,t0,tasks,G)
% Both deletions are essential: selecting whichever is more significant is invalid.
T=table();
if isempty(ids)
 status=['NOT RUN: the two context IDs of the repeated musician were not provided. ' ...
         'Set RepeatedMusicianContexts to the verified two IDs and rerun.'];
 return;
end
ids=cellstr(string(ids));
if numel(ids)~=2 || strcmp(ids{1},ids{2})
 error('RepeatedMusicianContexts must contain two DIFFERENT verified context IDs.');
end
if ~all(ismember(ids,unique(B.Subject))) || ~all(ismember(ids,unique(P.Subject)))
 error('Repeated musician context IDs not found in BrainSummary/FunctionalPairSubject.');
end
for i=1:2
 drop=ids{i}; keep=ids{3-i};
 BB=B(~strcmp(B.Subject,drop),:); PP=P(~strcmp(P.Subject,drop),:);
 gg=add_fdr_by_metric(build_t0_global_contrasts(BB,t0,tasks));
 ee=add_fdr_by_connection(build_t0_pair_contrasts(PP,t0,tasks,G));
 for j=1:height(gg)
  T=[T;table({drop},{keep},{'Global'},{gg.Metric{j}},{gg.Task{j}}, ...
    gg.NPaired(j),gg.MeanDelta(j),gg.P_Wilcoxon(j),gg.Q_FDR(j), ...
    'VariableNames',{'DroppedContext','RetainedContext','Family','Metric','Task','NPaired','MeanDelta','P_Wilcoxon','Q_WithinFamily'})]; %#ok<AGROW>
 end
 for j=1:height(ee)
  T=[T;table({drop},{keep},{'Edge'},{ee.Pair{j}},{ee.Task{j}}, ...
    ee.NPaired(j),ee.MeanDelta(j),ee.P_Wilcoxon(j),ee.Q_FDR(j), ...
    'VariableNames',{'DroppedContext','RetainedContext','Family','Metric','Task','NPaired','MeanDelta','P_Wilcoxon','Q_WithinFamily'})]; %#ok<AGROW>
 end
end
status=sprintf('RUN: both exclusions tested, %s and %s. Results are sensitivity analyses, not replacement primary estimates.',ids{1},ids{2});
end

function frontal14_plot_coverage_by_context(C,G)
setappdata(gcf,'KM_CoherentQCStyle',true);
if isempty(C),axis off;return;end
ss=unique(C.Subject,'stable');H=nan(numel(ss),numel(G));
for i=1:numel(ss)
 for j=1:numel(G)
  q=strcmp(C.Subject,ss{i})&strcmp(C.EEGGroup,G{j});
  if any(q),H(i,j)=mean(double(C.Included(q)),'omitnan');end
 end
end
imagesc(H,[0 1]);colormap(parula);colorbar;
set(gca,'XTick',1:numel(G),'XTickLabel',short_group_names(G), ...
 'YTick',1:numel(ss),'YTickLabel',strrep(ss,'_','-'),'FontSize',14,'TickLabelInterpreter','none');
set(gca,'YLim',[.5 numel(ss)+.5]);
xlabel('Scalp-electrode group');ylabel('Participant-dyad context');
title('Fraction of available conditions meeting channel-coverage threshold');
for i=1:size(H,1)
 for j=1:size(H,2)
  if isfinite(H(i,j)),text(j,i,sprintf('%.0f%%',100*H(i,j)), ...
   'HorizontalAlignment','center','FontSize',17,'FontWeight','bold','Color','k');end
 end
end
end

function frontal14_plot_repeated_context(T)
setappdata(gcf,'KM_CoherentQCStyle',true);
% Two verified context exclusions; abbreviate labels to preserve space.
Q=T(strcmp(T.Family,'Edge') & ismember(T.Metric, ...
 {'Auditory--Sensorimotor','Auditory--Parietal', ...
  'Frontal-Executive--Parietal','Sensorimotor--Parietal'}),:);
if isempty(Q),axis off;return;end
[~,ord]=sortrows(Q,{'Metric','Task','DroppedContext'});Q=Q(ord,:);
y=(1:height(Q))'; ax=gca; hold(ax,'on');box(ax,'on');grid(ax,'on');
plot(ax,Q.MeanDelta,y,'o','MarkerSize',7,'MarkerFaceColor',[.12 .39 .73], ...
 'MarkerEdgeColor',[.12 .39 .73]);xline(ax,0,'k--');
labels=cell(height(Q),1);
for i=1:height(Q)
    edge=frontal14_short_metric(Q.Metric{i});
    task=task_display_label(Q.Task{i});
    labels{i}=sprintf('%s / %s / omit %s',edge,task,strrep(Q.DroppedContext{i},'_','-'));
end
set(ax,'YTick',y,'YTickLabel',labels,'YDir','reverse', ...
 'TickLabelInterpreter','none','FontSize',10);
% 48 rows: use a deliberately smaller tick size, not the normal 14-pt.
setappdata(gcf,'KM_QCCompactYTicks',true);
setappdata(gcf,'KM_QCCompactYFont',9); % 48 participant/context rows; doubled from 4.5 pt on Supplement p. 18
ax.Position=[.34 .09 .62 .83];
ylim(ax,[.35 height(Q)+.65]);
xlabel(ax,'Mean \DeltaCS = CS_{task} - CS_{rest}');
title(ax,'Repeated-musician sensitivity: both context exclusions');
end


function [T,status] = frontal14_unique_participant_sensitivity(B,P,ids,t0,tasks,G)
% Collapse the two VERIFIED contexts from the same musician into a single
% participant identity before paired inference. pairvals() already averages
% multiple rows for a Subject/Task, so assigning a shared Subject ID causes
% the two contexts to contribute exactly ONCE per task/metric/edge.
T=table();
if isempty(ids)
 status='NOT RUN: verified repeated-musician context IDs were not supplied.';
 return;
end
ids=cellstr(string(ids));
if numel(ids)~=2 || strcmp(ids{1},ids{2})
 error('Unique-participant sensitivity requires two different verified context IDs.');
end
if ~all(ismember(ids,unique(B.Subject))) || ~all(ismember(ids,unique(P.Subject)))
 error('Verified repeated-musician context IDs were not found in BrainSummary/FunctionalPairSubject.');
end
Bc=B; Pc=P; sharedID='P_REPEAT_VERIFIED';
Bc.Subject(ismember(Bc.Subject,ids))={sharedID};
Pc.Subject(ismember(Pc.Subject,ids))={sharedID};
Gg=add_fdr_by_metric(build_t0_global_contrasts(Bc,t0,tasks));
Ee=add_fdr_by_connection(build_t0_pair_contrasts(Pc,t0,tasks,G));
for j=1:height(Gg)
 T=[T;table({'UniqueParticipantCollapsed'},{'Global'},{Gg.Metric{j}},{Gg.Task{j}}, ...
   Gg.NPaired(j),Gg.MeanDelta(j),Gg.MedianDelta(j),Gg.CI95_Low(j),Gg.CI95_High(j), ...
   Gg.P_Wilcoxon(j),Gg.Q_FDR(j),Gg.RankBiserial(j),Gg.SignificantFDR(j), ...
   'VariableNames',{'Sensitivity','Family','Metric','Task','NPaired','MeanDelta','MedianDelta','CI95_Low','CI95_High','P_Wilcoxon','Q_WithinFamily','RankBiserial','SignificantFDR'})]; %#ok<AGROW>
end
for j=1:height(Ee)
 T=[T;table({'UniqueParticipantCollapsed'},{'Edge'},{Ee.Pair{j}},{Ee.Task{j}}, ...
   Ee.NPaired(j),Ee.MeanDelta(j),Ee.MedianDelta(j),Ee.CI95_Low(j),Ee.CI95_High(j), ...
   Ee.P_Wilcoxon(j),Ee.Q_FDR(j),Ee.RankBiserial(j),Ee.SignificantFDR(j), ...
   'VariableNames',{'Sensitivity','Family','Metric','Task','NPaired','MeanDelta','MedianDelta','CI95_Low','CI95_High','P_Wilcoxon','Q_WithinFamily','RankBiserial','SignificantFDR'})]; %#ok<AGROW>
end
status=sprintf(['RUN: %s and %s were mapped to one unique participant before inference. ' ...
 'This yields participant-independent paired tests (maximum N=17) while retaining the prespecified within-family BH-FDR.'],ids{1},ids{2});
end

function [T,status] = frontal14_repeated_musician_dyad_sensitivity(R,affectedDyads,t0,tasks)
% D02 and D09 share the verified repeated musician. Drop each affected dyad
% in turn and recompute the same-edge dyadic six-task FDR family. In either
% sensitivity set, no musician appears in more than one retained dyad.
T=table();
if isempty(R) || numel(affectedDyads)~=2
 status='NOT RUN: dyadic repeated-musician sensitivity lacked data or dyad IDs.';
 return;
end
for z=1:2
 drop=affectedDyads{z}; keep=affectedDyads{3-z}; RR=R(~strcmp(R.Dyad,drop),:);
 metrics={'DeltaNormalizedDistance','DeltaMeanAbsEdgeDifference'};
 labels={'NormalizedEuclideanDistance','MeanAbsEdgeDifference'};
 tmp=table();
 for m=1:numel(metrics)
  for k=1:numel(tasks)
   tk=tasks{k}; if strcmp(tk,t0),continue;end
   q=RR(strcmp(RR.Task,tk),:); d=q.(metrics{m}); d=d(isfinite(d)); if isempty(d),continue;end
   [p,rb,md,mn,lo,hi]=dstat(zeros(size(d)),d);
   tmp=[tmp;table(labels(m),{tk},numel(d),mn,md,lo,hi,p,rb, ...
    'VariableNames',{'Metric','Task','NPairedDyads','MeanDelta','MedianDelta','CI95_Low','CI95_High','P_Wilcoxon','RankBiserial'})]; %#ok<AGROW>
  end
 end
 if ~isempty(tmp)
  tmp.Q_FDR=nan(height(tmp),1); tmp.SignificantFDR=false(height(tmp),1);
  for u=unique(tmp.Metric,'stable')'
   ix=strcmp(tmp.Metric,u{1}); tmp.Q_FDR(ix)=bh_fdr_local(tmp.P_Wilcoxon(ix));
  end
  tmp.SignificantFDR=tmp.Q_FDR<.05;
  tmp.DroppedDyad=repmat({drop},height(tmp),1); tmp.RetainedAffectedDyad=repmat({keep},height(tmp),1);
  T=[T;tmp]; %#ok<AGROW>
 end
end
status=sprintf(['RUN: dyadic dependence sensitivity tested both identity-resolving exclusions: drop %s and drop %s. ' ...
 'Each retained set contains the repeated musician only once.'],affectedDyads{1},affectedDyads{2});
end

function frontal14_plot_unique_participant_sensitivity(T)
setappdata(gcf,'KM_CoherentQCStyle',true);
% The four primary edges plus the two reported global effects.
wantEdge={'Auditory--Sensorimotor','Auditory--Parietal', ...
 'Frontal-Executive--Parietal','Sensorimotor--Parietal'};
Q=T((strcmp(T.Family,'Edge') & ismember(T.Metric,wantEdge)) | ...
    (strcmp(T.Family,'Global') & strcmp(T.Metric,'GlobalAbsCS')),:);
if isempty(Q),axis off;return;end
keep=false(height(Q),1);
for i=1:height(Q)
 if strcmp(Q.Family{i},'Edge')
  keep(i)=(strcmp(Q.Task{i},'T01') && ismember(Q.Metric{i},wantEdge(1:2))) || ...
          (strcmp(Q.Task{i},'T02') && ismember(Q.Metric{i},wantEdge(3:4)));
 else
  keep(i)=ismember(Q.Task{i},{'T02','T05'});
 end
end
Q=Q(keep,:); y=(1:height(Q))';ax=gca;hold(ax,'on');box(ax,'on');grid(ax,'on');xline(ax,0,'k--');
lo=Q.MeanDelta-Q.CI95_Low; hi=Q.CI95_High-Q.MeanDelta;
errorbar(ax,Q.MeanDelta,y,lo,hi,'horizontal','o','LineWidth',1.5,'MarkerSize',8, ...
 'MarkerFaceColor',[.12 .39 .73]);
labels=cell(height(Q),1);
for i=1:height(Q)
 if strcmp(Q.Family{i},'Global'), lab='Global |CS|';
 else,lab=frontal14_short_metric(Q.Metric{i});end
 labels{i}=sprintf('%s / %s',lab,task_display_label(Q.Task{i}));
end
set(ax,'YTick',y,'YTickLabel',labels,'YDir','reverse','TickLabelInterpreter','none');
% Leave one entire empty row above and below: extreme points never touch frame.
ylim(ax,[0 height(Q)+1]);
rightmost=max(Q.CI95_High(isfinite(Q.CI95_High)));
leftmost=min(Q.CI95_Low(isfinite(Q.CI95_Low)));
if isempty(rightmost),rightmost=.35;end
if isempty(leftmost),leftmost=0;end
span=max(.10,rightmost-leftmost);
xlim(ax,[min(0,leftmost-.06*span),rightmost+.29*span]);
xlabel(ax,'Task-minus-Rest change in |CS|');
title(ax,'Identity-resolved sensitivity: musician counted once');
for i=1:height(Q)
 txt=sprintf('n=%d, q=%.3g',Q.NPaired(i),Q.Q_WithinFamily(i));
 text(ax,Q.CI95_High(i)+.018*span,i,txt,'VerticalAlignment','middle', ...
  'HorizontalAlignment','left','FontSize',16,'FontWeight','bold','Clipping','off');
 if Q.SignificantFDR(i)
  text(ax,Q.CI95_High(i)+.018*span,i-.24,'*','FontSize',21,'FontWeight','bold','Clipping','off');
 end
end
end


function frontal14_plot_repeated_musician_dyad_sensitivity(T,task)
setappdata(gcf,'KM_CoherentQCStyle',true);
Q=T(strcmp(T.Metric,'NormalizedEuclideanDistance') & strcmp(T.Task,task),:);
if isempty(Q),axis off;return;end
hold on;box on;grid on;yline(0,'k--');
x=1:height(Q); bar(x,Q.MeanDelta);
set(gca,'XTick',x,'XTickLabel',strcat('omit ',Q.DroppedDyad));
ylabel('\Delta normalized partner-network distance');
title('Dyadic identity sensitivity: repeated musician appears once per retained set','FontWeight','bold');
for i=1:height(Q)
 text(i,Q.MeanDelta(i),sprintf('n=%d\nq=%.3g%s',Q.NPairedDyads(i),Q.Q_FDR(i), ...
      frontal14_significance_star(Q.Q_FDR(i)<.05)), ...
  'HorizontalAlignment','center','VerticalAlignment',ternary_v(Q.MeanDelta(i)<0,'top','bottom'));
end
end

function out=ternary_v(cond,a,b)
if cond,out=a;else,out=b;end
end

function [T,S]=frontal14_context_influence(B,P,t0,tasks,G)
% Exhaustive deletion of EACH context, not a claim to identify repeated musician.
% Recalculate all task tests and the full six-task FDR families each time.
T=table();S=table(); ids=unique(B.Subject,'stable');
for i=1:numel(ids)
    id=ids{i}; BB=B(~strcmp(B.Subject,id),:); PP=P(~strcmp(P.Subject,id),:);
    a=add_fdr_by_metric(build_t0_global_contrasts(BB,t0,tasks));
    b=add_fdr_by_connection(build_t0_pair_contrasts(PP,t0,tasks,G));
    for j=1:height(a)
        T=[T;table({id},{'Global'},a.Metric(j),a.Task(j),a.NPaired(j), ...
            a.MeanDelta(j),a.P_Wilcoxon(j),a.Q_FDR(j), ...
            'VariableNames',{'OmittedContext','Family','Metric','Task','NPaired','MeanDelta','P_Wilcoxon','Q_WithinFamily'})]; %#ok<AGROW>
    end
    for j=1:height(b)
        T=[T;table({id},{'Edge'},b.Pair(j),b.Task(j),b.NPaired(j), ...
            b.MeanDelta(j),b.P_Wilcoxon(j),b.Q_FDR(j), ...
            'VariableNames',{'OmittedContext','Family','Metric','Task','NPaired','MeanDelta','P_Wilcoxon','Q_WithinFamily'})]; %#ok<AGROW>
    end
end
if isempty(T),return;end
key=unique(T(:,{'Family','Metric','Task'}),'rows','stable');
for j=1:height(key)
    z=T(strcmp(T.Family,key.Family{j})&strcmp(T.Metric,key.Metric{j})&strcmp(T.Task,key.Task{j}),:);
    d=z.MeanDelta; q=z.Q_WithinFamily;
    S=[S;table(key.Family(j),key.Metric(j),key.Task(j),height(z), ...
        min(z.NPaired),min(d),max(d),min(q),max(q), ...
        sum(q<.05),sum(d>0),sum(d<0), ...
        'VariableNames',{'Family','Metric','Task','NExclusions','MinNPaired','MinMeanDelta','MaxMeanDelta','MinQ','MaxQ','NExclusionsQBelow05','NPositive','NNegative'})]; %#ok<AGROW>
end
end

function [T,S]=frontal14_dyad_influence(R,t0,tasks)
% Same-edge dyadic metric, one DYAD deleted per run; BH over six tasks.
T=table();S=table(); if isempty(R),return;end
ids=unique(R.Dyad,'stable');
for i=1:numel(ids)
    id=ids{i}; RR=R(~strcmp(R.Dyad,id),:);
    ss=summarize_sensitivity_rows(RR,'DeltaNormalizedDistance','DyadLeaveOneOut');
    for j=1:height(ss)
        T=[T;table({id},ss.Task(j),ss.NPaired(j),ss.MeanDelta(j), ...
            ss.P_Wilcoxon(j),ss.Q_FDR(j), ...
            'VariableNames',{'OmittedDyad','Task','NPairedDyads','MeanDelta','P_Wilcoxon','Q_WithinMetric'})]; %#ok<AGROW>
    end
end
if isempty(T),return;end
ut=unique(T.Task,'stable');
for j=1:numel(ut)
    z=T(strcmp(T.Task,ut{j}),:);
    S=[S;table(ut(j),height(z),min(z.NPairedDyads),min(z.MeanDelta),max(z.MeanDelta), ...
        min(z.Q_WithinMetric),max(z.Q_WithinMetric),sum(z.Q_WithinMetric<.05), ...
        'VariableNames',{'Task','NExclusions','MinNPairedDyads','MinMeanDelta','MaxMeanDelta','MinQ','MaxQ','NExclusionsQBelow05'})]; %#ok<AGROW>
end
end

function T=frontal14_auditory_selection_qc(C,B,t0,tasks,G)
% Coverage is observational; no claim that missing channels are MCAR.
T=table(); if isempty(C),return;end
ids=unique(B.Subject,'stable'); a=G{1};
for i=1:numel(ids)
    id=ids{i}; c=C(strcmp(C.Subject,id)&strcmp(C.EEGGroup,a),:);
    b=B(strcmp(B.Subject,id)&strcmp(B.Task,t0),:);
    restCS=NaN;if ~isempty(b)&&ismember('MeanAbsBrainCS',B.Properties.VariableNames)
        restCS=mean(b.MeanAbsBrainCS,'omitnan');end
    for j=1:numel(tasks)
        tk=tasks{j}; q=c(strcmp(c.Task,tk),:);
        if isempty(q),continue;end
        included=any(q.Included);
        T=[T;table({id},{tk},logical(included),restCS, ...
            'VariableNames',{'Subject','Task','AuditoryIncluded','RestGlobalAbsCS'})]; %#ok<AGROW>
    end
end
end

function frontal14_plot_context_influence(S)
setappdata(gcf,'KM_CoherentQCStyle',true);
% Plot all four primary edges and two global task effects; full data in CSV.
if isempty(S),axis off;return;end
pairs={'Auditory--Sensorimotor','Auditory--Parietal', ...
    'Frontal-Executive--Parietal','Sensorimotor--Parietal', ...
    'GlobalAbsCS','GlobalAbsCS'};
tasks={'T01','T01','T02','T02','T02','T05'};
labels={'Coord A-M','Coord A-P','C&R F-P','C&R M-P','C&R global','Imp global'};
hold on;box on;grid on;xline(0,'k--');
for j=1:numel(pairs)
    z=S(strcmp(S.Metric,pairs{j})&strcmp(S.Task,tasks{j}),:);
    if isempty(z),continue;end
    plot([z.MinMeanDelta(1) z.MaxMeanDelta(1)],[j j],'-o','LineWidth',2);
    text(z.MaxMeanDelta(1),j,sprintf('  %d/%d%s',z.NExclusionsQBelow05(1),z.NExclusions(1), ...
        frontal14_significance_star(z.NExclusionsQBelow05(1)==z.NExclusions(1))), ...
        'FontSize',16,'FontWeight','bold','VerticalAlignment','middle');
end
set(gca,'YTick',1:numel(labels),'YTickLabel',labels,'YDir','reverse');
% A blank row at either end and space for right-hand audit annotations.
ylim(gca,[0 numel(labels)+1]);
xl=xlim(gca);xlim(gca,[min(0,xl(1)) xl(2)+.15*max(eps,diff(xl))]);
xlabel('Mean change after deleting any ONE context');
title('Influence audit (not identity-specific repeated-musician test)');
end

function frontal14_plot_dyad_influence(T,task)
setappdata(gcf,'KM_CoherentQCStyle',true);
if isempty(T),axis off;return;end
q=T(strcmp(T.Task,task),:);if isempty(q),axis off;return;end
hold on;box on;grid on;yline(0,'k--');
bar(1:height(q),q.MeanDelta);set(gca,'XTick',1:height(q),'XTickLabel',q.OmittedDyad);
xtickangle(35);ylabel('Mean change in same-edge dyadic distance');
title('C&R dyadic convergence: delete each dyad in turn');
for i=1:height(q)
 text(i,q.MeanDelta(i),sprintf('q=%.3g; n=%d%s',q.Q_WithinMetric(i),q.NPairedDyads(i), ...
       frontal14_significance_star(q.Q_WithinMetric(i)<.05)), ...
     'Rotation',90,'HorizontalAlignment','left','FontSize',10);
end
end

function frontal14_plot_auditory_selection(T)
setappdata(gcf,'KM_CoherentQCStyle',true);
if isempty(T),axis off;return;end
ss=unique(T.Subject,'stable'); tt=unique(T.Task,'stable');M=nan(numel(ss),numel(tt));
for i=1:numel(ss)
 for j=1:numel(tt)
  q=T(strcmp(T.Subject,ss{i})&strcmp(T.Task,tt{j}),:);
  if ~isempty(q),M(i,j)=double(q.AuditoryIncluded(1));end
 end
end
imagesc(M,[0 1]);colormap(parula);colorbar;
set(gca,'XTick',1:numel(tt),'XTickLabel',task_display_labels(tt), ...
 'YTick',1:numel(ss),'YTickLabel',strrep(ss,'_','-'),'TickLabelInterpreter','none');
set(gca,'YLim',[.5 numel(ss)+.5]);
xlabel('Condition');ylabel('Participant-dyad context');
title('Auditory inclusion: 1 usable, 0 unusable, blank missing condition');
end


function label=frontal14_short_metric(metric)
% Consistent manuscript notation: A, F, M, V, and hyphenated edges.
switch char(metric)
 case 'Auditory--Sensorimotor',label='A-M';
 case 'Auditory--Parietal',label='A-P';
 case 'Frontal-Executive--Parietal',label='F-P';
 case 'Sensorimotor--Parietal',label='M-P';
 case 'Auditory--Frontal-Executive',label='A-F';
 case 'Frontal-Executive--Sensorimotor',label='F-M';
 otherwise,label=strrep(char(metric),'--','-');
end
end

function frontal14_apply_coherent_qc_style(fig)
% Shared, absolute font sizes for reviewer-QC figures (Supplement pp.17+).
% Applied at every export, so PDF/JPG/TIFF remain visually consistent.
ax=findall(fig,'Type','axes');
compact=isappdata(fig,'KM_QCCompactYTicks') && getappdata(fig,'KM_QCCompactYTicks');
for k=1:numel(ax)
 try
  ax(k).FontName='Arial';ax(k).FontSize=14;ax(k).LineWidth=.8;
  ax(k).TickLabelInterpreter='none';
  if compact,ax(k).FontSize=getappdata(fig,'KM_QCCompactYFont');end
  ax(k).Title.FontName='Arial';ax(k).Title.FontSize=20;
  ax(k).Title.FontWeight='bold';
  ax(k).XLabel.FontName='Arial';ax(k).XLabel.FontSize=18;
  ax(k).YLabel.FontName='Arial';ax(k).YLabel.FontSize=18;
 catch
 end
end
% Match in-plot numerical labels across these figures. Do not shrink the
% coverage percentages or compact 48-row tick labels.
txt=findall(fig,'Type','text');
for k=1:numel(txt)
 try
  if any(arrayfun(@(a) isequal(txt(k),a.Title)||isequal(txt(k),a.XLabel)||isequal(txt(k),a.YLabel),ax))
   continue;
  end
  txt(k).FontName='Arial';
  if strcmp(strtrim(char(string(txt(k).String))),'*')
   txt(k).FontSize=22;txt(k).FontWeight='bold';continue;
  end
  if contains(string(txt(k).String),'%') && ~compact
   txt(k).FontSize=16;
  elseif compact
   txt(k).FontSize=14; % annotations remain legible; only 48 y-ticks are tiny
  else
   txt(k).FontSize=16;
  end
 catch
 end
end
cb=findall(fig,'Type','colorbar');
for k=1:numel(cb),try,cb(k).FontName='Arial';cb(k).FontSize=12;catch,end,end
end

function out=frontal14_significance_star(isSig)
% Asterisk denotes FDR-adjusted q < 0.05; no star for nonsignificant tests.
if isSig,out=' *';else,out='';end
end


function music2_mdea_selftest(P,OUT)
% Smoke test calls ONLY corrected MDEA, without assuming reconstructed outputs.
fs=512; n=round(60*fs); t=(0:n-1)/fs;
rng(240924,'twister');
x=sin(2*pi*9*t)+0.2*randn(size(t));
[d,q]=musicCorrectedMDEAwindow(x,P,0);
assert(isfinite(d),'Corrected MDEA self-test: no finite slope for 60-s synthetic signal.');
assert(numel(q.events)==n,'Corrected MDEA diagnostic event count length invalid.');
fid=fopen(fullfile(OUT,'MDEA_SELFTEST.txt'),'w');
fprintf(fid,'PASS: user-supplied MDEAcorrected.m synthetic 60-s numerical smoke test\n');
fprintf(fid,'MDEAcorrected(EEGwindow,%.2f,1,0.2,0.8,0); slope %.8g; genuine events %d\n',P.StripeWidth,d,q.NumEvents);
fprintf(fid,'Fit R2 from MDEAcorrected Info: %.8g; genuine stripe-transition events: %d\n',q.R2,q.NumEvents);
fprintf(fid,'NOTE: this 60-s test does NOT validate shorter 3.2/6.4/9.6-s geometry windows.\n');
fclose(fid);
end

%% PRE-REGISTERED WINDOW / OVERLAP SENSITIVITY DIAGNOSTIC
function music2_window_overlap_sweep(files,P,OUT)
% Pilot-only robustness study; NEVER optimizes the task significance of CS.
% Uses contiguous windows in a centered pilot segment for valid temporal QC.
% Earlier evenly-spaced subsampling invalidated lag-1 and step-change metrics.
% All primary estimates call corrected MDEA with the SAME (0.18,1,0.2,0.8,0) parameters.
% Event and entropy fit QC assess numerical stability, not physiological truth.
D=fullfile(OUT,'WINDOW_OVERLAP_SENSITIVITY'); if ~isfolder(D),mkdir(D);end
rng(P.SweepSeed,'twister');
fileIDs=music2_sweep_pick_files(files,P.SweepMaxFiles);
rows=cell(0,20); traces=struct([]); itr=0;
N=numel(fileIDs)*numel(P.SweepWindowSeconds)*numel(P.SweepOverlaps);
h=waitbar(0,'Window/overlap sensitivity','Name','Music2 MDEA sensitivity');
cleanup=onCleanup(@()closeWaitbar(h)); tic0=tic; done=0;
for f=1:numel(fileIDs)
 k=fileIDs(f); fn=fullfile(files(k).folder,files(k).name);
 try
  [data,fs,~,loc,~]=read_set_file(fn);
  if size(data,3)~=1,error('Epoched file; expected continuous EEG');end
  labels=string({loc.labels}); labels=labels(:);
  picks=nan(1,numel(P.SweepChannels));
  for c=1:numel(picks),z=find(strcmpi(labels,P.SweepChannels{c}),1);if ~isempty(z),picks(c)=z;end,end
  if sum(isfinite(picks))<3,error('Fewer than three pilot channels present');end
  fprintf('SENSITIVITY: %s, %d pilot channels, fs=%g\n',files(k).name,sum(isfinite(picks)),fs);
  for wi=1:numel(P.SweepWindowSeconds)
   for oi=1:numel(P.SweepOverlaps)
    winS=P.SweepWindowSeconds(wi); ov=P.SweepOverlaps(oi);
    nwin=round(winS*fs); step=max(1,round(nwin*(1-ov)));
    if size(data,2)<nwin,continue;end
    starts=1:step:(size(data,2)-nwin+1);
    % Retain CONSECUTIVE windows; nonadjacent subsampling corrupts lag-1
    % correlation, delta step-change, and circular-shift exclusion logic.
    % Use a centered segment of the same recording for all geometries.
    % Fixed common ~180-s midpoint segment; geometry changes number of points,
    % not the physical interval being examined. MaxWindows is no longer used.
    fullMid=(size(data,2)-1)/(2*fs);
    commonHalf=min(90,(size(data,2)/fs-P.SweepWindowSeconds(end))/2);
    allCenters=((starts-1)+(nwin-1)/2)/fs;
    starts=starts(abs(allCenters-fullMid)<=commonHalf);
    if numel(starts)<8,continue;end % insufficient consecutive windows for this pilot geometry
    centers=((starts-1)+(nwin-1)/2)/fs;
    dv=nan(numel(starts),numel(picks)); rv=dv; ev=dv;
    for c=1:numel(picks)
     if ~isfinite(picks(c)),continue;end
     x=double(data(picks(c),:,1));
     for z=1:numel(starts)
      [dv(z,c),q]=musicCorrectedMDEAwindow(x(starts(z):starts(z)+nwin-1),P);
      rv(z,c)=q.R2; ev(z,c)=q.NumEvents;
     end
    end
    for c=1:numel(picks)
     if ~isfinite(picks(c)),continue;end
     v=dv(:,c); good=isfinite(v); g=v(good);
     if numel(g)>2 && std(g)>0
      ac=music2_sweep_corr(g(1:end-1),g(2:end));
     else,ac=NaN;end
     if isfinite(ac), neff=numel(g)*(1-ac)/(1+ac);neff=min(numel(g),max(1,neff));
     else,neff=NaN;end
     % adjacent-window autocorrelation is not the same as statistical independence.
     % These are adjacent overlapping/nonoverlapping windows; report actual center gap.
     rows(end+1,:)={string(files(k).name),string(P.SweepChannels{c}),winS,ov,nwin,step, ...
      numel(starts),sum(good),mean(good),music2_sweep_mean(g),music2_sweep_std(g), ...
      music2_sweep_mean(rv(:,c)),music2_sweep_mean(ev(:,c)), ...
      music2_sweep_mean(ev(:,c))/winS,ac,neff, ...
      music2_sweep_mean(diff(centers)),music2_sweep_mean(abs(diff(g))), ...
      sum(g<0 | g>2),sum(rv(:,c)<.90 & isfinite(rv(:,c)))}; %#ok<AGROW>
    end
    % CS network fingerprint from the 4 scalp representatives; this is NOT
    % the manuscript's multi-electrode group-level CS network.
    itr=itr+1; traces(itr).File=string(files(k).name);
    traces(itr).WindowSeconds=winS;traces(itr).Overlap=ov;
    traces(itr).TimeSeconds=centers(:);traces(itr).Delta=dv;
    traces(itr).Labels=string(P.SweepChannels);
    traces(itr).CS=nan(4);traces(itr).SurrogateP=nan(4);
    for a=1:3
     for b=a+1:4
      aa=dv(:,a);bb=dv(:,b);ok=isfinite(aa)&isfinite(bb);
      aa=aa(ok);bb=bb(ok);
      if numel(aa)<12 || std(aa)==0 || std(bb)==0,continue;end
      rho=music2_sweep_spearman(aa,bb);
      traces(itr).CS(a,b)=rho;traces(itr).CS(b,a)=rho;
      if numel(aa)>=16
       null=nan(P.SweepNSurrogates,1);
       % shifts of >= max(3, ceil(window/median center gap)) samples
       minShift=max(3,ceil(winS/max(eps,music2_sweep_mean(diff(centers)))));
       allowed=minShift:(numel(bb)-minShift);
       if ~isempty(allowed)
        for q=1:numel(null)
         shift=allowed(randi(numel(allowed)));
         null(q)=abs(music2_sweep_spearman(aa,circshift(bb,shift)));
        end
        pval=(1+sum(null>=abs(rho)))/(numel(null)+1);
        traces(itr).SurrogateP(a,b)=pval;traces(itr).SurrogateP(b,a)=pval;
       end
      end
     end
    end
    done=done+1; elapsed=toc(tic0);eta=elapsed/max(done,1)*(N-done);
    if isgraphics(h),waitbar(done/N,h,sprintf('Sensitivity %d/%d | %.1f min elapsed | %.1f min ETA',done,N,elapsed/60,eta/60));end
   end
  end
 catch ME
  fprintf(2,'SENSITIVITY FILE FAILED: %s : %s\n',files(k).name,ME.message);
 end
end
if isempty(rows),error('Sensitivity sweep produced no valid estimates.');end
T=cell2table(rows,'VariableNames',{'File','Channel','WindowSeconds','Overlap', ...
 'WindowSamples','StepSamples','NWindows','NFinite','FiniteFraction', ...
 'MeanDelta','SDDelta','MeanFitR2','MeanEvents','EventsPerSecond', ...
 'Lag1DeltaCorrelation','ApproxNeff','MeanCenterGapSeconds','MeanAbsStepDelta', ...
 'DeltaOutsideZeroTwo','FitsBelowR2_090'});
writetable(T,fullfile(D,'CHANNEL_WINDOW_QC.csv'));
S=table(); ix=0;
for w=P.SweepWindowSeconds
 for o=P.SweepOverlaps
  sub=T(T.WindowSeconds==w & T.Overlap==o,:);
  ix=ix+1; S.WindowSeconds(ix,1)=w;S.Overlap(ix,1)=o;
  S.NChannelFiles(ix,1)=height(sub);
  S.MeanFiniteFraction(ix,1)=music2_sweep_mean(sub.FiniteFraction);
  S.MeanFitR2(ix,1)=music2_sweep_mean(sub.MeanFitR2);
  S.MedianDelta(ix,1)=music2_sweep_median(sub.MeanDelta);
  S.MeanWithinRecordingDeltaSD(ix,1)=music2_sweep_mean(sub.SDDelta);
  S.MeanEventsPerSecond(ix,1)=music2_sweep_mean(sub.EventsPerSecond);
  S.MeanLag1Correlation(ix,1)=music2_sweep_mean(sub.Lag1DeltaCorrelation);
  S.MeanApproxNeff(ix,1)=music2_sweep_mean(sub.ApproxNeff);
  S.MeanCenterGapSeconds(ix,1)=music2_sweep_mean(sub.MeanCenterGapSeconds);
 end
end
writetable(S,fullfile(D,'GEOMETRY_SUMMARY.csv'));
% Preallocate the representative-channel CS table in one operation.
% This avoids MATLAB's warning about extending a table one variable at a time
% (which temporarily creates new rows without values for all existing variables).
nPairs=nchoosek(4,2);
nRows=numel(traces)*nPairs;
File=strings(nRows,1); WindowSeconds=nan(nRows,1); Overlap=nan(nRows,1);
NodeA=strings(nRows,1); NodeB=strings(nRows,1);
SpearmanDeltaCS=nan(nRows,1); CircularShiftP_Exploratory=nan(nRows,1);
cr=0;
for z=1:numel(traces)
 for a=1:3
  for b=a+1:4
   cr=cr+1;
   File(cr)=traces(z).File;
   WindowSeconds(cr)=traces(z).WindowSeconds;
   Overlap(cr)=traces(z).Overlap;
   NodeA(cr)=traces(z).Labels(a);
   NodeB(cr)=traces(z).Labels(b);
   SpearmanDeltaCS(cr)=traces(z).CS(a,b);
   CircularShiftP_Exploratory(cr)=traces(z).SurrogateP(a,b);
  end
 end
end
C=table(File,WindowSeconds,Overlap,NodeA,NodeB,SpearmanDeltaCS,CircularShiftP_Exploratory);
writetable(C,fullfile(D,'REPRESENTATIVE_CHANNEL_CS.csv'));
save(fullfile(D,'SWEEP_RAW.mat'),'P','T','S','C','traces','fileIDs','-v7.3');
% Main diagnostic: each point = a channel-recording, no optimization score.
f=figure('Visible','off','Color','w','Position',[100 100 1400 850]);
tiledlayout(2,2,'Padding','compact');
metrics={'FiniteFraction','MeanFitR2','SDDelta','ApproxNeff'};
labels={'Fraction finite delta','Mean entropy-fit R^2','Within-recording SD(delta)', ...
 'Approximate N effective (sampled series)'};
for m=1:4
 nexttile;hold on;
 for w=P.SweepWindowSeconds
  q=T(T.WindowSeconds==w,:);
  xx=q.Overlap+(w/9.6-0.5)*.055;
  plot(xx,q.(metrics{m}),'.','MarkerSize',11);
  s=S(S.WindowSeconds==w,:);
  plot(s.Overlap,s.(music2_sweep_summary_field(metrics{m})),'-o','LineWidth',1.5, ...
   'DisplayName',sprintf('%g s',w));
 end
 xlabel('Window overlap');ylabel(labels{m});grid on;xticks(P.SweepOverlaps);
 if m==1,legend('Location','best');end
end
sgtitle('MDEA geometry sensitivity: numerical quality and temporal dependence');
music2_sweep_export(f,D,'01_QC_vs_window_overlap');close(f);
% Matched example trajectories for same file/channel across 9 geometries.
if ~isempty(traces)
 f=figure('Visible','off','Color','w','Position',[100 100 1500 1100]);
 tl=tiledlayout(3,3,'Padding','compact','TileSpacing','compact');
 first=traces(1).File;
 for wi=1:3
  for oi=1:3
   nexttile; idx=find([traces.WindowSeconds]==P.SweepWindowSeconds(wi) & ...
     [traces.Overlap]==P.SweepOverlaps(oi) & string({traces.File})==first,1);
   if isempty(idx),continue;end
   plot(traces(idx).TimeSeconds,traces(idx).Delta(:,2),'k.-');grid on;
   xlabel('Time (s)');ylabel('delta');
   title(sprintf('%g s / %.0f%% overlap',P.SweepWindowSeconds(wi),100*P.SweepOverlaps(oi)));
  end
 end
 linkaxes(findall(f,'Type','axes'),'x');
 title(tl,['Same EEG file / F3, different window geometries: ' char(first)],'Interpreter','none');
 music2_sweep_export(f,D,'02_MATCHED_TRAJECTORIES');close(f);
end
% Representative-channel network matrices across geometries (descriptive).
if ~isempty(traces)
 f=figure('Visible','off','Color','w','Position',[100 100 1500 1050]);
 tl=tiledlayout(3,3,'Padding','compact','TileSpacing','compact');
 first=traces(1).File;
 for wi=1:3
  for oi=1:3
   nexttile; idx=find([traces.WindowSeconds]==P.SweepWindowSeconds(wi) & ...
     [traces.Overlap]==P.SweepOverlaps(oi) & string({traces.File})==first,1);
   if isempty(idx),continue;end
   imagesc(abs(traces(idx).CS),[0 1]);axis square;
   xticks(1:4);yticks(1:4);xticklabels(P.SweepChannels);yticklabels(P.SweepChannels);
   title(sprintf('%g s / %.0f%%',P.SweepWindowSeconds(wi),100*P.SweepOverlaps(oi)));
  end
 end
 title(tl,['Representative-electrode |CS| sensitivity: ' char(first)],'Interpreter','none');
 colorbar;music2_sweep_export(f,D,'03_REPRESENTATIVE_CS_MAPS');close(f);
end
fid=fopen(fullfile(D,'INTERPRETATION_AND_LIMITATIONS.txt'),'w');
fprintf(fid,['EXPLORATORY PARAMETER ROBUSTNESS, NOT PARAMETER OPTIMIZATION.\n' ...
 'Primary geometry is 6.4 s / 50%%; all nine geometries are explored for sensitivity.\n' ...
 'Sensitivity: 3.2/6.4/9.6 s x 0/50/75%% overlap; up to %d recordings, centered common physical interval (max-window setting unused).\n' ...
 'Pilot channels: FT7 F3 C3 O1; NOT the full Frontal14 group averages.\n' ...
 'Windows in this pilot are consecutive and drawn from the recording midpoint.\n' ...
 'The CS maps here are representative-electrode diagnostics, NOT the published group-level networks.\n' ...
 'An R2 near one does not prove physiological origin; overlap can inflate apparent smoothness.\n' ...
 'Pilot results cannot establish best window size for all 118 recordings or all music tasks.\n' ...
 'Lag-1 correlation and N_eff are heuristic, not formal independence tests.\n' ...
 'Surrogate p-values are exploratory circular shifts; do not use them to choose a favorable geometry.\n' ...
 'Delta values are NOT expected to be statistically independent across overlapped windows.\n' ...
 'To support physiology, also inspect artifacts, spectral confounds, test-retest and task replication.\n' ...
 'Corrected MDEA stripe/fit/preprocessing settings remain UNVERIFIED.\n'], ...
 P.SweepMaxFiles);
fclose(fid);
fprintf('Sensitivity reports and PDF/JPG figures: %s\n',D);
end
function ids=music2_sweep_pick_files(files,n)
% Prefer Rest, coordinated rhythm, C&R and a second Rest context.
names=string({files.name}); ids=[];
for task=[0 1 2 0]
 mask=contains(names,sprintf('_T%02d_',task)); candidates=find(mask);
 candidates=candidates(~ismember(candidates,ids));
 if ~isempty(candidates),ids(end+1)=candidates(1);end %#ok<AGROW>
end
if numel(ids)<n
 for k=1:numel(files)
  if ~ismember(k,ids),ids(end+1)=k;end %#ok<AGROW>
  if numel(ids)>=n,break;end
 end
end
ids=ids(1:min(n,numel(ids)));
end
function v=music2_sweep_mean(x)
x=x(isfinite(x));if isempty(x),v=NaN;else,v=mean(x);end
end
function v=music2_sweep_median(x)
x=x(isfinite(x));if isempty(x),v=NaN;else,v=median(x);end
end
function v=music2_sweep_std(x)
x=x(isfinite(x));if numel(x)<2,v=NaN;else,v=std(x);end
end
function v=music2_sweep_corr(x,y)
x=x(:);y=y(:);good=isfinite(x)&isfinite(y);x=x(good);y=y(good);
if numel(x)<3||std(x)==0||std(y)==0,v=NaN;else,q=corrcoef(x,y);v=q(1,2);end
end
function v=music2_sweep_spearman(x,y)
x=x(:);y=y(:);good=isfinite(x)&isfinite(y);x=x(good);y=y(good);
if numel(x)<3||std(x)==0||std(y)==0,v=NaN;return;end
v=music2_sweep_corr(tiedrank(x),tiedrank(y));
end
function field=music2_sweep_summary_field(metric)
switch metric
 case 'FiniteFraction',field='MeanFiniteFraction';
 case 'MeanFitR2',field='MeanFitR2';
 case 'SDDelta',field='MeanWithinRecordingDeltaSD';
 case 'ApproxNeff',field='MeanApproxNeff';
end
end
function music2_sweep_export(f,D,name)
exportgraphics(f,fullfile(D,[name '.pdf']),'ContentType','vector');
exportgraphics(f,fullfile(D,[name '.jpg']),'Resolution',300);
end


%% ===== FULL-COHORT CS GEOMETRY ROBUSTNESS (9 GEOMETRIES; 5 MUSIC-FUNCTIONAL GROUPS) =====
function music2_full_cohort_robustness(files,P,OUT,reportPDF,mainPDF)
% FULL-COHORT ROBUSTNESS, failure-tolerant edition.
if nargin<5,mainPDF='';end
% Important design choice: a failure in ONE surrogate/geometry must not discard
% an otherwise valid recording.  All failures are written to diagnostic logs.
D=fullfile(OUT,'FULL_COHORT_ROBUSTNESS');if ~isfolder(D),mkdir(D);end
names={'Auditory','Frontal-Executive','Sensorimotor','Parietal','Occipital'};
montage={{'FT7','FT8','T7','T8','TP7','TP8'}, ...
 {'AF3','AF4','AF7','AF8','AFz','F1','F2','F3','F4','F5','F6','F7','F8','Fz'}, ...
 {'FC1','FC2','FC3','FC4','C1','C2','C3','C4','C5','C6','Cz'}, ...
 {'CP1','CP2','CP3','CP4','P1','P2','P3','P4','P5','P6','P7','P8','Pz'}, ...
 {'PO3','PO4','PO7','PO8','O1','O2','Oz'}};
edgeI=[1 1 1 1 2 2 2 3 3 4];
edgeJ=[2 3 4 5 3 4 5 4 5 5];
edgeNames={'A-F','A-M','A-P','A-O','F-M','F-P','F-O','M-P','M-O','P-O'};
nGroups=numel(names); nEdges=numel(edgeNames);
geom=zeros(numel(P.SweepWindowSeconds)*numel(P.SweepOverlaps),2);k=0;
for w=P.SweepWindowSeconds,for o=P.SweepOverlaps
 k=k+1;geom(k,:)=[w o];
end,end
n=numel(files);results=cell(n,1);errs=cell(n,1);geomErrs=cell(n,1);
q=parallel.pool.DataQueue; t0=tic;h=waitbar(0,'Full-cohort robustness','Name','Music CS robustness');
cleanup=onCleanup(@()closeWaitbar(h)); %#ok<NASGU>
count=0;afterEach(q,@progress);
parfor fi=1:n
 localRows=cell(size(geom,1),1); localGeomErrs={};
 try
  fn=fullfile(files(fi).folder,files(fi).name);
  [data,fs,~,loc,~]=read_set_file(fn);
  assert(size(data,3)==1,'Expected continuous EEG');
  lab=string({loc.labels});lab=lab(:);nS=size(data,2);
  tok=regexp(files(fi).name,'^D(\d+)_B(\d+)_T(\d+)_','tokens','once','ignorecase');
  assert(~isempty(tok),'Cannot parse dyad/participant/task from %s',files(fi).name);
  dyad=str2double(tok{1});person=str2double(tok{2});task=str2double(tok{3});

  for gi=1:size(geom,1)
   try
    ws=geom(gi,1);ov=geom(gi,2);nw=round(ws*fs);step=max(1,round(nw*(1-ov)));
    if nS<nw
     localGeomErrs{end+1}=sprintf('%s | %g s / %g%%: recording shorter than window',files(fi).name,ws,100*ov); %#ok<AGROW>
     continue;
    end
    starts=1:step:(nS-nw+1);nwin=numel(starts);
    if nwin<P.RobustMinSamples
     localGeomErrs{end+1}=sprintf('%s | %g s / %g%%: only %d windows (<%d)',files(fi).name,ws,100*ov,nwin,P.RobustMinSamples); %#ok<AGROW>
     continue;
    end

    delta=nan(nwin,nGroups);nchan=zeros(1,nGroups);finitefrac=nan(1,nGroups);fitR2=nan(1,nGroups);meanEvents=nan(1,nGroups);deltaSD=nan(1,nGroups);
    ordinaryEEG=nan(1,nEdges);rawGroups=nan(nGroups,nS); temporalHFLogPower=NaN;
    nBands=size(P.PLVBands,1);
    plvEEG=nan(nEdges,nBands);
    % Columns: [coherence, absolute imaginary coherence, debiased wPLI].
    spectralEEG=nan(nEdges,3);
    for g=1:nGroups
     % strcmpi is intentionally used here instead of string/lower membership;
     % it is robust to char/string channel-label representations.
     idx=[];
     for cc=1:numel(montage{g})
      hit=find(strcmpi(cellstr(lab),montage{g}{cc}),1);
      if ~isempty(hit),idx(end+1)=hit;end %#ok<AGROW>
     end
     idx=unique(idx,'stable');
     nchan(g)=numel(idx);req=max(2,ceil(.30*numel(montage{g})));
     if numel(idx)<req,continue;end
     vals=nan(nwin,numel(idx));fits=nan(nwin,numel(idx));events=nan(nwin,numel(idx));
     for c=1:numel(idx)
      x=double(data(idx(c),:,1));
      for wi=1:nwin
       [vals(wi,c),diag]=musicCorrectedMDEAwindow(x(starts(wi):starts(wi)+nw-1),P);
       fits(wi,c)=diag.R2; events(wi,c)=diag.NumEvents; % genuine MDEA diagnostics
      end
     end
     delta(:,g)=mean(vals,2,'omitnan');
     % Store group-average continuous EEG for window-matched raw Pearson below.
     rawGroups(g,:)=mean(double(data(idx,:,1)),1,'omitnan');
     finitefrac(g)=mean(isfinite(vals(:)));
     fitR2(g)=mean(fits(:),'omitnan');meanEvents(g)=mean(events(:),'omitnan');
     deltaSD(g)=std(delta(:,g),'omitnan');
    end

    % Temporal high-frequency EEG power proxy (NOT measured EMG).
    % Use the cleaned Auditory/Temporal regional signal (group 1) and compute
    % 30-45 Hz log10 power over the full recording. The same recording-level
    % value is attached to every edge row below so A-* task-minus-reference
    % contrasts can test whether temporal HF changes track CS changes.
    xt=rawGroups(1,:);
    okt=isfinite(xt);
    if sum(okt)>=max(100,round(2*fs)) && fs>2*45 && std(xt(okt))>0
     try
      % Fill any rare nonfinite samples before zero-phase filtering.
      if any(~okt),xt=fillmissing(xt,'linear','EndValues','nearest');end
      [bhf,ahf]=butter(4,[30 45]/(fs/2),'bandpass');
      xhf=filtfilt(bhf,ahf,double(xt));
      temporalHFLogPower=10*log10(mean(xhf.^2,'omitnan')+eps);
     catch MEhf
      temporalHFLogPower=NaN;
      localGeomErrs{end+1}=sprintf('%s | %g s / %g%% | temporal HF proxy: %s', ...
       files(fi).name,ws,100*ov,MEhf.message); %#ok<AGROW>
     end
    end

    rho=nan(1,nEdges);pval=nan(1,nEdges);nullMean=nan(1,nEdges);null95=nan(1,nEdges);
    % Geometry-matched conventional comparator: calculate raw-EEG Pearson
    % within the SAME physical windows as MDEA; Fisher-z average across
    % windows, rather than a geometry-invariant full-recording correlation.
    for e0=1:nEdges
     a=rawGroups(edgeI(e0),:);b=rawGroups(edgeJ(e0),:);
     rw=nan(nwin,1);
     for jj=1:nwin
      ii=starts(jj):starts(jj)+nw-1;
      xx=a(ii);yy=b(ii);okraw=isfinite(xx)&isfinite(yy);
      if sum(okraw)>=20 && std(xx(okraw))>0 && std(yy(okraw))>0
       rw(jj)=corr(xx(okraw)',yy(okraw)','Type','Pearson');
      end
     end
     rw=rw(isfinite(rw));
     if ~isempty(rw)
      ordinaryEEG(e0)=tanh(mean(atanh(max(-1+1e-10,min(1-1e-10,rw)))));
     end
    end
    % Frequency-specific conventional phase synchronization (PLV).
    % For direct comparability, PLV uses the same five regional EEG signals
    % and exactly the same physical windows as this MDEA geometry. Each
    % regional signal is band-pass filtered over the full recording, Hilbert
    % phase is extracted, PLV is calculated within each window, and window
    % PLVs are averaged for the recording/edge/geometry.
    if P.RunPLVComparison
     for bb=1:nBands
      lo=P.PLVBands(bb,1); hi=P.PLVBands(bb,2);
      if hi >= fs/2
       localGeomErrs{end+1}=sprintf('%s | PLV %s skipped: upper band %.3g Hz >= Nyquist %.3g Hz', ...
        files(fi).name,P.PLVBandNames{bb},hi,fs/2); %#ok<AGROW>
       continue;
      end
      try
       [bf,af]=butter(P.PLVFilterOrder,[lo hi]/(fs/2),'bandpass');
       phase=nan(nGroups,nS);
       for gg=1:nGroups
        xx=rawGroups(gg,:);
        if all(isfinite(xx)) && std(xx)>0
         xf=filtfilt(bf,af,double(xx));
         phase(gg,:)=angle(hilbert(xf));
        end
       end
       for e0=1:nEdges
        pa=phase(edgeI(e0),:); pb=phase(edgeJ(e0),:);
        pw=nan(nwin,1);
        for jj=1:nwin
         ii=starts(jj):starts(jj)+nw-1;
         dphi=pa(ii)-pb(ii); dphi=dphi(isfinite(dphi));
         if numel(dphi)>=20
          pw(jj)=abs(mean(exp(1i*dphi)));
         end
        end
        plvEEG(e0,bb)=mean(pw,'omitnan');
       end
      catch MEplv
       localGeomErrs{end+1}=sprintf('%s | %g s / %g%% | PLV %s: %s', ...
        files(fi).name,ws,100*ov,P.PLVBandNames{bb},MEplv.message); %#ok<AGROW>
      end
     end
    end

    % Supplementary conventional spectral-connectivity controls from the
    % earlier benchmark.  They are intentionally evaluated only at the old
    % benchmark geometry (9.6 s / 75% overlap) so the method is unchanged.
    if P.RunSpectralComparators && ...
       abs(ws-P.SpectralWindowSeconds)<1e-9 && abs(ov-P.SpectralWindowOverlap)<1e-12
     for e0=1:nEdges
      a=rawGroups(edgeI(e0),:); b=rawGroups(edgeJ(e0),:);
      cw=nan(nwin,1); iw=nan(nwin,1); ww=nan(nwin,1);
      for jj=1:nwin
       ii=starts(jj):starts(jj)+nw-1;
       try
        [cw(jj),iw(jj),ww(jj)]=music2_spectral_pair_local( ...
         a(ii),b(ii),fs,P.SpectralBandHz,P.SpectralSegmentSec, ...
         P.SpectralSegmentOverlap,P.MinSpectralSegments);
       catch MEspec
        localGeomErrs{end+1}=sprintf('%s | %g s / %g%% | %s spectral comparator: %s', ...
         files(fi).name,ws,100*ov,edgeNames{e0},MEspec.message); %#ok<AGROW>
       end
      end
      spectralEEG(e0,1)=mean(cw,'omitnan');
      spectralEEG(e0,2)=mean(iw,'omitnan');
      spectralEEG(e0,3)=mean(ww,'omitnan');
     end
    end

    for e=1:nEdges
     x=delta(:,edgeI(e));y=delta(:,edgeJ(e));
     ok=isfinite(x)&isfinite(y);x=x(ok);y=y(ok);
     if numel(x)<P.RobustMinSamples || std(x)==0 || std(y)==0,continue;end
     rho(e)=music2_sweep_spearman(x,y);

     % Surrogate failure must NOT erase the observed CS estimate.
     try
      minshift=max(3,ceil(P.RobustMinShiftSeconds/(step/fs)));
      % Circular shift k and N-k are both near-zero alignments when k is near
      % either endpoint.  Restrict shifts to [minshift, N-minshift].
      allowed=minshift:(numel(x)-minshift);
      if numel(allowed)>=1 && P.RobustNSurrogates>0
       rs=RandStream('mt19937ar','Seed',P.RobustSeed+fi*100003+gi*1009+e);
       drawIdx=randperm(rs,numel(allowed),min(numel(allowed),P.RobustNSurrogates));
       shifts=allowed(drawIdx); % unique shifts: do not claim 2000 independent nulls if fewer exist
       null=nan(numel(shifts),1);
       for z=1:numel(shifts)
        null(z)=abs(music2_sweep_spearman(x,circshift(y,shifts(z))));
       end
       null=null(isfinite(null));
       if ~isempty(null)
        pval(e)=(1+sum(null>=abs(rho(e))))/(numel(null)+1);
        nullMean(e)=mean(null);
        null95(e)=prctile(null,95);
       end
      end
     catch MEshift
      localGeomErrs{end+1}=sprintf('%s | %g s / %g%% | %s surrogate: %s', ...
       files(fi).name,ws,100*ov,edgeNames{e},MEshift.message); %#ok<AGROW>
     end
    end

    localRows{gi}=struct('Dyad',dyad,'Musician',person,'Task',task,'File',string(files(fi).name), ...
     'WindowSeconds',ws,'Overlap',ov,'CS',rho,'P',pval,'NullMean',nullMean, ...
     'Null95',null95,'Channels',nchan,'FiniteFraction',finitefrac,'FitR2',fitR2, ...
     'NWindows',nwin,'WindowSamples',nw,'StepSamples',step,'StepSeconds',step/fs,'Fs',fs,'Delta',delta,'MeanEvents',meanEvents,'DeltaSD',deltaSD, ...
     'OrdinaryEEG',ordinaryEEG,'PLV',plvEEG,'Spectral',spectralEEG,'TemporalHFLogPower',temporalHFLogPower);
   catch MEg
    localGeomErrs{end+1}=sprintf('%s | geometry %d (%g s / %g%%): %s', ...
     files(fi).name,gi,geom(gi,1),100*geom(gi,2),getReport(MEg,'basic','hyperlinks','off')); %#ok<AGROW>
   end
  end
  results{fi}=localRows;
  geomErrs{fi}=localGeomErrs;
 catch ME
  errs{fi}=sprintf('%s: %s',files(fi).name,getReport(ME,'extended','hyperlinks','off'));
 end
 send(q,fi);
end

% Always write diagnostics before deciding whether enough results exist.
fileErrMask=~cellfun(@isempty,errs);
allGeomErrs={};
for ii=1:n
 if ~isempty(geomErrs{ii}),allGeomErrs=[allGeomErrs;geomErrs{ii}(:)];end %#ok<AGROW>
end
if any(fileErrMask)
 fid=fopen(fullfile(D,'FILE_LEVEL_ERRORS.txt'),'w');fprintf(fid,'%s\n',errs{fileErrMask});fclose(fid);
end
if ~isempty(allGeomErrs)
 fid=fopen(fullfile(D,'GEOMETRY_AND_SURROGATE_WARNINGS.txt'),'w');fprintf(fid,'%s\n',allGeomErrs{:});fclose(fid);
end

R=table();Q=table();
for fi=1:n
 if isempty(results{fi}),continue;end
 for gi=1:numel(results{fi})
  a=results{fi}{gi};if isempty(a),continue;end
  for e=1:nEdges
   rr=table(a.File,a.Dyad,a.Musician,a.Task,a.WindowSeconds,a.Overlap, ...
    string(edgeNames{e}),a.CS(e),abs(a.CS(e)),a.P(e),a.NullMean(e),a.Null95(e), ...
    a.NWindows,a.StepSeconds,a.Channels(edgeI(e)),a.Channels(edgeJ(e)),a.OrdinaryEEG(e),a.TemporalHFLogPower, ...
    'VariableNames',{'File','Dyad','Musician','Task','WindowSeconds','Overlap', ...
    'Edge','SignedCS','AbsCS','SurrogateP','NullMeanAbsCS','Null95AbsCS', ...
    'NWindows','StepSeconds','ChannelsA','ChannelsB','RawEEGPearson','TemporalHFLogPower'});
   R=[R;rr]; %#ok<AGROW>
  end
  for g=1:nGroups
   windowSamples=a.WindowSamples;
   eventFraction=a.MeanEvents(g)/max(windowSamples,1);
   qr=table(a.File,a.Task,a.WindowSeconds,a.Overlap,string(names{g}), ...
    a.Channels(g),a.FiniteFraction(g),a.FitR2(g),a.NWindows,a.MeanEvents(g), ...
    windowSamples,eventFraction,a.DeltaSD(g), ...
    'VariableNames',{'File','Task','WindowSeconds','Overlap','Group', ...
    'NChannels','FiniteFraction','MeanFitR2','NWindows','MeanEventsPerWindow', ...
    'WindowSamples','EventFraction','DeltaSD'});
   Q=[Q;qr]; %#ok<AGROW>
  end
 end
end

if isempty(R)
 fprintf(2,'\nFULL-COHORT ROBUSTNESS produced no rows. Diagnostic folder:\n%s\n',D);
 if any(fileErrMask)
  fprintf(2,'First file-level error:\n%s\n',errs{find(fileErrMask,1)});
 end
 if ~isempty(allGeomErrs)
  fprintf(2,'First geometry warning/error:\n%s\n',allGeomErrs{1});
 end
 error(['No full-cohort CS records produced. The revised code wrote the exact cause to ' ...
  'FILE_LEVEL_ERRORS.txt and/or GEOMETRY_AND_SURROGATE_WARNINGS.txt in %s'],D);
end

R.SurrogateQ=nan(height(R),1);
% Ten-edge FDR WITHIN each recording/geometry; missing/NaN edges excluded.
[~,~,ic]=unique(strcat(R.File,'|',string(R.WindowSeconds),'|',string(R.Overlap)));
for i=1:max(ic)
 idx=find(ic==i);R.SurrogateQ(idx)=music2_bh(R.SurrogateP(idx));
end
R.SurvivesShift=double(R.SurrogateQ<P.RobustAlpha);
R.SurvivesShift(~isfinite(R.SurrogateQ))=NaN; % unavailable is NOT a negative result
writetable(R,fullfile(D,'ALL_EDGES_ALL_GEOMETRIES.csv'));
writetable(Q,fullfile(D,'ALL_GROUP_QC.csv'));

% Explicit CS null-model summary: circularly shifted delta(t) preserves each
% trajectory's marginal/autocorrelation structure while disrupting alignment.
SNULL=music2_surrogate_null_summary(R,geom,edgeNames,P);
writetable(SNULL,fullfile(D,'CS_CIRCULAR_SHIFT_NULL_SUMMARY.csv'));

% Long-format PLV table: one row per file/geometry/edge/frequency band.
PLV=table();
if P.RunPLVComparison
 for fi=1:n
  if isempty(results{fi}),continue;end
  for gi=1:numel(results{fi})
   a=results{fi}{gi}; if isempty(a) || ~isfield(a,'PLV'),continue;end
   for e=1:nEdges
    for bb=1:numel(P.PLVBandNames)
     pr=table(a.File,a.Dyad,a.Musician,a.Task,a.WindowSeconds,a.Overlap, ...
      string(edgeNames{e}),string(P.PLVBandNames{bb}),P.PLVBands(bb,1),P.PLVBands(bb,2),a.PLV(e,bb), ...
      'VariableNames',{'File','Dyad','Musician','Task','WindowSeconds','Overlap', ...
      'Edge','Band','LowHz','HighHz','PLV'});
     PLV=[PLV;pr]; %#ok<AGROW>
    end
   end
  end
 end
 writetable(PLV,fullfile(D,'PLV_ALL_EDGES_ALL_GEOMETRIES.csv'));
end

% Long-format supplementary spectral connectivity table.  Only the preserved
% 9.6-s/75%-overlap benchmark geometry has finite values by design.
SPEC=table();
if P.RunSpectralComparators
 for fi=1:n
  if isempty(results{fi}),continue;end
  for gi=1:numel(results{fi})
   a=results{fi}{gi}; if isempty(a) || ~isfield(a,'Spectral'),continue;end
   if abs(a.WindowSeconds-P.SpectralWindowSeconds)>1e-9 || ...
      abs(a.Overlap-P.SpectralWindowOverlap)>1e-12, continue; end
   for e=1:nEdges
    sr=table(a.File,a.Dyad,a.Musician,a.Task,a.WindowSeconds,a.Overlap, ...
     string(edgeNames{e}),a.Spectral(e,1),a.Spectral(e,2),a.Spectral(e,3), ...
     'VariableNames',{'File','Dyad','Musician','Task','WindowSeconds','Overlap', ...
     'Edge','Coherence830','ImagCoherence830','DebiasedWPLI830'});
    SPEC=[SPEC;sr]; %#ok<AGROW>
   end
  end
 end
 writetable(SPEC,fullfile(D,'SPECTRAL_CONVENTIONAL_830_PRIMARY_GEOMETRY.csv'));
end
save(fullfile(D,'FULL_ROBUSTNESS.mat'),'R','Q','PLV','SPEC','SNULL','results','P','geom','errs','geomErrs','-v7.3');

% PRIMARY Rest-referenced matched comparisons on SIGNED CS.
% Scientific estimand: DeltaCS = CS(task) - CS(rest).
% No task inference in the paper is based on |CS(task)|-|CS(rest)|.
C=music2_signed_cs_task_contrasts(R,geom,edgeNames,0);
C.SignificanceStars = strings(height(C),1); % line style encodes significance
writetable(C,fullfile(D,'SIGNED_CS_MATCHED_TASK_VS_REST_BY_GEOMETRY.csv'));

% Reviewer control retained: explicit circular-shift null model for whether
% observed CS magnitude exceeds chance alignment.  Absolute rho is used only
% as the TWO-SIDED null statistic; task effects above remain signed DeltaCS.
save(fullfile(D,'PAPER_CS_CONTROLS.mat'),'SNULL','-v7.3');

% Geometry-level robustness summary: direction and significance consistency.
GR = music2_geometry_effect_summary(C,edgeNames);
writetable(GR,fullfile(D,'TASK_EFFECT_GEOMETRY_ROBUSTNESS_SUMMARY.csv'));

% Primary network-level question: do the TEN-edge CS fingerprints change as a
% vector across tasks? Paired musician-level sign-flip test; repeated musician
% contexts are averaged BEFORE inference. Test is two-sided and not selected
% according to which individual edges pass their own FDR threshold.
OM = music2_network_omnibus(R,geom,edgeNames,P);
writetable(OM,fullfile(D,'PAIRED_MUSICIAN_NETWORK_OMNIBUS.csv'));

% Conventional EEG comparator using the same matched Rest-vs-task design.
Craw = music2_raw_eeg_task_contrasts(R,geom,edgeNames);
writetable(Craw,fullfile(D,'RAW_EEG_MATCHED_TASK_VS_REST_BY_GEOMETRY.csv'));

% Frequency-specific PLV benchmark with the identical matched Rest-vs-task design.
Cplv=table();
if P.RunPLVComparison && ~isempty(PLV)
 Cplv=music2_plv_task_contrasts(PLV,geom,edgeNames,P.PLVBandNames);
 writetable(Cplv,fullfile(D,'PLV_MATCHED_TASK_VS_REST_BY_GEOMETRY.csv'));
end

% Supplementary 8-30 Hz coherence / imaginary coherence / debiased-wPLI
% benchmarks using the exact old 9.6-s/75%-overlap spectral recipe.
Cspectral=table();
if P.RunSpectralComparators && ~isempty(SPEC)
 Cspectral=music2_spectral_task_contrasts(SPEC,edgeNames,P);
 writetable(Cspectral,fullfile(D,'SPECTRAL_CONVENTIONAL_MATCHED_TASK_VS_REST.csv'));
end

% Symmetric cross-geometry agreement: all 36 unordered pairs, no anchor.
BP=table();
for g1=1:size(geom,1)
 for g2=g1+1:size(geom,1)
  a=R(R.WindowSeconds==geom(g1,1)&R.Overlap==geom(g1,2),:);
  b=R(R.WindowSeconds==geom(g2,1)&R.Overlap==geom(g2,2),:);
  ka=strcat(a.File,'|',a.Edge);kb=strcat(b.File,'|',b.Edge);
  [~,ia,ib]=intersect(ka,kb);x=a.AbsCS(ia);y=b.AbsCS(ib);
  good=isfinite(x)&isfinite(y);x=x(good);y=y(good);
  if numel(x)>=4,rc=music2_sweep_spearman(x,y);else,rc=NaN;end
  if isempty(x),mae=NaN;else,mae=mean(abs(x-y));end
  BP=[BP;table(geom(g1,1),geom(g1,2),geom(g2,1),geom(g2,2), ...
   numel(x),rc,mae,'VariableNames',{'WindowSeconds1','Overlap1', ...
   'WindowSeconds2','Overlap2','NMatchedEdges','SpearmanAgreement','MeanAbsWeightDifference'})]; %#ok<AGROW>
 end
end
% A stripe-sensitivity subrun intentionally contains only ONE geometry
% (6.4 s / 75% overlap).  In that case there are no cross-geometry pairs,
% so BP is empty and MATLAB would otherwise create it with no variable names.
% Give BP its schema explicitly so downstream code is valid for both the
% normal nine-geometry run and the one-geometry stripe subruns.
if isempty(BP)
 BP=table('Size',[0 7], ...
  'VariableTypes',{'double','double','double','double','double','double','double'}, ...
  'VariableNames',{'WindowSeconds1','Overlap1','WindowSeconds2','Overlap2', ...
  'NMatchedEdges','SpearmanAgreement','MeanAbsWeightDifference'});
end
writetable(BP,fullfile(D,'NETWORK_WEIGHT_ALL_36_GEOMETRY_PAIRS.csv'));
B=table();
for gi=1:size(geom,1)
 ix=(BP.WindowSeconds1==geom(gi,1)&BP.Overlap1==geom(gi,2)) | ...
    (BP.WindowSeconds2==geom(gi,1)&BP.Overlap2==geom(gi,2));
 z=BP(ix,:);
 if isempty(z)
  medR=NaN; medD=NaN;
 else
  medR=median(z.SpearmanAgreement,'omitnan');
  medD=median(z.MeanAbsWeightDifference,'omitnan');
 end
 B=[B;table(geom(gi,1),geom(gi,2),height(z),medR,medD, ...
  'VariableNames',{'WindowSeconds','Overlap','NPeerGeometries', ...
  'MedianSpearmanToOtherGeometries','MedianAbsWeightDifferenceToOtherGeometries'})]; %#ok<AGROW>
end
writetable(B,fullfile(D,'NETWORK_WEIGHT_SYMMETRIC_GEOMETRY_AGREEMENT.csv'));
% Reviewer audit: preserve denominator, failed/missing surrogates and matched coverage.
AUD=table();
for jj=1:size(geom,1)
 ix=R.WindowSeconds==geom(jj,1)&R.Overlap==geom(jj,2);
 zz=R(ix,:);
 AUD=[AUD;table(geom(jj,1),geom(jj,2),numel(unique(zz.File)),height(zz), ...
 sum(isfinite(zz.SignedCS)),sum(isfinite(zz.SurrogateP)),sum(zz.SurvivesShift==1), ...
 'VariableNames',{'WindowSeconds','Overlap','Files','EdgeRows','FiniteCS','TestableShifts','SignificantShifts'})]; %#ok<AGROW>
end
writetable(AUD,fullfile(D,'GEOMETRY_COMPLETENESS_AUDIT.csv'));
% The repeated musician is one person across two contexts: report leave-one-context-out.
L=table();
for exclusion=0:2
 Z=R;
 if exclusion==1,Z=Z(~(Z.Dyad==2&Z.Musician==2),:);end
 if exclusion==2,Z=Z(~(Z.Dyad==9&Z.Musician==1),:);end
 for jj=1:size(geom,1)
  for ee=1:numel(edgeNames)
   for tt=1:6
    rr=Z(Z.WindowSeconds==geom(jj,1)&Z.Overlap==geom(jj,2)&Z.Edge==edgeNames{ee}&Z.Task==0,:);
    aa=Z(Z.WindowSeconds==geom(jj,1)&Z.Overlap==geom(jj,2)&Z.Edge==edgeNames{ee}&Z.Task==tt,:);
    [~,ir,ia]=intersect(strcat(string(rr.Dyad),'_',string(rr.Musician)),strcat(string(aa.Dyad),'_',string(aa.Musician)));
    d=aa.SignedCS(ia)-rr.SignedCS(ir);d=d(isfinite(d));
    if isempty(d),md=NaN;else,md=mean(d);end
    L=[L;table(exclusion,geom(jj,1),geom(jj,2),string(edgeNames{ee}),tt,numel(d),md, ...
    'VariableNames',{'ExcludedRepeatedContext','WindowSeconds','Overlap','Edge','Task','NMatched','MeanDeltaCS'})]; %#ok<AGROW>
   end
  end
 end
end
writetable(L,fullfile(D,'REPEATED_MUSICIAN_LEAVE_ONE_CONTEXT_OUT.csv'));
% Compare CS with conventional RAW EEG Pearson across matched recordings/edges.
V=table();
for jj=1:size(geom,1)
 zz=R(R.WindowSeconds==geom(jj,1)&R.Overlap==geom(jj,2),:);
 ok=isfinite(zz.AbsCS)&isfinite(zz.RawEEGPearson);
 if sum(ok)>=5,rval=music2_sweep_spearman(zz.AbsCS(ok),abs(zz.RawEEGPearson(ok)));else,rval=NaN;end
 V=[V;table(geom(jj,1),geom(jj,2),sum(ok),rval, ...
 'VariableNames',{'WindowSeconds','Overlap','NMatchedEdges','SpearmanAbsCSvsAbsRawEEG'})]; %#ok<AGROW>
end
writetable(V,fullfile(D,'CS_VS_CONVENTIONAL_EEG_CORRELATION.csv'));

% Main-paper figure pack only.
% IMPORTANT: all inferential/QC analyses and CSV/MAT outputs above are retained.
% This block only limits GRAPHICAL output to figures needed for the manuscript.
if P.GeneratePaperFigures
    primary=find(abs(geom(:,1)-6.4)<1e-9 & abs(geom(:,2)-.50)<1e-9);
    assert(numel(primary)==1,'Primary 6.4-s/50%% geometry is missing.');

    % ---------------- MAIN PAPER ----------------
    % M1 is generated before this function: observed MDEA method/fit example.
    % M2: observed scaling-exponent trajectories illustrating CS.
    music2_append_scaling_example(results,geom(primary,:),names,mainPDF);

    % M3: central result -- six task-minus-Rest five-node CS networks on ONE page.
    music2_append_compact_primary_cs_networks(C,geom(primary,:),edgeNames,mainPDF);

    % M4: edge x task CS topology summary.
    music2_append_primary_cs_heatmap(C,geom(primary,:),edgeNames,mainPDF);

    % M5: compact conventional benchmark used for the central claim:
    % raw Pearson + theta/alpha/beta PLV, shown beside CS task effects.
    music2_append_compact_main_conventional(C,Craw,Cplv,geom(primary,:),edgeNames,P,mainPDF);

    % Main primary clustered Holm-corrected figure is appended after statistical validation.
    % All nine geometry-specific omnibus tests are retained in supplementary CSVs.

    % owns stripe-size, renewal, and supplementary-figure generation.
    % Keep conventional spectral calculations and all numerical CSV/MAT results.

    % Detailed numerical evidence remains in CSV/MAT files even though the
    % exhaustive figure pages are intentionally suppressed.
end % GeneratePaperFigures

fprintf('FULL COHORT ROBUSTNESS: %s\n',D);

 function progress(~)
  count=count+1;dt=toc(t0);
  if isgraphics(h),waitbar(count/n,h,sprintf('%d/%d files | %.1f min elapsed | %.1f min ETA', ...
   count,n,dt/60,(n-count)*dt/max(count,1)/60));end
 end
end


function out=music2_join_report_lines(lines)
% Robustly join report text even if a preallocated cell contains [], string,
% numeric, or missing entries. This avoids MATLAB strjoin type failures.
if isstring(lines)
    s=lines(:);
elseif iscell(lines)
    s=strings(numel(lines),1);
    for i=1:numel(lines)
        v=lines{i};
        if isempty(v)
            s(i)="";
        elseif ischar(v)
            s(i)=string(v);
        elseif isstring(v)
            if isempty(v), s(i)=""; else, s(i)=v(1); end
        elseif isnumeric(v) || islogical(v)
            s(i)=string(v);
        else
            try
                s(i)=string(v);
            catch
                s(i)="[unprintable]";
            end
        end
    end
else
    s=string(lines(:));
end
out=char(join(s,newline));
end

function stars=music2_qstars(q)
% Conventional FDR-star notation used ONLY for already FDR-adjusted q values.
if ~isfinite(q)
    stars='';
elseif q<0.001
    stars='***';
elseif q<0.01
    stars='**';
elseif q<0.05
    stars='*';
else
    stars='';
end
end

function GR=music2_geometry_effect_summary(C,edgeNames)
% Symmetric summary: no direction, q, or effect is compared to one geometry.
GR=table();
for e=1:numel(edgeNames)
 for task=1:6
  z=C(C.Edge==edgeNames{e} & C.Task==task,:);
  zg=z(isfinite(z.MeanDeltaCS),:);n=height(zg);
  if n==0
   med=NaN;mn=NaN;mx=NaN;npos=0;nneg=0;nsig=0;nsigpos=0;nsigneg=0;dircons=NaN;
  else
   d=zg.MeanDeltaCS;med=median(d);mn=min(d);mx=max(d);
   npos=sum(d>0);nneg=sum(d<0);
   sig=isfinite(zg.QwithinEdge)&zg.QwithinEdge<.05;
   nsig=sum(sig);nsigpos=sum(sig&d>0);nsigneg=sum(sig&d<0);
   dircons=max(npos,nneg)/n;
  end
  GR=[GR;table(string(edgeNames{e}),task,n,med,mn,mx,npos,nneg,dircons, ...
   nsig,nsigpos,nsigneg,'VariableNames',{'Edge','Task','NGeometries', ...
   'MedianDeltaCS','MinDeltaCS','MaxDeltaCS','NPositive','NNegative', ...
   'DirectionConsistency','NFDRSignificant','NFDRSignificantPositive', ...
   'NFDRSignificantNegative'})]; %#ok<AGROW>
 end
end
end


function [c,ic,dw]=music2_spectral_pair_local(x,y,fs,band,segSec,overlap,minSegments)
% Exact spectral-control recipe carried forward from the older conventional
% connectivity benchmark.  Coherence is magnitude-squared coherence;
% imaginary coherence is absolute imaginary coherency; dwPLI is the
% debiased squared weighted phase-lag index and may be negative.
c=NaN;ic=NaN;dw=NaN;
x=double(x(:));y=double(y(:));n=min(numel(x),numel(y));seg=round(segSec*fs);
if n<seg||seg<16,return;end
step=max(1,round(seg*(1-overlap)));starts=1:step:(n-seg+1);
if numel(starts)<minSegments,return;end
nfft=2^nextpow2(seg);hz=(0:nfft/2)'*fs/nfft;
fidx=find(hz>=band(1)&hz<=band(2));if isempty(fidx),return;end
win=.5-.5*cos(2*pi*(0:seg-1)'/max(1,seg-1));
nf=numel(fidx);C=zeros(numel(starts),nf);A=zeros(numel(starts),nf);B=A;
valid=false(numel(starts),1);
for j=1:numel(starts)
 ii=starts(j):(starts(j)+seg-1);a=x(ii);b=y(ii);
 good=isfinite(a)&isfinite(b);if mean(good)<.99,continue;end
 if any(~isfinite(a)),a(~isfinite(a))=mean(a(isfinite(a)));end
 if any(~isfinite(b)),b(~isfinite(b))=mean(b(isfinite(b)));end
 a=(a-mean(a)).*win;b=(b-mean(b)).*win;
 X=fft(a,nfft);Y=fft(b,nfft);X=X(fidx);Y=Y(fidx);
 C(j,:)=X.*conj(Y);A(j,:)=abs(X).^2;B(j,:)=abs(Y).^2;valid(j)=true;
end
if nnz(valid)<minSegments,return;end
C=C(valid,:);A=A(valid,:);B=B(valid,:);
cc=sum(C,1);den=sqrt(sum(A,1).*sum(B,1));good=den>eps;if ~any(good),return;end
c=mean(min(1,abs(cc(good)).^2./den(good).^2),'omitnan');
ic=mean(min(1,abs(imag(cc(good)))./den(good)),'omitnan');
im=imag(C);si=sum(im,1);sq=sum(im.^2,1);sa=sum(abs(im),1);d=sa.^2-sq;
v=good & d>eps;if any(v),dw=mean((si(v).^2-sq(v))./d(v),'omitnan');end
end

function Cspec=music2_spectral_task_contrasts(SPEC,edgeNames,P)
% Matched task-minus-Rest contrasts for the three supplementary spectral
% connectivity metrics. FDR family: six task contrasts within edge and metric.
metrics={'Coherence830','ImagCoherence830','DebiasedWPLI830'};
metricLabels={'Coherence 8-30 Hz','Imaginary coherence 8-30 Hz','Debiased wPLI 8-30 Hz'};
Cspec=table();
for mm=1:numel(metrics)
 met=metrics{mm};
 for e=1:numel(edgeNames)
  for task=1:6
   rr=SPEC(abs(SPEC.WindowSeconds-P.SpectralWindowSeconds)<1e-9 & ...
    abs(SPEC.Overlap-P.SpectralWindowOverlap)<1e-12 & SPEC.Edge==edgeNames{e} & SPEC.Task==0,:);
   aa=SPEC(abs(SPEC.WindowSeconds-P.SpectralWindowSeconds)<1e-9 & ...
    abs(SPEC.Overlap-P.SpectralWindowOverlap)<1e-12 & SPEC.Edge==edgeNames{e} & SPEC.Task==task,:);
   idr=strcat(string(rr.Dyad),'_',string(rr.Musician));
   ida=strcat(string(aa.Dyad),'_',string(aa.Musician));
   [~,ir,ia]=intersect(idr,ida);
   x=rr.(met)(ir);y=aa.(met)(ia);ok=isfinite(x)&isfinite(y);x=x(ok);y=y(ok);
   if numel(x)>=5 && any(y~=x),p=signrank(y,x);else,p=NaN;end
   if isempty(x),md=NaN;else,md=mean(y-x);end
   Cspec=[Cspec;table(string(met),string(metricLabels{mm}),string(edgeNames{e}),task, ...
    numel(x),md,p,'VariableNames',{'Metric','MetricLabel','Edge','Task','NMatched','MeanDelta','P'})]; %#ok<AGROW>
  end
 end
end
Cspec.QwithinEdgeMetric=nan(height(Cspec),1);
for mm=1:numel(metrics)
 for e=1:numel(edgeNames)
  ix=Cspec.Metric==metrics{mm} & Cspec.Edge==edgeNames{e};
  Cspec.QwithinEdgeMetric(ix)=music2_bh(Cspec.P(ix));
 end
end
end

function music2_append_spectral_comparator_pages(C,Cspec,edgeNames,P,reportPDF)
% Three supplementary pages: coherence, imaginary coherence and dwPLI.
% Each page contains six five-node task-minus-Rest networks plus a compact
% matched edge-by-task CS comparison panel. These are controls, not a ranking.
metrics={'Coherence830','ImagCoherence830','DebiasedWPLI830'};
labels={'Coherence (8-30 Hz)','Imaginary coherence (8-30 Hz)','Debiased wPLI (8-30 Hz)'};
taskLabels={'Coord','C&R','Fam','Unfam','Imp','Listen'};
for mm=1:numel(metrics)
 met=string(metrics{mm});
 f=figure('Color','w','Position',[40 40 1750 1120]);
 tl=tiledlayout(2,4,'Padding','compact','TileSpacing','compact');
 for task=1:6
  ax=nexttile;music2_draw_one_spectral_network(ax,Cspec,task,edgeNames,met);
  title(ax,sprintf('%s - Rest',taskLabels{task}),'FontWeight','bold','FontSize',13);
 end
 % Seventh panel: direct task-effect correspondence with CS at the same geometry.
 ax=nexttile;hold(ax,'on');box(ax,'on');grid(ax,'on');
 aa=C(abs(C.WindowSeconds-P.SpectralWindowSeconds)<1e-9 & ...
      abs(C.Overlap-P.SpectralWindowOverlap)<1e-12,:);
 bb=Cspec(Cspec.Metric==met,:);
 ka=strcat(aa.Edge,'|',string(aa.Task));kb=strcat(bb.Edge,'|',string(bb.Task));
 [~,ia,ib]=intersect(ka,kb);
 x=bb.MeanDelta(ib);y=aa.MeanDeltaCS(ia);ok=isfinite(x)&isfinite(y);x=x(ok);y=y(ok);
 plot(ax,x,y,'o','MarkerSize',5);xline(ax,0,'k:');yline(ax,0,'k:');
 if numel(x)>=5,rho=music2_sweep_spearman(x,y);else,rho=NaN;end
 xlabel(ax,'Task - Rest conventional connectivity');ylabel(ax,'Task - Rest |CS|');
 title(ax,sprintf('Matched edge/task effects, rho=%.2f',rho),'FontSize',12);
 % Eighth panel: method note for reviewer clarity.
 ax=nexttile;axis(ax,'off');
 text(ax,.03,.95,sprintf(['Spectral control: %s\n\nGeometry: %.1f s / %.0f%% overlap\n' ...
  'Band: %.0f-%.0f Hz\nWithin-window segments: %.1f s, %.0f%% overlap\n' ...
  'Minimum segments: %d\n\nSolid edge: BH-FDR q<0.05\nDashed edge: q>=0.05\n' ...
  'Pale dotted: unavailable\n\nEdge label = mean task - Rest change.\n' ...
  'dwPLI is left unbiased and may be negative.'], ...
  labels{mm},P.SpectralWindowSeconds,100*P.SpectralWindowOverlap, ...
  P.SpectralBandHz(1),P.SpectralBandHz(2),P.SpectralSegmentSec, ...
  100*P.SpectralSegmentOverlap,P.MinSpectralSegments), ...
  'VerticalAlignment','top','Interpreter','none','FontSize',11);
 title(tl,sprintf('Supplementary conventional connectivity: %s',labels{mm}), ...
  'FontSize',18,'FontWeight','bold');
 annotation(f,'textbox',[.16 .004 .68 .028],'String', ...
  'Same five A/F/M/P/O scalp groups. Spectral controls reproduce the earlier benchmark recipe and are not used to select or tune CS parameters.', ...
  'HorizontalAlignment','center','EdgeColor','none','FontSize',10,'Interpreter','none');
 append_pdf_page_v22(f,reportPDF);if isgraphics(f),close(f);end
end
end

function music2_draw_one_spectral_network(ax,Cspec,task,edgeNames,metric)
axes(ax);cla(ax);hold(ax,'on');axis(ax,[0 1 0 1]);axis(ax,'off');axis(ax,'equal');
pos=struct('A',[.50 .91],'F',[.12 .64],'M',[.26 .16],'P',[.74 .16],'O',[.88 .64]);
zall=Cspec(Cspec.Metric==metric,:);scale=max(abs(zall.MeanDelta(isfinite(zall.MeanDelta))));
if isempty(scale)||~isfinite(scale)||scale<=0,scale=1;end
for e=1:numel(edgeNames)
 parts=strsplit(edgeNames{e},'-');p1=pos.(parts{1});p2=pos.(parts{2});
 z=Cspec(Cspec.Metric==metric & Cspec.Edge==edgeNames{e} & Cspec.Task==task,:);
 if isempty(z)||~isfinite(z.MeanDelta(1))
  plot(ax,[p1(1) p2(1)],[p1(2) p2(2)],':','Color',[.75 .75 .75],'LineWidth',.8);continue;
 end
 d=z.MeanDelta(1);q=z.QwithinEdgeMetric(1);lw=.8+5.5*min(abs(d)/scale,1);
 if d>=0,col=[0 0 0];else,col=[.75 0 0];end
 if isfinite(q)&&q<.05,ls='-';else,ls='--';end
 plot(ax,[p1(1) p2(1)],[p1(2) p2(2)],ls,'Color',col,'LineWidth',lw);
 mid=(p1+p2)/2;text(ax,mid(1),mid(2),sprintf('%+.3f',d),'HorizontalAlignment','center', ...
  'VerticalAlignment','middle','FontSize',9,'FontWeight','bold','BackgroundColor','w','Margin',1,'Interpreter','none');
end
nodes={'A','F','M','P','O'};
for i=1:numel(nodes)
 p=pos.(nodes{i});plot(ax,p(1),p(2),'o','MarkerSize',9,'MarkerFaceColor',[1 .1 .55], ...
  'MarkerEdgeColor','k','LineWidth',1);text(ax,p(1),p(2)+.055,nodes{i}, ...
  'HorizontalAlignment','center','FontSize',12,'FontWeight','bold');
end
end

function Cplv=music2_plv_task_contrasts(PLV,geom,edgeNames,bandNames)
% Matched task-minus-Rest changes in conventional phase-locking value.
% FDR family: six task contrasts within each edge x frequency band x geometry.
Cplv=table();
for gi=1:size(geom,1)
 for bb=1:numel(bandNames)
  for e=1:numel(edgeNames)
   for task=1:6
    rr=PLV(PLV.WindowSeconds==geom(gi,1) & abs(PLV.Overlap-geom(gi,2))<1e-12 & ...
           PLV.Edge==edgeNames{e} & PLV.Band==bandNames{bb} & PLV.Task==0,:);
    aa=PLV(PLV.WindowSeconds==geom(gi,1) & abs(PLV.Overlap-geom(gi,2))<1e-12 & ...
           PLV.Edge==edgeNames{e} & PLV.Band==bandNames{bb} & PLV.Task==task,:);
    idr=strcat(string(rr.Dyad),'_',string(rr.Musician));
    ida=strcat(string(aa.Dyad),'_',string(aa.Musician));
    [~,ir,ia]=intersect(idr,ida);
    x=rr.PLV(ir); y=aa.PLV(ia);
    ok=isfinite(x)&isfinite(y); x=x(ok); y=y(ok);
    if numel(x)>=5 && any(y~=x), p=signrank(y,x); else, p=NaN; end
    if isempty(x),md=NaN;else,md=mean(y-x);end
    Cplv=[Cplv;table(geom(gi,1),geom(gi,2),string(edgeNames{e}),string(bandNames{bb}), ...
     task,numel(x),md,p,'VariableNames',{'WindowSeconds','Overlap','Edge','Band', ...
     'Task','NMatched','MeanDeltaPLV','P'})]; %#ok<AGROW>
   end
  end
 end
end
Cplv.QwithinEdgeBand=nan(height(Cplv),1);
for gi=1:size(geom,1)
 for bb=1:numel(bandNames)
  for e=1:numel(edgeNames)
   ix=Cplv.WindowSeconds==geom(gi,1) & abs(Cplv.Overlap-geom(gi,2))<1e-12 & ...
      Cplv.Edge==edgeNames{e} & Cplv.Band==bandNames{bb};
   Cplv.QwithinEdgeBand(ix)=music2_bh(Cplv.P(ix));
  end
 end
end
end

function music2_append_cs_vs_plv_pages(C,Cplv,geom,edgeNames,bandNames,reportPDF)
% For each conventional frequency band, show the PLV network and a direct
% edge-by-task comparison with CS. These are comparisons of task effects,
% not a competition based on the number of significant edges.
taskLabels={'Coord','C&R','Fam','Unfam','Imp','Listen'};
for bb=1:numel(bandNames)
 band=string(bandNames{bb});
 % Page 1: matched PLV task-minus-Rest networks.
 for task=1:6
  f=figure('Color','w','Position',[50 50 1650 1100]);
  if size(geom,1)==1
   tl=tiledlayout(1,1,'Padding','compact','TileSpacing','compact');
  else
   tl=tiledlayout(3,3,'Padding','compact','TileSpacing','compact');
  end
  for gi=1:size(geom,1)
   ax=nexttile;
   music2_draw_one_plv_geometry_network(ax,Cplv,geom(gi,1),geom(gi,2),task,edgeNames,band);
   title(ax,sprintf('%g s / %g%% overlap',geom(gi,1),100*geom(gi,2)), ...
    'FontWeight','bold','FontSize',13);
  end
  title(tl,sprintf('%s - Rest: %s PLV network',taskLabels{task},band), ...
   'FontSize',19,'FontWeight','bold');
  annotation(f,'textbox',[.17 .005 .66 .035], ...
   'String','Edge label = mean task-minus-Rest PLV. SOLID: q<0.05; DASHED: q>=0.05; pale dotted: unavailable. BH-FDR across six tasks within each edge, band, and geometry.', ...
   'HorizontalAlignment','center','EdgeColor','none','FontSize',10.5,'Interpreter','none');
  append_pdf_page_v22(f,reportPDF); if isgraphics(f), close(f); end
 end

 % Page 2: direct CS-versus-PLV task-effect comparison.
 f=figure('Color','w','Position',[60 60 1500 950]);
 if size(geom,1)==1
  tl=tiledlayout(1,1,'Padding','compact','TileSpacing','compact');
 else
  tl=tiledlayout(3,3,'Padding','compact','TileSpacing','compact');
 end
 for gi=1:size(geom,1)
  ax=nexttile;hold(ax,'on');box(ax,'on');grid(ax,'on');
  a=C(C.WindowSeconds==geom(gi,1)&abs(C.Overlap-geom(gi,2))<1e-12,:);
  b=Cplv(Cplv.WindowSeconds==geom(gi,1)&abs(Cplv.Overlap-geom(gi,2))<1e-12& ...
         Cplv.Band==band,:);
  ka=strcat(a.Edge,'|',string(a.Task));kb=strcat(b.Edge,'|',string(b.Task));
  [~,ia,ib]=intersect(ka,kb);
  x=b.MeanDeltaPLV(ib);y=a.MeanDeltaCS(ia);
  ok=isfinite(x)&isfinite(y);x=x(ok);y=y(ok);
  plot(ax,x,y,'o','MarkerSize',5);xline(ax,0,'k:');yline(ax,0,'k:');
  if numel(x)>=5,rr=music2_sweep_spearman(x,y);else,rr=NaN;end
  xlabel(ax,sprintf('Task-Rest Delta PLV (%s)',band));
  ylabel(ax,'Task-Rest Delta |CS|');
  title(ax,sprintf('%g s / %g%%, rho=%.2f',geom(gi,1),100*geom(gi,2),rr),'FontSize',11);
 end
 title(tl,sprintf('CS versus conventional %s PLV: matched edge-by-task effects',band), ...
  'FontSize',17,'FontWeight','bold');
 append_pdf_page_v22(f,reportPDF); if isgraphics(f), close(f); end
end
end

function music2_draw_one_plv_geometry_network(ax,Cplv,w,o,task,edgeNames,band)
axes(ax);cla(ax);hold(ax,'on');axis(ax,[0 1 0 1]);axis(ax,'off');axis(ax,'equal');
pos=struct('A',[.50 .91],'F',[.12 .64],'M',[.26 .16],'P',[.74 .16],'O',[.88 .64]);
for e=1:numel(edgeNames)
 parts=strsplit(edgeNames{e},'-');p1=pos.(parts{1});p2=pos.(parts{2});
 z=Cplv(Cplv.WindowSeconds==w & abs(Cplv.Overlap-o)<1e-12 & ...
         Cplv.Edge==edgeNames{e} & Cplv.Band==band & Cplv.Task==task,:);
 if isempty(z)||~isfinite(z.MeanDeltaPLV(1))
  plot(ax,[p1(1) p2(1)],[p1(2) p2(2)],':','Color',[.75 .75 .75],'LineWidth',.8);
  continue;
 end
 d=z.MeanDeltaPLV(1);q=z.QwithinEdgeBand(1);
 lw=.8+5.5*min(abs(d)/.15,1);
 if d>=0,col=[0 0 0];else,col=[.75 0 0];end
 if isfinite(q)&&q<.05,ls='-';else,ls='--';end
 plot(ax,[p1(1) p2(1)],[p1(2) p2(2)],ls,'Color',col,'LineWidth',lw);
 mid=(p1+p2)/2;
 text(ax,mid(1),mid(2),sprintf('%+.2f',d),'HorizontalAlignment','center', ...
  'VerticalAlignment','middle','FontSize',10,'FontWeight','bold', ...
  'BackgroundColor','w','Margin',1,'Interpreter','none');
end
nodes={'A','F','M','P','O'};
for i=1:numel(nodes)
 p=pos.(nodes{i});plot(ax,p(1),p(2),'o','MarkerSize',9, ...
  'MarkerFaceColor',[1 .1 .55],'MarkerEdgeColor','k','LineWidth',1);
 text(ax,p(1),p(2)+.055,nodes{i},'HorizontalAlignment','center', ...
  'FontSize',13,'FontWeight','bold');
end
end

function Craw=music2_raw_eeg_task_contrasts(R,geom,edgeNames)
% Matched task-minus-Rest changes in absolute raw-EEG Pearson correlation.
Craw=table();
for gi=1:size(geom,1)
    for e=1:numel(edgeNames)
        for task=1:6
            rr=R(R.WindowSeconds==geom(gi,1) & R.Overlap==geom(gi,2) & ...
                 R.Edge==edgeNames{e} & R.Task==0,:);
            aa=R(R.WindowSeconds==geom(gi,1) & R.Overlap==geom(gi,2) & ...
                 R.Edge==edgeNames{e} & R.Task==task,:);
            idr=strcat(string(rr.Dyad),'_',string(rr.Musician));
            ida=strcat(string(aa.Dyad),'_',string(aa.Musician));
            [~,ir,ia]=intersect(idr,ida);
            x=abs(rr.RawEEGPearson(ir)); y=abs(aa.RawEEGPearson(ia));
            ok=isfinite(x)&isfinite(y); x=x(ok); y=y(ok);
            if numel(x)>=5 && any(y~=x), p=signrank(y,x); else, p=NaN; end
            if isempty(x), md=NaN; else, md=mean(y-x); end
            Craw=[Craw;table(geom(gi,1),geom(gi,2),string(edgeNames{e}),task,numel(x),md,p, ...
                'VariableNames',{'WindowSeconds','Overlap','Edge','Task','NMatched', ...
                'MeanDeltaAbsRawEEG','P'})]; %#ok<AGROW>
        end
    end
end
Craw.QwithinEdge=nan(height(Craw),1);
for gi=1:size(geom,1)
    for e=1:numel(edgeNames)
        ix=Craw.WindowSeconds==geom(gi,1) & Craw.Overlap==geom(gi,2) & Craw.Edge==edgeNames{e};
        Craw.QwithinEdge(ix)=music2_bh(Craw.P(ix));
    end
end
end

function music2_append_geometry_network_pages(C,geom,edgeNames,reportPDF)
taskLabels={'Coord','C&R','Fam','Unfam','Imp','Listen'};
for task=1:6
    f=figure('Color','w','Position',[50 50 1650 1100]);
    if size(geom,1)==1
        tl=tiledlayout(1,1,'Padding','compact','TileSpacing','compact');
    else
        tl=tiledlayout(3,3,'Padding','compact','TileSpacing','compact');
    end
    for gi=1:size(geom,1)
        ax=nexttile;
        music2_draw_one_geometry_network(ax,C,geom(gi,1),geom(gi,2),task,edgeNames);
        title(ax,sprintf('%g s / %g%% overlap',geom(gi,1),100*geom(gi,2)), ...
            'FontWeight','bold','FontSize',13);
    end
    title(tl,sprintf('%s - Rest: CS network sensitivity to MDEA geometry',taskLabels{task}), ...
        'FontSize',19,'FontWeight','bold');
    annotation(f,'textbox',[.20 .005 .60 .035], ...
        'String','Edge label = mean Delta CS. SOLID: q<0.05; DASHED: q>=0.05; pale dotted: unavailable. BH-FDR across six tasks within each edge and geometry.', ...
        'HorizontalAlignment','center','EdgeColor','none','FontSize',11,'Interpreter','none');
    append_pdf_page_v22(f,reportPDF); close(f);
end
end

function music2_draw_one_geometry_network(ax,C,w,o,task,edgeNames)
axes(ax); cla(ax); hold(ax,'on'); axis(ax,[0 1 0 1]); axis(ax,'off'); axis(ax,'equal');
pos=struct('A',[.50 .91],'F',[.12 .64],'M',[.26 .16],'P',[.74 .16],'O',[.88 .64]);
for e=1:numel(edgeNames)
    parts=strsplit(edgeNames{e},'-'); p1=pos.(parts{1}); p2=pos.(parts{2});
    z=C(C.WindowSeconds==w & abs(C.Overlap-o)<1e-12 & C.Edge==edgeNames{e} & C.Task==task,:);
    if isempty(z) || ~isfinite(z.MeanDeltaCS(1))
        plot(ax,[p1(1) p2(1)],[p1(2) p2(2)],':','Color',[.75 .75 .75],'LineWidth',.8);
        continue;
    end
    d=z.MeanDeltaCS(1); q=z.QwithinEdge(1);
    lw=.8+5.5*min(abs(d)/.25,1);
    if d>=0, col=[0 0 0]; else, col=[.75 0 0]; end
    if isfinite(q) && q<.05, ls='-'; else, ls='--'; end
    plot(ax,[p1(1) p2(1)],[p1(2) p2(2)],ls,'Color',col,'LineWidth',lw);
    mid=(p1+p2)/2;
    % Offset each edge annotation perpendicular to its line; stable across tasks.
    vec=p2-p1; normal=[-vec(2) vec(1)]/max(norm(vec),eps);
    if dot(normal,mid-[.5 .52])<0,normal=-normal;end
    mid=mid+.055*normal;
    lab=sprintf('%+.2f',d);
    text(ax,mid(1),mid(2),lab,'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'FontSize',13,'FontWeight','bold','BackgroundColor','w','Margin',1.5,'Interpreter','none');
end
nodes={'A','F','M','P','O'};
for i=1:numel(nodes)
    p=pos.(nodes{i});
    plot(ax,p(1),p(2),'o','MarkerSize',9,'MarkerFaceColor',[1 .1 .55], ...
        'MarkerEdgeColor','k','LineWidth',1);
    % Keep the two bottom labels outside the pentagon for visibility.
    if nodes{i}=="M"
        tx=p(1)-.035; ty=p(2)-.070; ha='right'; va='top';
    elseif nodes{i}=="P"
        tx=p(1)+.035; ty=p(2)-.070; ha='left'; va='top';
    else
        tx=p(1); ty=p(2)+.055; ha='center'; va='bottom';
    end
    text(ax,tx,ty,nodes{i},'HorizontalAlignment',ha,'VerticalAlignment',va, ...
        'FontSize',16,'FontWeight','bold');
end
end

function music2_append_geometry_consensus_page(GR,edgeNames,reportPDF)
taskLabels={'Coord','C&R','Fam','Unfam','Imp','Listen'};
f=figure('Color','w','Position',[50 50 1650 1050]);
tl=tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
for task=1:6
    ax=nexttile; hold(ax,'on'); axis(ax,[0 1 0 1]); axis(ax,'off'); axis(ax,'equal');
    pos=struct('A',[.50 .91],'F',[.12 .64],'M',[.26 .16],'P',[.74 .16],'O',[.88 .64]);
    for e=1:numel(edgeNames)
        z=GR(GR.Edge==edgeNames{e} & GR.Task==task,:);
        if isempty(z) || ~isfinite(z.MedianDeltaCS(1)), continue; end
        parts=strsplit(edgeNames{e},'-'); p1=pos.(parts{1}); p2=pos.(parts{2});
        d=z.MedianDeltaCS(1); n=z.NGeometries(1); ns=z.NFDRSignificant(1);
        same=z.DirectionConsistency(1);
        lw=.8+5.5*min(abs(d)/.25,1);
        if d>=0, col=[0 0 0]; else, col=[.75 0 0]; end
        if isfinite(same) && same>=.80, ls='--'; else, ls=':'; end
        plot(ax,[p1(1) p2(1)],[p1(2) p2(2)],ls,'Color',col,'LineWidth',lw);
        mid=(p1+p2)/2;
        lab=sprintf('%+.2f | sig %d/%d | dir %.0f%%',d,ns,n,100*same);
        text(ax,mid(1),mid(2),lab,'HorizontalAlignment','center','FontSize',8.5, ...
            'FontWeight','bold','BackgroundColor','w','Margin',1,'Interpreter','none');
    end
    nodes={'A','F','M','P','O'};
    for i=1:numel(nodes)
        p=pos.(nodes{i}); plot(ax,p(1),p(2),'o','MarkerSize',8,'MarkerFaceColor',[1 .1 .55], ...
            'MarkerEdgeColor','k'); text(ax,p(1),p(2)+.05,nodes{i},'HorizontalAlignment','center','FontWeight','bold');
    end
    title(ax,taskLabels{task},'FontWeight','bold','FontSize',14);
end
title(tl,'Across-geometry consensus: median task-minus-Rest Delta CS, significant geometries, and direction consistency', ...
    'FontSize',17,'FontWeight','bold');
annotation(f,'textbox',[.08 .005 .84 .04], ...
    'String','Consensus dashed: >=80% of geometries agree in direction; dotted: weaker agreement. This page is descriptive; "sig k/n" counts FDR-significant geometries, not a combined p-value.', ...
    'HorizontalAlignment','center','EdgeColor','none','FontSize',10.5,'Interpreter','none');
append_pdf_page_v22(f,reportPDF); close(f);
end

function music2_append_cs_vs_raw_task_effect_page(C,Craw,geom,reportPDF)
f=figure('Color','w','Position',[60 60 1500 950]);
tl=tiledlayout(3,3,'Padding','compact','TileSpacing','compact');
for gi=1:size(geom,1)
    ax=nexttile; hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    a=C(C.WindowSeconds==geom(gi,1)&abs(C.Overlap-geom(gi,2))<1e-12,:);
    b=Craw(Craw.WindowSeconds==geom(gi,1)&abs(Craw.Overlap-geom(gi,2))<1e-12,:);
    ka=strcat(a.Edge,'|',string(a.Task)); kb=strcat(b.Edge,'|',string(b.Task));
    [~,ia,ib]=intersect(ka,kb);
    x=b.MeanDeltaAbsRawEEG(ib); y=a.MeanDeltaCS(ia);
    ok=isfinite(x)&isfinite(y); x=x(ok); y=y(ok);
    plot(ax,x,y,'o','MarkerSize',5);
    xline(ax,0,'k:'); yline(ax,0,'k:');
    if numel(x)>=5, rr=music2_sweep_spearman(x,y); else, rr=NaN; end
    xlabel(ax,'Task-Rest Delta |raw EEG Pearson|'); ylabel(ax,'Task-Rest Delta |CS|');
    title(ax,sprintf('%g s / %g%%, rho=%.2f',geom(gi,1),100*geom(gi,2),rr),'FontSize',11);
end
title(tl,'Do task-related CS changes merely reproduce conventional raw-EEG correlation changes?', ...
    'FontSize',17,'FontWeight','bold');
append_pdf_page_v22(f,reportPDF); close(f);
end

function q=music2_bh(p)
q=nan(size(p));ok=find(isfinite(p));if isempty(ok),return;end
[ps,order]=sort(p(ok));m=numel(ps);adj=ps.*m./(1:m)';
adj=flipud(cummin(flipud(adj)));adj=min(1,adj);
q(ok(order))=adj;
end
function music2_append_pilot_pages(OUT,reportPDF)
D=fullfile(OUT,'WINDOW_OVERLAP_SENSITIVITY');
% MATLAB exportgraphics cannot append a pre-existing PDF as a PDF input;
% reproduce pilot figures from saved data, without creating separate PDFs.
mat=fullfile(D,'SWEEP_RAW.mat');if ~isfile(mat),return;end
s=load(mat,'T','S','traces','P');T=s.T;S=s.S;traces=s.traces;P=s.P;
f=figure('Color','w','Position',[100 100 1400 900]);tl=tiledlayout(2,2,'Padding','compact');
metrics={'FiniteFraction','MeanFitR2','SDDelta','ApproxNeff'};
ylabels={'Finite delta fraction','Mean entropy fit R^2','Within-recording SD(delta)','Approximate effective N'};
for m=1:4
 nexttile;hold on;
 for w=P.SweepWindowSeconds
  a=T(T.WindowSeconds==w,:);plot(a.Overlap,a.(metrics{m}),'.','MarkerSize',12);
  b=S(S.WindowSeconds==w,:);
  plot(b.Overlap,b.(music2_sweep_summary_field(metrics{m})),'-o','DisplayName',sprintf('%g s',w));
 end
 xlabel('Overlap');ylabel(ylabels{m});xticks(P.SweepOverlaps);grid on;
 if m==1,legend('Location','best');end
end
title(tl,'Pilot numerical QC: representative electrodes only');
append_pdf_page_v22(f,reportPDF); if isgraphics(f), close(f); end
if isempty(traces),return;end
first=traces(1).File;
f=figure('Color','w','Position',[100 100 1550 1100]);tl=tiledlayout(3,3,'Padding','compact');
for wi=1:3,for oi=1:3
 nexttile;idx=find([traces.WindowSeconds]==P.SweepWindowSeconds(wi)& ...
 [traces.Overlap]==P.SweepOverlaps(oi)&string({traces.File})==first,1);
 if isempty(idx),continue;end
 plot(traces(idx).TimeSeconds,traces(idx).Delta(:,2),'k.-');grid on;
 title(sprintf('%g s / %.0f%%',P.SweepWindowSeconds(wi),100*P.SweepOverlaps(oi)));
 xlabel('Time (s)');ylabel('delta');
end,end
ax=findall(f,'Type','axes');linkaxes(ax,'x');
title(tl,['Same physical EEG interval: ' char(first)],'Interpreter','none');
append_pdf_page_v22(f,reportPDF); if isgraphics(f), close(f); end
f=figure('Color','w','Position',[100 100 1500 1050]);tl=tiledlayout(3,3,'Padding','compact');
for wi=1:3,for oi=1:3
 nexttile;idx=find([traces.WindowSeconds]==P.SweepWindowSeconds(wi)& ...
 [traces.Overlap]==P.SweepOverlaps(oi)&string({traces.File})==first,1);
 if isempty(idx),continue;end
 imagesc(abs(traces(idx).CS),[0 1]);axis square;
 xticks(1:4);yticks(1:4);xticklabels(P.SweepChannels);yticklabels(P.SweepChannels);
 title(sprintf('%g s / %.0f%%',P.SweepWindowSeconds(wi),100*P.SweepOverlaps(oi)));
end,end
colorbar;title(tl,['Pilot representative electrodes, NOT five-group network: ' char(first)],'Interpreter','none');
append_pdf_page_v22(f,reportPDF); if isgraphics(f), close(f); end
end

function S=music2_surrogate_null_summary(R,geom,edgeNames,P)
% Summarize the already-computed circular-shift CS null model.
S=table();
for gi=1:size(geom,1)
 for task=0:6
  for e=1:numel(edgeNames)
   z=R(R.WindowSeconds==geom(gi,1)&abs(R.Overlap-geom(gi,2))<1e-12 & R.Task==task & R.Edge==edgeNames{e},:);
   avail=isfinite(z.SurrogateP); pass=isfinite(z.SurrogateQ)&z.SurrogateQ<P.RobustAlpha;
   if any(avail), medp=median(z.SurrogateP(avail)); else, medp=NaN; end
   S=[S;table(geom(gi,1),geom(gi,2),task,string(edgeNames{e}),height(z),sum(avail),sum(pass), ...
    mean(pass(avail),'omitnan'),mean(z.AbsCS,'omitnan'),mean(z.NullMeanAbsCS,'omitnan'),mean(z.Null95AbsCS,'omitnan'),medp, ...
    'VariableNames',{'WindowSeconds','Overlap','Task','Edge','NRows','NSurrogateAvailable','NSurviveFDR', ...
    'FractionSurviveFDR','MeanObservedAbsCS','MeanNullAbsCS','MeanNull95AbsCS','MedianSurrogateP'})]; %#ok<AGROW>
  end
 end
end
end

function C=music2_signed_cs_task_contrasts(R,geom,edgeNames,refTask)
% Matched contrasts in signed CS: CS(task)-CS(reference).
C=table();
for gi=1:size(geom,1),for e=1:numel(edgeNames),for task=1:6
 rr=R(R.WindowSeconds==geom(gi,1)&abs(R.Overlap-geom(gi,2))<1e-12&R.Edge==edgeNames{e}&R.Task==refTask,:);
 aa=R(R.WindowSeconds==geom(gi,1)&abs(R.Overlap-geom(gi,2))<1e-12&R.Edge==edgeNames{e}&R.Task==task,:);
 [~,ir,ia]=intersect(strcat(string(rr.Dyad),'_',string(rr.Musician)),strcat(string(aa.Dyad),'_',string(aa.Musician)));
 x=rr.SignedCS(ir);y=aa.SignedCS(ia);ok=isfinite(x)&isfinite(y);x=x(ok);y=y(ok);
 if numel(x)>=5&&any(y~=x),p=signrank(y,x);else,p=NaN;end
 if isempty(x),md=NaN;else,md=mean(y-x);end
 C=[C;table(geom(gi,1),geom(gi,2),string(edgeNames{e}),task,numel(x),md,p, ...
  'VariableNames',{'WindowSeconds','Overlap','Edge','Task','NMatched','MeanDeltaCS','P'})]; %#ok<AGROW>
end,end,end
C.QwithinEdge=nan(height(C),1);
for gi=1:size(geom,1),for e=1:numel(edgeNames)
 ix=C.WindowSeconds==geom(gi,1)&abs(C.Overlap-geom(gi,2))<1e-12&C.Edge==edgeNames{e};C.QwithinEdge(ix)=music2_bh(C.P(ix));
end,end
end

function C=music2_abs_cs_reference_contrasts(R,geom,edgeNames,refTask,targetTasks,refName)
C=table();
for gi=1:size(geom,1),for e=1:numel(edgeNames),for task=targetTasks
 rr=R(R.WindowSeconds==geom(gi,1)&abs(R.Overlap-geom(gi,2))<1e-12&R.Edge==edgeNames{e}&R.Task==refTask,:);
 aa=R(R.WindowSeconds==geom(gi,1)&abs(R.Overlap-geom(gi,2))<1e-12&R.Edge==edgeNames{e}&R.Task==task,:);
 [~,ir,ia]=intersect(strcat(string(rr.Dyad),'_',string(rr.Musician)),strcat(string(aa.Dyad),'_',string(aa.Musician)));
 x=rr.AbsCS(ir);y=aa.AbsCS(ia);ok=isfinite(x)&isfinite(y);x=x(ok);y=y(ok);
 if numel(x)>=5&&any(y~=x),p=signrank(y,x);else,p=NaN;end
 if isempty(x),md=NaN;else,md=mean(y-x);end
 C=[C;table(geom(gi,1),geom(gi,2),string(edgeNames{e}),task,string(refName),numel(x),md,p, ...
  'VariableNames',{'WindowSeconds','Overlap','Edge','Task','Reference','NMatched','MeanDeltaCS','P'})]; %#ok<AGROW>
end,end,end
C.QwithinEdge=nan(height(C),1);
for gi=1:size(geom,1),for e=1:numel(edgeNames)
 ix=C.WindowSeconds==geom(gi,1)&abs(C.Overlap-geom(gi,2))<1e-12&C.Edge==edgeNames{e};C.QwithinEdge(ix)=music2_bh(C.P(ix));
end,end
end

function OM=music2_network_omnibus_reference(R,geom,edgeNames,P,refTask,targetTasks)
OM=table();
for gi=1:size(geom,1)
 z=R(R.WindowSeconds==geom(gi,1)&abs(R.Overlap-geom(gi,2))<1e-12,:);
 for task=targetTasks
  rr=z(z.Task==refTask,:);aa=z(z.Task==task,:);contexts=unique(strcat(string(rr.Dyad),'_',string(rr.Musician)));
  d=nan(numel(contexts),numel(edgeNames));ids=strings(numel(contexts),1);
  for ci=1:numel(contexts),ids(ci)=contexts(ci);for e=1:numel(edgeNames)
   ix=strcat(string(rr.Dyad),'_',string(rr.Musician))==contexts(ci)&rr.Edge==edgeNames{e};
   iy=strcat(string(aa.Dyad),'_',string(aa.Musician))==contexts(ci)&aa.Edge==edgeNames{e};
   if sum(ix)==1&&sum(iy)==1,a=rr.AbsCS(ix);b=aa.AbsCS(iy);if isfinite(a)&&isfinite(b),d(ci,e)=b-a;end,end
  end,end
  valid=all(isfinite(d),2);d=d(valid,:);ids=ids(valid);dup=(ids=="2_2"|ids=="9_1");if sum(dup)==2,d=[d(~dup,:);mean(d(dup,:),1)];end
  n=size(d,1);effect=NaN;stat=NaN;p=NaN;
  if n>=5&&any(d(:)~=0),effect=norm(mean(d,1));stat=effect^2;rs=RandStream('mt19937ar','Seed',P.OmnibusSeed+7000+gi*101+task);null=nan(P.OmnibusPermutations,1);
   for b=1:P.OmnibusPermutations,sgn=2*(rand(rs,n,1)>.5)-1;null(b)=sum(mean(d.*sgn,1).^2);end;p=(1+sum(null>=stat))/(P.OmnibusPermutations+1);end
  OM=[OM;table(geom(gi,1),geom(gi,2),task,n,effect,stat,p,'VariableNames',{'WindowSeconds','Overlap','Task','NUniqueMusicians','NormMeanDeltaCS','SquaredNetworkStatistic','PermutationP'})]; %#ok<AGROW>
 end
end
OM.QAcrossTasks=nan(height(OM),1);for gi=1:size(geom,1),ix=OM.WindowSeconds==geom(gi,1)&abs(OM.Overlap-geom(gi,2))<1e-12;OM.QAcrossTasks(ix)=music2_bh(OM.PermutationP(ix));end
end

function H=music2_temporal_hf_proxy_control(R,geom,edgeNames)
% Association of task-minus-Rest temporal 30-45 Hz log-power change with
% task-minus-Rest |CS|. Restrict to A-* edges; this is an EEG artifact proxy.
H=table();audEdges=startsWith(string(edgeNames),'A-');ae=string(edgeNames(audEdges));
for gi=1:size(geom,1),for e=1:numel(ae),for task=1:6
 rr=R(R.WindowSeconds==geom(gi,1)&abs(R.Overlap-geom(gi,2))<1e-12&R.Edge==ae(e)&R.Task==0,:);
 aa=R(R.WindowSeconds==geom(gi,1)&abs(R.Overlap-geom(gi,2))<1e-12&R.Edge==ae(e)&R.Task==task,:);
 [~,ir,ia]=intersect(strcat(string(rr.Dyad),'_',string(rr.Musician)),strcat(string(aa.Dyad),'_',string(aa.Musician)));
 dx=aa.TemporalHFLogPower(ia)-rr.TemporalHFLogPower(ir);dy=aa.AbsCS(ia)-rr.AbsCS(ir);ok=isfinite(dx)&isfinite(dy);dx=dx(ok);dy=dy(ok);
 if numel(dx)>=5&&std(dx)>0&&std(dy)>0,rho=music2_sweep_spearman(dx,dy);else,rho=NaN;end
 H=[H;table(geom(gi,1),geom(gi,2),ae(e),task,numel(dx),mean(dx,'omitnan'),mean(dy,'omitnan'),rho, ...
  'VariableNames',{'WindowSeconds','Overlap','Edge','Task','NMatched','MeanDeltaTemporalHFdB','MeanDeltaCS','SpearmanRho'})]; %#ok<AGROW>
end,end,end
end

function OM=music2_network_omnibus(R,geom,edgeNames,P)
% Paired multivariate task-vs-Rest test on ten-edge signed-CS fingerprint.
% Unit of inference is the unique musician, NOT the overlapping delta window.
% D02_M2 and D09_M1 are the same musician; average their paired contrasts.
% Complete ten-edge networks only: fixed dimension avoids changing edge set.
OM=table();
for gi=1:size(geom,1)
 w=geom(gi,1);o=geom(gi,2);
 z=R(R.WindowSeconds==w & abs(R.Overlap-o)<1e-12,:);
 for task=1:6
  rr=z(z.Task==0,:); aa=z(z.Task==task,:);
  contexts=unique(strcat(string(rr.Dyad),'_',string(rr.Musician)));
  d=nan(numel(contexts),numel(edgeNames)); ids=strings(numel(contexts),1);
  for ci=1:numel(contexts)
   cx=contexts(ci);ids(ci)=cx;
   for e=1:numel(edgeNames)
    ix=strcat(string(rr.Dyad),'_',string(rr.Musician))==cx & rr.Edge==edgeNames{e};
    iy=strcat(string(aa.Dyad),'_',string(aa.Musician))==cx & aa.Edge==edgeNames{e};
    if sum(ix)==1 && sum(iy)==1
     a=rr.SignedCS(ix);b=aa.SignedCS(iy);
     if isfinite(a)&&isfinite(b),d(ci,e)=b-a;end
    end
   end
  end
  valid=all(isfinite(d),2);d=d(valid,:);ids=ids(valid);
  % Replace two independently recorded contexts with one musician's mean.
  dup=(ids=="2_2" | ids=="9_1");
  if sum(dup)==2
   dd=mean(d(dup,:),1);d=[d(~dup,:);dd];
  end
  n=size(d,1);effect=NaN;stat=NaN;p=NaN;
  if n>=5 && any(d(:)~=0)
   effect=norm(mean(d,1));stat=effect^2;
   rs=RandStream('mt19937ar','Seed',P.OmnibusSeed+gi*101+task);
   nPerm=P.OmnibusPermutations;null=nan(nPerm,1);
   for b=1:nPerm
    signs=2*(rand(rs,n,1)>.5)-1;
    null(b)=sum(mean(d.*signs,1).^2);
   end
   p=(1+sum(null>=stat))/(nPerm+1);
  end
  OM=[OM;table(w,o,task,n,effect,stat,p, ...
   'VariableNames',{'WindowSeconds','Overlap','Task','NUniqueMusicians', ...
   'NormMeanDeltaCS','SquaredNetworkStatistic','PermutationP'})]; %#ok<AGROW>
 end
end
OM.QAcrossTasks=nan(height(OM),1);
for gi=1:size(geom,1)
 ix=OM.WindowSeconds==geom(gi,1)&abs(OM.Overlap-geom(gi,2))<1e-12;
 OM.QAcrossTasks(ix)=music2_bh(OM.PermutationP(ix));
end
end

function music2_stripe_sensitivity(files,P,OUT,suppPDF)
% Full-cohort, supplementary-only stripe sensitivity at 6.4s/75% overlap.
% Identical raw files, montage, tests, and windows; ONLY StripeWidth changes.
% 0.18 is the central/primary stripe and is taken from the main run.
% The extended 0.05-0.30 grid diagnoses estimator behavior without using
% task significance to choose a stripe.
D=fullfile(OUT,'STRIPE_SIZE_SENSITIVITY');if ~isfolder(D),mkdir(D);end
% The unified driver intentionally passes '' for the legacy supplement PDF.
% Resolve it here so exportgraphics always receives a filename with .pdf.
if nargin<4 || isempty(suppPDF) || (isstring(suppPDF) && strlength(suppPDF)==0)
    suppPDF=fullfile(D,'STRIPE_SENSITIVITY_DIAGNOSTICS.pdf');
end
suppPDF=char(suppPDF);
[~,~,suppExt]=fileparts(suppPDF);
if isempty(suppExt), suppPDF=[suppPDF '.pdf']; end

stripes=P.StripeSweep(:)'; assert(any(abs(stripes-P.StripeWidth)<1e-12), ...
    'Primary stripe must occur in sensitivity grid.');
assert(all(stripes>0 & stripes<1) && numel(unique(stripes))==numel(stripes), ...
    'Stripe grid must contain distinct values between zero and one.');
allC=table();allQ=table();allR=table();
for k=1:numel(stripes)
    sw=stripes(k);
    if abs(sw-P.StripeWidth)<1e-12
        source=fullfile(OUT,'FULL_COHORT_ROBUSTNESS');
        fprintf('STRIPE %g: reusing main cohort results.\n',sw);
    else
        source=fullfile(D,sprintf('STRIPE_%03d',round(sw*1000)));
        if ~isfolder(source),mkdir(source);end
        P2=P;P2.StripeWidth=sw;P2.SweepWindowSeconds=P.SweepWindowSeconds;
        P2.SweepOverlaps=P.SweepOverlaps;P2.GeneratePaperFigures=false;
        P2.RunPLVComparison=false; % PLV is invariant to MDEA stripe width; do not recompute it in stripe-only subruns.
        % The subrun uses the exact same full-cohort estimator/statistical code.
        music2_full_cohort_robustness(files,P2,source,'','');
        source=fullfile(source,'FULL_COHORT_ROBUSTNESS');
    end
    C=readtable(fullfile(source,'SIGNED_CS_MATCHED_TASK_VS_REST_BY_GEOMETRY.csv'));
    Q=readtable(fullfile(source,'ALL_GROUP_QC.csv'));
    R=readtable(fullfile(source,'ALL_EDGES_ALL_GEOMETRIES.csv'));
    % readtable can import text columns as cell arrays, categorical arrays, or
    % strings depending on MATLAB release / CSV contents. Normalize here so
    % all downstream comparisons are type-safe and reproducible.
    if ismember('Edge',C.Properties.VariableNames), C.Edge=string(C.Edge); end
    if ismember('Edge',R.Properties.VariableNames), R.Edge=string(R.Edge); end
    mask=true(height(C),1);
    C=C(mask,:);
    mask=true(height(Q),1);
    Q=Q(mask,:);
    mask=true(height(R),1);
    R=R(mask,:);
    nConfiguredEdges=nchoosek(5,2);
    nTaskContrasts=numel(unique(C.Task));
    expectedContrasts=nConfiguredEdges*nTaskContrasts*numel(P.SweepWindowSeconds)*numel(P.SweepOverlaps);
    assert(height(C)==expectedContrasts, ...
        'Expected %d edge x task x geometry contrasts per stripe for the 5-node network, but found %d.', ...
        expectedContrasts,height(C));
    C.StripeWidth=repmat(sw,height(C),1);
    Q.StripeWidth=repmat(sw,height(Q),1);
    R.StripeWidth=repmat(sw,height(R),1);
    allC=[allC;C];allQ=[allQ;Q];allR=[allR;R]; %#ok<AGROW>
end
writetable(allC,fullfile(D,'STRIPE_MATCHED_TASK_VS_REST.csv'));
writetable(allQ,fullfile(D,'STRIPE_GROUP_FIT_QC.csv'));
writetable(allR,fullfile(D,'STRIPE_ALL_EDGES.csv'));

% -------- STRIPE-CHOICE DIAGNOSTICS (independent of task significance) --------
% Summarize estimator quality across files/tasks/groups. These quantities are
% used to judge whether larger stripes become too coarse/sparse.
Diag=table();
for k=1:numel(stripes)
 sw=stripes(k);
 z=allQ(abs(allQ.StripeWidth-sw)<1e-12,:);
 if isempty(z),continue;end
 medR2=median(z.MeanFitR2,'omitnan');
 q25R2=prctile(z.MeanFitR2(isfinite(z.MeanFitR2)),25);
 q75R2=prctile(z.MeanFitR2(isfinite(z.MeanFitR2)),75);
 meanFinite=mean(z.FiniteFraction,'omitnan');
 medEvents=median(z.MeanEventsPerWindow,'omitnan');
 medEventFrac=median(z.EventFraction,'omitnan');
 medDeltaSD=median(z.DeltaSD,'omitnan');
 fracR2_090=mean(z.MeanFitR2>=.90,'omitnan');
 fracFinite_090=mean(z.FiniteFraction>=.90,'omitnan');
 row=table(sw,height(z),medR2,q25R2,q75R2,meanFinite,medEvents,medEventFrac, ...
     medDeltaSD,fracR2_090,fracFinite_090, ...
     'VariableNames',{'StripeWidth','NGroupRecords','MedianFitR2','FitR2_Q25','FitR2_Q75', ...
     'MeanFiniteFraction','MedianEventsPerWindow','MedianEventFraction','MedianDeltaSD', ...
     'FractionFitR2_GE_090','FractionFinite_GE_090'});
 Diag=[Diag;row]; %#ok<AGROW>
end
% Express event retention and delta variability relative to the central/primary 0.18.
ip=find(abs(Diag.StripeWidth-P.StripeWidth)<1e-12,1);
if ~isempty(ip)
 Diag.EventsRelativeToPrimary=Diag.MedianEventsPerWindow./Diag.MedianEventsPerWindow(ip);
 Diag.EventFractionRelativeToPrimary=Diag.MedianEventFraction./Diag.MedianEventFraction(ip);
 Diag.DeltaSDRelativeToPrimary=Diag.MedianDeltaSD./Diag.MedianDeltaSD(ip);
else
 Diag.EventsRelativeToPrimary=nan(height(Diag),1);
 Diag.EventFractionRelativeToPrimary=nan(height(Diag),1);
 Diag.DeltaSDRelativeToPrimary=nan(height(Diag),1);
end
writetable(Diag,fullfile(D,'STRIPE_CHOICE_DIAGNOSTICS.csv'));
% Transparent manuscript-facing justification for the central stripe.
% IMPORTANT: this rationale deliberately excludes task p-values/significance counts.
ip=find(abs(Diag.StripeWidth-P.StripeWidth)<1e-12,1);
jf=fopen(fullfile(D,'PRIMARY_STRIPE_JUSTIFICATION.txt'),'w');
if jf>=0
 fprintf(jf,'CENTRAL/PRIMARY MDEA STRIPE JUSTIFICATION\n');
 fprintf(jf,'Primary SZ = %.3g. Sensitivity range = %s.\n',P.StripeWidth,mat2str(stripes));
 fprintf(jf,['Selection principle: choose a central operating point with high MDEA fit quality, ', ...
             'near-complete finite scaling estimates, adequate stripe-transition event density, ', ...
             'and preserved delta(t) variability before larger stripes become progressively coarse.\n']);
 fprintf(jf,'Task p-values and counts of significant task effects are NOT selection criteria.\n');
 if ~isempty(ip)
  fprintf(jf,'At primary SZ %.3g: median fit R2 = %.6f; mean finite fraction = %.6f; ', ...
      P.StripeWidth,Diag.MedianFitR2(ip),Diag.MeanFiniteFraction(ip));
  fprintf(jf,'median events/window = %.3f; median event fraction = %.6f; median delta SD = %.6f.\n', ...
      Diag.MedianEventsPerWindow(ip),Diag.MedianEventFraction(ip),Diag.MedianDeltaSD(ip));
 end
 fprintf(jf,['Interpretation: SZ=0.18 is treated as a defensible central operating point, ', ...
             'not as a uniquely optimized value. Robustness across SZ=0.05-0.30 must be reported.\n']);
 fclose(jf);
end
save(fullfile(D,'STRIPE_SWEEP.mat'),'allC','allQ','allR','Diag','P','-v7.3');
edgeNames={'A-F','A-M','A-P','A-O','F-M','F-P','F-O','M-P','M-O','P-O'};
M=nan(numel(edgeNames)*6,numel(stripes));Sig=false(size(M));N=nan(size(M));
for e=1:numel(edgeNames)
 for t=1:6
  row=(e-1)*6+t;
  for k=1:numel(stripes)
   z=allC(strcmp(string(allC.Edge),string(edgeNames{e})) & allC.Task==t & ...
      abs(allC.StripeWidth-stripes(k))<1e-12,:);
   if isempty(z),continue;end
   M(row,k)=z.MeanDeltaCS(1);
   Sig(row,k)=isfinite(z.QwithinEdge(1)) && z.QwithinEdge(1)<P.RobustAlpha;
   N(row,k)=z.NMatched(1);
  end
 end
end
if false % replaced by matched multi-geometry publication figure
f=figure('Color','w','Position',[40 40 1150 1250]);
imagesc(M,[-.30 .30]);colorbar;colormap(parula);
set(gca,'YTick',1:(numel(edgeNames)*6),'YTickLabel',strcat(repelem(string(edgeNames(:)),6), ' / T',string(repmat((1:6)',numel(edgeNames),1))), ...
 'XTick',1:numel(stripes),'XTickLabel',compose('%.3g',stripes));
xlabel('Stripe width (fraction of window-normalized [0,1] range)');
ylabel('Functional connection / task');
title('SUPPLEMENT: Stripe-size sensitivity of matched task-minus-Rest signed CS');
for i=1:size(M,1)
 for k=1:numel(stripes)
  if isfinite(M(i,k))
   if Sig(i,k), mark='S';else,mark='';end
   text(k,i,sprintf('%+.2f%s',M(i,k),mark),'HorizontalAlignment','center', ...
    'FontSize',8,'FontWeight','bold','BackgroundColor','w','Margin',.3);
  end
 end
end
annotation(f,'textbox',[.08 .002 .84 .035],'String', ...
 'S: within-edge BH-FDR q<0.05 across six tasks at that stripe. Same recordings and 6.4-s/75% geometry; not independent tests.', ...
 'EdgeColor','none','HorizontalAlignment','center','FontSize',10);
append_pdf_page_v22(f,suppPDF);close(f);
end
% Numerical QC for stripe choice: deliberately independent of task p-values.
f=figure('Color','w','Position',[40 40 1600 900]);
tl=tiledlayout(2,3,'Padding','compact','TileSpacing','compact');

nexttile;
plot(Diag.StripeWidth,Diag.MedianFitR2,'-o','LineWidth',1.5); hold on;
plot(Diag.StripeWidth,Diag.FitR2_Q25,'--','LineWidth',1);
plot(Diag.StripeWidth,Diag.FitR2_Q75,'--','LineWidth',1);
xline(P.StripeWidth,':',sprintf('Primary %.2f',P.StripeWidth),'LabelVerticalAlignment','bottom');
xlabel('Stripe width');ylabel('MDEA fit R^2');grid on;
title('Fit quality (median and IQR)');

nexttile;
plot(Diag.StripeWidth,Diag.MeanFiniteFraction,'-o','LineWidth',1.5); hold on;
xline(P.StripeWidth,':',sprintf('Primary %.2f',P.StripeWidth),'LabelVerticalAlignment','bottom');
xlabel('Stripe width');ylabel('Finite delta fraction');ylim([0 1.02]);grid on;
title('Estimator success rate');

nexttile;
plot(Diag.StripeWidth,Diag.MedianEventsPerWindow,'-o','LineWidth',1.5); hold on;
xline(P.StripeWidth,':',sprintf('Primary %.2f',P.StripeWidth),'LabelVerticalAlignment','bottom');
xlabel('Stripe width');ylabel('Median events / window');grid on;
title('Stripe-transition event count');

nexttile;
plot(Diag.StripeWidth,Diag.MedianEventFraction,'-o','LineWidth',1.5); hold on;
xline(P.StripeWidth,':',sprintf('Primary %.2f',P.StripeWidth),'LabelVerticalAlignment','bottom');
xlabel('Stripe width');ylabel('Median events / sample');grid on;
title('Event density');

nexttile;
plot(Diag.StripeWidth,Diag.EventsRelativeToPrimary,'-o','LineWidth',1.5); hold on;
yline(1,':'); xline(P.StripeWidth,':',sprintf('Primary %.2f',P.StripeWidth),'LabelVerticalAlignment','bottom');
xlabel('Stripe width');ylabel(sprintf('Events relative to SZ=%.2f',P.StripeWidth));grid on;
title('Event retention vs primary');

nexttile;
plot(Diag.StripeWidth,Diag.DeltaSDRelativeToPrimary,'-o','LineWidth',1.5); hold on;
yline(1,':'); xline(P.StripeWidth,':',sprintf('Primary %.2f',P.StripeWidth),'LabelVerticalAlignment','bottom');
xlabel('Stripe width');ylabel(sprintf('delta SD relative to SZ=%.2f',P.StripeWidth));grid on;
title('Scaling-trajectory variability');

title(tl,['SUPPLEMENT: Stripe-choice diagnostics (NO task p-values used) | ', ...
 'prefer a stable plateau with high fit/finite fraction and adequate event density']);
append_pdf_page_v22(f,suppPDF);close(f);
% Each task: one panel per tested stripe; suppressed in essential-figures mode.
if ~P.EssentialFiguresOnly
labels={'Coord','C&R','Fam','Unfam','Imp','Listen'};
for t=1:6
 f=figure('Color','w','Position',[20 40 max(1750,260*numel(stripes)) 500]);
 tl=tiledlayout(1,numel(stripes),'Padding','compact','TileSpacing','compact');
 for k=1:numel(stripes)
  ax=nexttile;
  z=allC(abs(allC.StripeWidth-stripes(k))<1e-12,:);
  music2_draw_one_geometry_network(ax,z,P.StripeSweepWindowSeconds, ...
      P.StripeSweepOverlap,t,edgeNames);
  title(ax,sprintf('stripe = %.3g',stripes(k)),'FontSize',12);
 end
 title(tl,sprintf('SUPPLEMENT: %s - Rest | stripe sensitivity at 6.4s / 75%%',labels{t}), ...
    'FontSize',16,'FontWeight','bold');
 annotation(f,'textbox',[.08 .002 .84 .04], ...
    'String','SOLID: within-edge FDR q<0.05; DASHED: nonsignificant; pale dotted: unavailable. Label: mean change in |CS|.', ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',10);
 append_pdf_page_v22(f,suppPDF);close(f);
end
end
fid=fopen(fullfile(D,'STRIPE_SWEEP_README.txt'),'w');
fprintf(fid,'Supplement-only stripe sensitivity: widths %s; 6.4 s / 75%% overlap.\n',mat2str(stripes));
fprintf(fid,'Same files, five groups, MDEAcorrected and paired task statistics. Central stripe .18 reused from main run.\n');
fprintf(fid,'No significance-driven parameter selection. S in heatmap = BH-FDR within six tasks per edge and stripe.\n');
fprintf(fid,'PRIMARY ANALYSIS uses stripe 0.18, selected as the central operating point from estimator diagnostics rather than task significance.\n');
fprintf(fid,'Use STRIPE_CHOICE_DIAGNOSTICS.csv and the numerical-QC figure to diagnose stripe choice.\n');
fprintf(fid,'Look for a stable region with high finite-delta fraction and fit R2, adequate stripe-transition event count/density, and stable delta variability.\n');
fprintf(fid,'Stripe 0.18 is justified by estimator diagnostics (fit/finite fraction, event adequacy, and delta variability), NOT by the number of significant task effects.\n');
fprintf(fid,'Large stripes can become too coarse after per-window min-max normalization; event loss is therefore reported relative to the primary 0.18.\n');
fclose(fid);
end

function music2_append_omnibus_page(OM,geom,reportPDF)
% Main Fig. 7: clear 9-geometry x labels, no footnotes inside figure.
f=figure('Color','w','Position',[50 50 1800 1120],'Renderer','painters');
ax=axes(f,'Position',[.10 .23 .78 .63]);
q=nan(6,size(geom,1));n=q;
for gi=1:size(geom,1)
 for t=1:6
  ix=OM.WindowSeconds==geom(gi,1)&abs(OM.Overlap-geom(gi,2))<1e-12&OM.Task==t;
  if any(ix),q(t,gi)=OM.QAcrossTasks(find(ix,1));n(t,gi)=OM.NUniqueMusicians(find(ix,1));end
 end
end
imagesc(ax,-log10(max(q,eps)));colormap(ax,parula);
cb=colorbar(ax);cb.Label.String='-log_{10}(q)';cb.Label.Interpreter='tex';cb.FontSize=12;
set(ax,'YTick',1:6,'YTickLabel',{'Coord','C&R','Fam','Unfam','Imp','Listen'}, ...
 'XTick',1:size(geom,1),'XTickLabel',compose('%g s / %g%%',geom(:,1),100*geom(:,2)), ...
 'XTickLabelRotation',40,'FontSize',13,'TickLabelInterpreter','none');
xlabel(ax,'MDEA window / overlap','FontSize',16,'Interpreter','none');
ylabel(ax,'Musical condition versus Rest','FontSize',16,'Interpreter','none');
title(ax,'Geometry-specific ten-edge network permutation results','FontSize',18,'Interpreter','none');
for t=1:6
 for gi=1:size(geom,1)
  if isfinite(q(t,gi)),lab=sprintf('q=%.3f\nn=%d',q(t,gi),n(t,gi));
  else,lab=sprintf('N/A\nn=%d',n(t,gi));end
  text(ax,gi,t,lab,'HorizontalAlignment','center','VerticalAlignment','middle', ...
   'FontSize',11,'FontWeight','bold','BackgroundColor','w','Margin',1,'Interpreter','none');
 end
end
% Geometry-specific tests are secondary; details are in the manuscript caption.
append_pdf_page_v22(f,reportPDF);if isgraphics(f),close(f);end
end

function music2_export_mdea_method_figure(files,P,mainPDF)
% MAIN Figure M1. Use the user's MDEAcorrected PLOT=1 so the displayed
% entropy curve, fit interval, slope and event construction come from the
% estimator itself rather than a reconstructed plotting routine.
if isempty(files),return;end
made=false;
fileOrder=randperm(numel(files),min(numel(files),6));
for fii=1:numel(fileOrder)
 fi=fileOrder(fii);
 try
  [data,fs,~,loc,~]=read_set_file(fullfile(files(fi).folder,files(fi).name));
  labels=string({loc.labels}); labels=labels(:);
  pref={'F3','Cz','FT7','O1'};
  cand=[];
  for kk=1:numel(pref), hit=find(strcmpi(labels,pref{kk}),1); if ~isempty(hit),cand(end+1)=hit;end,end %#ok<AGROW>
  if isempty(cand),continue;end
  ch=cand(randi(numel(cand)));
  nw=round(P.WindowSeconds*fs); if size(data,2)<nw,continue;end
  maxStart=size(data,2)-nw+1; startSample=randi(maxStart);
  w=double(data(ch,startSample:startSample+nw-1,1));
  before=findall(groot,'Type','figure');
  [d,~]=musicCorrectedMDEAwindow(w,P,1);
  after=findall(groot,'Type','figure'); newF=after(~ismember(after,before));
  if isempty(newF),continue;end
  % If MDEAcorrected creates more than one explanatory figure, retain all:
  % they are method panels generated from the same observed EEG window.
  for jj=numel(newF):-1:1
   f=newF(jj); set(f,'Color','w');
   sgtitle(f,sprintf('Observed MDEA example | %s | %s | SZ=%.2f | \\delta=%.3f', ...
       files(fi).name,labels(ch),P.StripeWidth,d),'Interpreter','none','FontWeight','bold');
   append_pdf_page_v22(f,mainPDF); close(f);
  end
  made=true; break;
 catch ME
  warning('Could not create paper MDEA example from %s: %s',files(fi).name,ME.message);
 end
end
if ~made,warning('No MDEA method figure was generated; inspect MDEAcorrected PLOT=1.');end
end

function music2_append_scaling_example(results,g,names,mainPDF)
% Scaling example is randomly selected from all eligible observed pairs.
% It is illustrative only and does not affect any inferential result.
% MAIN Figure M2. Randomly select one valid observed A-M trajectory pair on each run.
candidates={};
for fi=1:numel(results)
 if isempty(results{fi}),continue;end
 for gi=1:numel(results{fi})
  a=results{fi}{gi}; if isempty(a),continue;end
  if abs(a.WindowSeconds-g(1))>1e-9 || abs(a.Overlap-g(2))>1e-12,continue;end
  x=a.Delta(:,1);y=a.Delta(:,3);ok=isfinite(x)&isfinite(y);
  if sum(ok)<8,continue;end
  r=music2_sweep_spearman(x(ok),y(ok));
  if isfinite(r),candidates{end+1}=struct('a',a,'x',x,'y',y,'r',r);end %#ok<AGROW>
 end
end
if isempty(candidates),return;end
% Independent random draw from all valid observed scaling-pair candidates.
candidateOrder=randperm(numel(candidates));
best=candidates{candidateOrder(1)};
% Use actual sample geometry for time. Each delta estimate is plotted at the
% center of its EEG window: t_k = (windowSamples/2 + k*stepSamples)/Fs.
% This makes the x-axis explicitly consistent with both window size and sample rate.
if isfield(best.a,'Fs') && isfield(best.a,'StepSamples') && isfield(best.a,'WindowSamples') && ...
        isfinite(best.a.Fs) && best.a.Fs>0
    t=((best.a.WindowSamples/2) + (0:numel(best.x)-1)'*best.a.StepSamples)/best.a.Fs;
else
    % Backward-compatible fallback for cached older result structures.
    t=(g(1)/2) + (0:numel(best.x)-1)'*best.a.StepSeconds;
end
f=figure('Color','w','Position',[80 80 1450 760]);ax=axes(f);hold(ax,'on');box(ax,'on');
plot(ax,t,best.x,'LineWidth',2.4);plot(ax,t,best.y,'LineWidth',2.4);
set(ax,'FontSize',15,'LineWidth',1.1);
xlabel(ax,'Time (s)','FontSize',18,'FontWeight','bold');
ylabel(ax,'MDEA scaling exponent, \delta(t)','FontSize',18,'FontWeight','bold');
lg=legend(ax,{names{1},names{3}},'Location','best'); set(lg,'FontSize',15);
title(ax,sprintf('Observed scaling trajectories | A-M CS = %.3f | %.1f s / %.0f%% overlap',best.r,g(1),100*g(2)), ...
    'FontWeight','bold','FontSize',18);
grid(ax,'on');
% Match the plotted support to the centers of the first and last valid windows.
if numel(t)>1, xlim(ax,[t(1) t(end)]); end
append_pdf_page_v22(f,mainPDF); if isgraphics(f), close(f); end
end

function music2_append_rest_network(R,g,edgeNames,mainPDF)
% MAIN Figure M3. Descriptive five-node Rest network at the manuscript geometry.
z=R(R.Task==0 & abs(R.WindowSeconds-g(1))<1e-9 & abs(R.Overlap-g(2))<1e-12,:);
w=nan(numel(edgeNames),1);for e=1:numel(edgeNames),q=z(z.Edge==edgeNames{e},:);w(e)=mean(q.AbsCS,'omitnan');end
pairs=[1 2;1 3;1 4;1 5;2 3;2 4;2 5;3 4;3 5;4 5];
th=linspace(pi/2,pi/2+2*pi,6);th(end)=[];pos=[cos(th(:)) sin(th(:))];
f=figure('Color','w','Position',[80 80 1100 900]);ax=axes(f);hold(ax,'on');axis(ax,'equal');axis(ax,'off');
for e=1:10
 if ~isfinite(w(e)),continue;end;i=pairs(e,1);j=pairs(e,2);lw=.5+6*min(w(e),1);
 plot(ax,pos([i j],1),pos([i j],2),'-','Color',[.18 .18 .18],'LineWidth',lw);
 mid=mean(pos([i j],:),1);text(ax,mid(1),mid(2),sprintf('%.2f',w(e)),'HorizontalAlignment','center','BackgroundColor','w','Margin',1,'FontSize',12);
end
scatter(ax,pos(:,1),pos(:,2),150,'filled','MarkerEdgeColor','k','LineWidth',1,'Tag','KMNetworkNode');
lab={'A','F','M','P','O'};for i=1:5,text(ax,1.18*pos(i,1),1.18*pos(i,2),lab{i},'FontWeight','bold','FontSize',18,'HorizontalAlignment','center');end
title(ax,'Rest: five-node Complexity Synchronization network','FontWeight','bold');xlim(ax,[-1.5 1.5]);ylim(ax,[-1.45 1.45]);
append_pdf_page_v22(f,mainPDF); if isgraphics(f), close(f); end
end

function music2_append_primary_cs_heatmap(C,g,edgeNames,mainPDF)
% MAIN Figure M4. Compact topology summary; stars are intentionally omitted.
M=nan(numel(edgeNames),6);Q=nan(size(M));
for e=1:numel(edgeNames),for t=1:6
 z=C(abs(C.WindowSeconds-g(1))<1e-9 & abs(C.Overlap-g(2))<1e-12 & C.Edge==edgeNames{e} & C.Task==t,:);
 if ~isempty(z),M(e,t)=z.MeanDeltaCS(1); if ismember('QwithinEdge',z.Properties.VariableNames),Q(e,t)=z.QwithinEdge(1);end,end
end,end
f=figure('Color','w','Position',[80 80 1300 900]);ax=axes(f);imagesc(ax,M,[-.30 .30]);clim(ax,[-.30 .30]);axis(ax,'tight');
yticks(ax,1:numel(edgeNames));yticklabels(ax,edgeNames);xticks(ax,1:6);xticklabels(ax,{'Coord','C&R','Fam','Unfam','Imp','Listen'});xtickangle(ax,25);
xlabel(ax,'Musical condition');ylabel(ax,'Five-node CS edge');title(ax,'Rest-referenced CS changes across musical conditions','FontWeight','bold');
cb=colorbar(ax);clim(ax,[-.30 .30]);cb.Ticks=-.30:.10:.30;cb.Label.String='Mean \DeltaCS';cb.Label.Interpreter='tex';cb.Label.FontSize=15.6;
for e=1:size(M,1),for t=1:6,if isfinite(M(e,t)),text(ax,t,e,sprintf('%.2f',M(e,t)),'HorizontalAlignment','center','FontWeight','bold','FontSize',12);end,end,end
append_pdf_page_v22(f,mainPDF); if isgraphics(f), close(f); end
end


function music2_append_compact_primary_cs_networks(C,g,edgeNames,pdfFile)
% Main Fig. 4: six Rest-referenced weighted networks. Method legend belongs
% in the manuscript caption; no bottom annotation can obscure the panels.
labels={'Coordination','Call-response','Familiar','Unfamiliar','Improvisation','Listening'};
f=figure('Color','w','Position',[40 40 2400 1500],'Renderer','painters');
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','loose');
for t=1:6
 ax=nexttile(tl);
 music2_draw_one_geometry_network(ax,C,g(1),g(2),t,edgeNames);
 title(ax,sprintf('%s - Rest',labels{t}),'FontSize',16,'FontWeight','bold','Interpreter','none');
end
title(tl,sprintf('Rest-referenced changes in weighted CS networks | %.1f s / %.0f%% overlap',g(1),100*g(2)), ...
 'FontSize',19,'FontWeight','bold','Interpreter','none');
setappdata(f,'KM_PublicationNetworkFigure',true);
append_pdf_page_v22(f,pdfFile); if isgraphics(f),close(f);end
end

function music2_append_compact_geometry_robustness(C,geom,edgeNames,pdfFile)
% SUPPLEMENT: one 3x3 page showing the complete nine-geometry CS result.
f=figure('Color','w','Position',[40 40 1750 1200]);
tl=tiledlayout(3,3,'Padding','compact','TileSpacing','compact');
for gi=1:size(geom,1)
 ax=nexttile;
 M=nan(numel(edgeNames),6);
 for e=1:numel(edgeNames)
  for t=1:6
   z=C(abs(C.WindowSeconds-geom(gi,1))<1e-9 & abs(C.Overlap-geom(gi,2))<1e-12 & ...
       C.Edge==edgeNames{e} & C.Task==t,:);
   if ~isempty(z),M(e,t)=z.MeanDeltaCS(1);end
  end
 end
 imagesc(ax,M,[-.30 .30]);axis(ax,'tight');
 yticks(ax,1:numel(edgeNames));yticklabels(ax,edgeNames);
 xticks(ax,1:6);xticklabels(ax,{'Coord','C&R','Fam','Unfam','Imp','Listen'});xtickangle(ax,45);
 title(ax,sprintf('%.1f s / %.0f%%',geom(gi,1),100*geom(gi,2)),'FontSize',12);
end
cb=colorbar;cb.Layout.Tile='east';cb.Label.String='Mean \DeltaCS = CS_{task} - CS_{rest}';
title(tl,'Supplement: CS robustness across all nine window/overlap geometries', ...
 'FontSize',18,'FontWeight','bold');
append_pdf_page_v22(f,pdfFile); if isgraphics(f),close(f);end
end

function music2_append_compact_main_conventional(C,Craw,Cplv,g,edgeNames,P,pdfFile)
% Main Fig. 6: use TeX rendering for all Delta/rho notation; retain common
% signed color limits for a fair visual comparison of effect magnitudes.
f=figure('Color','w','Position',[30 30 2400 1550],'Renderer','painters');
tl=tiledlayout(f,2,3,'Padding','compact','TileSpacing','loose');
ax=nexttile(tl); M=music2_metric_matrix_local(C,g,edgeNames,'MeanDeltaCS','');
music2_plot_metric_heat_local(ax,M,edgeNames,'CS: \DeltaCS');
ax=nexttile(tl); M=music2_metric_matrix_local(Craw,g,edgeNames,'MeanDeltaAbsRawEEG','');
music2_plot_metric_heat_local(ax,M,edgeNames,'Raw EEG: \Delta|r|');
for bb=1:numel(P.PLVBandNames)
 ax=nexttile(tl);
 M=music2_metric_matrix_local(Cplv,g,edgeNames,'MeanDeltaPLV',string(P.PLVBandNames{bb}));
 music2_plot_metric_heat_local(ax,M,edgeNames,sprintf('%s PLV: \\DeltaPLV',P.PLVBandNames{bb}));
end
ax=nexttile(tl);hold(ax,'on');box(ax,'on');grid(ax,'on');
a=C(abs(C.WindowSeconds-g(1))<1e-9 & abs(C.Overlap-g(2))<1e-12,:);
rhos=nan(4,1); names={'Raw','Theta PLV','Alpha PLV','Beta PLV'};
b=Craw(abs(Craw.WindowSeconds-g(1))<1e-9 & abs(Craw.Overlap-g(2))<1e-12,:);
rhos(1)=music2_matched_effect_rho_local(a,b,'MeanDeltaCS','MeanDeltaAbsRawEEG','');
for bb=1:3
 b=Cplv(abs(Cplv.WindowSeconds-g(1))<1e-9 & abs(Cplv.Overlap-g(2))<1e-12 & ...
        Cplv.Band==string(P.PLVBandNames{bb}),:);
 rhos(bb+1)=music2_matched_effect_rho_local(a,b,'MeanDeltaCS','MeanDeltaPLV','');
end
bar(ax,1:4,rhos);yline(ax,0,'k:');ylim(ax,[-1 1]);
xticks(ax,1:4);xticklabels(ax,names);xtickangle(ax,20);
ylabel(ax,'Spearman \rho with CS effect','Interpreter','tex');
title(ax,'Effect-pattern correspondence','FontWeight','bold','Interpreter','none');
title(tl,sprintf('CS and conventional EEG connectivity | %.1f s / %.0f%% overlap',g(1),100*g(2)), ...
 'FontSize',19,'FontWeight','bold','Interpreter','none');
append_pdf_page_v22(f,pdfFile); if isgraphics(f),close(f);end
end

function music2_append_compact_spectral_controls(C,Cspec,edgeNames,P,pdfFile)
% SUPPLEMENT: one page for all additional conventional spectral controls.
metrics={'Coherence830','ImagCoherence830','DebiasedWPLI830'};
titles={'Coherence 8-30 Hz','|Imaginary coherence| 8-30 Hz','Debiased wPLI 8-30 Hz'};
f=figure('Color','w','Position',[30 30 1800 1000]);
tl=tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
for mm=1:3
 ax=nexttile;
 M=nan(numel(edgeNames),6);
 for e=1:numel(edgeNames)
  for t=1:6
   z=Cspec(Cspec.Edge==edgeNames{e} & Cspec.Task==t & Cspec.Metric==string(metrics{mm}),:);
   if ~isempty(z),M(e,t)=z.MeanDelta(1);end
  end
 end
 music2_plot_metric_heat_local(ax,M,edgeNames,titles{mm});
end
% Bottom row: direct correspondence with CS for each spectral control.
aa=C(abs(C.WindowSeconds-P.SpectralWindowSeconds)<1e-9 & ...
     abs(C.Overlap-P.SpectralWindowOverlap)<1e-12,:);
for mm=1:3
 ax=nexttile;hold(ax,'on');box(ax,'on');grid(ax,'on');
 bb=Cspec(Cspec.Metric==string(metrics{mm}),:);
 ka=strcat(aa.Edge,'|',string(aa.Task));kb=strcat(bb.Edge,'|',string(bb.Task));
 [~,ia,ib]=intersect(ka,kb);
 x=bb.MeanDelta(ib);y=aa.MeanDeltaCS(ia);ok=isfinite(x)&isfinite(y);x=x(ok);y=y(ok);
 plot(ax,x,y,'o','MarkerSize',5);xline(ax,0,'k:');yline(ax,0,'k:');
 if numel(x)>=5,rho=music2_sweep_spearman(x,y);else,rho=NaN;end
 xlabel(ax,'Conventional task - Rest effect');ylabel(ax,'\Delta CS');
 title(ax,sprintf('%s vs CS, \\rho=%.2f',titles{mm},rho),'FontSize',11);
end
title(tl,sprintf(['Supplement: additional conventional connectivity controls | %.1f s / %.0f%% overlap\n' ...
 'Same five A/F/M/P/O groups; controls are not used to tune CS'], ...
 P.SpectralWindowSeconds,100*P.SpectralWindowOverlap),'FontSize',17,'FontWeight','bold');
append_pdf_page_v22(f,pdfFile); if isgraphics(f),close(f);end
end

function M=music2_metric_matrix_local(T,g,edgeNames,valueVar,band)
M=nan(numel(edgeNames),6);
if isempty(T),return;end
for e=1:numel(edgeNames)
 for t=1:6
  ix=abs(T.WindowSeconds-g(1))<1e-9 & abs(T.Overlap-g(2))<1e-12 & ...
     T.Edge==edgeNames{e} & T.Task==t;
  if strlength(string(band))>0 && ismember('Band',T.Properties.VariableNames)
   ix=ix & T.Band==string(band);
  end
  z=T(ix,:);
  if ~isempty(z) && ismember(valueVar,z.Properties.VariableNames),M(e,t)=z.(valueVar)(1);end
 end
end
end

function music2_plot_metric_heat_local(ax,M,edgeNames,ttl)
% Fixed color limits across CS, Pearson and PLV; visible labels, no clipping.
commonLim=[-.30 .30];
imagesc(ax,M,commonLim);clim(ax,commonLim);axis(ax,'tight');
set(ax,'FontName','Arial','FontSize',14,'TickLabelInterpreter','none');
yticks(ax,1:numel(edgeNames));yticklabels(ax,edgeNames);
xticks(ax,1:6);xticklabels(ax,{'Coord','C&R','Fam','Unfam','Imp','Listen'});xtickangle(ax,35);
title(ax,ttl,'FontWeight','bold','FontSize',15,'Interpreter','tex');
cb=colorbar(ax);cb.Ticks=-.30:.15:.30;cb.FontSize=12;
cb.Label.String='Task - Rest';cb.Label.Interpreter='none';cb.Label.FontSize=12;
end

function rho=music2_matched_effect_rho_local(a,b,varA,varB,band)
rho=NaN;if isempty(a)||isempty(b),return;end
if strlength(string(band))>0 && ismember('Band',b.Properties.VariableNames)
 b=b(b.Band==string(band),:);
end
ka=strcat(a.Edge,'|',string(a.Task));kb=strcat(b.Edge,'|',string(b.Task));
[~,ia,ib]=intersect(ka,kb);
if isempty(ia),return;end
x=a.(varA)(ia);y=b.(varB)(ib);ok=isfinite(x)&isfinite(y);
if sum(ok)>=5,rho=music2_sweep_spearman(x(ok),y(ok));end
end

function music2_write_figure_index(figDir,mainPDF)
% Human-readable map for the deliberately compact manuscript figure pack.
path=fullfile(figDir,'FIGURE_INDEX.txt');fid=fopen(path,'w');if fid<0,return;end
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'ESSENTIAL PUBLICATION FIGURE PACK\n=================================\n');
fprintf(fid,'All figure pages are exported as 600-dpi JPG and vector PDF.\n');
fprintf(fid,'All numerical analyses, CSVs and MAT outputs are still retained.\n\n');
fprintf(fid,'MAIN combined PDF: %s\n',mainPDF);
fprintf(fid,'\nSupplementary figures are generated separately by the V15 supplementary pipeline.\n\n');
fprintf(fid,['MAIN: MDEA estimator/fit example; observed delta(t) CS example; six task-minus-Rest ', ...
 'five-node CS networks on one page; CS edge-by-task heatmap; compact raw-correlation + ', ...
 'theta/alpha/beta PLV comparison; nine-geometry musician-level network omnibus.\n']);
fprintf(fid,'This main-paper script does not generate supplementary figures or stripe-size sweep outputs.\n');
end


function music2_apply_paper_typography(fig)
% Standard typography for publication and pilot/MDEA figures.
% Match the rest of the paper: ticks/legends 11 pt, axis labels 13 pt,
% axes titles 14 pt, overall figure titles 14 pt.
if isempty(fig) || ~isgraphics(fig), return; end
axs=findall(fig,'Type','axes');
for k=1:numel(axs)
    ax=axs(k);
    try, ax.FontSize=13.2; end
    try, ax.XLabel.FontSize=15.6; end
    try, ax.YLabel.FontSize=15.6; end
    try, ax.ZLabel.FontSize=15.6; end
    try, ax.Title.FontSize=16.8; end
end
lg=findall(fig,'Type','legend');
for k=1:numel(lg)
    try, lg(k).FontSize=13.2; end
end
cb=findall(fig,'Type','colorbar');
for k=1:numel(cb)
    try, cb(k).FontSize=12; end
end
% sgtitle/tiled-layout titles are text objects rather than axes titles.
txt=findall(fig,'Type','text');
for k=1:numel(txt)
    try
        if txt(k).FontSize < 11 && ~isappdata(fig,'KM_PublicationNetworkFigure')
            txt(k).FontSize=11;
        end
    end
end
end


function unified_matched_stripe_figures(OUT,P)
% The same nine-geometry MDEA/CS pipeline generated all stripe results.
D=fullfile(OUT,'STRIPE_SIZE_SENSITIVITY');
T=readtable(fullfile(D,'STRIPE_MATCHED_TASK_VS_REST.csv'));
B=readtable(fullfile(OUT,'FULL_COHORT_ROBUSTNESS','SIGNED_CS_MATCHED_TASK_VS_REST_BY_GEOMETRY.csv'));
assert(all(ismember({'StripeWidth','MeanDeltaCS','WindowSeconds','Overlap','Task','Edge'},T.Properties.VariableNames)), ...
    'Matched sweep missing required columns');
C=T(abs(T.StripeWidth-P.StripeWidth)<1e-10,:);
assert(height(C)==height(B),'Central-stripe row count differs from primary analysis');
keys={'WindowSeconds','Overlap','Task','Edge'};
C=sortrows(C,keys);B=sortrows(B,keys);
err=max(abs(C.MeanDeltaCS-B.MeanDeltaCS),[],'omitnan');
assert(isfinite(err)&&err<1e-10,'Primary 0.18 and supplementary 0.18 do not match! Max discrepancy: %.6g',err);
W=unique(T.StripeWidth); W=sort(W);
G=unique(T.WindowSeconds); O=unique(T.Overlap);
assert(numel(G)==3&&numel(O)==3,'Matched sensitivity did not include all nine geometries');
F=fullfile(OUT,'UNIFIED_VALIDATION');if ~isfolder(F),mkdir(F);end
m=nan(numel(W),1); med=nan(numel(W),1);lo=nan(numel(W),1);hi=nan(numel(W),1);n=zeros(numel(W),1);
for k=1:numel(W)
 z=T(abs(T.StripeWidth-W(k))<1e-10,:); v=z.MeanDeltaCS(isfinite(z.MeanDeltaCS));
 n(k)=numel(v);if isempty(v),continue;end
 m(k)=mean(v);med(k)=median(v);lo(k)=min(v);hi(k)=max(v);
end
Summary=table(W,m,med,lo,hi,n,'VariableNames',{'StripeWidth','MeanOfGeometryEdgeTaskMeans','MedianOfGeometryEdgeTaskMeans','MinContrast','MaxContrast','NContrasts'});
writetable(Summary,fullfile(F,'MATCHED_STRIPE_SUMMARY.csv'));
check=table(P.StripeWidth,height(B),height(C),err,numel(G)*numel(O), ...
 'VariableNames',{'ReferenceStripe','NPrimaryContrasts','NMatchedContrasts','MaxAbsoluteDifference','NGeometries'});
writetable(check,fullfile(F,'PRIMARY_SUPPLEMENT_EXACT_MATCH.csv'));
fig=figure('Visible','off','Color','w','Units','pixels','Position',[100 100 1900 1200]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
ax=nexttile;plot(ax,W,m,'-o','LineWidth',2,'MarkerSize',8);hold(ax,'on');
xline(ax,P.StripeWidth,'--','Primary 0.18','LineWidth',1.2,'HandleVisibility','off');
yline(ax,0,':','LineWidth',1,'HandleVisibility','off');grid(ax,'on');
ylabel(ax,'Mean signed \DeltaCS');xlabel(ax,'Stripe width');
title(ax,'Matched nine-geometry signed CS sensitivity (same estimand and analysis)');
ax=nexttile;hold(ax,'on');
geometryHandles=gobjects(numel(G)*numel(O),1); geometryIndex=0;
for gi=1:numel(G)
 for oi=1:numel(O)
  z=nan(size(W));for k=1:numel(W)
   ix=abs(T.StripeWidth-W(k))<1e-10 & T.WindowSeconds==G(gi) & abs(T.Overlap-O(oi))<1e-10;
   z(k)=mean(T.MeanDeltaCS(ix),'omitnan');
  end
  geometryIndex=geometryIndex+1;
  geometryHandles(geometryIndex)=plot(ax,W,z,'-o','LineWidth',1.6,'MarkerSize',5,'DisplayName',sprintf('%.1fs / %g%%',G(gi),O(oi)*100));
 end
end
xline(ax,P.StripeWidth,'--','LineWidth',1.2,'HandleVisibility','off');
yline(ax,0,':','HandleVisibility','off');grid(ax,'on');
xlabel(ax,'Stripe width');ylabel(ax,'Mean signed \DeltaCS');
title(ax,'Geometry-specific sensitivity; geometries are not independent subjects');
legend(ax,geometryHandles(1:geometryIndex),'Location','eastoutside','FontSize',12,'AutoUpdate','off');
set(findall(fig,'Type','axes'),'FontName','Arial','FontSize',11,'LineWidth',1);
name=fullfile(F,'S04_MATCHED_STRIPE_CS');
exportgraphics(fig,[name '.jpg'],'Resolution',600);
exportgraphics(fig,[name '.pdf'],'ContentType','vector');
savefig(fig,[name '.fig']);close(fig);
fid=fopen(fullfile(F,'READ_ME_FIRST.txt'),'w');
fprintf(fid,['MATCHED STRIPE SENSITIVITY\n', ...
 'Central stripe exactly agrees with nine-geometry sensitivity at the same 540 contrasts (verified).\n', ...
 'Means plotted across 540 edge-task-geometry contrasts; these are NOT independent subjects or inferential confidence intervals.\n', ...
 'The original 16-window V15/V16 supplementary CS figure is replaced by this matched figure for publication.\n', ...
 'Other V15 diagnostics (MDEA, survival, renewal) remain separate.\n', ...
 'Do not claim significance/robustness from a descriptive curve alone.\n']);fclose(fid);
end

function unifiedV15Diagnostics()
% No panel-specific interval adjustment; insufficient support is shown as unavailable.
% S01/S03 use concise bold panel labels, matching layout conventions.
% RUN_MUSIC_STRIPE_SUPPLEMENT_V15_FINAL.m
% Requires MDEAcorrected.m and read_set_file.m on MATLAB path.
% RUN_MUSIC_STRIPE_SUPPLEMENT_V15_NO_DECADE.m
% Purpose: independent exponent-fit diagnostics; do not maximize observed CS.
% V10: subject-cluster inference, CS separate, renewal not selection.
% V7: longest supported diagnostic fit is NOT selected to pass R2/mu/span gates.
% Requires read_set_file.m and MDEAcorrected.m on MATLAB path.
% MATLAB R2021b+ recommended. No ginput; no automatically hidden failures.
clc; rng(7);
P=struct;
P.Stripes=[.13:.01:.23 .25 .27]; % measured fine-resolution stripe sweep, includes .15
P.WindowSamples=10000; P.MaxWindows=24; P.MinCSWindows=8;
% More temporal samples in the candidate region; same windows within each width.
P.FocusStripes=P.Stripes; P.FocusMaxWindows=P.MaxWindows; % identical temporal windows
% A single auditory channel is allowed but flagged as reduced spatial robustness.
P.MinAuditoryChannels=1; P.MinSensorimotorChannels=2;
P.RequireMultiChannelConfirmation=true;
P.Rule=1; P.ST=.20; P.EN=.80;
P.MuMin=1;P.MuMax=4;P.MuR2Min=.90; % fitted span is descriptive, never an acceptance gate
P.MuFitMode="manual";P.MuTauStart=2;P.MuTauEnd=20; % FIXED for every survival fit; never optimized per panel
P.MinFitPoints=8;P.MinTauCount=30;P.PsiMin=.02;P.PsiMax=.90;
P.MinCoverage=.70;P.MinValidMuFraction=.40;
P.MinHalfWindows=5; P.MaxHalfDifference=.35; P.MinSplitHalfCoverage=.60;
P.MaxNeighborDeltaChange=.20; P.MaxNeighborCSChange=.20;
P.RestTaskCode='T00'; % VERIFY T00 denotes Rest before interpreting task effects!
P.EnableTaskRest=false; % Enable ONLY after verifying task coding from dataset metadata.
P.UseParallel=true;
P.NumWorkers=0;
P.PreviewFiles=3; P.PreviewStripes=[.15 .18 .22];
P.ReferenceSZ=.18; P.NBootstrap=1000; % manuscript reference; not optimized from task effects
% V12: full EEG-channel renewal audit, subject bootstrap and calibrated controls.
% V13: stratified representative renewal audit; avoid expensive all-channel MDEA.
P.V12AllEEGChannels=false; P.V12PermutationN=99; P.V12ControlN=100;
P.V13RenewalStripes=[.15 .18 .20 .27]; % sensitivity, not selection
P.V13MaxRecordingsPerSubjectTask=1;
P.V13MaxChannelsPerRecording=2; % one auditory + one central/sensorimotor
P.V13MaxSamples=60000; % first continuous ~195 s at 512 Hz
P.V13MaxRenewalIntervals=3000; % subsample for permutation only, preserve ordering
P.V13RenewalSeed=20261021;
P.V12MinIntervals=150; P.V12ControlMaxIntervals=800;
P.V12FiveNodeCS=true; P.V12FiveNodeWindows=16; P.V12FiveNodeMaxChannelsPerGroup=2;
P.FactorialStripes=[.15 .18 .20 .22 .27]; % matched broad factorial subset
P.FiveNodeStripes=P.FactorialStripes; % avoids 13x expensive five-node pass
% Tail-model comparison: one representative matched window/channel per recording and stripe.
P.ModelTailQuantile=.25; P.ModelMinTailN=30; P.ModelCompareEnabled=true;
P.Auditory=["FT7","FT8","T7","T8","TP7","TP8"];
P.Sensorimotor=["FC1","FC2","FC3","FC4","C1","C2","C3","C4","C5","C6","Cz"];
P.MinGroupChannels=2; % legacy; use group-specific minima below
P.MaxChannelsA=4;
P.MaxChannelsM=5;
assert(exist('read_set_file','file')==2,'Missing read_set_file.m');
assert(exist('MDEAcorrected','file')==2,'Missing MDEAcorrected.m');
home=getenv('USERPROFILE');if isempty(home),home=getenv('HOME');end
preferred=fullfile(home,'Downloads','DOD SAFE-xKR6BUC6jggTkZpQ','DOD SAFE-xKR6BUC6jggTkZpQ','EEG');
roots={preferred,fullfile(home,'Downloads'),fullfile(home,'Desktop'),pwd};files=[];
for j=1:numel(roots)
 if ~isfolder(roots{j}),continue;end
 files=dir(fullfile(roots{j},'D*_B*_T*_ICApruned.set'));
 if isempty(files),files=dir(fullfile(roots{j},'**','D*_B*_T*_ICApruned.set'));end
 if ~isempty(files),break;end
end
assert(~isempty(files),'EEG .set files not found');
[~,ii]=sort({files.name});files=files(ii); nF=numel(files);nS=numel(P.Stripes);
outbase=fullfile(home,'Downloads');if ~isfolder(outbase),outbase=pwd;end
OUT=fullfile(outbase,['MUSIC_STRIPE_SUPPLEMENT_V15_PATCHED_' datestr(now,'yyyymmdd_HHMMSS')]);mkdir(OUT);
fprintf('Found %d recordings, %d stripe widths.\n',nF,nS);
%% Visual preflight of the EXACT MDEA and mu estimators used in batch.
% No ginput. Figures stay open while user reviews. Preflight never silently accepts.
accepted=false;
while ~accepted
 f=figure('Visible','on','Color','w','Name','Preflight: MDEA entropy fits',...
  'Units','normalized','Position',[.05 .07 .88 .82]);
 t=tiledlayout(f,P.PreviewFiles,numel(P.PreviewStripes),'TileSpacing','loose','Padding','loose');
 title(t,'MDEA scaling and approved fit regions','FontSize',17,'FontWeight','bold');
 xlabel(t,'Lag l (log scale)','FontSize',16,'FontWeight','bold');
 ylabel(t,'Diffusion entropy S(l)','FontSize',16,'FontWeight','bold');
 title(t,sprintf('Entropy scaling: ST %.2f EN %.2f. Verify red fitted segment.',P.ST,P.EN));
 for e=1:P.PreviewFiles
  fi=max(1,min(nF,round(1+(e-1)*(nF-1)/max(1,P.PreviewFiles-1))));
  [X,~,labels]=loadEEG(fullfile(files(fi).folder,files(fi).name));
  ch=find(ismember(lower(labels),lower(P.Auditory)),1);
  if isempty(ch),ch=1;end
  W=min(size(X,2),P.WindowSamples);a=max(1,round((size(X,2)-W)*e/(P.PreviewFiles+1)));
  for si=1:numel(P.PreviewStripes)
   ax=nexttile(t);hold(ax,'on');sz=P.PreviewStripes(si);
   try
    [d,info]=MDEAcorrected(X(ch,a:a+W-1),sz,P.Rule,P.ST,P.EN,0);
    if isstruct(info)&&isfield(info,'LogLag')&&isfield(info,'Entropy')
     xx=double(info.LogLag(:));yy=double(info.Entropy(:));g=isfinite(xx)&isfinite(yy);
     % Info.LogLag is log10(lag); display physical lag on logarithmic x-axis.
     lag=10.^xx;
     semilogx(ax,lag(g),yy(g),'k.-','MarkerSize',5);
     xlabel(ax,'');ylabel(ax,'');
     if isfield(info,'FitMask')&&numel(info.FitMask)==numel(xx)
      use=logical(info.FitMask(:))&g;
     else
      use=false(size(xx));lo=max(1,round(P.ST*numel(xx)));hi=min(numel(xx),round(P.EN*numel(xx)));
      use(lo:hi)=true;use=use&g;
     end
     if nnz(use)>=2
      % Render one continuous fitted segment across the observed fit bounds.
      % FitMask can be noncontiguous; plotting only masked points created
      pp=polyfit(xx(use),yy(use),1);
      xfit=linspace(min(xx(use)),max(xx(use)),200);
      semilogx(ax,10.^xfit,polyval(pp,xfit),'b-','LineWidth',2);
      xline(ax,min(lag(use)),'r--','LineWidth',1.2);
      xline(ax,max(lag(use)),'r--','LineWidth',1.2);
     end
     title(ax,sprintf('SZ %.3f | \delta %.3f',sz,d),'FontSize',13,'FontWeight','bold');
    else
     text(ax,.05,.5,'No Info.LogLag/Entropy','Units','normalized');
    end
   catch ME
    text(ax,.05,.5,ME.message,'Units','normalized','FontSize',7,'Interpreter','none');
   end
   grid(ax,'on');set(ax,'XScale','log','FontSize',11,'FontName','Arial');
  end
 end
 drawnow;choice=questdlg('Approve MDEA ST/EN fits?','MDEA preflight','Accept','Change','Abort','Accept');
 if strcmp(choice,'Abort')||isempty(choice),error('User cancelled MDEA preflight');end
 if strcmp(choice,'Accept')
  accepted=true;
  v14SavePreflight(f,OUT,'SUPP_S1_REPRESENTATIVE_MDEA_FITS');
 else
  a=inputdlg({'ST fraction','EN fraction'},'MDEA fitting limits',[1 40],{num2str(P.ST),num2str(P.EN)});
  if ~isempty(a),st=str2double(a{1});en=str2double(a{2});
   if isfinite(st)&&isfinite(en)&&st>=0&&en<=1&&st<en,P.ST=st;P.EN=en;else,warndlg('Require 0<=ST<EN<=1');end
  end
 end
 if isgraphics(f),close(f);end
end
% Mu preflight: inspect true log-log survival curves. Red dashed boundaries
% are unlabeled; mu is annotated beside the fitted blue line.
% Fixed [2,20] fit is used in both preview and batch; user may accept or abort.
acceptedMu=false;
while ~acceptedMu
 f=figure('Visible','on','Color','w','Name','Preflight: survival exponent fits',...
  'Units','normalized','Position',[.05 .07 .88 .82]);
 t=tiledlayout(f,P.PreviewFiles,numel(P.PreviewStripes),'TileSpacing','loose','Padding','loose');
 title(t,'Survival exponent fits (fixed fitting interval: 2-20 samples)','FontSize',17,'FontWeight','bold');
 xlabel(t,'Waiting time \tau (log scale)','FontSize',16,'FontWeight','bold');
 ylabel(t,'Survival \Psi(\tau)','FontSize',16,'FontWeight','bold');
 for e=1:P.PreviewFiles
  fi=max(1,min(nF,round(1+(e-1)*(nF-1)/max(1,P.PreviewFiles-1))));
  [X,~,labels]=loadEEG(fullfile(files(fi).folder,files(fi).name));
  ch=find(ismember(lower(labels),lower(P.Auditory)),1);if isempty(ch),ch=1;end
  W=min(size(X,2),P.WindowSamples);a=max(1,round((size(X,2)-W)*e/(P.PreviewFiles+1)));
  for si=1:numel(P.PreviewStripes)
   ax=nexttile(t);hold(ax,'on');sz=P.PreviewStripes(si);
   try
    [~,info]=MDEAcorrected(X(ch,a:a+W-1),sz,P.Rule,P.ST,P.EN,0);
    tau=getTau(info);[mu,r2,lo,hi,npt,span]=muFit(tau,P);
    [u,psi]=survivalPoints(tau);
    if ~isempty(u),loglog(ax,u,psi,'k.-','MarkerSize',5);end
    % Preview is constrained to the same fixed [2,20] interval; it never changes fit boundaries.
    % This visual-only fallback never counts as a valid batch exponent.
    previewMu=mu;previewR2=r2;previewLo=lo;previewHi=hi;
    if ~isfinite(mu)
     [previewMu,previewR2,previewLo,previewHi]=muPreviewFit(tau,P);
    end
    if isfinite(previewMu)
     use=u>=previewLo&u<=previewHi&psi>0;
     if nnz(use)>=2
      q=polyfit(log10(u(use)),log10(psi(use)),1);
      % Continuous fitted line; no white annotation boxes obscuring data.
      xfit=linspace(log10(P.MuTauStart),log10(P.MuTauEnd),200);
      loglog(ax,10.^xfit,10.^polyval(q,xfit),'b-','LineWidth',2);
      xline(ax,P.MuTauStart,'r--','LineWidth',1.1);
      xline(ax,P.MuTauEnd,'r--','LineWidth',1.1);
     end
    end
    valid=isfinite(mu)&&mu>P.MuMin&&mu<P.MuMax&&r2>=P.MuR2Min;
    if valid,status='PASS';else,status='NOT VALID';end
    if isfinite(previewMu)
     title(ax,sprintf('SZ %.3f | \mu %.2f | R^2 %.3f | %s',sz,previewMu,previewR2,status), ...
       'FontSize',12,'FontWeight','bold');
    else
     title(ax,sprintf('SZ %.3f | fit unavailable | %s',sz,status),'FontSize',12,'FontWeight','bold');
    end
   catch ME
    text(ax,.05,.5,ME.message,'Units','normalized','Interpreter','none','FontSize',7);
   end
   grid(ax,'on');set(ax,'XScale','log','YScale','log','FontSize',11,'FontName','Arial');
   xlabel(ax,'');ylabel(ax,'');
  end
 end
 drawnow;
 choice=questdlg('Accept the FIXED tau [2,20] fit rule, or abort?',...
  'Exponent preflight','Accept','Abort','Accept');
 if strcmp(choice,'Accept')
  acceptedMu=true;
  v14SavePreflight(f,OUT,'SUPP_S1_REPRESENTATIVE_SURVIVAL_FITS');
 else
  if isgraphics(f),close(f);end
  error('User cancelled exponent preflight');
 end
 if isgraphics(f),close(f);end
end
%% Freeze approved fitting settings and prevent silent mismatch.
fitSettings=table(string(P.MuFitMode),P.MuTauStart,P.MuTauEnd,P.MuR2Min,P.MinFitPoints,P.PsiMin,P.PsiMax,...
 'VariableNames',{'Mode','TauStartSamples','TauEndSamples','R2Threshold','MinUniqueTau','PsiMin','PsiMax'});
writetable(fitSettings,fullfile(OUT,'APPROVED_SURVIVAL_FIT_SETTINGS.csv'));
fprintf('APPROVED survival fit: %s, tau [%g,%g], R2 >= %.3f (no span gate)\n',char(P.MuFitMode),P.MuTauStart,P.MuTauEnd,P.MuR2Min);
%% One overall progress bar; parfor runs only after GUI preflights.
results=cell(nF,1);h=[]; % no separate GUI progress bar for preliminary stage
canParallel=P.UseParallel&&license('test','Distrib_Computing_Toolbox');
if canParallel
 try
  pool=gcp('nocreate');if isempty(pool)
   if P.NumWorkers>0,pool=parpool('local',P.NumWorkers);else,pool=parpool('local');end
  end
  dq=parallel.pool.DataQueue;afterEach(dq,@(~) progressUpdate(h,nF));
  parfor fi=1:nF
   results{fi}=processRecording(files(fi),P);send(dq,fi);
  end
 catch ME
  if isgraphics(h),close(h);end
  rethrow(ME); % Never silently rerun a potentially multi-hour analysis.
 end
else
 for fi=1:nF
  results{fi}=processRecording(files(fi),P);progressUpdate(h,nF);
 end
end
if isgraphics(h),close(h);end
R=vertcat(results{:});assert(~isempty(R),'No recording results');
writetable(R,fullfile(OUT,'RECORDING_STRIPE_RESULTS.csv'));
%% Explicit coverage / failure accounting, including short recordings.
S=table(P.Stripes(:),'VariableNames',{'StripeWidth'});
S.NRecordings=repmat(nF,nS,1);
cols={'CS','MuValidFraction','MeanDelta','VarDelta','ValidWindowFraction','ValidMuMedian','NValidCSWindows','MuFiniteFraction','MuR2PassFraction','MuSpanPassFraction','MuRangePassFraction','CSFirstHalf','CSSecondHalf','CSHalfDifference','CSHalfValid','MedianTauCount','MedianFitPoints','MedianFitDecades','MedianFitR2','MuInsufficientEventsFraction','MuInsufficientPointsFraction','MuFitEstimableFraction',...
  'TailN','TailXmin','TailParetoMu','TailWeibullShape','TailAICPower','TailAICExponential','TailAICWeibull','TailDeltaAICPower'};
for j=1:numel(cols)
 S.(['Median' cols{j}])=nan(nS,1);S.(['N' cols{j}])=zeros(nS,1);
end
S.CSCoverage=zeros(nS,1);S.MuCoverage=zeros(nS,1);S.ShortCount=zeros(nS,1);
S.MissingChannelCount=zeros(nS,1);S.InsufficientWindowCount=zeros(nS,1);S.MDEAFailureCount=zeros(nS,1);
S.SplitHalfCoverage=zeros(nS,1); S.SplitHalfMedianDifference=nan(nS,1);
S.SingleAuditoryCSFraction=nan(nS,1);S.MultiAuditoryCSCoverage=nan(nS,1);S.NMultiAuditory=zeros(nS,1);
for si=1:nS
 z=R(abs(R.StripeWidth-P.Stripes(si))<1e-10,:);
 for j=1:numel(cols)
  v=z.(cols{j});
  assert(isnumeric(v) || islogical(v), 'Non-numeric summary column: %s', cols{j});
  g=isfinite(v);
  if any(g), S.(['Median' cols{j}])(si)=median(v(g),'omitnan'); end
  S.(['N' cols{j}])(si)=nnz(g);
 end
 S.CSCoverage(si)=mean(isfinite(z.CS));
 S.SplitHalfCoverage(si)=mean(z.CSHalfValid);
 S.SplitHalfMedianDifference(si)=median(z.CSHalfDifference,'omitnan');
 multi=z.NChannelsA>=2;S.NMultiAuditory(si)=nnz(multi);
 if any(multi),S.MultiAuditoryCSCoverage(si)=mean(isfinite(z.CS(multi)));end
 if any(isfinite(z.CS)),S.SingleAuditoryCSFraction(si)=mean(z.SingleAuditory(isfinite(z.CS)));end
 S.MuCoverage(si)=mean(z.MuValidFraction>=P.MinValidMuFraction);
 S.ShortCount(si)=nnz(z.Reason=="short_recording");
 S.MissingChannelCount(si)=nnz(z.Reason=="missing_channels");
 S.InsufficientWindowCount(si)=nnz(z.Reason=="insufficient_windows");
 S.MDEAFailureCount(si)=sum(z.MDEAFailures);
end
%% Paired signed Task - Rest (descriptive). Rest code must be verified by user.
TaskPairs=table();TaskSummary=table();
if P.EnableTaskRest
 pairRows=cell(0,1);
 for si=1:nS
  z=R(abs(R.StripeWidth-P.Stripes(si))<1e-10,:);
  subjects=unique(z.Subject);
  for a=1:numel(subjects)
   zz=z(z.Subject==subjects(a),:);
   rest=zz(zz.Task==string(P.RestTaskCode)&isfinite(zz.CS),:);
   if isempty(rest),continue;end
   taskCodes=unique(zz.Task(zz.Task~=string(P.RestTaskCode)));
   for b=1:numel(taskCodes)
    task=zz(zz.Task==taskCodes(b)&isfinite(zz.CS),:);
    if isempty(task),continue;end
    % Subject-level medians avoid treating blocks as independent subjects.
    pairRows{end+1,1}=table(subjects(a),taskCodes(b),P.Stripes(si), ...
      median(task.CS)-median(rest.CS),median(rest.CS),median(task.CS), ...
      'VariableNames',{'Subject','Task','StripeWidth','SignedDeltaCS','RestCS','TaskCS'}); %#ok<SAGROW>
   end
  end
 end
 if ~isempty(pairRows),TaskPairs=vertcat(pairRows{:});end
 if ~isempty(TaskPairs)
  tasks=unique(TaskPairs.Task);tmp=cell(nS*numel(tasks),1);kk=0;
  for si=1:nS
   for ti=1:numel(tasks)
    z=TaskPairs(TaskPairs.Task==tasks(ti)&abs(TaskPairs.StripeWidth-P.Stripes(si))<1e-10,:);
    kk=kk+1;tmp{kk}=table(P.Stripes(si),tasks(ti),height(z),median(z.SignedDeltaCS,'omitnan'),...
      'VariableNames',{'StripeWidth','Task','NSubjects','MedianSignedDeltaCS'});
   end
  end
  TaskSummary=vertcat(tmp{:});
 end
end
if ~isempty(TaskPairs),writetable(TaskPairs,fullfile(OUT,'PAIRED_SIGNED_TASK_MINUS_REST.csv'));end
if ~isempty(TaskSummary),writetable(TaskSummary,fullfile(OUT,'TASK_EFFECT_SUMMARY.csv'));end
%% Paired-width stability: compare only recordings with finite results at both widths.
% Valid-mu fit span is reported separately; it is NOT a hard gate because
% coarser stripe widths can mechanically create longer waiting-time support.
S.PairedCSChange=nan(nS,1); S.PairedDeltaChange=nan(nS,1);
for si=1:nS
 neigh=setdiff(max(1,si-1):min(nS,si+1),si);
 changesCS=[];changesD=[];
 for sj=neigh
  zi=R(abs(R.StripeWidth-P.Stripes(si))<1e-10,:);
  zj=R(abs(R.StripeWidth-P.Stripes(sj))<1e-10,:);
  [~,ia,ib]=intersect(zi.File,zj.File,'stable');
  ok=isfinite(zi.CS(ia))&isfinite(zj.CS(ib));
  changesCS=[changesCS;abs(zi.CS(ia(ok))-zj.CS(ib(ok)))]; %#ok<AGROW>
  ok=isfinite(zi.MeanDelta(ia))&isfinite(zj.MeanDelta(ib));
  changesD=[changesD;abs(zi.MeanDelta(ia(ok))-zj.MeanDelta(ib(ok)))./max(.05,abs(zi.MeanDelta(ia(ok))))]; %#ok<AGROW>
 end
 S.PairedCSChange(si)=median(changesCS,'omitnan');
 S.PairedDeltaChange(si)=median(changesD,'omitnan');
end
S.PassCSCoverage=S.CSCoverage>=P.MinCoverage;
S.PassSplitHalf=S.SplitHalfCoverage>=P.MinSplitHalfCoverage & ...
 S.SplitHalfMedianDifference<=P.MaxHalfDifference;
S.PassPairedStability=S.PairedCSChange<=P.MaxNeighborCSChange & ...
 S.PairedDeltaChange<=P.MaxNeighborDeltaChange;
S.PassMuQuality=S.MedianMuR2PassFraction>=.40 & S.MedianMuRangePassFraction>=.40;
S.MuSpanAvailability=S.MedianMuSpanPassFraction; % descriptive, not a gate
S.MultiChannelConfirmed=false(nS,1);
for si=1:nS
 z=R(abs(R.StripeWidth-P.Stripes(si))<1e-10 & R.NChannelsA>=2,:);
 if height(z)>=10
  S.MultiChannelConfirmed(si)=mean(isfinite(z.CS))>=P.MinCoverage && ...
   mean(z.CSHalfValid)>=P.MinSplitHalfCoverage;
 end
end
% Stripe selection must NOT depend on CS magnitude, CS availability,
% CS split-half reliability, renewal statistics or AIC model preference.
% Use only MDEA exponent fit quality and stability of delta estimates.
S.PassDeltaStability=S.PairedDeltaChange<=P.MaxNeighborDeltaChange;
S.Reasonable=S.PassMuQuality & S.PassDeltaStability;
% Other flags remain in CSV for descriptive sensitivity analysis only.
S.Decision=repmat("insufficient_evidence",nS,1);
S.Decision(S.Reasonable)="reasonable_candidate";
S.Decision(S.PassCSCoverage&S.PassSplitHalf&S.PassPairedStability&S.PassMuQuality & ...
 ~S.MultiChannelConfirmed)="provisional_single_channel_support";
writetable(S,fullfile(OUT,'STRIPE_DECISION_SUMMARY.csv'));
% Explicit audit of channel labels/eligibility, including previously excluded files.
channelAudit=unique(R(:,{'File','Subject','Task','NChannelsA','NChannelsM','SingleAuditory'}),'rows');
writetable(channelAudit,fullfile(OUT,'CHANNEL_ELIGIBILITY_AUDIT.csv'));
% Export candidate-focused subset for inspection without rerunning analysis.
focusMask=ismembertol(R.StripeWidth,P.FocusStripes,1e-8);
writetable(R(focusMask,:),fullfile(OUT,'FOCUS_STRIPE_RECORDING_RESULTS.csv'));
% Exponent QC: these distinct fractions identify the failed gate.
qc=S(:,{'StripeWidth','MedianMuFiniteFraction','MedianMuR2PassFraction','MedianMuSpanPassFraction','MedianMuRangePassFraction','MedianMuValidFraction','MuCoverage','MedianMedianTauCount','MedianMedianFitPoints','MedianMedianFitDecades','MedianMedianFitR2','MedianMuInsufficientEventsFraction','MedianMuInsufficientPointsFraction','MedianMuFitEstimableFraction'});
writetable(qc,fullfile(OUT,'MU_FIT_QC_BY_STRIPE.csv'));
modelRows=R(:,{'File','Subject','Task','StripeWidth','TailN','TailXmin','TailParetoMu','TailWeibullShape','TailAICPower','TailAICExponential','TailAICWeibull','TailBestModel','TailDeltaAICPower'});
writetable(modelRows,fullfile(OUT,'TAIL_MODEL_COMPARISON_BY_RECORDING.csv'));
ModelSummary=table(P.Stripes(:),'VariableNames',{'StripeWidth'});
ModelSummary.NCompared=zeros(nS,1);ModelSummary.PowerPreferred=zeros(nS,1);
ModelSummary.ExponentialPreferred=zeros(nS,1);ModelSummary.WeibullPreferred=zeros(nS,1);
ModelSummary.MedianDeltaAICPower=nan(nS,1);ModelSummary.MedianTailN=nan(nS,1);
for si=1:nS
 z=R(abs(R.StripeWidth-P.Stripes(si))<1e-10,:);valid=isfinite(z.TailDeltaAICPower);
 ModelSummary.NCompared(si)=nnz(valid);
 if any(valid)
  b=z.TailBestModel(valid);ModelSummary.PowerPreferred(si)=mean(b=="power_law");
  ModelSummary.ExponentialPreferred(si)=mean(b=="exponential");
  ModelSummary.WeibullPreferred(si)=mean(b=="weibull");
  ModelSummary.MedianDeltaAICPower(si)=median(z.TailDeltaAICPower(valid));
  ModelSummary.MedianTailN(si)=median(z.TailN(valid));
 end
end
writetable(ModelSummary,fullfile(OUT,'TAIL_MODEL_COMPARISON_SUMMARY.csv'));
% Independently auditable event support and fitting-quality statistics.
writetable(R(:,{'File','StripeWidth','MedianTauCount','MedianFitPoints',...
 'MedianFitDecades','MedianFitR2','MuInsufficientEventsFraction',...
 'MuInsufficientPointsFraction','MuFitEstimableFraction','MuR2PassFraction',...
 'MuSpanPassFraction','MuRangePassFraction','MuValidFraction'}),...
 fullfile(OUT,'MU_FIT_RECORDING_DIAGNOSTICS.csv'));
%% Figures: only saved, no batch popups. Separate renewal not re-run.
F=figure('Visible','off','Color','w','Position',[100 100 1500 520]);
t=tiledlayout(F,1,3,'TileSpacing','compact','Padding','compact');
ax=nexttile(t);plot(ax,S.StripeWidth,S.MedianValidMuMedian,'o-');hold(ax,'on');
yline(ax,P.MuMin,'--');yline(ax,P.MuMax,'--');
xlabel(ax,'Stripe width');ylabel(ax,'Median estimated \mu');title(ax,'A. Exponent plausibility');grid(ax,'on');
ax=nexttile(t);plot(ax,S.StripeWidth,S.MedianMedianFitR2,'o-');hold(ax,'on');
yline(ax,P.MuR2Min,'--');xlabel(ax,'Stripe width');ylabel(ax,'Median R^2');
title(ax,'B. Fit quality');grid(ax,'on');
ax=nexttile(t);plot(ax,S.StripeWidth,S.MedianMedianFitDecades,'o-');hold(ax,'on');
xlabel(ax,'Stripe width');ylabel(ax,'Median fitted decades (descriptive only)');
title(ax,'C. Fit support');grid(ax,'on');
title(t,'S2 | Stripe-width fitting diagnostics (CS excluded from selection)','FontSize',12);
for aa=findobj(F,'Type','axes')'
 xline(aa,P.ReferenceSZ,':','Color',[.25 .25 .25],'LineWidth',1.2);
 set(aa,'FontSize',10,'LineWidth',1,'Box','off');
end
exportgraphics(F,fullfile(OUT,'SUPP_STRIPE_FIT_DIAGNOSTICS.pdf'),'ContentType','vector');
mainPdf=fullfile(OUT,'ALL_FIGURES.pdf');
exportgraphics(F,mainPdf,'ContentType','vector');
exportgraphics(F,fullfile(OUT,'SUPP_STRIPE_FIT_DIAGNOSTICS.jpg'),'Resolution',600);
savefig(F,fullfile(OUT,'SUPP_STRIPE_FIT_DIAGNOSTICS.fig'));close(F);
F=figure('Visible','off','Color','w','Position',[100 100 1400 500]);
t=tiledlayout(F,1,3,'TileSpacing','compact','Padding','compact');
ax=nexttile(t);plot(ax,S.StripeWidth,S.MedianMeanDelta,'o-','LineWidth',1.5);
xlabel(ax,'Stripe width');ylabel(ax,'Median MDEA delta');title(ax,'A. Measured diffusion-entropy exponent');grid(ax,'on');
ax=nexttile(t);plot(ax,S.StripeWidth,S.PairedDeltaChange,'o-','LineWidth',1.5);
yline(ax,P.MaxNeighborDeltaChange,'--');xlabel(ax,'Stripe width');ylabel(ax,'Median matched neighbor relative delta change');title(ax,'B. Delta stability');grid(ax,'on');
ax=nexttile(t);plot(ax,S.StripeWidth,S.MedianValidWindowFraction,'o-','LineWidth',1.5);
xlabel(ax,'Stripe width');ylabel(ax,'Median fraction finite MDEA windows');ylim(ax,[0 1]);title(ax,'C. MDEA availability');grid(ax,'on');
for aa=findobj(F,'Type','axes')'
 xline(aa,P.ReferenceSZ,':','Color',[.25 .25 .25],'LineWidth',1.2);
 set(aa,'FontSize',10,'LineWidth',1,'Box','off');
end
title(t,'S2b | Direct MDEA delta sensitivity (no survival-based selection)','FontSize',12);
exportgraphics(F,fullfile(OUT,'SUPP_MDEA_DELTA_SENSITIVITY.pdf'),'ContentType','vector');
exportgraphics(F,mainPdf,'ContentType','vector','Append',true);
exportgraphics(F,fullfile(OUT,'SUPP_MDEA_DELTA_SENSITIVITY.jpg'),'Resolution',600);
savefig(F,fullfile(OUT,'SUPP_MDEA_DELTA_SENSITIVITY.fig'));close(F);
if ~isempty(TaskSummary)
 F=figure('Visible','off','Color','w','Position',[100 100 1000 600]);hold on;
 tasks=unique(TaskSummary.Task);
 for i=1:numel(tasks)
  z=TaskSummary(TaskSummary.Task==tasks(i),:);
  plot(z.StripeWidth,z.MedianSignedDeltaCS,'o-','DisplayName',char(tasks(i)));
 end
 yline(0,'k--');xlabel('Stripe width');ylabel('Signed \Delta CS = CS_{task}-CS_{rest}');
 title(sprintf('Paired subject-level effects; VERIFY %s is Rest',P.RestTaskCode));legend('Location','best');grid on;
 exportgraphics(F,fullfile(OUT,'SIGNED_TASK_REST_EFFECTS.pdf'),'ContentType','vector');
 exportgraphics(F,fullfile(OUT,'SIGNED_TASK_REST_EFFECTS.jpg'),'Resolution',600);
 savefig(F,fullfile(OUT,'SIGNED_TASK_REST_EFFECTS.fig'));close(F);
end
%% Single multipage PDF + reproducible numerical archive.
% ALL_FIGURES.pdf already contains S2 survival QC and S2b MDEA delta diagnostics.


if ~isempty(TaskSummary)
 F=figure('Visible','off','Color','w');ax=axes(F);hold(ax,'on');
 for i=1:numel(tasks)
  z=TaskSummary(TaskSummary.Task==tasks(i),:);
  plot(ax,z.StripeWidth,z.MedianSignedDeltaCS,'o-','DisplayName',char(tasks(i)));
 end
 yline(ax,0,'--');legend(ax,'Location','best');grid(ax,'on');
 title(ax,'Subject-level signed Task - Rest; confirm T00 is Rest');xlabel(ax,'Stripe width');ylabel(ax,'Signed \Delta CS');
 exportgraphics(F,mainPdf,'ContentType','vector','Append',true);close(F);
end
save(fullfile(OUT,'STRIPE_RESULTS.mat'),'P','R','S','ModelSummary','TaskPairs','TaskSummary','files','-v7.3');
fid=fopen(fullfile(OUT,'README_INTERPRETATION.txt'),'w');
fprintf(fid,'MUSIC STRIPE DECISION V8: matched widths + tail distribution model comparison\n');
fprintf(fid,'TAIL MODEL: one matched mid-recording window and first selected channel per recording/stripe.\n');
fprintf(fid,'Tail threshold = empirical 25th percentile; same threshold for three competing models within each sample.\n');
fprintf(fid,'Models fitted to raw tail observations by approximate continuous likelihood: Pareto power law, shifted exponential, shifted Weibull.\n');
fprintf(fid,'AIC is exploratory for integer-valued waiting times; not a formal discrete distribution test.\n');
fprintf(fid,'AIC winner is descriptive and not used as a stripe-size selection gate.\n');
fprintf(fid,'Survival fit mode: %s, tau interval: [%g,%g] samples.\n',char(P.MuFitMode),P.MuTauStart,P.MuTauEnd);
fprintf(fid,'Quality flags: mu in (%g,%g), R2 >= %.3f, at least %d distinct tau. No minimum fit-span gate.\n',P.MuMin,P.MuMax,P.MuR2Min,P.MinFitPoints);
fprintf(fid,'Changing survival fit bounds changes mu estimates; changing R2 threshold changes only QC/pass flags. Neither is evidence that a power law is true.\n');
fprintf(fid,'Mu fitting reports fit span and R2 separately; span is NOT enforced by estimator.\n');
fprintf(fid,'The reported coverage denominator includes ALL recordings, including failures.\n');
fprintf(fid,'CS failures recorded as short_recording, missing_channels, insufficient_windows or MDEA failure.\n');
fprintf(fid,'Candidate classification uses prespecified descriptive gates, not a formal test or optimum.\n');
fprintf(fid,'No stripe is declared optimal; zero candidates means evidence insufficient.\n');
fprintf(fid,'IMPORTANT: VERIFY T00 is Rest before interpreting signed task-rest effects.\n');
fprintf(fid,'Rest-task comparisons are matched by subject, not by exact time/block.\n');
fprintf(fid,'Task contrasts are descriptive and do not include multiplicity-corrected inference.\n');
fprintf(fid,'This is an Auditory-Sensorimotor diagnostic, not the complete five-node network.\n');
fprintf(fid,'Single Auditory channel allowed as proxy; flagged and separated from multi-channel confirmation.\n');
fprintf(fid,'ALL candidate widths use the same 24 temporal windows per recording.\n');
fprintf(fid,'Split-half CS is computed on independent early and late sets of sampled windows.\n');
fprintf(fid,'Mu span availability is descriptive and NOT a selection gate.\n');
fprintf(fid,'Neighbor differences use matched recordings.\n');
fprintf(fid,'Task-minus-rest disabled until T00 mapping is verified from dataset metadata.\n');
fprintf(fid,'No renewal result or observed CS magnitude is used to choose stripe width.\n');
fprintf(fid,'The preflight MDEA plot requires Info.LogLag and Info.Entropy for visual checking.\n');
fclose(fid);
% Extra model-comparison figure, appended to the combined PDF.
F=figure('Visible','off','Color','w','Position',[100 100 1200 450]);
t=tiledlayout(F,1,2,'TileSpacing','compact');
ax=nexttile(t);plot(ax,ModelSummary.StripeWidth,ModelSummary.PowerPreferred,'o-',...
 ModelSummary.StripeWidth,ModelSummary.ExponentialPreferred,'s-',...
 ModelSummary.StripeWidth,ModelSummary.WeibullPreferred,'^-');
legend(ax,{'Pareto','Exponential','Weibull'},'Location','best');
xlabel(ax,'Stripe width');ylabel(ax,'Fraction best AIC');ylim(ax,[0 1]);grid(ax,'on');
title(ax,'Tail model preference (exploratory)');
ax=nexttile(t);plot(ax,ModelSummary.StripeWidth,ModelSummary.MedianDeltaAICPower,'o-');
yline(ax,0,'--');xlabel(ax,'Stripe width');ylabel(ax,'Median \Delta AIC (Pareto - best)');grid(ax,'on');
title(ax,'Penalty for power-law model');
exportgraphics(F,fullfile(OUT,'TAIL_MODEL_COMPARISON.pdf'),'ContentType','vector');
exportgraphics(F,fullfile(OUT,'TAIL_MODEL_COMPARISON.jpg'),'Resolution',600);
exportgraphics(F,mainPdf,'ContentType','vector','Append',true);close(F);
%% V9: factorial window-duration / overlap / stripe sweep and renewal checks.
% This stage uses matched recording IDs, channel definitions, and deterministic
% within-condition windows. It does NOT treat overlapping windows as independent.
Q=struct;
Q.WindowSeconds=[3.2 6.4 9.6];
Q.OverlapFractions=[0 .50 .75];
Q.Stripes=P.FactorialStripes; % finer sweep is in main stripe-fit stage; no interpolated data
Q.MaxWindowsPerCondition=24; % use Inf to evaluate full window grid (very expensive)
Q.MinCSWindows=6;
Q.MinIntervals=40;
Q.NPermutation=99;  % exploratory sweep only; targeted renewal audit below
Q.NBootstrap=1000;    % subject/recording-level CI, not window-level pseudo-replication
Q.RngSeed=20261021;
Q.Enable=true;
Q.NAgingSurrogates=49; Q.MinSurvivalAtAge=15;
Q.RunRenewalControls=true;
if Q.Enable
 fprintf('V9 factorial sweep: %d files x %d durations x %d overlaps x %d stripes.\n', ...
   nF,numel(Q.WindowSeconds),numel(Q.OverlapFractions),numel(Q.Stripes));
 sweepCell=cell(nF,1);
 h2=waitbar(0,'Factorial sweep and renewal checks...','Name','Overall supplementary analysis');
 % Use serial loop here for reliable waitbar updates and bounded memory;
 for fi=1:nF
  sweepCell{fi}=v9RecordingSweep(files(fi),P,Q,fi);
  if isgraphics(h2),waitbar(fi/nF,h2,sprintf('V9 sweep: %d / %d',fi,nF));end
 end
 if isgraphics(h2),close(h2);end
 V9=vertcat(sweepCell{:});
 writetable(V9,fullfile(OUT,'V9_FACTORIAL_RECORDING_RESULTS.csv'));
 V9Summary=v9Summarize(V9,Q);
 writetable(V9Summary,fullfile(OUT,'V9_FACTORIAL_SUMMARY.csv'));
 % Only recording-level resampling for uncertainty intervals.
 V9CI=v9Bootstrap(V9,Q);
 writetable(V9CI,fullfile(OUT,'V9_RECORDING_BOOTSTRAP_CI.csv'));
 save(fullfile(OUT,'V9_FACTORIAL_RENEWAL.mat'),'V9','V9Summary','V9CI','Q','-v7.3');
 % CS is EXCLUSIVELY a descriptive supplemental figure, never a gate.
 f9=figure('Visible','off','Color','w','Position',[100 100 1300 800]);
 t9=tiledlayout(f9,2,2,'TileSpacing','compact');
 for oi=1:numel(Q.OverlapFractions)
  ax=nexttile(t9);hold(ax,'on');
  for wi=1:numel(Q.WindowSeconds)
   g=V9Summary.WindowSeconds==Q.WindowSeconds(wi)&abs(V9Summary.Overlap-Q.OverlapFractions(oi))<1e-8;
   plot(ax,V9Summary.Stripe(g),V9Summary.MedianCS(g),'-o','DisplayName',sprintf('%.1f s',Q.WindowSeconds(wi)));
  end
  title(ax,sprintf('CS | %.0f%% overlap',100*Q.OverlapFractions(oi)));
  xline(ax,P.ReferenceSZ,':','Color',[.35 .35 .35]);
  xlabel(ax,'Stripe width');ylabel(ax,'Median CS');grid(ax,'on');legend(ax,'Location','best');
 end
 ax=nexttile(t9);plot(ax,S.StripeWidth,S.SplitHalfMedianDifference,'o-');
 xlabel(ax,'Stripe width');ylabel(ax,'Median split-half |\Delta CS|');
 title(ax,'Temporal CS stability (descriptive)');grid(ax,'on');
 xline(ax,P.ReferenceSZ,':','Color',[.35 .35 .35]);
 exportgraphics(f9,fullfile(OUT,'SUPP_CS_PARAMETER_SENSITIVITY.jpg'),'Resolution',600);
 exportgraphics(f9,fullfile(OUT,'SUPP_CS_PARAMETER_SENSITIVITY.pdf'),'ContentType','vector');
 exportgraphics(f9,mainPdf,'ContentType','vector','Append',true);close(f9);
 % Renewal diagnostics are reported separately and never used for selection.
 fR=figure('Visible','off','Color','w','Position',[100 100 1350 520]);
 tR=tiledlayout(fR,1,3,'TileSpacing','compact');
 ax=nexttile(tR);hold(ax,'on');
 for wi=1:numel(Q.WindowSeconds)
  g=V9Summary.WindowSeconds==Q.WindowSeconds(wi)&abs(V9Summary.Overlap-.5)<1e-8;
  plot(ax,V9Summary.Stripe(g),V9Summary.RenewalPassFraction(g),'-o','DisplayName',sprintf('%.1f s',Q.WindowSeconds(wi)));
 end
 xlabel(ax,'Stripe width');ylabel(ax,'Fraction p >= 0.05');title(ax,'A. Lag-one shuffle test');
 ylim(ax,[0 1]);legend(ax,'Location','best');grid(ax,'on');
 ax=nexttile(tR);hold(ax,'on');
 for si=1:numel(Q.Stripes)
  z=V9(abs(V9.Stripe-Q.Stripes(si))<1e-8,:);
  plot(ax,Q.Stripes(si),median(z.Lag1Spearman,'omitnan'),'o','MarkerSize',7);
 end
 xlabel(ax,'Stripe width');ylabel(ax,'Median lag-one Spearman');title(ax,'B. Interval dependence');grid(ax,'on');
 ax=nexttile(tR);hold(ax,'on');
 for si=1:numel(Q.Stripes)
  z=V9(abs(V9.Stripe-Q.Stripes(si))<1e-8,:);
  plot(ax,Q.Stripes(si),median(z.AgingDistance,'omitnan'),'o','MarkerSize',7);
 end
 xlabel(ax,'Stripe width');ylabel(ax,'Residual-life aging distance');
 title(ax,'C. Aging vs memorylessness (not a renewal test)');grid(ax,'on');
 title(tR,'SUPPLEMENT: Renewal diagnostics — NOT used for stripe selection');
 exportgraphics(fR,fullfile(OUT,'SUPP_RENEWAL_SEPARATE.jpg'),'Resolution',600);
 exportgraphics(fR,fullfile(OUT,'SUPP_RENEWAL_SEPARATE.pdf'),'ContentType','vector');
 exportgraphics(fR,mainPdf,'ContentType','vector','Append',true);close(fR);
 % Paired subject summaries: first average within subject, then summarize.
 subjSummary=groupsummary(V9,{'Subject','WindowSeconds','Overlap','Stripe'},'median', ...
  {'CS','MedianMu','MedianR2','MedianFitSpan','Lag1Spearman','AgingDistance'});
 writetable(subjSummary,fullfile(OUT,'SUPP_SUBJECT_LEVEL_SUMMARY.csv'));
 fid=fopen(fullfile(OUT,'V9_METHODS_AND_LIMITATIONS.txt'),'w');
 fprintf(fid,'V10 factorial sweep: window durations in seconds [3.2,6.4,9.6], overlaps [0,.5,.75], stripes [.15,.18,.20,.22,.27].\n');
 fprintf(fid,'Per recording and condition, at most 24 windows are sampled across the full valid start grid. The full grid respects requested overlap.\n');
 fprintf(fid,'CS is correlation across windows of auditory and sensorimotor median MDEA exponents. It is NOT the full five-node manuscript network.\n');
 fprintf(fid,'Renewal diagnostic: successive waiting-time lag-one Spearman correlation vs permutation of intervals, using first recognized auditory channel in one central window.\n');
 fprintf(fid,'Earlier EEG nonrenewal findings are compatible with this analysis. Renewal results are NOT a stripe-size decision criterion.\n');
 fprintf(fid,'Renewal pass = permutation p >= 0.05: failure to reject dependence, NOT proof of renewal. Multiple-testing adjustment required for inferential claims.\n');
 fprintf(fid,'Aging surrogate sequence test compares median next interval after long vs short preceding interval, against shuffled intervals.\n');
 fprintf(fid,'Aging: conditional survival P(T>a+t | T>a) computed directly from empirical waiting times; compared to exponential memoryless prediction. Aging alone does not prove renewal.\n');
 fprintf(fid,'Bootstrap resamples subjects as clusters; all their recordings remain together.\n');
 fprintf(fid,'The 0.75 overlap condition has strongly dependent windows; compare reliability, not nominal sample counts.\n');
 fprintf(fid,'V10 is a bounded full-cohort sweep, not a full nested optimization or proof of renewal.\n');
 fclose(fid);
end
%% V13: V11 exhaustive auditory audit intentionally omitted.
% V12/V13 representative renewal analysis below replaces it; no all-channel pass.

%% V12: publication-oriented renewal validation (independent of stripe choice).
% Empirical interval shuffling is the exact conditional renewal null for order
% dependence, but it cannot test renewal aging alone: marginal residual-life
% curves are identical after shuffling. We therefore compare age-conditioned
% next-interval distributions, and calibrate against simulated iid and
% dependent controls. No renewal result enters the stripe-selection score.
fprintf('\nV13: stratified representative EEG renewal validation...\n');
V12=table(); representativeTau=[]; representativeStripe=NaN;
% One recording per participant and task code, chosen deterministically;
% prevents one participant or condition dominating expensive renewal tests.
subjectKey=strings(nF,1);taskKey=strings(nF,1);
for fi=1:nF
 tk=regexp(files(fi).name,'^(D\d+)_B\d+_(T\d+)','tokens','once');
 if isempty(tk),subjectKey(fi)=string(files(fi).name);taskKey(fi)="unknown";
 else,subjectKey(fi)=string(tk{1});taskKey(fi)=string(tk{2});end
end
chosen=false(nF,1);
for fi=1:nF
 prior=find(chosen & subjectKey==subjectKey(fi) & taskKey==taskKey(fi));
 if numel(prior)<P.V13MaxRecordingsPerSubjectTask,chosen(fi)=true;end
end
chosenIdx=find(chosen); fprintf('V13 representative recordings: %d of %d\n',numel(chosenIdx),nF);
for ki=1:numel(chosenIdx)
 fi=chosenIdx(ki);
 try
  [XX,~,labs]=loadEEG(fullfile(files(fi).folder,files(fi).name));
  subject=subjectKey(fi);
  auditory=find(ismember(upper(string(labs)),upper(P.Auditory)));
  motor=find(ismember(upper(string(labs)),upper(P.Sensorimotor)));
  idx=unique([auditory(1:min(1,numel(auditory)));motor(1:min(1,numel(motor)))],'stable');
  idx=idx(1:min(P.V13MaxChannelsPerRecording,numel(idx)));
  for ci=idx(:)'
   x=double(XX(ci,:));x=x(1:min(numel(x),P.V13MaxSamples));
   if any(~isfinite(x))||numel(x)<256||max(x)==min(x),continue;end
   for si=1:numel(P.V13RenewalStripes)
    stripe=P.V13RenewalStripes(si);
    try
     [~,infostr]=MDEAcorrected(x,stripe,P.Rule,P.ST,P.EN,0);
     tau=getTau(infostr);
     if isempty(representativeTau) && abs(stripe-P.ReferenceSZ)<1e-8 && numel(tau)>200
      representativeTau=tau(:);representativeStripe=stripe;
     end
     % Use ordered, evenly spaced observations only for costly permutations;
     % report full event count separately. Not a replacement for full-sequence tests.
     nAll=numel(tau);
     if nAll>P.V13MaxRenewalIntervals
      first=floor((nAll-P.V13MaxRenewalIntervals)/2)+1;
      tau=tau(first:first+P.V13MaxRenewalIntervals-1);
     end
     a=v12RenewalValidation(tau,P.V12PermutationN,P.V13RenewalSeed+fi*10000+ci*100+si,P.V12MinIntervals);
     row=table(string(files(fi).name),subject,string(labs(ci)),stripe,...
      a.N,a.Lag1,a.Lag2,a.P1,a.P2,a.PJoint,a.PCond,a.AgingD,a.AgingP,...
      a.Age,a.StationarityP,a.Valid,...
      'VariableNames',{'File','Subject','Channel','Stripe','NIntervals',...
      'Lag1','Lag2','Lag1P','Lag2P','JointOrderP','ConditionalNextP',...
      'RenewalAgingDeviation','RenewalAgingP','AgeThreshold','StationarityP','Valid'});
     row.FullIntervalCount=nAll;
     V12=[V12;row]; %#ok<AGROW>
    catch ME
     fprintf('V13 skip %s / %s / %.3f: %s\n',files(fi).name,char(labs(ci)),stripe,ME.message);
    end
   end
  end
 catch ME
  fprintf('V13 file error %s: %s\n',files(fi).name,ME.message);
 end
 fprintf('V13 representative renewal %d/%d\n',ki,numel(chosenIdx));
end
% Representative residual-life aging: theoretical iid renewal prediction is
% determined by the empirical marginal waiting-time survival, not exponential.
% A single observed marginal cannot prove independence; sequence-order tests
% and controls are therefore reported separately.
if ~isempty(representativeTau)
 tau=double(representativeTau(:));tau=tau(isfinite(tau)&tau>0);
 ages=unique(max(1,round(prctile(tau,[0 25 50 70]))));
 tgrid=linspace(0,prctile(tau,85),80);
 fAge=figure('Visible','off','Color','w','Position',[80 80 1050 670]);
 ax=axes(fAge);hold(ax,'on');
 for jj=1:numel(ages)
  a=ages(jj);den=mean(tau>a);
  if den<.05,continue;end
  conditional=arrayfun(@(t)mean(tau>a+t)/den,tgrid);
  plot(ax,tgrid,conditional,'LineWidth',1.6,'DisplayName',sprintf('Age = %.0f samples',a));
 end
 xlabel(ax,'Additional waiting time (samples)');
 ylabel(ax,'P(T > a+t | T > a)');
 title(ax,sprintf('Representative empirical renewal-aging curves (stripe %.2f)',representativeStripe));
 legend(ax,'Location','northeast');grid(ax,'on');
 subtitle(ax,'Aging is expected even for iid nonexponential renewal intervals; not a renewal-independence test');
 v11SaveFigure(fAge,OUT,'SUPP_V13_RENEWAL_AGING_CURVES',mainPdf);
end
if ~isempty(V12)
 writetable(V12,fullfile(OUT,'V12_ALL_CHANNEL_RENEWAL_TESTS.csv'));
 % Equal weighting: channel -> recording -> subject, then subjects.
 K=groupsummary(V12,{'Subject','File','Stripe'},'median',...
  {'Lag1','Lag2','RenewalAgingDeviation'});
 writetable(K,fullfile(OUT,'V12_RECORDING_RENEWAL_MEDIANS.csv'));
 S=groupsummary(K,{'Subject','Stripe'},'median',...
  {'median_Lag1','median_Lag2','median_RenewalAgingDeviation'});
 writetable(S,fullfile(OUT,'V12_SUBJECT_RENEWAL_MEDIANS.csv'));
 % Holm correction across the entire prespecified family of renewal tests;
 % exploratory due to within-subject correlation. Subject-level inference
 % is provided by cluster bootstrap below, not channel-level p values.
 for col={'Lag1P','Lag2P','JointOrderP','ConditionalNextP','RenewalAgingP','StationarityP'}
  nm=col{1};V12.([nm 'Holm'])=v12Holm(V12.(nm));
 end
 writetable(V12,fullfile(OUT,'V12_ALL_CHANNEL_RENEWAL_TESTS_WITH_HOLM.csv'));
 f=figure('Visible','off','Color','w','Position',[50 50 1650 580]);
 t=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
 met={'median_median_Lag1','median_median_Lag2','median_median_RenewalAgingDeviation'};
 ylab={'Lag-one interval correlation','Lag-two interval correlation','Conditional aging-order deviation'};
 for k=1:3
  ax=nexttile(t);hold(ax,'on');sub=unique(S.Subject);
  for j=1:numel(sub)
   z=S(S.Subject==sub(j),:);plot(ax,z.Stripe,z.(met{k}),'-o','Color',[.75 .75 .75]);
  end
  med=nan(numel(P.Stripes),1);lo=med;hi=med;
  for j=1:numel(P.Stripes)
   z=S(abs(S.Stripe-P.Stripes(j))<1e-8,:);v=z.(met{k});v=v(isfinite(v));
   if isempty(v),continue;end
   med(j)=median(v);[lo(j),hi(j)]=v12SubjectCI(v,P.NBootstrap,400+j+k);
  end
  errorbar(ax,P.Stripes(isfinite(med)&isfinite(lo)&isfinite(hi)),med(isfinite(med)&isfinite(lo)&isfinite(hi)),med(isfinite(med)&isfinite(lo)&isfinite(hi))-lo(isfinite(med)&isfinite(lo)&isfinite(hi)),hi(isfinite(med)&isfinite(lo)&isfinite(hi))-med(isfinite(med)&isfinite(lo)&isfinite(hi)),'ko-','LineWidth',1.5,'MarkerFaceColor','k');
  xlabel(ax,'Stripe size');ylabel(ax,ylab{k});grid(ax,'on');
  title(ax,sprintf('%c. Subject-cluster 95%% bootstrap CI','A'+k-1));
 end
 title(t,'Representative stratified EEG renewal audit; NOT stripe selection');
 v11SaveFigure(f,OUT,'SUPP_V12_RENEWAL_SUBJECT_BOOTSTRAP',mainPdf);
end
% Five-node CS sensitivity audit: A/F/M/P/O, separately from selection.
% Uses exactly matched temporal windows and channels for all stripe widths.
if P.V12FiveNodeCS
 fprintf('V12 five-node CS sensitivity audit...\n');
 F5=table();
 for fi=1:nF
  try
   [XX,fs,labs]=loadEEG(fullfile(files(fi).folder,files(fi).name));
   [~,stem]=fileparts(files(fi).name);
   tk=regexp(stem,'^(D\d+)_B\d+_(T\d+)','tokens','once');
   if isempty(tk),subject=string(stem);else,subject=string(tk{1});end
   P5=P;P5.Stripes=P.FiveNodeStripes;
   r=v12FiveNode(XX,fs,labs,P5);
   for si=1:numel(P.FiveNodeStripes)
    F5=[F5;table(string(files(fi).name),subject,P.FiveNodeStripes(si),...
     r.NNodes(si),r.NEdges(si),r.MeanSignedCS(si),r.MedianAbsCS(si),...
     'VariableNames',{'File','Subject','Stripe','NNodes','NEdges','MeanSignedCS','MedianAbsCS'})]; %#ok<AGROW>
   end
  catch ME
   fprintf('Five-node audit skipped %s: %s\n',files(fi).name,ME.message);
  end
  fprintf('Five-node audit %d/%d\n',fi,nF);
 end
 if ~isempty(F5)
  writetable(F5,fullfile(OUT,'V12_FIVE_NODE_CS_SENSITIVITY.csv'));
  G5=groupsummary(F5,{'Subject','Stripe'},'median',{'MeanSignedCS','MedianAbsCS','NEdges'});
  writetable(G5,fullfile(OUT,'V12_FIVE_NODE_CS_SUBJECT.csv'));
  f=figure('Visible','off','Color','w','Position',[60 60 1250 500]);
  t=tiledlayout(f,1,2,'Padding','compact','TileSpacing','compact');
  mm={'median_MeanSignedCS','median_MedianAbsCS'};
  yy={'Mean signed five-node edge CS','Median absolute five-node edge CS'};
  for k=1:2
   ax=nexttile(t);hold(ax,'on');
   for j=1:numel(P.FiveNodeStripes)
    z=G5(abs(G5.Stripe-P.FiveNodeStripes(j))<1e-8,:);
    v=z.(mm{k});v=v(isfinite(v));if isempty(v),continue;end
    [lo,hi]=v12SubjectCI(v,P.NBootstrap,910+j+k);
    errorbar(ax,P.FiveNodeStripes(j),median(v),median(v)-lo,hi-median(v),'ko','MarkerFaceColor','k');
   end
   xlabel(ax,'Stripe size');ylabel(ax,yy{k});grid(ax,'on');
  end
  title(t,'Five-node CS sensitivity (supplement only; not stripe selection)');
  v11SaveFigure(f,OUT,'SUPP_V12_FIVE_NODE_CS',mainPdf);
 end
end
% Positive and negative control power / false-positive calibration.
C=v12Controls(P.V12ControlN,P.V12ControlMaxIntervals,P.V12MinIntervals);
writetable(C,fullfile(OUT,'V12_RENEWAL_CONTROL_CALIBRATION.csv'));
f=figure('Visible','off','Color','w','Position',[80 80 1250 500]);
t=tiledlayout(f,1,2,'Padding','compact');
ax=nexttile(t);bar(ax,categorical(C.Model),C.JointRejectFraction);ylim(ax,[0 1]);
ylabel(ax,'Joint order test rejection fraction');title(ax,'A. Null calibration and detection power');
ax=nexttile(t);bar(ax,categorical(C.Model),C.AgingRejectFraction);ylim(ax,[0 1]);
ylabel(ax,'Conditional aging-order rejection fraction');title(ax,'B. Renewal-aging order test');
title(t,'Simulated renewal vs dependent controls; nominal alpha = 0.05');
v11SaveFigure(f,OUT,'SUPP_V12_RENEWAL_CONTROLS',mainPdf);
% Paired subject-cluster uncertainty for stripe diagnostics. One paired
% observation per subject (averaged across matched duration/overlap).
if exist('D','var') && ~isempty(D)
 Z=groupsummary(D,{'Subject','ComparisonStripe'},'median',...
  {'DeltaR2','DeltaFitDecades','DeltaValidFraction'});
 names={'median_DeltaR2','median_DeltaFitDecades','median_DeltaValidFraction'};
 Tci=table();
 for j=1:numel(P.Stripes)
  st=P.Stripes(j);if abs(st-P.ReferenceSZ)<1e-8,continue;end
  zz=Z(abs(Z.ComparisonStripe-st)<1e-8,:);
  for k=1:3
   v=zz.(names{k});v=v(isfinite(v));
   if isempty(v),continue;end
   [low,high]=v12SubjectCI(v,P.NBootstrap,700+j*10+k);
   rr=table(st,string(names{k}),numel(v),median(v),low,high,...
    'VariableNames',{'Stripe','Metric','NSubjects','MedianPairedDifference','CI95Low','CI95High'});
   Tci=[Tci;rr]; %#ok<AGROW>
  end
 end
 writetable(Tci,fullfile(OUT,'V12_SUBJECT_PAIRED_BOOTSTRAP_CI.csv'));
end
fid=fopen(fullfile(OUT,'V12_INTERPRETATION_AND_LIMITATIONS.txt'),'w');
fprintf(fid,'V12 tests interval independence (necessary for iid renewal), not a metaphysical binary renewal label.\n');
fprintf(fid,'Aging residual-life curves alone cannot discriminate iid renewal from shuffled intervals because they depend on the marginal distribution.\n');
fprintf(fid,'Conditional-next-interval aging order test compares dependence on previous-interval age, with shuffled intervals as the renewal null.\n');
fprintf(fid,'Representative audit: one recording per subject/task, one auditory and one sensorimotor channel, 3 stripe widths, bounded continuous segment.\n');
fprintf(fid,'Subject bootstrap resamples subjects; nine subjects imply wide and unstable population uncertainty.\n');
fprintf(fid,'Holm channel-level p values are exploratory because channels and repeated recordings are dependent.\n');
fprintf(fid,'Positive control: iid heavy-tailed intervals. Negative controls: alternating and autoregressive log intervals.\n');
fprintf(fid,'CS magnitude and renewal never enter stripe selection. Full five-node manuscript CS is NOT recomputed by V12.\n');
fprintf(fid,'Fitted power laws remain exploratory: no exact discrete-tail GOF bootstrap has been implemented.\n');
fprintf(fid,'V13 deliberately avoids all-channel full-recording MDEA; representative selection is stratified, not exhaustive.\n');
fclose(fid);

% T00 is assumed Rest; verify task labels against dataset metadata.
fprintf('\nV19 extension: fine 21-stripe task-vs-Rest five-node sweep...\n');
% v19FineTaskSweep disabled: replaced by exact primary-pipeline matched sweep.
% v19FineTaskSweep(files,P,OUT,mainPdf);
% Curated S4 is replaced by primary-matched figure in master; legacy pack disabled.
v20PublicationFigures(OUT);
fprintf('\nV15 diagnostics and figures completed.\n');
%% Local functions
end % unifiedV15Diagnostics

function progressUpdate(h,nF)
 persistent count; if isempty(count),count=0;end
 count=count+1;
 if isgraphics(h)
  try,waitbar(min(1,count/nF),h,sprintf('%d / %d recordings',count,nF));catch,end
 end
end
function [X,fs,labels]=loadEEG(path)
 [X,fs,~,chanlocs,EEG]=read_set_file(path);X=double(X);
 if ndims(X)>2,X=reshape(X,size(X,1),[]);end
 if ~isempty(chanlocs)&&isstruct(chanlocs)&&isfield(chanlocs,'labels')
  labels=string({chanlocs.labels})';
 elseif isstruct(EEG)&&isfield(EEG,'chanlocs')&&isfield(EEG.chanlocs,'labels')
  labels=string({EEG.chanlocs.labels})';
 else,error('Missing channel labels: %s',path);end
 if numel(labels)~=size(X,1),error('Channel label count mismatch');end
end

function v14SavePreflight(f,out,name)
 % Save exactly the accepted fitting examples before closing the GUI.
 % All panels represent measured curves; no smoothing or interpolation.
 try
  set(f,'Color','w','InvertHardcopy','off');
  exportgraphics(f,fullfile(out,[name '.jpg']),'Resolution',600);
  exportgraphics(f,fullfile(out,[name '.pdf']),'ContentType','vector');
  savefig(f,fullfile(out,[name '.fig']));
 catch ME
  warning('V15:PreflightExport','Could not export %s: %s',name,ME.message);
 end
end

function R=processRecording(file,P)
 [~,stem]=fileparts(file.name);
 tok=regexp(stem,'^(D\d+)_B\d+_(T\d+)','tokens','once');
 if isempty(tok),subj=string(stem);task="unknown";else,subj=string(tok{1});task=string(tok{2});end
 nS=numel(P.Stripes);
 names={'File','Subject','Task','StripeWidth','CS','NValidCSWindows','MeanDelta','VarDelta',...
  'MuValidFraction','ValidMuMedian','ValidWindowFraction','MDEAFailures','Reason','NWindows','NChannelsA','NChannelsM','SingleAuditory','MuFiniteFraction','MuR2PassFraction','MuSpanPassFraction','MuRangePassFraction','CSFirstHalf','CSSecondHalf','CSHalfDifference','CSHalfValid','MedianTauCount','MedianFitPoints','MedianFitDecades','MedianFitR2','MuInsufficientEventsFraction','MuInsufficientPointsFraction','MuFitEstimableFraction',...
  'TailN','TailXmin','TailParetoMu','TailWeibullShape','TailAICPower','TailAICExponential','TailAICWeibull','TailBestModel','TailDeltaAICPower'};
 % Derive types from the actual names so adding diagnostic columns cannot
 % silently break table construction again.
 types=repmat({'double'},1,numel(names));
 types(ismember(names,{'File','Subject','Task','Reason','TailBestModel'}))={'string'};
 types(ismember(names,{'SingleAuditory','CSHalfValid'}))={'logical'};
 assert(numel(types)==numel(names),'Internal table schema mismatch');
 R=table('Size',[nS numel(names)],'VariableTypes',types,'VariableNames',names);
 R.MedianTauCount=nan(nS,1);R.MedianFitPoints=nan(nS,1);
 R.MedianFitDecades=nan(nS,1);R.MedianFitR2=nan(nS,1);
 R.MuInsufficientEventsFraction=zeros(nS,1);
 R.MuInsufficientPointsFraction=zeros(nS,1);
 R.MuFitEstimableFraction=zeros(nS,1);
 R.TailN(:)=NaN;R.TailXmin(:)=NaN;R.TailParetoMu(:)=NaN;R.TailWeibullShape(:)=NaN;
 R.TailAICPower(:)=NaN;R.TailAICExponential(:)=NaN;R.TailAICWeibull(:)=NaN;
 R.TailDeltaAICPower(:)=NaN;R.TailBestModel(:)="not_estimable";
 R.File(:)=string(file.name);R.Subject(:)=subj;R.Task(:)=task;R.StripeWidth=P.Stripes(:);
 R.CS(:)=NaN;R.MeanDelta(:)=NaN;R.VarDelta(:)=NaN;R.MuValidFraction(:)=0;
 R.ValidMuMedian(:)=NaN;R.ValidWindowFraction(:)=0;R.Reason(:)="unknown";
 R.SingleAuditory(:)=false; R.CSFirstHalf(:)=NaN; R.CSSecondHalf(:)=NaN; R.CSHalfDifference(:)=NaN; R.CSHalfValid(:)=false; R.MuFiniteFraction(:)=0; R.MuR2PassFraction(:)=0; R.MuSpanPassFraction(:)=0; R.MuRangePassFraction(:)=0;
 try,[X,~,labels]=loadEEG(fullfile(file.folder,file.name));
 catch ME,R.Reason(:)="load_error: "+string(ME.message);return;end
 idxA=find(ismember(lower(labels),lower(P.Auditory)));
 idxM=find(ismember(lower(labels),lower(P.Sensorimotor)));
 if numel(idxA)>P.MaxChannelsA,idxA=idxA(unique(round(linspace(1,numel(idxA),P.MaxChannelsA))));end
 if numel(idxM)>P.MaxChannelsM,idxM=idxM(unique(round(linspace(1,numel(idxM),P.MaxChannelsM))));end
 R.NChannelsA(:)=numel(idxA);R.NChannelsM(:)=numel(idxM);
 R.SingleAuditory(:)=numel(idxA)==1;
 if numel(idxA)<P.MinAuditoryChannels||numel(idxM)<P.MinSensorimotorChannels
  R.Reason(:)="missing_channels";return;end
 L=size(X,2);W=P.WindowSamples;
 if L<W,R.Reason(:)="short_recording";return;end
 % Construct a common full-recording grid, then use a denser grid only for focus widths.
 startsBase=unique(round(linspace(1,L-W+1,min(P.MaxWindows,L-W+1))));
 startsFocus=unique(round(linspace(1,L-W+1,min(P.FocusMaxWindows,L-W+1))));
 if numel(startsBase)<P.MinCSWindows,R.Reason(:)="insufficient_windows";return;end
 allCh=unique([idxA(:);idxM(:)]);map=zeros(size(X,1),1);map(allCh)=1:numel(allCh);
 for si=1:nS
  sz=P.Stripes(si);
  if any(abs(sz-P.FocusStripes)<1e-9),starts=startsFocus;else,starts=startsBase;end
  nW=numel(starts);R.NWindows(si)=nW;
  d=nan(numel(allCh),nW);mu=nan(numel(allCh),nW);
  valid=false(numel(allCh),nW);r2OK=false(numel(allCh),nW);
  spanOK=false(numel(allCh),nW);rangeOK=false(numel(allCh),nW);fail=0;
  tauCount=nan(numel(allCh),nW);fitPoints=nan(numel(allCh),nW);
  fitSpan=nan(numel(allCh),nW);fitR2=nan(numel(allCh),nW);
  for ci=1:numel(allCh)
   for wi=1:nW
    seg=X(allCh(ci),starts(wi):starts(wi)+W-1);
    if any(~isfinite(seg))||max(seg)==min(seg),continue;end
    try,[v,info]=MDEAcorrected(seg,sz,P.Rule,P.ST,P.EN,0);
    catch,fail=fail+1;continue;end
    if isscalar(v)&&isfinite(v),d(ci,wi)=v;end
    tau=getTau(info);
    % Identical channel and temporal window for all candidate widths.
    % This is a raw waiting-time likelihood comparison, not a fit to
    % correlated empirical survival ordinates.
    if P.ModelCompareEnabled && ci==1 && wi==ceil(nW/2)
     model=compareTailModels(tau,P);
     R.TailN(si)=model.n;R.TailXmin(si)=model.xmin;
     R.TailParetoMu(si)=model.mu;R.TailWeibullShape(si)=model.shape;
     R.TailAICPower(si)=model.aic(1);R.TailAICExponential(si)=model.aic(2);
     R.TailAICWeibull(si)=model.aic(3);R.TailBestModel(si)=model.best;
     R.TailDeltaAICPower(si)=model.deltaPower;
    end
    tauCount(ci,wi)=numel(tau);
    [m,r2,~,~,npt,span]=muFit(tau,P);
    fitPoints(ci,wi)=npt;fitSpan(ci,wi)=span;fitR2(ci,wi)=r2;
    if isfinite(m),mu(ci,wi)=m;end
    r2OK(ci,wi)=isfinite(r2)&&r2>=P.MuR2Min;
    spanOK(ci,wi)=isfinite(span);
    rangeOK(ci,wi)=isfinite(m)&&m>P.MuMin&&m<P.MuMax;
    valid(ci,wi)=rangeOK(ci,wi)&&r2OK(ci,wi)&&npt>=P.MinFitPoints;
   end
  end
  a=median(d(map(idxA),:),1,'omitnan')';b=median(d(map(idxM),:),1,'omitnan')';
  good=isfinite(a)&isfinite(b);ng=nnz(good);cs=NaN;
  if ng>=P.MinCSWindows&&std(a(good))>0&&std(b(good))>0
   c=corrcoef(a(good),b(good));cs=c(1,2);
  end
  % Nonoverlapping temporal halves, using the SAME window centers for every SZ.
  mid=floor(nW/2);
  [c1,n1]=halfCorr(a(1:mid),b(1:mid),P.MinHalfWindows);
  [c2,n2]=halfCorr(a(mid+1:end),b(mid+1:end),P.MinHalfWindows);
  R.CSFirstHalf(si)=c1;R.CSSecondHalf(si)=c2;
  if isfinite(c1)&&isfinite(c2)
   R.CSHalfDifference(si)=abs(c1-c2);
   R.CSHalfValid(si)=true;
  end
  R.CS(si)=cs;R.NValidCSWindows(si)=ng;
  R.MeanDelta(si)=mean([a;b],'omitnan');R.VarDelta(si)=var([a;b],0,'omitnan');
  R.MedianTauCount(si)=median(tauCount(:),'omitnan');
  R.MedianFitPoints(si)=median(fitPoints(:),'omitnan');
  R.MedianFitDecades(si)=median(fitSpan(:),'omitnan');
  R.MedianFitR2(si)=median(fitR2(:),'omitnan');
  R.MuInsufficientEventsFraction(si)=mean(tauCount(:)<P.MinTauCount,'omitnan');
  R.MuInsufficientPointsFraction(si)=mean(tauCount(:)>=P.MinTauCount & fitPoints(:)<P.MinFitPoints);
  R.MuFitEstimableFraction(si)=mean(isfinite(mu(:)));
  R.MuValidFraction(si)=nnz(valid)/numel(valid);
  R.MuFiniteFraction(si)=nnz(isfinite(mu))/numel(mu);
  R.MuR2PassFraction(si)=nnz(r2OK)/numel(mu);
  R.MuSpanPassFraction(si)=nnz(spanOK)/numel(mu);
  R.MuRangePassFraction(si)=nnz(rangeOK)/numel(mu);
  mm=mu(valid);if ~isempty(mm),R.ValidMuMedian(si)=median(mm);end
  R.ValidWindowFraction(si)=mean(isfinite(d(:)));R.MDEAFailures(si)=fail;
  if isfinite(cs),R.Reason(si)="ok";
  elseif ng<P.MinCSWindows,R.Reason(si)="insufficient_valid_mdea_windows";
  else,R.Reason(si)="zero_delta_variance";end
 end
end
function tau=getTau(info)
 tau=[];
 if isstruct(info)&&isfield(info,'Event')&&~isempty(info.Event)
  ev=info.Event(:)~=0;tau=diff(find(ev));
 end
 tau=double(tau(:));tau=tau(isfinite(tau)&tau>0);
end
function [u,psi]=survivalPoints(tau)
 tau=double(tau(:));tau=tau(isfinite(tau)&tau>0);
 if isempty(tau),u=[];psi=[];return;end
 [u,~,ic]=unique(tau);counts=accumarray(ic,1);
 psi=flipud(cumsum(flipud(counts)))/numel(tau);
end
function [mu,r2,lo,hi,npt,span]=muFit(tau,P)
 mu=NaN;r2=NaN;lo=NaN;hi=NaN;npt=0;span=NaN;
 if numel(tau)<P.MinTauCount,return;end
 if isfield(P,'MuFitMode')&&P.MuFitMode=="manual"
  [mu,r2,lo,hi,npt,span]=muManualFit(tau,P);
  % Keep the estimate for display, but validity is checked separately.
  return;
 end
 [u,psi]=survivalPoints(tau);
 g=psi>=P.PsiMin&psi<=P.PsiMax&u>0;
 u=u(g);psi=psi(g);n=numel(u);if n<P.MinFitPoints,return;end
 % Bound the cost of the quality search without altering its log-scale support.
 if n>100
  pick=unique(round(linspace(1,n,100)));u=u(pick);psi=psi(pick);n=numel(u);
 end
 % Select the longest estimable fit interval independently of quality gates.
 % This avoids the V6 circularity: previously mu/r2/span were NaN unless
 % ALL three gates passed, so separate QC fractions were identical.
 % Prefer the broadest available interval (at least MinFitPoints); report
 % R2, exponent, span separately, even when they fail their thresholds.
 x=log10(u);y=log10(psi);
 sx=[0;cumsum(x)];sy=[0;cumsum(y)];sxx=[0;cumsum(x.^2)];...
 sxy=[0;cumsum(x.*y)];syy=[0;cumsum(y.^2)];
 best=-Inf;
 for i=1:n-P.MinFitPoints+1
  for j=n:-1:i+P.MinFitPoints-1
   sp=x(j)-x(i);if sp<=best,break;end
   nn=j-i+1;Sx=sx(j+1)-sx(i);Sy=sy(j+1)-sy(i);
   Sxx=sxx(j+1)-sxx(i);Sxy=sxy(j+1)-sxy(i);Syy=syy(j+1)-syy(i);
   den=Sxx-Sx^2/nn;tot=Syy-Sy^2/nn;
   if den<=eps||tot<=eps,continue;end
   slope=(Sxy-Sx*Sy/nn)/den;
   if slope>=0,continue;end
   rr=max(-Inf,min(1,(Sxy-Sx*Sy/nn)^2/(den*tot)));
   mu=1-slope;r2=rr;lo=u(i);hi=u(j);npt=nn;span=sp;
   best=sp;break;
  end
 end
 % A broad-fit diagnostic is not evidence of a true power law. Users must
 % inspect curvature / alternate intervals in the interactive preflight.

end
function [mu,r2,lo,hi,npt,span]=muManualFit(tau,P)
 mu=NaN;r2=NaN;lo=NaN;hi=NaN;npt=0;span=NaN;
 [u,psi]=survivalPoints(tau);
 use=u>=P.MuTauStart&u<=P.MuTauEnd&psi>=P.PsiMin&psi<=P.PsiMax;
 if nnz(use)<P.MinFitPoints,return;end
 x=log10(u(use));y=log10(psi(use));q=polyfit(x,y,1);
 ss=sum((y-mean(y)).^2);if ss<=eps,return;end
 mu=1-q(1);r2=1-sum((y-polyval(q,x)).^2)/ss;
 lo=P.MuTauStart;hi=P.MuTauEnd;npt=nnz(use);span=log10(hi/lo);
end
function [mu,r2,lo,hi]=muPreviewFit(tau,P)
 % Display-only fallback: never contributes to MuValidFraction or stripe choice.
 mu=NaN;r2=NaN;lo=NaN;hi=NaN;
 [u,psi]=survivalPoints(tau);
 g=u>0&psi>=P.PsiMin&psi<=P.PsiMax;
 if P.MuFitMode=="manual",g=g&u>=P.MuTauStart&u<=P.MuTauEnd;end
 u=u(g);psi=psi(g);if numel(u)<P.MinFitPoints,return;end
 % Use broad central candidate so even nonpassing fits are inspectable.
 lo=u(1);hi=u(end);x=log10(u);y=log10(psi);
 q=polyfit(x,y,1);ss=sum((y-mean(y)).^2);
 if ss<=eps,return;end
 mu=1-q(1);r2=1-sum((y-polyval(q,x)).^2)/ss;
end
function x=tern(cond,a,b)
 if cond,x=a;else,x=b;end
end

function [c,n]=halfCorr(a,b,minN)
 good=isfinite(a)&isfinite(b);n=nnz(good);c=NaN;
 if n>=minN && std(a(good))>0 && std(b(good))>0
  z=corrcoef(a(good),b(good));c=z(1,2);
 end
end

function M=compareTailModels(tau,P)
 M=struct('n',NaN,'xmin',NaN,'mu',NaN,'shape',NaN,...
  'aic',nan(1,3),'best',"not_estimable",'deltaPower',NaN);
 tau=double(tau(:));tau=tau(isfinite(tau)&tau>0);
 if numel(tau)<P.ModelMinTailN,return;end
 xmin=prctile(tau,100*P.ModelTailQuantile);
 x=tau(tau>=xmin);n=numel(x);
 M.n=n;M.xmin=xmin;
 if n<P.ModelMinTailN || xmin<=0 || numel(unique(x))<4,return;end
 % Continuous approximations for integer waiting times. All three models
 % are conditioned on the same xmin and fitted to the same tail sample.
 y=x-xmin;z=max(y,.5); % half-sample continuity correction for discrete tau
 den=sum(log(x/xmin));
 if den<=0,return;end
 alpha=n/den;M.mu=alpha+1;
 llP=n*log(alpha)-n*log(xmin)-(alpha+1)*den;
 rate=1/max(mean(y),eps);
 llE=n*log(rate)-rate*sum(y);
 % Weibull excess-time fit: shape k, scale lambda; k<1 is stretched exp.
 obj=@(q) weibullNegLogLik(z,exp(q(1)),exp(q(2)));
 q0=[0,log(max(mean(z),.5))];
 opts=optimset('Display','off','MaxIter',150,'MaxFunEvals',300);
 q=fminsearch(obj,q0,opts);
 k=exp(q(1));lambda=exp(q(2));llW=-obj(q);
 M.shape=k;
 M.aic=[2-2*llP,2-2*llE,4-2*llW];
 if any(~isfinite(M.aic)),return;end
 [best,idx]=min(M.aic);M.deltaPower=M.aic(1)-best;
 labels=["power_law","exponential","weibull"];M.best=labels(idx);
end
function v=weibullNegLogLik(z,k,lambda)
 if ~isfinite(k)||~isfinite(lambda)||k<.05||k>10||lambda<=0
  v=realmax/1e100;return;
 end
 a=z./lambda;
 if any(~isfinite(a))||any(a<=0),v=realmax/1e100;return;end
 v=-(numel(z)*log(k)-numel(z)*k*log(lambda)+...
   (k-1)*sum(log(z))-sum(a.^k));
 if ~isfinite(v),v=realmax/1e100;end
end


function T=v9RecordingSweep(file,P,Q,fi)
 names={'File','Subject','Task','WindowSeconds','Overlap','Stripe','NWindows','NValidWindows', ...
  'CS','MedianMu','MedianR2','MedianFitSpan','MuValidFraction','TauCount', ...
  'Lag1Spearman','RenewalPermutationP','RenewalPass','AgingDistance','AgingAtAge','AgingSurrogateP','AgingSurrogateZ','Reason'};
 types=repmat({'double'},1,numel(names));
 types(ismember(names,{'File','Subject','Task','Reason'}))={'string'};
 types(ismember(names,{'RenewalPass'}))={'logical'};
 n=numel(Q.WindowSeconds)*numel(Q.OverlapFractions)*numel(Q.Stripes);
 T=table('Size',[n numel(names)],'VariableTypes',types,'VariableNames',names);
 T.File(:)=string(file.name);T.Reason(:)="not_processed";
 T.CS(:)=NaN;T.MedianMu(:)=NaN;T.MedianR2(:)=NaN;T.MedianFitSpan(:)=NaN;
 T.Lag1Spearman(:)=NaN;T.RenewalPermutationP(:)=NaN;T.AgingDistance(:)=NaN;
 T.AgingAtAge(:)=NaN;T.AgingSurrogateP(:)=NaN;T.AgingSurrogateZ(:)=NaN;T.MuValidFraction(:)=NaN;
 [~,stem]=fileparts(file.name);
 tok=regexp(stem,'^(D\d+)_B\d+_(T\d+)','tokens','once');
 if isempty(tok),subj=string(stem);task="unknown";else,subj=string(tok{1});task=string(tok{2});end
 T.Subject(:)=subj;T.Task(:)=task;
 row=0;
 for wi=1:numel(Q.WindowSeconds)
  for oi=1:numel(Q.OverlapFractions)
   for si=1:numel(Q.Stripes)
    row=row+1;T.WindowSeconds(row)=Q.WindowSeconds(wi);
    T.Overlap(row)=Q.OverlapFractions(oi);T.Stripe(row)=Q.Stripes(si);
   end
  end
 end
 try,[X,fs,labels]=loadEEG(fullfile(file.folder,file.name));
 catch ME,T.Reason(:)="load_error: "+string(ME.message);return;end
 idxA=find(ismember(lower(labels),lower(P.Auditory)));
 idxM=find(ismember(lower(labels),lower(P.Sensorimotor)));
 if numel(idxA)<P.MinAuditoryChannels||numel(idxM)<P.MinSensorimotorChannels
  T.Reason(:)="missing_channels";return;
 end
 idxA=idxA(1:min(numel(idxA),P.MaxChannelsA));
 idxM=idxM(1:min(numel(idxM),P.MaxChannelsM));
 row=0;
 for wi=1:numel(Q.WindowSeconds)
  W=round(Q.WindowSeconds(wi)*fs);
  for oi=1:numel(Q.OverlapFractions)
   ov=Q.OverlapFractions(oi);
   for si=1:numel(Q.Stripes)
    row=row+1;sz=Q.Stripes(si);
    if W<128||W>size(X,2),T.Reason(row)="short_recording";continue;end
    hop=max(1,round(W*(1-ov)));
    starts=1:hop:(size(X,2)-W+1);
    if numel(starts)>Q.MaxWindowsPerCondition
     starts=starts(unique(round(linspace(1,numel(starts),Q.MaxWindowsPerCondition))));
    end
    nW=numel(starts);T.NWindows(row)=nW;
    a=nan(nW,1);b=nan(nW,1);mm=nan(nW,1);rr=nan(nW,1);ss=nan(nW,1);
    % Use all recognized selected auditory and sensorimotor channels
    % per window, with all five stripes on identical starts.
    ac=idxA;mc=idxM; % use all selected auditory/sensorimotor channels
    central=ceil(nW/2);tauCentral=[];
    for k=1:nW
     av=nan(numel(ac),1);mv=nan(numel(mc),1);
     for c=1:numel(ac)
      x=X(ac(c),starts(k):starts(k)+W-1);
      if any(~isfinite(x))||max(x)==min(x),continue;end
      try
       [av(c),info]=MDEAcorrected(x,sz,P.Rule,P.ST,P.EN,0);
       if c==1
        tau=getTau(info);
        [mu,r2,~,~,np,span]=muFit(tau,P);
        mm(k)=mu;rr(k)=r2;ss(k)=span;
        if k==central,tauCentral=tau;end
       end
      catch
      end
     end
     for c=1:numel(mc)
      x=X(mc(c),starts(k):starts(k)+W-1);
      if any(~isfinite(x))||max(x)==min(x),continue;end
      try,mv(c)=MDEAcorrected(x,sz,P.Rule,P.ST,P.EN,0);catch,end
     end
     a(k)=median(av,'omitnan');b(k)=median(mv,'omitnan');
    end
    good=isfinite(a)&isfinite(b);T.NValidWindows(row)=nnz(good);
    if nnz(good)>=Q.MinCSWindows&&std(a(good))>0&&std(b(good))>0
     C=corrcoef(a(good),b(good));T.CS(row)=C(1,2);
    end
    T.MedianMu(row)=median(mm,'omitnan');T.MedianR2(row)=median(rr,'omitnan');
    T.MedianFitSpan(row)=median(ss,'omitnan');
    T.MuValidFraction(row)=mean(isfinite(mm)&mm>P.MuMin&mm<P.MuMax&rr>=P.MuR2Min);
    T.TauCount(row)=numel(tauCentral);
    [rho,pval,dist,age,ap,az]=v9Renewal(tauCentral,Q,fi,row);
    T.Lag1Spearman(row)=rho;T.RenewalPermutationP(row)=pval;
    T.RenewalPass(row)=isfinite(pval)&&pval>=.05;
    T.AgingDistance(row)=dist;T.AgingAtAge(row)=age;
    T.AgingSurrogateP(row)=ap;T.AgingSurrogateZ(row)=az;
    if isfinite(T.CS(row)),T.Reason(row)="ok";else,T.Reason(row)="insufficient_cs_windows";end
   end
  end
 end
end

function [rho,pval,dist,age,ap,az]=v9Renewal(tau,Q,fi,row)
 % Renewal compatibility: exchangeable intervals vs serially ordered data.
 % Aging statistic compares ordered residual-life curves with a surrogate
 % renewal realization. Aging relative to an exponential is NOT renewal evidence.
 rho=NaN;pval=NaN;dist=NaN;age=NaN;ap=NaN;az=NaN;
 tau=double(tau(:));tau=tau(isfinite(tau)&tau>0);
 if numel(tau)<Q.MinIntervals,return;end
 rs=RandStream('mt19937ar','Seed',Q.RngSeed+fi*1000+row);
 rho=corr(tau(1:end-1),tau(2:end),'Type','Spearman');
 if ~isfinite(rho),return;end
 rnull=nan(Q.NPermutation,1);
 for b=1:Q.NPermutation
  yy=tau(randperm(rs,numel(tau)));
  rnull(b)=corr(yy(1:end-1),yy(2:end),'Type','Spearman');
 end
 pval=(1+nnz(abs(rnull)>=abs(rho)))/(1+Q.NPermutation);
 age=max(1,round(prctile(tau,35)));
 alive=tau(tau>age);
 if numel(alive)<Q.MinSurvivalAtAge,return;end
 tgrid=unique(max(1,round(prctile(tau,[20 35 50 65 80]))));
 empirical=arrayfun(@(t)mean(tau>age+t)/max(mean(tau>age),eps),tgrid);
 memoryless=arrayfun(@(t)mean(tau>t),tgrid);
 dist=max(abs(empirical-memoryless));
 % Under an iid renewal process, shuffling the INTERVALS leaves this
 % marginal aging statistic unchanged. It is therefore not a valid
 % order-sensitive renewal test. Instead use lag-one serial dependence
 % above and a sequence-sensitive aged-count test below.
 observed=agedCountStatistic(tau,age);
 null=nan(Q.NAgingSurrogates,1);
 for b=1:Q.NAgingSurrogates
  yy=tau(randperm(rs,numel(tau)));
  null(b)=agedCountStatistic(yy,age);
 end
 null=null(isfinite(null));
 if numel(null)>=20 && isfinite(observed)
  ap=(1+nnz(abs(null-median(null))>=abs(observed-median(null))))/(1+numel(null));
  az=(observed-mean(null))/max(std(null),eps);
 end
end
function z=agedCountStatistic(tau,age)
 % Compare successive waiting intervals following an unusually long interval.
 % A renewal iid sequence has no systematic effect of the previous interval
 % on the next one; this statistic is sensitive to sequence dependence.
 previous=tau(1:end-1);following=tau(2:end);
 high=previous>=age;low=previous<age;
 if nnz(high)<8||nnz(low)<8,z=NaN;return;end
 z=median(following(high))-median(following(low));
end

function S=v9Summarize(T,Q)
 n=numel(Q.WindowSeconds)*numel(Q.OverlapFractions)*numel(Q.Stripes);
 S=table('Size',[n 11],'VariableTypes',repmat({'double'},1,11), ...
 'VariableNames',{'WindowSeconds','Overlap','Stripe','NRecordings','CSCoverage', ...
 'MedianCS','MedianMu','MedianR2','MedianFitSpan','RenewalTestCoverage','RenewalPassFraction'});
 row=0;
 for wi=1:numel(Q.WindowSeconds)
  for oi=1:numel(Q.OverlapFractions)
   for si=1:numel(Q.Stripes)
    row=row+1;g=T.WindowSeconds==Q.WindowSeconds(wi)& ...
      abs(T.Overlap-Q.OverlapFractions(oi))<1e-8&abs(T.Stripe-Q.Stripes(si))<1e-8;
    z=T(g,:);S.WindowSeconds(row)=Q.WindowSeconds(wi);
    S.Overlap(row)=Q.OverlapFractions(oi);S.Stripe(row)=Q.Stripes(si);
    S.NRecordings(row)=height(z);S.CSCoverage(row)=mean(isfinite(z.CS));
    S.MedianCS(row)=median(z.CS,'omitnan');S.MedianMu(row)=median(z.MedianMu,'omitnan');
    S.MedianR2(row)=median(z.MedianR2,'omitnan');
    S.MedianFitSpan(row)=median(z.MedianFitSpan,'omitnan');
    ok=isfinite(z.RenewalPermutationP);
    S.RenewalTestCoverage(row)=mean(ok);
    if any(ok),S.RenewalPassFraction(row)=mean(z.RenewalPass(ok));
    else,S.RenewalPassFraction(row)=NaN;end
   end
  end
 end
end

function C=v9Bootstrap(T,Q)
 % Cluster bootstrap: draw subjects, then retain all their recordings.
 S=v9Summarize(T,Q);C=S(:,{'WindowSeconds','Overlap','Stripe'});
 C.NSubjects=zeros(height(S),1);
 C.MedianCSLow=nan(height(S),1);C.MedianCSHigh=nan(height(S),1);
 C.MedianMuLow=nan(height(S),1);C.MedianMuHigh=nan(height(S),1);
 rs=RandStream('mt19937ar','Seed',Q.RngSeed+100000);
 for i=1:height(S)
  g=T.WindowSeconds==S.WindowSeconds(i)&abs(T.Overlap-S.Overlap(i))<1e-8& ...
    abs(T.Stripe-S.Stripe(i))<1e-8;
  z=T(g,:);subjects=unique(z.Subject);subjects=subjects(~ismissing(subjects));
  n=numel(subjects);C.NSubjects(i)=n;if n<4,continue;end
  bootCS=nan(Q.NBootstrap,1);bootMu=nan(Q.NBootstrap,1);
  for b=1:Q.NBootstrap
   draw=randi(rs,n,n,1);indices=[];
   for k=1:n,indices=[indices;find(z.Subject==subjects(draw(k)))];end %#ok<AGROW>
   bootCS(b)=median(z.CS(indices),'omitnan');
   bootMu(b)=median(z.MedianMu(indices),'omitnan');
  end
  bootCS=bootCS(isfinite(bootCS));bootMu=bootMu(isfinite(bootMu));
  if numel(bootCS)>10
   C.MedianCSLow(i)=prctile(bootCS,2.5);C.MedianCSHigh(i)=prctile(bootCS,97.5);
  end
  if numel(bootMu)>10
   C.MedianMuLow(i)=prctile(bootMu,2.5);C.MedianMuHigh(i)=prctile(bootMu,97.5);
  end
 end
end

function a=v11RenewalAudit(tau,B,seed)
 a=struct('N',0,'Lag1',NaN,'Lag2',NaN,'Lag1P',NaN,'Lag2P',NaN,...
 'OrderP',NaN,'AgingDistance',NaN,'AgingN',0);
 tau=double(tau(:));tau=tau(isfinite(tau)&tau>0);a.N=numel(tau);
 if numel(tau)<50,return;end
 rs=RandStream('mt19937ar','Seed',seed);
 a.Lag1=corr(tau(1:end-1),tau(2:end),'Type','Spearman');
 a.Lag2=corr(tau(1:end-2),tau(3:end),'Type','Spearman');
 age=prctile(tau,35);a.AgingN=nnz(tau>age);
 if a.AgingN>=15
  tg=unique(prctile(tau,[20 35 50 65 80]));
  cond=arrayfun(@(t)mean(tau>age+t)/mean(tau>age),tg);
  base=arrayfun(@(t)mean(tau>t),tg);
  a.AgingDistance=max(abs(cond-base));
 end
 obs=agedCountStatistic(tau,age);
 n1=nan(B,1);n2=n1;no=n1;
 for i=1:B
  z=tau(randperm(rs,numel(tau)));
  n1(i)=corr(z(1:end-1),z(2:end),'Type','Spearman');
  n2(i)=corr(z(1:end-2),z(3:end),'Type','Spearman');
  no(i)=agedCountStatistic(z,age);
 end
 a.Lag1P=(1+nnz(abs(n1)>=abs(a.Lag1)))/(B+1);
 a.Lag2P=(1+nnz(abs(n2)>=abs(a.Lag2)))/(B+1);
 no=no(isfinite(no));
 if isfinite(obs)&&~isempty(no)
  a.OrderP=(1+nnz(abs(no-median(no))>=abs(obs-median(no))))/(1+numel(no));
 end
end
function v11SaveFigure(f,out,name,pdf)
 exportgraphics(f,fullfile(out,[name '.jpg']),'Resolution',600);
 exportgraphics(f,fullfile(out,[name '.pdf']),'ContentType','vector');
 exportgraphics(f,pdf,'ContentType','vector','Append',true);
 savefig(f,fullfile(out,[name '.fig']));close(f);
end

function a=v12RenewalValidation(tau,B,seed,minN)
 a=struct('N',numel(tau),'Lag1',NaN,'Lag2',NaN,'P1',NaN,'P2',NaN,...
 'PJoint',NaN,'PCond',NaN,'AgingD',NaN,'AgingP',NaN,'Age',NaN,'StationarityP',NaN,'Valid',false);
 tau=double(tau(:));tau=tau(isfinite(tau)&tau>0);a.N=numel(tau);
 if numel(tau)<minN,return;end
 % Log intervals are more stable under extreme tails; Spearman is invariant.
 z=log(tau);n=numel(z);rs=RandStream('mt19937ar','Seed',mod(seed,2^31-1));
 a.Lag1=corr(z(1:end-1),z(2:end),'Type','Spearman');
 a.Lag2=corr(z(1:end-2),z(3:end),'Type','Spearman');
 % Conditional renewal aging: under iid intervals the distribution of the
 % NEXT interval is independent of whether the previous interval was long.
 a.Age=median(tau);flag=tau(1:end-1)>a.Age;
 if nnz(flag)<20||nnz(~flag)<20,return;end
 next=z(2:end);a.AgingD=abs(median(next(flag))-median(next(~flag)));
 % Rank-based conditional-order test complements median difference.
 ranks=tiedrank(next);a.PCond=NaN;
 obsCond=abs(mean(ranks(flag))-mean(ranks(~flag)))/n;
 obsJoint=max(abs([a.Lag1 a.Lag2]));
 obsStat=abs(mean(z(1:floor(n/2)))-mean(z(floor(n/2)+1:end)));
 null1=zeros(B,1);null2=null1;nullD=null1;nullC=null1;nullS=null1;
 for b=1:B
  perm=z(randperm(rs,n));
  null1(b)=corr(perm(1:end-1),perm(2:end),'Type','Spearman');
  null2(b)=corr(perm(1:end-2),perm(3:end),'Type','Spearman');
  f=perm(1:end-1)>median(perm);nx=perm(2:end);
  nullD(b)=abs(median(nx(f))-median(nx(~f)));
  rr=tiedrank(nx);nullC(b)=abs(mean(rr(f))-mean(rr(~f)))/n;
  nullS(b)=abs(mean(perm(1:floor(n/2)))-mean(perm(floor(n/2)+1:end)));
 end
 a.P1=(1+nnz(abs(null1)>=abs(a.Lag1)))/(B+1);
 a.P2=(1+nnz(abs(null2)>=abs(a.Lag2)))/(B+1);
 a.PJoint=(1+nnz(max(abs([null1 null2]),[],2)>=obsJoint))/(B+1);
 a.AgingP=(1+nnz(nullD>=a.AgingD))/(B+1);
 a.PCond=(1+nnz(nullC>=obsCond))/(B+1);
 a.StationarityP=(1+nnz(nullS>=obsStat))/(B+1);
 a.Valid=true;
end
function p=v12Holm(p)
 out=nan(size(p));ix=find(isfinite(p));if isempty(ix),p=out;return;end
 [s,o]=sort(p(ix));m=numel(s);q=cummax((m-(0:m-1)').*s(:));
 v=min(1,q);out(ix(o))=v;p=out;
end
function [lo,hi]=v12SubjectCI(v,B,seed)
 v=double(v(:));v=v(isfinite(v));lo=NaN;hi=NaN;
 if numel(v)<3,return;end
 rs=RandStream('mt19937ar','Seed',seed);boot=nan(B,1);
 for b=1:B,boot(b)=median(v(randi(rs,numel(v),[numel(v) 1])));end
 ci=prctile(boot,[2.5 97.5]);lo=ci(1);hi=ci(2);
end
function C=v12Controls(B,N,minN)
 % Repeated simulations: false-positive rate for iid renewal and sensitivity
 % for correlated nonrenewal, using the same diagnostic code.
 models=["IID_Pareto","IID_Weibull","Alternating","Log_AR1"];
 C=table(models',zeros(4,1),zeros(4,1),zeros(4,1),...
  'VariableNames',{'Model','JointRejectFraction','AgingRejectFraction','ConditionalRejectFraction'});
 rs=RandStream('mt19937ar','Seed',18021988);
 nRep=30;Ptest=99;
 for j=1:4
  q=zeros(nRep,3);
  for r=1:nRep
   u=rand(rs,N,1);u=max(u,1e-10);
   switch j
    case 1,tau=ceil((1-u).^(-1/1.7));
    case 2,tau=ceil(10*(-log(u)).^(1/.7));
    case 3
     z=randn(rs,N,1);z(2:2:end)=z(2:2:end)+1.2;
     z(1:2:end)=z(1:2:end)-1.2;tau=ceil(exp(2+z));
    otherwise
     z=zeros(N,1);epsi=randn(rs,N,1);
     for i=2:N,z(i)=.75*z(i-1)+sqrt(1-.75^2)*epsi(i);end
     tau=ceil(exp(2+z));
   end
   a=v12RenewalValidation(tau,Ptest,100000*j+r,minN);
   q(r,:)=[a.PJoint<.05,a.AgingP<.05,a.PCond<.05];
  end
  C.JointRejectFraction(j)=mean(q(:,1));
  C.AgingRejectFraction(j)=mean(q(:,2));
  C.ConditionalRejectFraction(j)=mean(q(:,3));
 end
end

function R=v12FiveNode(X,fs,labels,P)
 % Five nonoverlapping anatomical groups. These mappings are documented here
 % and MUST be checked against the manuscript channel-to-region mapping.
 names={... 
  ["FT7","FT8","T7","T8","TP7","TP8"],...
  ["FP1","FP2","F1","F2","F3","F4","F5","F6","F7","F8","FZ","AF3","AF4"],...
  ["FC1","FC2","FC3","FC4","C1","C2","C3","C4","C5","C6","CZ"],...
  ["CP1","CP2","CP3","CP4","P1","P2","P3","P4","P5","P6","P7","P8","PZ"],...
  ["PO3","PO4","PO7","PO8","O1","O2","OZ"]};
 idx=cell(1,5);
 for g=1:5
  q=find(ismember(upper(string(labels)),upper(names{g})));
  idx{g}=q(1:min(numel(q),P.V12FiveNodeMaxChannelsPerGroup));
 end
 R=struct('NNodes',zeros(numel(P.Stripes),1),'NEdges',zeros(numel(P.Stripes),1),...
  'MeanSignedCS',nan(numel(P.Stripes),1),'MedianAbsCS',nan(numel(P.Stripes),1));
 W=round(6.4*fs);if W>size(X,2),return;end
 starts=unique(round(linspace(1,size(X,2)-W+1,P.V12FiveNodeWindows)));
 for si=1:numel(P.Stripes)
  d=nan(numel(starts),5);
  for g=1:5
   for w=1:numel(starts)
    v=nan(numel(idx{g}),1);
    for c=1:numel(idx{g})
     x=X(idx{g}(c),starts(w):starts(w)+W-1);
     if any(~isfinite(x))||max(x)==min(x),continue;end
     try,v(c)=MDEAcorrected(x,P.Stripes(si),P.Rule,P.ST,P.EN,0);catch,end
    end
    if ~isempty(v),d(w,g)=median(v,'omitnan');end
   end
  end
  valid=sum(isfinite(d),1)>=8;R.NNodes(si)=nnz(valid);
  edges=[];
  for a=1:4
   for b=a+1:5
    ok=isfinite(d(:,a))&isfinite(d(:,b));
    if nnz(ok)>=8 && std(d(ok,a))>0 && std(d(ok,b))>0
     c=corrcoef(d(ok,a),d(ok,b));edges(end+1)=c(1,2); %#ok<AGROW>
    end
   end
  end
  R.NEdges(si)=numel(edges);
  if ~isempty(edges),R.MeanSignedCS(si)=mean(edges);R.MedianAbsCS(si)=median(abs(edges));end
 end
end

function v19FineTaskSweep(files,Pbase,OUT,mainPdf)
P=struct();P.Stripes=round((.14:.005:.24)*10000)/10000;
P.ST=Pbase.ST;P.EN=Pbase.EN;P.Rule=Pbase.Rule;
P.WindowSeconds=6.4;P.NWindows=16;P.MinPairedWindows=8;
P.MaxChannelsPerGroup=2;P.BootstrapN=2000;
P.UseParallel=Pbase.UseParallel;P.Reference=Pbase.ReferenceSZ;
P.Rest='T00';P.Tasks={'T01','T02','T03','T04','T05','T06'};
P.Groups={ ...
 {'FT7','FT8','T7','T8','TP7','TP8'}, ...
 {'FP1','FP2','F1','F2','F3','F4','F5','F6','F7','F8','FZ','AF3','AF4'}, ...
 {'FC1','FC2','FC3','FC4','C1','C2','C3','C4','C5','C6','CZ'}, ...
 {'CP1','CP2','CP3','CP4','P1','P2','P3','P4','P5','P6','P7','P8','PZ'}, ...
 {'PO3','PO4','PO7','PO8','O1','O2','OZ'}};
P.NodeLabels={'Audio','Frontal','Motor','Parietal','Occipital'};
OUT=fullfile(OUT,'FINE_TASK_CS');if ~isfolder(OUT),mkdir(OUT);end
rng(20261023);
N=numel(files);C=cell(N,1);
fprintf('V16: %d recordings x %d stripe widths, %d windows per width.\n',N,numel(P.Stripes),P.NWindows);
usePar=P.UseParallel&&license('test','Distrib_Computing_Toolbox');
if usePar
 try
  if isempty(gcp('nocreate')),parpool('local');end
 catch ME
  warning('Parallel pool unavailable; running serial: %s',ME.message);usePar=false;
 end
end
h=waitbar(0,'Five-node fine stripe sweep','Name','V16 overall progress');count=0;
if usePar
 dq=parallel.pool.DataQueue;
 afterEach(dq,@advance);
 parfor i=1:N
  C{i}=v19AnalyzeFile(files(i),P);send(dq,1);
 end
else
 for i=1:N
  C{i}=v19AnalyzeFile(files(i),P);advance(1);
 end
end
if isgraphics(h),close(h);end
C=C(~cellfun(@isempty,C));assert(~isempty(C),'No valid recording results');
Raw=vertcat(C{:});writetable(Raw,fullfile(OUT,'V16_RECORDING_EDGE_CS.csv'));
% Median across repeated blocks WITHIN subject/task/stripe/edge.
BySubject=groupsummary(Raw,{'Subject','Task','Stripe','Edge'},'median','CS');
BySubject=BySubject(:,{'Subject','Task','Stripe','Edge','median_CS'});
writetable(BySubject,fullfile(OUT,'V16_SUBJECT_TASK_EDGE_CS.csv'));
% Strict matched subject, edge and stripe. Missing edges are never replaced with 0.
Rest=BySubject(BySubject.Task==string(P.Rest),{'Subject','Stripe','Edge','median_CS'});
Rest.Properties.VariableNames{4}='RestCS';
Task=BySubject(BySubject.Task~=string(P.Rest),:);
Paired=innerjoin(Task,Rest,'Keys',{'Subject','Stripe','Edge'});
Paired.DeltaCS=Paired.median_CS-Paired.RestCS;
writetable(Paired,fullfile(OUT,'V16_SUBJECT_PAIRED_EDGE_DELTA_CS.csv'));
assert(~isempty(Paired),'No matched Rest/task results. Verify T00 is Rest and recording filenames.');
% Per subject and task: signed edge-average, plus magnitude of changes without sign cancellation.
ST=groupsummary(Paired,{'Subject','Task','Stripe'},'mean','DeltaCS');
ST=ST(:,{'Subject','Task','Stripe','mean_DeltaCS'});
AbsP=Paired;AbsP.AbsDelta=abs(AbsP.DeltaCS);
AA=groupsummary(AbsP,{'Subject','Task','Stripe'},'mean','AbsDelta');
ST=innerjoin(ST,AA(:,{'Subject','Task','Stripe','mean_AbsDelta'}),'Keys',{'Subject','Task','Stripe'});
writetable(ST,fullfile(OUT,'V16_SUBJECT_TASK_SUMMARY.csv'));
% Equal subject weight, and equal task weight for pooled descriptive summaries.
Summary=table();
for k=1:numel(P.Tasks)
 task=string(P.Tasks{k});
 for s=P.Stripes
  z=ST(ST.Task==task&abs(ST.Stripe-s)<1e-9,:);
  a=z.mean_DeltaCS;a=a(isfinite(a));b=z.mean_AbsDelta;b=b(isfinite(b));
  [med,lo,hi]=v19CiSubjects(a,P.BootstrapN,round(s*100000)+k*1000);
  Summary=[Summary;table(task,s,numel(a),med,lo,hi,mean(b,'omitnan'), ...
   'VariableNames',{'Task','Stripe','NSubjects','MeanSignedDeltaCS','CI95Low','CI95High','MeanAbsDeltaCS'})]; %#ok<AGROW>
 end
end
writetable(Summary,fullfile(OUT,'V16_TASK_STRIPE_SUMMARY.csv'));
% Aggregate tasks within each subject to avoid pseudoreplication.
Pooled=groupsummary(ST,{'Subject','Stripe'},'mean',{'mean_DeltaCS','mean_AbsDelta'});
Pool=table();
for s=P.Stripes
 z=Pooled(abs(Pooled.Stripe-s)<1e-9,:);
 a=z.mean_mean_DeltaCS;a=a(isfinite(a));b=z.mean_mean_AbsDelta;b=b(isfinite(b));
 [v,lo,hi]=v19CiSubjects(a,P.BootstrapN,round(s*100000)+300);
 [av,al,ah]=v19CiSubjects(b,P.BootstrapN,round(s*100000)+500);
 Pool=[Pool;table(s,numel(a),v,lo,hi,av,al,ah,...
  'VariableNames',{'Stripe','NSubjects','MeanSignedDeltaCS','CI95Low','CI95High','MeanAbsDeltaCS','AbsCI95Low','AbsCI95High'})]; %#ok<AGROW>
end
writetable(Pool,fullfile(OUT,'V16_POOLED_SUBJECT_SUMMARY.csv'));
% Figure S3: six tasks and one pooled panel. Avoid visual cherry-picking.
f=figure('Visible','off','Color','w','Position',[100 100 1350 880]);
tl=tiledlayout(f,3,3,'TileSpacing','compact','Padding','compact');
for k=1:numel(P.Tasks)
 ax=nexttile(tl);z=Summary(Summary.Task==string(P.Tasks{k}),:);
 v19DrawCI(ax,z.Stripe,z.MeanSignedDeltaCS,z.CI95Low,z.CI95High,P.Reference);
 title(ax,strrep(P.Tasks{k},'T','Task T'),'FontWeight','normal');
 ylabel(ax,'Mean signed \DeltaCS');xlabel(ax,'Stripe size');
end
ax=nexttile(tl,[1 3]);v19DrawCI(ax,Pool.Stripe,Pool.MeanSignedDeltaCS,Pool.CI95Low,Pool.CI95High,P.Reference);
title(ax,'Pooled across tasks (equal subject weight)','FontWeight','normal');
ylabel(ax,'Mean signed \DeltaCS');xlabel(ax,'Stripe size');
title(tl,'S3 | Task minus Rest: five-node CS stripe sensitivity','FontSize',12);
exportgraphics(f,fullfile(OUT,'SUPP_S3_TASK_SPECIFIC_FINE_STRIPE.jpg'),'Resolution',600);
exportgraphics(f,fullfile(OUT,'SUPP_S3_TASK_SPECIFIC_FINE_STRIPE.pdf'),'ContentType','vector');
exportgraphics(f,mainPdf,'ContentType','vector','Append',true);
savefig(f,fullfile(OUT,'SUPP_S3_TASK_SPECIFIC_FINE_STRIPE.fig'));close(f);
% Figure S4: pooled absolute change is secondary; never used to pick the reference.
f=figure('Visible','off','Color','w','Position',[100 100 1000 520]);ax=axes(f);
v19DrawCI(ax,Pool.Stripe,Pool.MeanAbsDeltaCS,Pool.AbsCI95Low,Pool.AbsCI95High,P.Reference);
ylabel(ax,'Mean absolute edge change |Task - Rest|');xlabel(ax,'Stripe size');
title(ax,'S4 | Five-node change magnitude (secondary; not selection criterion)','FontWeight','normal');
exportgraphics(f,fullfile(OUT,'SUPP_S4_ABSOLUTE_EDGE_CHANGE.jpg'),'Resolution',600);
exportgraphics(f,fullfile(OUT,'SUPP_S4_ABSOLUTE_EDGE_CHANGE.pdf'),'ContentType','vector');
exportgraphics(f,mainPdf,'ContentType','vector','Append',true);
savefig(f,fullfile(OUT,'SUPP_S4_ABSOLUTE_EDGE_CHANGE.fig'));close(f);
% Edge-level table enables subsequent network inference without rerunning MDEA.
EdgeSummary=groupsummary(Paired,{'Task','Stripe','Edge'},'mean','DeltaCS');
writetable(EdgeSummary,fullfile(OUT,'V16_EDGE_TASK_STRIPE_SUMMARY.csv'));
save(fullfile(OUT,'V16_RESULTS.mat'),'P','Raw','BySubject','Paired','ST','Summary','Pool','EdgeSummary','-v7.3');
fid=fopen(fullfile(OUT,'INTERPRETATION.txt'),'w');
fprintf(fid,['V16 task-specific five-node stripe sensitivity. T00 assumed Rest; verify task mapping.\n',...
 'All six non-Rest tasks analyzed; signed Task-Rest per matched subject/edge.\n',...
 'Repeated blocks summarized within subject. Subjects are bootstrap units.\n',...
 'Task mean averages available edge differences; missing edges are not imputed.\n',...
 'Reference 0.18 is prespecified; do not select stripe from maximum observed effect.\n',...
 'Pointwise 95%% bootstrap intervals are descriptive, not simultaneous bands.\n',...
 'No correction for 21 stripes x 6 tasks x 10 edges; no inferential peak claim.\n',...
 'Matched channel labels and time window positions across stripe sizes; no renewal rerun.\n',...
 'This focused audit uses 16 uniformly spaced windows, not necessarily the full main pipeline.\n',...
 'Output: S3 task curves and S4 absolute edge change, 600-dpi JPG + vector PDF.\n']);fclose(fid);
fprintf('Done. Outputs: %s\n',OUT);
 function advance(~)
  count=count+1;
  if isgraphics(h),waitbar(count/N,h,sprintf('V16 five-node fine sweep: %d/%d',count,N));end
 end
end

function T=v19AnalyzeFile(file,P)
T=table();
tok=regexp(file.name,'^(D\d+)_B\d+_(T\d+)','tokens','once');
if isempty(tok),return;end
subject=string(tok{1});task=string(tok{2});
if ~ismember(task,[string(P.Rest),string(P.Tasks)]),return;end
try
 [X,fs,labels]=loadEEG(fullfile(file.folder,file.name));
 catch ME
 warning('Skipping %s: %s',file.name,ME.message);return;
end
W=round(P.WindowSeconds*fs);if W>size(X,2),return;end
starts=unique(round(linspace(1,size(X,2)-W+1,P.NWindows)));
idx=cell(1,5);labs=upper(string(labels));
for g=1:5
 ii=find(ismember(labs,upper(string(P.Groups{g}))));
 idx{g}=ii(1:min(numel(ii),P.MaxChannelsPerGroup));
end
% Channel mapping fixed across all widths and tasks; all ten edges retained if estimable.
rows=cell(numel(P.Stripes)*10,1);nr=0;
for s=P.Stripes
 D=nan(numel(starts),5);
 for g=1:5
  for w=1:numel(starts)
   vv=nan(numel(idx{g}),1);
   for c=1:numel(idx{g})
    x=double(X(idx{g}(c),starts(w):starts(w)+W-1));
    if any(~isfinite(x))||max(x)==min(x),continue;end
    try
     val=MDEAcorrected(x,s,P.Rule,P.ST,P.EN,0);
     if isfinite(val),vv(c)=val;end
    catch
    end
   end
   if any(isfinite(vv)),D(w,g)=median(vv,'omitnan');end
  end
 end
 for a=1:4
  for b=a+1:5
   ok=isfinite(D(:,a))&isfinite(D(:,b));v=NaN;
   if nnz(ok)>=P.MinPairedWindows && std(D(ok,a))>0 && std(D(ok,b))>0
    z=corrcoef(D(ok,a),D(ok,b));v=z(1,2);
   end
   nr=nr+1;
   rows{nr}=table(string(file.name),subject,task,s,string([P.NodeLabels{a} '-' P.NodeLabels{b}]),v,nnz(ok),...
    'VariableNames',{'File','Subject','Task','Stripe','Edge','CS','NPairedWindows'});
  end
 end
end
T=vertcat(rows{1:nr});
end
function [m,lo,hi]=v19CiSubjects(x,B,seed)
x=x(isfinite(x));n=numel(x);m=NaN;lo=NaN;hi=NaN;
if n==0,return;end
m=mean(x);
if n<2,return;end
st=rng;rng(seed,'twister');
bs=zeros(B,1);
for j=1:B,bs(j)=mean(x(randi(n,n,1)));end
rng(st);q=prctile(bs,[2.5 97.5]);lo=q(1);hi=q(2);
end
function v19DrawCI(ax,x,y,lo,hi,ref)
hold(ax,'on');good=isfinite(x)&isfinite(y);
plot(ax,x(good),y(good),'-o','Color',[.12 .30 .52],'LineWidth',1.5,'MarkerSize',4,'MarkerFaceColor',[.12 .30 .52]);
for i=find(good & isfinite(lo) & isfinite(hi))'
 line(ax,[x(i) x(i)],[lo(i) hi(i)],'Color',[.65 .70 .75],'LineWidth',1);
end
xline(ax,ref,'--','Color',[.4 .4 .4]);yline(ax,0,':','Color',[.5 .5 .5]);
grid(ax,'on');box(ax,'off');set(ax,'FontSize',9,'LineWidth',.8);
xlim(ax,[min(x)-.003 max(x)+.003]);
end


function v20PublicationFigures(out)
% Exactly six publication-oriented pages; detailed diagnostics are preserved.
% recomputed, interpolated, or relabelled as new scientific measurements.
% Composite PDF pages contain 600-dpi raster images; source vector PDFs
figdir=fullfile(out,'FINAL_SUPPLEMENTARY_FIGURES');
if ~isfolder(figdir),mkdir(figdir);end
oldpdf=fullfile(figdir,'ALL_SUPPLEMENTARY_FIGURES.pdf');
if isfile(oldpdf),delete(oldpdf);end
PAGES={...
 'S01_MDEA_SCALING', {'SUPP_S1_REPRESENTATIVE_MDEA_FITS'}, 'MDEA scaling and approved fit regions';...
 'S02_STRIPE_VALIDATION', {'SUPP_MDEA_DELTA_SENSITIVITY','SUPP_STRIPE_FIT_DIAGNOSTICS'}, 'Stripe-width sensitivity: MDEA stability and survival-fit quality';...
 'S03_SURVIVAL_FITS', {'SUPP_S1_REPRESENTATIVE_SURVIVAL_FITS'}, 'Representative survival exponent fits';...
 'S04_TASK_SPECIFIC_CS', {fullfile('FINE_TASK_CS','SUPP_S3_TASK_SPECIFIC_FINE_STRIPE')}, 'Signed task-minus-Rest five-node CS: 21-width sweep';...
 'S05_RENEWAL_DEPENDENCE_AGING', {'SUPP_V12_RENEWAL_SUBJECT_BOOTSTRAP','SUPP_V13_RENEWAL_AGING_CURVES'}, 'Interval-order dependence and residual-life aging';...
 'S06_RENEWAL_CONTROLS', {'SUPP_V12_RENEWAL_CONTROLS'}, 'Renewal and dependent-process control calibration'...
};
PAGES(4,:)=[]; % S4 is supplied by matched main-pipeline sensitivity.
idx=fopen(fullfile(figdir,'FIGURE_INDEX_AND_CAPTION_NOTES.txt'),'w');
assert(idx>0,'Cannot create figure index');
fprintf(idx,'FINAL SUPPLEMENTARY FIGURES: six pages in numbered order.\n');
fprintf(idx,'Original detailed V15/V16 diagnostic figures and tables remain in the parent output.\n');
fprintf(idx,'Primary stripe 0.18 is prespecified from the main Music2 analysis, not selected from task-effect peaks.\n');
fprintf(idx,'MDEA diffusion entropy R2 and waiting-time survival R2 are different diagnostics.\n');
fprintf(idx,'Task comparison uses signed CS_task - CS_rest, with T00 assumed Rest (verify metadata).\n');
fprintf(idx,'S4 is replaced by matched full-cohort nine-geometry analysis from main pipeline.\n');
fprintf(idx,'Matched S4 is descriptive and does not claim subject-level confidence intervals.\n');
fprintf(idx,'Residual-life aging alone does not test interval independence or prove renewal.\n');
fprintf(idx,'Composites embed existing 600-dpi JPGs and thus PDFs are raster, not vector.\n');
fprintf(idx,'For vector source artwork see original individual PDFs in the parent output.\n\n');
for k=1:size(PAGES,1)
 name=PAGES{k,1};sources=PAGES{k,2};pageTitle=PAGES{k,3};
 f=figure('Visible','off','Color','w','Units','pixels','Position',[100 100 1800 1100]);
 tl=tiledlayout(f,numel(sources),1,'TileSpacing','compact','Padding','compact');
 if ~ismember(name,{'S01_MDEA_SCALING','S03_SURVIVAL_FITS'})
 title(tl,sprintf('%s | %s',name,pageTitle),'FontName','Arial','FontSize',17,'FontWeight','bold');
end
 for j=1:numel(sources)
  fn=fullfile(out,[sources{j} '.jpg']);
  if ~isfile(fn)
   close(f);fclose(idx);error('Missing figure source: %s',fn);
  end
  ax=nexttile(tl);img=imread(fn);image(ax,img);axis(ax,'image');axis(ax,'off');
 end
 exportgraphics(f,fullfile(figdir,[name '.jpg']),'Resolution',600);
 exportgraphics(f,fullfile(figdir,[name '.pdf']),'ContentType','image','Resolution',600);
 exportgraphics(f,oldpdf,'ContentType','image','Resolution',600,'Append',k>1);
 savefig(f,fullfile(figdir,[name '.fig']));close(f);
 fprintf(idx,'S%d: %s\n',k,pageTitle);
 for j=1:numel(sources),fprintf(idx,'    source: %s\n',sources{j});end
end
fprintf(idx,'\nAdditional diagnostic data are not part of the primary Rest-referenced inference.\n');
fprintf(idx,'All numerical CSV/MAT outputs are retained in the parent folder.\n');
fclose(idx);
fprintf('Six final supplementary pages: %s\n',figdir);
fprintf('Combined six-page PDF: %s\n',oldpdf);
end


function final_statistical_validation(M)
% Rest-referenced statistical audit from saved recording-level signed CS.
% No direct musical-task-versus-musical-task inference is performed.
% Does not rerun MDEA. Uses verified repeated-person identity internally.
% Dyad 2/Musician 2 and Dyad 9/Musician 1 are the same person.
D=fullfile(M,'FULL_COHORT_ROBUSTNESS');
R=readtable(fullfile(D,'ALL_EDGES_ALL_GEOMETRIES.csv'));
C=readtable(fullfile(D,'SIGNED_CS_MATCHED_TASK_VS_REST_BY_GEOMETRY.csv'));
V=fullfile(M,'UNIFIED_PUBLICATION','STATISTICAL_VALIDATION');
if ~isfolder(V),mkdir(V);end
C.GlobalBH=final_bh(C.P); C.GlobalBY=min(1,C.GlobalBH*sum(1./(1:sum(isfinite(C.P)))));
writetable(C,fullfile(V,'GLOBAL_540_CONTRAST_FDR.csv'));
% VERIFIED IDENTITIES: dyad 2 musician 2 == dyad 9 musician 1.
% Derive the complete 18-context identity table from the observed records;
% do not require a separately maintained CSV.
contexts=unique(R(:,{'Dyad','Musician'}),'rows');
assert(height(contexts)==18,'Expected exactly 18 dyad/musician contexts.');
K=contexts;
K.Context=strcat(string(K.Dyad),'_',string(K.Musician));
K.PersonID=strcat("P_D",string(K.Dyad),"_M",string(K.Musician));
repeatA=K.Context=="2_2"; repeatB=K.Context=="9_1";
assert(nnz(repeatA)==1 && nnz(repeatB)==1, ...
 'Expected repeated contexts Dyad 2/Musician 2 and Dyad 9/Musician 1.');
K.PersonID(repeatA|repeatB)="P_REPEATED_HORN";
assert(numel(unique(K.PersonID))==17,'Expected exactly 17 unique people.');
writetable(K(:,{'Dyad','Musician','PersonID'}), ...
 fullfile(V,'MUSICIAN_ID_MAP_USED.csv'));
missingFlag=fullfile(V,'REQUIRES_PERSON_ID_MAPPING.txt');
if isfile(missingFlag),delete(missingFlag);end
R.Context=strcat(string(R.Dyad),'_',string(R.Musician));
[tf,loc]=ismember(R.Context,K.Context);
assert(all(tf),'Missing musician identity mapping for one or more contexts.');
R.PersonID=K.PersonID(loc);
assert(numel(unique(R.PersonID))==17,'Participant count mismatch.');
stripes=.18; taskNames={'Coordination','Call-response','Familiar','Unfamiliar','Improvisation','Listening'};
T=table();
rng(260924,'twister'); nBoot=5000;
for si=1:numel(stripes)
 if abs(stripes(si)-.18)<1e-10
  X=R;
 else
  d2=fullfile(M,'STRIPE_SIZE_SENSITIVITY',sprintf('STRIPE_%03d',round(stripes(si)*1000)), ...
   'FULL_COHORT_ROBUSTNESS','ALL_EDGES_ALL_GEOMETRIES.csv');
  X=readtable(d2);X.Context=strcat(string(X.Dyad),'_',string(X.Musician));
  [ok,ii]=ismember(X.Context,K.Context);assert(all(ok));X.PersonID=K.PersonID(ii);
  assert(numel(unique(X.PersonID))==17,'Stripe analysis does not contain all 17 musicians.');
 end
 X=X(abs(X.WindowSeconds-6.4)<1e-9 & abs(X.Overlap-.50)<1e-12,:);
 assert(~isempty(X),'Missing primary 6.4-second / 50%% geometry');
 X.Edge=string(X.Edge);
 X.Key=strcat(X.Context,'|',string(X.WindowSeconds),'|',string(X.Overlap),'|',X.Edge);
 ref=X(X.Task==0,:); a=X(X.Task~=0,:);
 [ok,idx]=ismember(a.Key,ref.Key);
 assert(all(ok),'Missing Rest for some task recordings.');
 a.DeltaCS=a.SignedCS-ref.SignedCS(idx);
 people=unique(a.PersonID);n=numel(people);
 % Per-person network average: first across edges/geometries/contexts, then participants.
 % Six independent targets are each task minus Rest, NOT task discrimination.
 E=nan(n,6);
 for pi=1:n
  for t=1:6
   vals=a.DeltaCS(a.PersonID==people(pi)&a.Task==t);
   if ~isempty(vals),E(pi,t)=mean(vals,'omitnan');end
  end
 end
 for t=1:6
  x=E(:,t);x=x(isfinite(x));nn=numel(x);if nn<8,continue;end
  boots=nan(nBoot,1);
  for b=1:nBoot,boots(b)=mean(x(randi(nn,nn,1)));end
  ci=prctile(boots,[2.5 97.5]);
  T=[T;table(stripes(si),t,string(taskNames{t}),nn,mean(x),ci(1),ci(2), ...
   'VariableNames',{'Stripe','Task','TaskLabel','NPeople','MeanDeltaCS','CI_Low','CI_High'})]; %#ok<AGROW>
 end
 if abs(stripes(si)-.18)<1e-10
  % Two-sided participant-level sign-flip p-values, followed by Holm.
  % One shared sign per musician across the six task contrasts preserves
  % their dependence. Each task's raw p uses its OWN null distribution;
  % Holm then controls the six-task family-wise error rate.
  obs=nan(1,6);for t=1:6,obs(t)=final_studentized(E(:,t));end
  nPerm=10000; nullT=nan(nPerm,6);
  for b=1:nPerm
   flip=2*(rand(n,1)>.5)-1;
   for t=1:6,nullT(b,t)=final_studentized(E(:,t).*flip);end
  end
  rawP=nan(6,1);
  for t=1:6
   if sum(isfinite(E(:,t)))>=8
    rawP(t)=(1+sum(abs(nullT(:,t))>=abs(obs(t))))/(nPerm+1);
   end
  end
  holmP=final_holm(rawP);
  result=table((1:6)',string(taskNames)',obs',rawP,holmP,holmP<.05, ...
   'VariableNames',{'Task','TaskLabel','ObservedT','RawPermutationP','HolmFWERP','SignificantHolm05'});
  writetable(result,fullfile(V,'PRIMARY_6p4s_50pct_NETWORK_SIX_TASK_HOLM.csv'));
  % Keep a human-readable primary result table with estimates, intervals,
  % raw and corrected p values in one CSV.
  current=T(abs(T.Stripe-.18)<1e-10,:);
  assert(height(current)==6,'Six task estimates expected for central stripe.');
  current.RawPermutationP=rawP;
  current.HolmFWERP=holmP;
  current.SignificantHolm05=holmP<.05;
  writetable(current,fullfile(V,'PRIMARY_6p4s_50pct_COMPLETE_PRIMARY_RESULTS.csv'));

 end
end
writetable(T,fullfile(V,'PRIMARY_6p4s_50pct_CLUSTER_BOOTSTRAP_STRIPE_TASK_CI.csv'));
% Global 540-contrast visualization omitted from primary outputs (secondary descriptive CSV retained).
final_ci_figure(T,V);
primary_geometry_inference_figure(T,V,M);

fid=fopen(fullfile(V,'STATISTICAL_VALIDATION_README.txt'),'w');
fprintf(fid,'17 unique musicians; 18 contexts. Repeated: D02_M2 and D09_M1.\n');
fprintf(fid,'Bootstrap: 5000 musician-cluster resamples per stripe and task.\n');
fprintf(fid,'PRIMARY 6.4s/50%%: 10000 musician-level sign flips for raw two-sided task p-values; Holm-Bonferroni adjustment across six Rest-referenced tasks.\n');
fprintf(fid,'All 540 edge/task/geometry tests are exploratory robustness diagnostics, not primary inferential claims.\n');
fprintf(fid,['Cluster bootstrap CIs are pointwise, not simultaneous.\n', ...
 'Primary geometry was chosen after exploratory review of the nine geometries; disclose post-hoc selection. Holm does not correct for geometry selection.\n']);
fprintf(fid,'Permutation inference assumes participant-level sign symmetry under the null.\n');
fprintf(fid,'No inferential claims should be made from geometry-level counts alone.\n');
fclose(fid);
end


function primary_geometry_inference_figure(T,V,M)
% PRIMARY inferential display: six musician-cluster task means at 6.4 s/50%.
X=T(abs(T.Stripe-.18)<1e-10,:);
if height(X)~=6,warning('Expected six primary task estimates.');return;end
P=readtable(fullfile(V,'PRIMARY_6p4s_50pct_NETWORK_SIX_TASK_HOLM.csv'));
f=figure('Visible','off','Color','w','Position',[100 100 1250 680]);
ax=axes(f,'Position',[.12 .23 .82 .65]);hold(ax,'on');
y=1:height(X);
for i=1:height(X)
 plot(ax,[X.CI_Low(i),X.CI_High(i)],[y(i),y(i)],'k-','LineWidth',2);
 plot(ax,X.MeanDeltaCS(i),y(i),'ko','MarkerFaceColor','k','MarkerSize',8);
 if i<=height(P),text(ax,X.CI_High(i)+.01,y(i),sprintf('Holm p=%.3g',P.HolmFWERP(i)),'FontSize',11);end
end
xline(ax,0,':','LineWidth',1.5);set(ax,'YTick',y,'YTickLabel',cellstr(X.TaskLabel),'YDir','reverse','FontName','Arial','FontSize',13);
xlabel(ax,'Mean signed task-minus-Rest Delta CS (95% musician bootstrap CI)');
title(ax,'Primary geometry: 6.4 s, 50% overlap | 6-task Holm corrected','FontSize',15);
box(ax,'on');grid(ax,'off');
base=fullfile(V,'PRIMARY_6p4s_50pct_SIX_TASK_INFERENCE');
exportgraphics(f,[base '.jpg'],'Resolution',600);
exportgraphics(f,[base '.pdf'],'ContentType','vector');
mainPDF=fullfile(M,'FIGURES','MAIN','MAIN_FIGURES.pdf');
if isfile(mainPDF),exportgraphics(f,mainPDF,'ContentType','vector','Append',true);end
close(f);
end

function t=final_studentized(x)
x=x(isfinite(x));
if numel(x)<8 || std(x)==0,t=0;else,t=mean(x)/(std(x)/sqrt(numel(x)));end
end

function q=final_holm(p)
% Holm step-down adjusted p-values; valid for dependent tests when each
% underlying p-value is valid. NaNs remain NaNs.
q=nan(size(p));valid=find(isfinite(p)&p>=0&p<=1);
if isempty(valid),return;end
[ps,ord]=sort(p(valid));m=numel(ps);
qa=cummax(ps(:).*(m:-1:1)');qa=min(1,qa);
q(valid(ord))=qa;
end

function q=final_bh(p)
q=nan(size(p));valid=find(isfinite(p)&p>=0&p<=1);if isempty(valid),return;end
[ps,ord]=sort(p(valid));m=numel(ps);
qs=flipud(cummin(flipud(ps(:).*m./(1:m)')));qs=min(1,qs);
q(valid(ord))=qs;
end

function final_fdr_figure(C,V)
f=figure('Visible','off','Color','w','Position',[100 100 1300 800]);
vals=[sum(C.QwithinEdge<.05),sum(C.GlobalBH<.05),sum(C.GlobalBY<.05)];
bar(vals);set(gca,'XTickLabel',{'Within-edge BH','Global BH','Global BY'},'FontSize',14);
ylabel('Significant contrasts (out of 540)','FontSize',16);
title('Multiple-comparison sensitivity across all edge/task/geometry tests','FontSize',17);
final_save_figure(f,V,'S07_GLOBAL_MULTIPLICITY');close(f);
end

function final_ci_figure(T,V)
f=figure('Visible','off','Color','w','Position',[100 100 1450 850]);
for i=1:3
 ax=subplot(1,3,i);stripeVals=[.15 .18 .20];z=T(abs(T.Stripe-stripeVals(i))<1e-10,:);
 errorbar(ax,1:height(z),z.MeanDeltaCS,z.MeanDeltaCS-z.CI_Low,z.CI_High-z.MeanDeltaCS,'o-');
 yline(ax,0,'k:');xticks(ax,1:6);xticklabels(ax,{'Coord','C&R','Fam','Unfam','Imp','Listen'});
 xtickangle(ax,45);title(ax,sprintf('Stripe %.2f',stripeVals(i)));
 ylabel(ax,'Participant-mean signed Delta CS');
end
final_save_figure(f,V,'S08_CLUSTERED_STRIPE_CI');close(f);
end

function final_save_figure(f,V,name)
set(f,'Color','w','Renderer','painters');
axs=findall(f,'Type','axes');
for k=1:numel(axs)
 axs(k).FontSize=14;
 try,axs(k).XLabel.FontSize=16;end
 try,axs(k).YLabel.FontSize=16;end
 try,axs(k).Title.FontSize=17;end
end
exportgraphics(f,fullfile(V,[name '.pdf']),'ContentType','vector');
exportgraphics(f,fullfile(V,[name '.jpg']),'Resolution',600);
savefig(f,fullfile(V,[name '.fig']));
end
