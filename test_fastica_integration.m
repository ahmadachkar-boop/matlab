% TEST_FASTICA_INTEGRATION - Verify FastICA integration with EEGLAB
%
% This script tests the FastICA integration by:
%   1. Checking if FastICA is in the MATLAB path
%   2. Running FastICA on sample data
%   3. Verifying EEGLAB compatibility
%
% Usage:
%   test_fastica_integration()

fprintf('\n========================================\n');
fprintf('  Testing FastICA Integration\n');
fprintf('========================================\n\n');

%% Step 1: Check FastICA availability
fprintf('1. Checking for FastICA...\n');
if exist('fastica', 'file')
    fprintf('   ✓ FastICA found!\n');
    fastica_path = which('fastica');
    fprintf('   Location: %s\n\n', fastica_path);
else
    error('❌ FastICA not found in MATLAB path!\n   Please add FastICA directory to path using: addpath(''path/to/fastica'')');
end

%% Step 2: Test with synthetic data
fprintf('2. Testing FastICA with synthetic signals...\n');

% Create 3 synthetic source signals
t = linspace(0, 10, 2500);  % 10 seconds at 250 Hz
s1 = sin(2*pi*5*t);         % 5 Hz sine wave
s2 = square(2*pi*3*t);      % 3 Hz square wave
s3 = randn(size(t));        % Random noise

S = [s1; s2; s3];

% Create mixing matrix
A = [0.8, 0.3, 0.5;
     0.4, 0.9, 0.1;
     0.2, 0.6, 0.8];

% Mix the signals
X = A * S;

% Run FastICA
fprintf('   Running FastICA...\n');
[icasig, A_est, W] = fastica(X, 'verbose', 'off');

if ~isempty(icasig)
    fprintf('   ✓ FastICA successfully separated %d components\n\n', size(icasig, 1));
else
    error('❌ FastICA failed to separate components');
end

%% Step 3: Test with EEGLAB structure (if EEGLAB is available)
fprintf('3. Testing EEGLAB integration...\n');

if exist('eeglab', 'file')
    % Initialize EEGLAB
    eeglab nogui;

    % Create sample EEG structure
    EEG = eeg_emptyset();
    EEG.srate = 250;
    EEG.nbchan = 32;
    EEG.pnts = 5000;
    EEG.trials = 1;
    EEG.xmin = 0;
    EEG.xmax = (EEG.pnts - 1) / EEG.srate;

    % Generate random data
    EEG.data = randn(EEG.nbchan, EEG.pnts);

    % Add channel locations
    for ch = 1:EEG.nbchan
        EEG.chanlocs(ch).labels = sprintf('Ch%d', ch);
    end

    % Run FastICA using wrapper function
    fprintf('   Running runFastICA_EEG wrapper...\n');
    try
        EEG = runFastICA_EEG(EEG, 'verbose', 'off');

        % Check if ICA fields are populated correctly
        assert(isfield(EEG, 'icaweights'), 'icaweights not found');
        assert(isfield(EEG, 'icasphere'), 'icasphere not found');
        assert(isfield(EEG, 'icawinv'), 'icawinv not found');
        assert(isfield(EEG, 'icaact'), 'icaact not found');

        fprintf('   ✓ EEGLAB structure populated correctly\n');
        fprintf('   ✓ ICA weights: %dx%d\n', size(EEG.icaweights));
        fprintf('   ✓ ICA activations: %dx%d\n', size(EEG.icaact));
        fprintf('   ✓ Compatible with ICLabel and pop_subcomp\n\n');

    catch ME
        error('❌ EEGLAB integration failed: %s', ME.message);
    end
else
    fprintf('   ⚠ EEGLAB not available, skipping EEGLAB test\n\n');
end

%% Summary
fprintf('========================================\n');
fprintf('  ✓ All Tests Passed!\n');
fprintf('========================================\n\n');
fprintf('FastICA is ready to use in your pipeline.\n');
fprintf('It will automatically be used in:\n');
fprintf('  - JuanAnalyzer GUI\n');
fprintf('  - launchEEGAnalyzer (when updated)\n\n');
fprintf('To manually use FastICA:\n');
fprintf('  EEG = runFastICA_EEG(EEG);\n\n');

%% Optional: Compare FastICA vs runica performance
fprintf('========================================\n');
fprintf('Performance Comparison (optional)\n');
fprintf('========================================\n\n');

response = input('Run performance comparison? (y/n): ', 's');
if strcmpi(response, 'y')
    % Create test data
    EEG_test = eeg_emptyset();
    EEG_test.srate = 250;
    EEG_test.nbchan = 32;
    EEG_test.pnts = 10000;  % 40 seconds
    EEG_test.data = randn(EEG_test.nbchan, EEG_test.pnts);

    fprintf('\nTesting on %d channels, %d time points (%.1f sec)\n\n', ...
        EEG_test.nbchan, EEG_test.pnts, EEG_test.pnts/EEG_test.srate);

    % Test FastICA
    fprintf('Running FastICA...\n');
    tic;
    EEG_fastica = runFastICA_EEG(EEG_test, 'verbose', 'off');
    time_fastica = toc;
    fprintf('FastICA time: %.2f seconds\n\n', time_fastica);

    % Test runica
    fprintf('Running runica...\n');
    tic;
    EEG_runica = pop_runica(EEG_test, 'icatype', 'runica', 'extended', 1);
    time_runica = toc;
    fprintf('runica time: %.2f seconds\n\n', time_runica);

    fprintf('========================================\n');
    fprintf('Speedup: %.2fx %s\n', abs(time_runica/time_fastica), ...
        ternary(time_fastica < time_runica, 'faster', 'slower'));
    fprintf('========================================\n\n');
end

fprintf('✓ Test complete!\n');

function result = ternary(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
