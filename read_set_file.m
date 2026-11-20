function [data, fs, times, chanlocs, EEG] = read_set_file(setFile)
% read_set_no_eeglab
% Standalone reader for many EEGLAB .set files WITHOUT EEGLAB.
%
% INPUT:
%   setFile : full path to .set file
%
% OUTPUT:
%   data     : EEG data array [nbchan x pnts x trials]
%   fs       : sampling rate
%   times    : time vector (if available)
%   chanlocs : channel locations (if available)
%   EEG      : loaded EEG struct
%
% NOTES:
% - Works for many .set files saved as MATLAB structs.
% - Supports embedded data or external .fdt binary data.
% - Does NOT reproduce all EEGLAB behavior.
% - Assumes .fdt data are stored as float32 in little-endian order,
%   which is the common EEGLAB case.
%
% Example:
%   [data, fs, times, chanlocs, EEG] = read_set_no_eeglab('myfile.set');
%   x = squeeze(data(1,:,1));
%   t = times / 1000;   % if times are in ms
%   plot(t, x)

    if nargin < 1 || isempty(setFile)
        error('You must provide the path to a .set file.');
    end

    if ~isfile(setFile)
        error('File not found: %s', setFile);
    end

    [folder, ~, ext] = fileparts(setFile);
    if ~strcmpi(ext, '.set')
        error('Input file must have extension .set');
    end

    % -------------------- Try loading as MATLAB file --------------------
    S = load(setFile, '-mat');

    % Find EEG struct
    if isfield(S, 'EEG')
        EEG = S.EEG;
    else
        % Sometimes the file may directly contain fields instead of EEG
        % Wrap them into EEG if they look like EEG fields
        possibleFields = fieldnames(S);
        if any(strcmpi(possibleFields, 'data')) || any(strcmpi(possibleFields, 'srate'))
            EEG = S;
        else
            error('Could not find EEG struct inside .set file.');
        end
    end

    % -------------------- Basic metadata --------------------
    fs = [];
    times = [];
    chanlocs = [];

    if isfield(EEG, 'srate')
        fs = EEG.srate;
    end

    if isfield(EEG, 'times')
        times = EEG.times;
    else
        % Construct times if not present
        if isfield(EEG, 'xmin') && isfield(EEG, 'xmax') && isfield(EEG, 'pnts')
            times = linspace(EEG.xmin, EEG.xmax, EEG.pnts);
            % If values look like seconds, user can keep them as seconds.
            % EEGLAB often stores EEG.times in ms, but xmin/xmax are often in seconds.
        end
    end

    if isfield(EEG, 'chanlocs')
        chanlocs = EEG.chanlocs;
    end

    % -------------------- Load data --------------------
    if ~isfield(EEG, 'data')
        error('EEG struct found, but no EEG.data field exists.');
    end

    % Case 1: data already numeric inside .set
    if isnumeric(EEG.data)
        data = EEG.data;
        return
    end

    % Case 2: EEG.data is a filename string pointing to .fdt
    if ischar(EEG.data) || isstring(EEG.data)
        fdtName = char(EEG.data);

        % If empty string, then data are missing
        if isempty(strtrim(fdtName))
            error('EEG.data is empty. Could not locate embedded data or .fdt filename.');
        end

        fdtPath = fullfile(folder, fdtName);
        if ~isfile(fdtPath)
            error('Companion .fdt file not found: %s', fdtPath);
        end

        % Read dimensions
        if ~isfield(EEG, 'nbchan') || ~isfield(EEG, 'pnts')
            error('Need EEG.nbchan and EEG.pnts to read .fdt data.');
        end

        nbchan = double(EEG.nbchan);
        pnts   = double(EEG.pnts);

        if isfield(EEG, 'trials')
            trials = double(EEG.trials);
            if isempty(trials) || trials < 1
                trials = 1;
            end
        else
            trials = 1;
        end

        nExpected = nbchan * pnts * trials;

        fid = fopen(fdtPath, 'r', 'ieee-le');
        if fid == -1
            error('Could not open .fdt file: %s', fdtPath);
        end

        raw = fread(fid, inf, 'float32=>single');
        fclose(fid);

        if numel(raw) ~= nExpected
            error(['Size mismatch reading .fdt file.\n' ...
                   'Expected %d float32 values but found %d.\n' ...
                   'Check whether this .set/.fdt pair uses a different format.'], ...
                   nExpected, numel(raw));
        end

        data = reshape(raw, [nbchan, pnts, trials]);
        return
    end

    error('Unsupported EEG.data format in this .set file.');
end