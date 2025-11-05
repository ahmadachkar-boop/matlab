function EEG = runFastICA_EEG(EEG, varargin)
    % runFastICA_EEG - Run FastICA on EEGLAB EEG structure
    %
    % Usage:
    %   EEG = runFastICA_EEG(EEG)
    %   EEG = runFastICA_EEG(EEG, 'param', value, ...)
    %
    % Inputs:
    %   EEG - EEGLAB EEG structure
    %
    % Optional Parameters:
    %   'approach'    - 'symm' (default) or 'defl' (deflation)
    %   'numOfIC'     - Number of ICs (default: EEG.nbchan)
    %   'g'           - Nonlinearity: 'tanh', 'gauss', 'pow3', 'skew' (default: 'tanh')
    %   'finetune'    - Fine-tuning: 'off', 'tanh', 'gauss', 'pow3' (default: 'off')
    %   'stabilization' - 'on' or 'off' (default: 'on')
    %   'verbose'     - 'on' or 'off' (default: 'on')
    %   'maxIter'     - Maximum iterations (default: 1000)
    %
    % Output:
    %   EEG - EEG structure with ICA fields populated
    %
    % Example:
    %   EEG = runFastICA_EEG(EEG);
    %   EEG = runFastICA_EEG(EEG, 'approach', 'symm', 'g', 'tanh', 'verbose', 'off');
    %
    % Note: Requires FastICA toolbox in MATLAB path
    %   Download from: https://research.ics.aalto.fi/ica/fastica/

    % Parse inputs
    p = inputParser;
    addParameter(p, 'approach', 'symm', @ischar);
    addParameter(p, 'numOfIC', EEG.nbchan, @isnumeric);
    addParameter(p, 'g', 'tanh', @ischar);
    addParameter(p, 'finetune', 'off', @ischar);
    addParameter(p, 'stabilization', 'on', @ischar);
    addParameter(p, 'verbose', 'on', @ischar);
    addParameter(p, 'maxIter', 1000, @isnumeric);
    parse(p, varargin{:});

    % Check if FastICA is available
    if ~exist('fastica', 'file')
        error('FastICA not found! Please add FastICA to your MATLAB path.');
    end

    fprintf('Running FastICA on %d channels, %d time points...\n', EEG.nbchan, EEG.pnts);

    % Prepare data: FastICA expects [channels x time points]
    data = double(EEG.data(:, :));

    % Handle multiple epochs
    if ndims(EEG.data) == 3
        fprintf('Concatenating %d epochs for ICA...\n', EEG.trials);
        data = reshape(EEG.data, EEG.nbchan, []);
    end

    % Run FastICA
    % Returns: icasig = [ICs x time], A = mixing matrix, W = unmixing matrix
    try
        [icasig, A, W] = fastica(data, ...
            'approach', p.Results.approach, ...
            'numOfIC', p.Results.numOfIC, ...
            'g', p.Results.g, ...
            'finetune', p.Results.finetune, ...
            'stabilization', p.Results.stabilization, ...
            'verbose', p.Results.verbose, ...
            'maxNumIterations', p.Results.maxIter);

        if isempty(icasig)
            error('FastICA returned empty result. Try adjusting parameters.');
        end

    catch ME
        error('FastICA failed: %s', ME.message);
    end

    % Store results in EEGLAB format
    % EEGLAB uses: icaweights, icasphere, icawinv, icaact
    % FastICA gives: W (unmixing), A (mixing), icasig (sources)

    EEG.icaweights = W;
    EEG.icasphere = eye(size(W, 2));  % FastICA doesn't use sphering separately
    EEG.icawinv = A;  % Inverse of unmixing = mixing matrix

    % Store ICA activations
    if ndims(EEG.data) == 3
        % Reshape back to epochs
        EEG.icaact = reshape(icasig, size(icasig, 1), EEG.pnts, EEG.trials);
    else
        EEG.icaact = icasig;
    end

    % Store ICA parameters
    EEG.icachansind = 1:EEG.nbchan;  % All channels used

    fprintf('✓ FastICA completed: %d independent components extracted\n', size(W, 1));
end
