%% QUICK START: Automatic Event Selection and Epoching
%
% This script shows the EASIEST way to automatically select and epoch
% around trial events without manually picking from 1000+ event types.
%
% Just update the file path below and run this script!

clear; clc;

%% ========== CONFIGURATION (EDIT THIS SECTION) ==========

% 1. Set your MFF file path
mffFilePath = 'path/to/your/file.mff';  % <-- CHANGE THIS

% 2. Choose which conditions to include (or leave empty for all)
% Examples:
%   {} - Include ALL conditions (auto-detect)
%   {'SG23', 'SG45', 'SKG1', 'KG1'} - Only these conditions
%   {'G23', 'G45'} - Only G-type conditions
conditionsToInclude = {};  % <-- CHANGE THIS if you want specific conditions

% 3. Set epoching time window (in seconds)
epochTimeWindow = [-0.2, 0.8];  % 200ms before to 800ms after event

% 4. Choose whether to preprocess data first
doPreprocessing = false;  % Set to true to enable filtering

%% ========== SCRIPT STARTS HERE (NO NEED TO EDIT BELOW) ==========

fprintf('\n');
fprintf('====================================================\n');
fprintf('  AUTOMATIC EVENT SELECTION AND EPOCHING\n');
fprintf('====================================================\n\n');

%% Step 1: Load MFF file
fprintf('[Step 1/5] Loading MFF file...\n');
fprintf('  File: %s\n', mffFilePath);

if ~exist(mffFilePath, 'file') && ~exist(mffFilePath, 'dir')
    error('File not found: %s\nPlease update the mffFilePath variable at the top of this script.', mffFilePath);
end

try
    EEG = pop_mffimport(mffFilePath);
    fprintf('  ✓ Loaded: %d channels, %d events, %.1f seconds\n\n', ...
        EEG.nbchan, length(EEG.event), EEG.xmax);
catch ME
    error('Failed to load MFF file: %s', ME.message);
end

%% Step 2: Auto-select trial events
fprintf('[Step 2/5] Auto-selecting trial events...\n');

if isempty(conditionsToInclude)
    fprintf('  Mode: Select ALL EVNT_TRSP events\n');
    selectedEvents = autoSelectTrialEvents(EEG);
else
    fprintf('  Mode: Select specific conditions only\n');
    fprintf('  Conditions: %s\n', strjoin(conditionsToInclude, ', '));
    selectedEvents = autoSelectTrialEvents(EEG, 'Conditions', conditionsToInclude);
end

if isempty(selectedEvents)
    error('No events selected! Check your conditions or data.');
end

fprintf('  ✓ Selected %d event types\n\n', length(selectedEvents));

%% Step 3: Preprocess (optional)
if doPreprocessing
    fprintf('[Step 3/5] Preprocessing data...\n');
    fprintf('  Resampling to 250 Hz...\n');
    EEG = pop_resample(EEG, 250);

    fprintf('  High-pass filtering at 0.5 Hz...\n');
    EEG = pop_eegfiltnew(EEG, 'locutoff', 0.5);

    fprintf('  Low-pass filtering at 50 Hz...\n');
    EEG = pop_eegfiltnew(EEG, 'hicutoff', 50);

    fprintf('  Re-referencing to average...\n');
    EEG = pop_reref(EEG, []);

    fprintf('  ✓ Preprocessing complete\n\n');
else
    fprintf('[Step 3/5] Skipping preprocessing (disabled)\n\n');
end

%% Step 4: Epoch around selected events
fprintf('[Step 4/5] Epoching data around selected events...\n');
fprintf('  Time window: [%.3f, %.3f] seconds\n', epochTimeWindow(1), epochTimeWindow(2));

try
    epochedData = epochEEGByEvents(EEG, selectedEvents, epochTimeWindow);
    fprintf('  ✓ Epoched %d event types\n\n', length(epochedData));
catch ME
    error('Epoching failed: %s', ME.message);
end

%% Step 5: Display results
fprintf('[Step 5/5] Results summary:\n');
fprintf('====================================================\n');

totalEpochs = 0;
for i = 1:length(epochedData)
    ed = epochedData(i);
    totalEpochs = totalEpochs + ed.numEpochs;

    % Extract condition code
    parts = strsplit(ed.eventType, '_');
    if length(parts) >= 4
        condition = parts{4};
    else
        condition = '?';
    end

    fprintf('%2d. %-40s [%s] n=%3d', i, ed.eventType, condition, ed.numEpochs);

    if isfield(ed, 'metrics') && isfield(ed.metrics, 'mean_snr_db')
        fprintf('  SNR=%.1fdB', ed.metrics.mean_snr_db);
    end
    fprintf('\n');
end

fprintf('====================================================\n');
fprintf('Total event types: %d\n', length(epochedData));
fprintf('Total epochs: %d\n', totalEpochs);
fprintf('====================================================\n\n');

%% Plot example ERP
fprintf('Plotting example ERP...\n');

if ~isempty(epochedData) && ~isempty(epochedData(1).avgERP)
    ed = epochedData(1);  % Plot first event type

    figure('Name', sprintf('Auto-Epoched ERP: %s', ed.eventType), ...
           'NumberTitle', 'off', 'Position', [100, 100, 1000, 600]);

    % Determine number of channels to plot
    numChans = min(9, size(ed.avgERP, 1));
    rows = ceil(sqrt(numChans));
    cols = ceil(numChans / rows);

    for ch = 1:numChans
        subplot(rows, cols, ch);
        hold on;

        % Get data
        erpWave = ed.avgERP(ch, :);
        stdWave = ed.stdERP(ch, :);
        timeVec = ed.timeVector;

        % Plot shaded error region
        fill([timeVec, fliplr(timeVec)], ...
             [erpWave + stdWave, fliplr(erpWave - stdWave)], ...
             [0.7 0.85 1], 'EdgeColor', 'none', 'FaceAlpha', 0.3);

        % Plot ERP line
        plot(timeVec, erpWave, 'b', 'LineWidth', 2);

        % Reference lines
        plot([timeVec(1), timeVec(end)], [0, 0], 'k--', 'LineWidth', 0.5);
        plot([0, 0], ylim, 'r--', 'LineWidth', 0.5);

        % Labels
        xlabel('Time (s)');
        ylabel('µV');

        if ch <= length(EEG.chanlocs)
            title(EEG.chanlocs(ch).labels);
        else
            title(sprintf('Ch %d', ch));
        end

        grid on;
        box on;
        hold off;
    end

    sgtitle(sprintf('ERP: %s (n=%d epochs)', ed.eventType, ed.numEpochs), ...
            'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');

    fprintf('  ✓ Figure created\n\n');
else
    fprintf('  ! No data to plot\n\n');
end

%% Save results (optional)
fprintf('====================================================\n');
fprintf('Saving results...\n');

% Create output directory
outputDir = 'auto_epoch_results';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Save MAT file
[~, fileName, ~] = fileparts(mffFilePath);
outputFile = fullfile(outputDir, sprintf('%s_epoched.mat', fileName));
save(outputFile, 'epochedData', 'selectedEvents', 'epochTimeWindow', 'EEG');
fprintf('  ✓ Saved: %s\n', outputFile);

% Save figure
if exist('ed', 'var')
    figFile = fullfile(outputDir, sprintf('%s_erp.png', fileName));
    saveas(gcf, figFile);
    fprintf('  ✓ Saved: %s\n', figFile);
end

fprintf('====================================================\n');
fprintf('\n✓ ALL DONE!\n\n');

fprintf('Next steps:\n');
fprintf('  1. Check the results in: %s/\n', outputDir);
fprintf('  2. Adjust conditions at top of script if needed\n');
fprintf('  3. Re-run to epoch different event types\n\n');
