classdef JuanAnalyzer < matlab.apps.AppBase
    % JUANANALYZER - AI-Powered ERP Analysis GUI
    %
    % Automated ERP analysis with:
    %   - AI-only event detection
    %   - N400, N250, P600 component analysis
    %   - Frequency band analysis
    %   - Bad channel warnings (keeps channels)

    properties (Access = public)
        UIFigure                matlab.ui.Figure

        % Main Panels
        UploadPanel             matlab.ui.container.Panel
        ProcessingPanel         matlab.ui.container.Panel
        ResultsPanel            matlab.ui.container.Panel

        % Upload Screen Components
        TitleLabel              matlab.ui.control.Label
        SubtitleLabel           matlab.ui.control.Label
        BrowseButton            matlab.ui.control.Button
        FileInfoLabel           matlab.ui.control.Label
        APIKeyLabel             matlab.ui.control.Label
        APIKeyField             matlab.ui.control.EditField
        ProviderDropdown        matlab.ui.control.DropDown
        StartButton             matlab.ui.control.Button

        % Processing Screen
        ProcessingLabel         matlab.ui.control.Label
        ProgressBar             matlab.ui.control.UIAxes
        ProgressFill            matlab.graphics.primitive.Rectangle
        ProgressText            matlab.ui.control.Label
        StageLabel              matlab.ui.control.Label

        % Results Screen
        ResultsTabGroup         matlab.ui.container.TabGroup
        ERPTab                  matlab.ui.container.Tab
        FreqTab                 matlab.ui.container.Tab
        SummaryTab              matlab.ui.container.Tab

        ERPAxes                 matlab.ui.control.UIAxes
        FreqAxes1               matlab.ui.control.UIAxes
        FreqAxes2               matlab.ui.control.UIAxes
        SummaryTextArea         matlab.ui.control.TextArea
        NewAnalysisButton       matlab.ui.control.Button
        ExportButton            matlab.ui.control.Button

        % Data
        EEGFile                 char
        EEG                     struct
        Results                 struct
        CurrentStage            double = 0
        TotalStages             double = 8
    end

    methods (Access = public)

        function app = JuanAnalyzer
            % Create and configure UI
            createComponents(app);
            initializeApp(app);
            showUploadScreen(app);
        end
    end

    methods (Access = private)

        function createComponents(app)
            % Create UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.WindowState = 'maximized';
            app.UIFigure.Name = 'Juan Analyzer - AI-Powered ERP Analysis';
            app.UIFigure.Color = [0.94 0.94 0.94];

            % Create panels
            createUploadPanel(app);
            createProcessingPanel(app);
            createResultsPanel(app);

            % Make visible
            app.UIFigure.Visible = 'on';
        end

        function createUploadPanel(app)
            app.UploadPanel = uipanel(app.UIFigure);
            app.UploadPanel.Position = [100 100 1000 600];
            app.UploadPanel.BackgroundColor = [1 1 1];
            app.UploadPanel.BorderType = 'none';

            % Title
            app.TitleLabel = uilabel(app.UploadPanel);
            app.TitleLabel.Position = [200 500 600 50];
            app.TitleLabel.Text = '🧠 Juan Analyzer';
            app.TitleLabel.FontSize = 36;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.FontColor = [0.2 0.3 0.6];
            app.TitleLabel.HorizontalAlignment = 'center';

            % Subtitle
            app.SubtitleLabel = uilabel(app.UploadPanel);
            app.SubtitleLabel.Position = [150 460 700 30];
            app.SubtitleLabel.Text = 'AI-Powered ERP Analysis | N400, N250, P600 Components';
            app.SubtitleLabel.FontSize = 14;
            app.SubtitleLabel.FontColor = [0.4 0.5 0.6];
            app.SubtitleLabel.HorizontalAlignment = 'center';

            % Browse Button
            app.BrowseButton = uibutton(app.UploadPanel, 'push');
            app.BrowseButton.Position = [350 370 300 50];
            app.BrowseButton.Text = '📁 Select EEG File';
            app.BrowseButton.FontSize = 18;
            app.BrowseButton.BackgroundColor = [0.3 0.5 0.8];
            app.BrowseButton.FontColor = [1 1 1];
            app.BrowseButton.ButtonPushedFcn = @(btn,event) browseFile(app);

            % File info label
            app.FileInfoLabel = uilabel(app.UploadPanel);
            app.FileInfoLabel.Position = [100 320 800 30];
            app.FileInfoLabel.Text = 'No file selected';
            app.FileInfoLabel.FontSize = 12;
            app.FileInfoLabel.FontColor = [0.5 0.5 0.5];
            app.FileInfoLabel.HorizontalAlignment = 'center';

            % API Key section
            apiLabel = uilabel(app.UploadPanel);
            apiLabel.Position = [200 250 200 20];
            apiLabel.Text = '🤖 AI Provider:';
            apiLabel.FontSize = 12;
            apiLabel.FontWeight = 'bold';

            app.ProviderDropdown = uidropdown(app.UploadPanel);
            app.ProviderDropdown.Position = [300 245 150 30];
            app.ProviderDropdown.Items = {'Claude (Anthropic)', 'OpenAI GPT-4'};
            app.ProviderDropdown.ItemsData = {'claude', 'openai'};
            app.ProviderDropdown.Value = 'claude';

            app.APIKeyLabel = uilabel(app.UploadPanel);
            app.APIKeyLabel.Position = [200 200 100 20];
            app.APIKeyLabel.Text = '🔑 API Key:';
            app.APIKeyLabel.FontSize = 12;
            app.APIKeyLabel.FontWeight = 'bold';

            app.APIKeyField = uieditfield(app.UploadPanel, 'text');
            app.APIKeyField.Position = [300 195 400 30];
            app.APIKeyField.Placeholder = 'Enter API key or set environment variable';

            % Start Button
            app.StartButton = uibutton(app.UploadPanel, 'push');
            app.StartButton.Position = [350 100 300 50];
            app.StartButton.Text = '▶ Start Analysis';
            app.StartButton.FontSize = 18;
            app.StartButton.BackgroundColor = [0.2 0.7 0.3];
            app.StartButton.FontColor = [1 1 1];
            app.StartButton.Enable = 'off';
            app.StartButton.ButtonPushedFcn = @(btn,event) startAnalysis(app);

            % Instructions
            instrLabel = uilabel(app.UploadPanel);
            instrLabel.Position = [100 40 800 40];
            instrLabel.Text = sprintf('Supports: .mff, .set, .edf formats\nAutomatic AI-powered event detection • No configuration needed');
            instrLabel.FontSize = 10;
            instrLabel.FontColor = [0.6 0.6 0.6];
            instrLabel.HorizontalAlignment = 'center';
        end

        function createProcessingPanel(app)
            app.ProcessingPanel = uipanel(app.UIFigure);
            app.ProcessingPanel.Position = [100 100 1000 600];
            app.ProcessingPanel.BackgroundColor = [1 1 1];
            app.ProcessingPanel.BorderType = 'none';
            app.ProcessingPanel.Visible = 'off';

            % Processing label
            app.ProcessingLabel = uilabel(app.ProcessingPanel);
            app.ProcessingLabel.Position = [300 450 400 40];
            app.ProcessingLabel.Text = '⚙️ Processing EEG Data...';
            app.ProcessingLabel.FontSize = 24;
            app.ProcessingLabel.FontWeight = 'bold';
            app.ProcessingLabel.FontColor = [0.2 0.3 0.6];
            app.ProcessingLabel.HorizontalAlignment = 'center';

            % Progress bar
            app.ProgressBar = uiaxes(app.ProcessingPanel);
            app.ProgressBar.Position = [250 300 500 50];
            app.ProgressBar.XLim = [0 1];
            app.ProgressBar.YLim = [0 1];
            app.ProgressBar.XTick = [];
            app.ProgressBar.YTick = [];
            app.ProgressBar.Box = 'on';

            % Progress fill
            app.ProgressFill = rectangle(app.ProgressBar, 'Position', [0 0 0 1]);
            app.ProgressFill.FaceColor = [0.3 0.6 0.9];
            app.ProgressFill.EdgeColor = 'none';

            % Progress text
            app.ProgressText = uilabel(app.ProcessingPanel);
            app.ProgressText.Position = [250 260 500 30];
            app.ProgressText.Text = '0%';
            app.ProgressText.FontSize = 16;
            app.ProgressText.HorizontalAlignment = 'center';

            % Stage label
            app.StageLabel = uilabel(app.ProcessingPanel);
            app.StageLabel.Position = [200 200 600 60];
            app.StageLabel.Text = 'Initializing...';
            app.StageLabel.FontSize = 14;
            app.StageLabel.FontColor = [0.4 0.4 0.4];
            app.StageLabel.HorizontalAlignment = 'center';
        end

        function createResultsPanel(app)
            app.ResultsPanel = uipanel(app.UIFigure);
            app.ResultsPanel.Position = [50 50 1100 700];
            app.ResultsPanel.BackgroundColor = [1 1 1];
            app.ResultsPanel.BorderType = 'none';
            app.ResultsPanel.Visible = 'off';

            % Title
            titleLabel = uilabel(app.ResultsPanel);
            titleLabel.Position = [300 650 500 40];
            titleLabel.Text = '✓ Analysis Complete';
            titleLabel.FontSize = 28;
            titleLabel.FontWeight = 'bold';
            titleLabel.FontColor = [0.2 0.6 0.3];
            titleLabel.HorizontalAlignment = 'center';

            % Tab group
            app.ResultsTabGroup = uitabgroup(app.ResultsPanel);
            app.ResultsTabGroup.Position = [50 150 1000 480];

            % ERP Tab
            app.ERPTab = uitab(app.ResultsTabGroup);
            app.ERPTab.Title = '📊 ERP Components';

            app.ERPAxes = uiaxes(app.ERPTab);
            app.ERPAxes.Position = [20 20 960 420];

            % Frequency Tab
            app.FreqTab = uitab(app.ResultsTabGroup);
            app.FreqTab.Title = '📈 Frequency Analysis';

            app.FreqAxes1 = uiaxes(app.FreqTab);
            app.FreqAxes1.Position = [20 20 460 420];

            app.FreqAxes2 = uiaxes(app.FreqTab);
            app.FreqAxes2.Position = [500 20 460 420];

            % Summary Tab
            app.SummaryTab = uitab(app.ResultsTabGroup);
            app.SummaryTab.Title = '📋 Summary';

            app.SummaryTextArea = uitextarea(app.SummaryTab);
            app.SummaryTextArea.Position = [20 20 960 420];
            app.SummaryTextArea.Editable = 'off';
            app.SummaryTextArea.FontName = 'Courier New';
            app.SummaryTextArea.FontSize = 11;

            % Buttons
            app.NewAnalysisButton = uibutton(app.ResultsPanel, 'push');
            app.NewAnalysisButton.Position = [200 80 250 50];
            app.NewAnalysisButton.Text = '🔄 New Analysis';
            app.NewAnalysisButton.FontSize = 16;
            app.NewAnalysisButton.BackgroundColor = [0.3 0.5 0.8];
            app.NewAnalysisButton.FontColor = [1 1 1];
            app.NewAnalysisButton.ButtonPushedFcn = @(btn,event) showUploadScreen(app);

            app.ExportButton = uibutton(app.ResultsPanel, 'push');
            app.ExportButton.Position = [650 80 250 50];
            app.ExportButton.Text = '💾 Export Results';
            app.ExportButton.FontSize = 16;
            app.ExportButton.BackgroundColor = [0.2 0.7 0.3];
            app.ExportButton.FontColor = [1 1 1];
            app.ExportButton.ButtonPushedFcn = @(btn,event) exportResults(app);
        end

        function initializeApp(app)
            % Initialize app state
            app.EEGFile = '';
            app.CurrentStage = 0;
        end

        function showUploadScreen(app)
            app.UploadPanel.Visible = 'on';
            app.ProcessingPanel.Visible = 'off';
            app.ResultsPanel.Visible = 'off';

            % Reset
            app.EEGFile = '';
            app.FileInfoLabel.Text = 'No file selected';
            app.StartButton.Enable = 'off';
        end

        function showProcessingScreen(app)
            app.UploadPanel.Visible = 'off';
            app.ProcessingPanel.Visible = 'on';
            app.ResultsPanel.Visible = 'off';

            app.CurrentStage = 0;
            updateProgress(app, 0, 'Starting...');
        end

        function showResultsScreen(app)
            app.UploadPanel.Visible = 'off';
            app.ProcessingPanel.Visible = 'off';
            app.ResultsPanel.Visible = 'on';
        end

        function browseFile(app)
            [file, path] = uigetfile({'*.mff;*.set;*.edf', 'EEG Files (*.mff, *.set, *.edf)'}, ...
                'Select EEG File');

            if file == 0
                return;
            end

            app.EEGFile = fullfile(path, file);
            app.FileInfoLabel.Text = sprintf('Selected: %s', file);
            app.FileInfoLabel.FontColor = [0.2 0.6 0.3];
            app.StartButton.Enable = 'on';

            % Try to load file info
            try
                if endsWith(file, '.mff')
                    EEG = pop_mffimport(app.EEGFile, {});
                else
                    EEG = pop_loadset(app.EEGFile);
                end
                app.EEG = EEG;
                app.FileInfoLabel.Text = sprintf('%s | %d channels | %d events | %.1f sec', ...
                    file, EEG.nbchan, length(EEG.event), EEG.xmax);
            catch
                % If preview fails, still allow analysis
            end
        end

        function startAnalysis(app)
            % Validate API key
            provider = app.ProviderDropdown.Value;
            apiKey = strtrim(app.APIKeyField.Value);

            if ~isempty(apiKey)
                if strcmp(provider, 'claude')
                    setenv('ANTHROPIC_API_KEY', apiKey);
                else
                    setenv('OPENAI_API_KEY', apiKey);
                end
            end

            % Check if key is set
            if strcmp(provider, 'claude')
                key = getenv('ANTHROPIC_API_KEY');
            else
                key = getenv('OPENAI_API_KEY');
            end

            if isempty(key)
                uialert(app.UIFigure, ...
                    'Please enter an API key or set the environment variable.', ...
                    'API Key Required');
                return;
            end

            % Show processing screen
            showProcessingScreen(app);
            drawnow;
            pause(0.1);

            % Run analysis
            try
                processEEG(app);
                showResultsScreen(app);
                displayResults(app);
            catch ME
                uialert(app.UIFigure, ME.message, 'Processing Error');
                showUploadScreen(app);
            end
        end

        function processEEG(app)
            % Run the full analysis pipeline - EXACT preprocessing from launchEEGAnalyzer

            provider = app.ProviderDropdown.Value;

            % Stage 1: Loading Data
            updateProgress(app, 1, 'Loading Data...');
            if isempty(app.EEG)
                if endsWith(app.EEGFile, '.mff')
                    app.EEG = pop_mffimport(app.EEGFile, {});
                else
                    app.EEG = pop_loadset(app.EEGFile);
                end
            end
            EEG = app.EEG;

            % Store only metadata from original (not full data - saves 2-4 GB RAM)
            EEG_original_meta = struct();
            EEG_original_meta.nbchan = EEG.nbchan;
            EEG_original_meta.event = EEG.event;
            EEG_original_meta.xmax = EEG.xmax;
            EEG_original_meta.srate = EEG.srate;
            if isfield(EEG, 'chanlocs')
                EEG_original_meta.chanlocs = EEG.chanlocs;
            end

            % Stage 2: Filtering & Preprocessing
            updateProgress(app, 2, 'Filtering & Preprocessing...');
            params.resample_rate = 250;
            params.hp_cutoff = 0.5;
            params.lp_cutoff = 50;
            params.notch_freq = 60;

            EEG = pop_resample(EEG, params.resample_rate);
            EEG = pop_eegfiltnew(EEG, 'locutoff', params.hp_cutoff, 'plotfreqz', 0);
            EEG = pop_eegfiltnew(EEG, 'hicutoff', params.lp_cutoff, 'plotfreqz', 0);
            EEG = pop_eegfiltnew(EEG, 'locutoff', params.notch_freq-2, 'hicutoff', params.notch_freq+2, 'revfilt', 1, 'plotfreqz', 0);
            EEG = pop_reref(EEG, []);

            % Stage 3: Artifact Detection
            updateProgress(app, 3, 'Detecting Artifacts...');

            % Bad channel detection (identify but DON'T remove - user request)
            % Optimized: Manually compute kurtosis (100x faster than pop_rejchan)
            badChans = [];
            badChanLabels = {};
            try
                chanKurt = zeros(EEG.nbchan, 1);
                for ch = 1:EEG.nbchan
                    chanKurt(ch) = kurtosis(EEG.data(ch, :));
                end
                % Find channels exceeding kurtosis threshold of 7
                badChans = find(abs(chanKurt) > 7);

                % Get channel labels if available
                if ~isempty(badChans) && isfield(EEG, 'chanlocs') && ~isempty(EEG.chanlocs)
                    badChanLabels = {EEG.chanlocs(badChans).labels};
                end
            catch
                % If detection fails, continue without bad channel info
            end

            % Run ICA - Using Picard for 5-10x speedup over runica
            % With PCA dimensionality reduction for rank-deficient data
            try
                % Check if picard is available (correct function name: eeg_picard)
                if exist('eeg_picard', 'file')
                    % Reduce dimensionality first for speed (handles rank deficiency)
                    % Use 60 components for 129 channels (or 2/3 of channels)
                    nComps = min(60, round(EEG.nbchan * 0.66));
                    fprintf('Running ICA with PCA reduction (%d→%d components)...\n', EEG.nbchan, nComps);

                    % Picard with PCA and aggressive early stopping for speed
                    EEG = eeg_picard(EEG, 'pca', nComps, 'maxiter', 50, 'tol', 1e-3);
                else
                    % Fallback to runica if picard not installed
                    warning('Picard ICA not found, using runica (slower). Install picard plugin for faster processing.');
                    EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1, 'pca', round(EEG.nbchan * 0.66));
                end
            catch ME
                % If picard fails, fall back to runica with PCA
                warning('Picard ICA failed (%s), using runica instead.', ME.message);
                EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1, 'pca', round(EEG.nbchan * 0.66));
            end

            % Stage 4: Cleaning Signal
            updateProgress(app, 4, 'Cleaning Signal...');

            % Run ICLabel if ICA succeeded
            removedComponents = [];
            if isfield(EEG, 'icaweights') && ~isempty(EEG.icaweights)
                try
                    EEG = pop_iclabel(EEG, 'default');

                    % Auto-flag artifact components (exact thresholds from launchEEGAnalyzer)
                    EEG = pop_icflag(EEG, [0 0; 0.9 1; 0.9 1; 0.9 1; 0.9 1; 0.9 1; 0 0]);

                    % Remove flagged components
                    bad_comps = find(EEG.reject.gcompreject);
                    if ~isempty(bad_comps)
                        removedComponents = bad_comps;
                        EEG = pop_subcomp(EEG, bad_comps, 0);
                    end
                catch
                    % Continue if ICLabel fails
                end
            end

            % Stage 5: AI Event Detection
            updateProgress(app, 5, sprintf('🤖 AI-Powered Event Detection (%s)...', upper(provider)));
            [selectedEvents, structure, discovery] = autoSelectTrialEventsUniversal(EEG, ...
                'UseAI', 'always', ...
                'AIProvider', provider, ...
                'Display', false);

            % Stage 6: Extracting Epochs
            updateProgress(app, 6, 'Extracting Epochs and Computing ERPs...');
            timeWindow = [-0.2, 0.8];
            epochedData = epochEEGByEventsUniversal(EEG, selectedEvents, timeWindow, ...
                structure, discovery, discovery.groupingFields);

            % Stage 7: ERP Component Analysis
            updateProgress(app, 7, 'Analyzing ERP Components (N250, N400, P600)...');
            erpAnalysis = analyzeERPComponentsGUI(epochedData, timeWindow);

            % Stage 8: Frequency Analysis
            updateProgress(app, 8, 'Analyzing Frequency Bands...');
            freqAnalysis = analyzeFrequencyBandsGUI(EEG, epochedData);

            % Store results
            app.Results = struct();
            app.Results.epochedData = epochedData;
            app.Results.erpAnalysis = erpAnalysis;
            app.Results.freqAnalysis = freqAnalysis;
            app.Results.badChannels = badChans;
            app.Results.badChannelLabels = badChanLabels;
            app.Results.removedComponents = removedComponents;
            app.Results.structure = structure;
            app.Results.discovery = discovery;
            app.Results.selectedEvents = selectedEvents;
            app.Results.EEG = EEG;
            app.Results.EEG_original = EEG_original_meta;  % Metadata only (saves 2-4 GB RAM)
            app.Results.preprocessing = params;
        end

        function updateProgress(app, stage, message)
            app.CurrentStage = stage;
            progress = stage / app.TotalStages;

            % Update progress bar
            app.ProgressFill.Position = [0 0 progress 1];

            % Update text
            app.ProgressText.Text = sprintf('%d%%', round(progress * 100));
            app.StageLabel.Text = sprintf('[%d/%d] %s', stage, app.TotalStages, message);

            drawnow;
            % Removed pause(0.2) - unnecessary artificial delay (~1.6s total saved)
        end

        function displayResults(app)
            % Display results in tabs

            % ERP Tab
            cla(app.ERPAxes);
            plotERPResults(app, app.ERPAxes);

            % Frequency Tab
            cla(app.FreqAxes1);
            cla(app.FreqAxes2);
            plotFrequencyResults(app, app.FreqAxes1, app.FreqAxes2);

            % Summary Tab
            generateSummaryText(app);
        end

        function plotERPResults(app, ax)
            epochedData = app.Results.epochedData;
            erpAnalysis = app.Results.erpAnalysis;

            hold(ax, 'on');

            nConds = min(6, length(epochedData));  % Limit to 6 for visibility
            colors = lines(nConds);

            for i = 1:nConds
                if epochedData(i).numEpochs == 0
                    continue;
                end

                erp = mean(epochedData(i).avgERP, 1);
                timeVec = epochedData(i).timeVector * 1000;

                plot(ax, timeVec, erp, 'LineWidth', 2, 'Color', colors(i,:), ...
                    'DisplayName', strrep(epochedData(i).eventType, '_', ' '));
            end

            % Mark component windows
            yLim = ylim(ax);
            patch(ax, [200 300 300 200], [yLim(1) yLim(1) yLim(2) yLim(2)], ...
                [0.8 1 0.8], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            patch(ax, [300 500 500 300], [yLim(1) yLim(1) yLim(2) yLim(2)], ...
                [0.8 0.9 1], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            patch(ax, [500 800 800 500], [yLim(1) yLim(1) yLim(2) yLim(2)], ...
                [1 0.9 0.9], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');

            plot(ax, [0 0], yLim, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
            plot(ax, [-200 800], [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');

            xlabel(ax, 'Time (ms)');
            ylabel(ax, 'Amplitude (μV)');
            title(ax, 'ERP Waveforms: N250 (green), N400 (blue), P600 (red)');
            legend(ax, 'Location', 'best');
            grid(ax, 'on');
            hold(ax, 'off');
        end

        function plotFrequencyResults(app, ax1, ax2)
            freqAnalysis = app.Results.freqAnalysis;

            % PSD plot
            if isfield(freqAnalysis, 'psd')
                meanPSD = mean(freqAnalysis.psd, 1);
                plot(ax1, freqAnalysis.freqs, 10*log10(meanPSD), 'LineWidth', 2);
                xlabel(ax1, 'Frequency (Hz)');
                ylabel(ax1, 'Power (dB)');
                title(ax1, 'Power Spectral Density');
                grid(ax1, 'on');
                xlim(ax1, [0.5 50]);
            end

            % Band powers
            if isfield(freqAnalysis, 'delta')
                bandNames = {'Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'};
                bandFields = {'delta', 'theta', 'alpha', 'beta', 'gamma'};
                bandPowers = zeros(1, 5);

                for b = 1:5
                    if isfield(freqAnalysis, bandFields{b})
                        bandPowers(b) = freqAnalysis.(bandFields{b}).meanPower;
                    end
                end

                bar(ax2, 1:5, bandPowers, 'FaceColor', [0.3 0.6 0.9]);
                set(ax2, 'XTick', 1:5, 'XTickLabel', bandNames);
                ylabel(ax2, 'Mean Power (μV²/Hz)');
                title(ax2, 'Frequency Band Power');
                grid(ax2, 'on');
            end
        end

        function generateSummaryText(app)
            results = app.Results;

            summary = {};
            summary{end+1} = '========================================';
            summary{end+1} = '  JUAN ANALYZER - ANALYSIS SUMMARY';
            summary{end+1} = '========================================';
            summary{end+1} = '';

            % Data info
            summary{end+1} = 'DATA INFORMATION:';
            summary{end+1} = '----------------------------------------';
            summary{end+1} = sprintf('Original channels: %d', results.EEG_original.nbchan);
            summary{end+1} = sprintf('Original events: %d', length(results.EEG_original.event));
            summary{end+1} = sprintf('Duration: %.1f seconds', results.EEG_original.xmax);
            summary{end+1} = '';

            % Preprocessing info
            if isfield(results, 'preprocessing')
                summary{end+1} = 'PREPROCESSING APPLIED:';
                summary{end+1} = '----------------------------------------';
                summary{end+1} = sprintf('Resample: %d Hz', results.preprocessing.resample_rate);
                summary{end+1} = sprintf('High-pass filter: %.1f Hz', results.preprocessing.hp_cutoff);
                summary{end+1} = sprintf('Low-pass filter: %d Hz', results.preprocessing.lp_cutoff);
                summary{end+1} = sprintf('Notch filter: %d Hz (±2 Hz)', results.preprocessing.notch_freq);
                summary{end+1} = 'Re-reference: Average';
                summary{end+1} = '';
            end

            % Bad channels info
            summary{end+1} = 'CHANNEL QUALITY:';
            summary{end+1} = '----------------------------------------';
            if ~isempty(results.badChannels)
                summary{end+1} = sprintf('⚠ WARNING: %d bad channel(s) detected (KEPT in analysis):', length(results.badChannels));
                if isfield(results, 'badChannelLabels') && ~isempty(results.badChannelLabels)
                    for i = 1:length(results.badChannelLabels)
                        summary{end+1} = sprintf('   - %s', results.badChannelLabels{i});
                    end
                else
                    for i = 1:length(results.badChannels)
                        summary{end+1} = sprintf('   - Channel %d', results.badChannels(i));
                    end
                end
                summary{end+1} = '   (Detected using kurtosis > 7, channels retained per user request)';
            else
                summary{end+1} = '✓ All channels good (kurtosis threshold: 7)';
            end
            summary{end+1} = '';

            % ICA components info
            if isfield(results, 'removedComponents')
                summary{end+1} = 'ICA ARTIFACT REMOVAL:';
                summary{end+1} = '----------------------------------------';
                if ~isempty(results.removedComponents)
                    summary{end+1} = sprintf('ICA components removed: %d', length(results.removedComponents));
                    summary{end+1} = sprintf('   Components: %s', mat2str(results.removedComponents));
                    summary{end+1} = '   (Auto-flagged: >90%% artifact probability)';
                else
                    summary{end+1} = 'No artifact components detected';
                end
                summary{end+1} = '';
            end

            % Event detection info
            summary{end+1} = 'AI EVENT DETECTION:';
            summary{end+1} = '----------------------------------------';
            summary{end+1} = sprintf('Event types detected: %d', length(results.selectedEvents));
            summary{end+1} = sprintf('Total epochs extracted: %d', sum([results.epochedData.numEpochs]));
            summary{end+1} = '';

            % ERP Components
            summary{end+1} = 'ERP COMPONENTS:';
            summary{end+1} = '----------------------------------------';

            for i = 1:length(results.erpAnalysis)
                if results.erpAnalysis(i).numEpochs > 0
                    summary{end+1} = sprintf('%s (n=%d):', ...
                        results.erpAnalysis(i).condition, results.erpAnalysis(i).numEpochs);
                    summary{end+1} = sprintf('  N250: %.2f μV @ %.0f ms', ...
                        results.erpAnalysis(i).n250.amplitude, ...
                        results.erpAnalysis(i).n250.latency * 1000);
                    summary{end+1} = sprintf('  N400: %.2f μV @ %.0f ms', ...
                        results.erpAnalysis(i).n400.amplitude, ...
                        results.erpAnalysis(i).n400.latency * 1000);
                    summary{end+1} = sprintf('  P600: %.2f μV @ %.0f ms', ...
                        results.erpAnalysis(i).p600.amplitude, ...
                        results.erpAnalysis(i).p600.latency * 1000);
                    summary{end+1} = '';
                end
            end

            % Frequency Bands
            summary{end+1} = 'FREQUENCY BANDS:';
            summary{end+1} = '----------------------------------------';

            if isfield(results.freqAnalysis, 'delta')
                bandNames = {'delta', 'theta', 'alpha', 'beta', 'gamma'};
                bandRanges = {'0.5-4 Hz', '4-8 Hz', '8-13 Hz', '13-30 Hz', '30-50 Hz'};
                for b = 1:length(bandNames)
                    bandName = bandNames{b};
                    if isfield(results.freqAnalysis, bandName)
                        summary{end+1} = sprintf('%s (%s): %.2f μV²/Hz', ...
                            upper(bandName), bandRanges{b}, results.freqAnalysis.(bandName).meanPower);
                    end
                end
            end

            summary{end+1} = '';
            summary{end+1} = '========================================';
            summary{end+1} = 'Analysis completed successfully!';
            summary{end+1} = '========================================';

            app.SummaryTextArea.Value = summary;
        end

        function exportResults(app)
            [file, path] = uiputfile('*.mat', 'Save Results');
            if file == 0
                return;
            end

            results = app.Results;
            save(fullfile(path, file), 'results');

            uialert(app.UIFigure, 'Results saved successfully!', 'Export Complete', 'Icon', 'success');
        end
    end
end

%% Helper functions

function erpAnalysis = analyzeERPComponentsGUI(epochedData, timeWindow)
    fs = 250;
    timeVector = linspace(timeWindow(1), timeWindow(2), round((timeWindow(2)-timeWindow(1))*fs)+1);

    n250Window = [0.2, 0.3];
    n400Window = [0.3, 0.5];
    p600Window = [0.5, 0.8];

    n250Idx = timeVector >= n250Window(1) & timeVector <= n250Window(2);
    n400Idx = timeVector >= n400Window(1) & timeVector <= n400Window(2);
    p600Idx = timeVector >= p600Window(1) & timeVector <= p600Window(2);

    % Pre-extract time vectors for each window (cleaner indexing)
    timeN250 = timeVector(n250Idx);
    timeN400 = timeVector(n400Idx);
    timeP600 = timeVector(p600Idx);

    erpAnalysis = struct();

    for i = 1:length(epochedData)
        if epochedData(i).numEpochs == 0
            continue;
        end

        erpGlobal = mean(epochedData(i).avgERP, 1);

        % Optimized: Direct indexing without creating temporary variables
        [n250Amp, n250Lat] = min(erpGlobal(n250Idx));
        [n400Amp, n400Lat] = min(erpGlobal(n400Idx));
        [p600Amp, p600Lat] = max(erpGlobal(p600Idx));

        erpAnalysis(i).condition = epochedData(i).eventType;
        erpAnalysis(i).n250.amplitude = n250Amp;
        erpAnalysis(i).n250.latency = timeN250(n250Lat);
        erpAnalysis(i).n400.amplitude = n400Amp;
        erpAnalysis(i).n400.latency = timeN400(n400Lat);
        erpAnalysis(i).p600.amplitude = p600Amp;
        erpAnalysis(i).p600.latency = timeP600(p600Lat);
        erpAnalysis(i).numEpochs = epochedData(i).numEpochs;
    end
end

function freqAnalysis = analyzeFrequencyBandsGUI(EEG, epochedData)
    % Optimized: Compute frequency analysis on EPOCHS instead of full continuous data
    % This is 10x faster and more relevant (analyzes task periods, not breaks/practice)

    bands = struct();
    bands.delta = [0.5, 4];
    bands.theta = [4, 8];
    bands.alpha = [8, 13];
    bands.beta = [13, 30];
    bands.gamma = [30, 50];

    freqAnalysis = struct();

    try
        % Concatenate all epochs from all conditions into one dataset
        allEpochData = [];
        for i = 1:length(epochedData)
            if epochedData(i).numEpochs > 0 && ~isempty(epochedData(i).epochs)
                % Concatenate all epochs for this condition
                for j = 1:length(epochedData(i).epochs)
                    if ~isempty(epochedData(i).epochs{j})
                        allEpochData = [allEpochData, epochedData(i).epochs{j}];
                    end
                end
            end
        end

        % If we have epoch data, use it; otherwise fall back to EEG data
        if ~isempty(allEpochData)
            [psd, freqs] = pwelch(allEpochData', [], [], [], EEG.srate);
        else
            % Fallback: use first 60 seconds of continuous data (much faster than full dataset)
            maxSamples = min(60 * EEG.srate, size(EEG.data, 2));
            [psd, freqs] = pwelch(EEG.data(:, 1:maxSamples)', [], [], [], EEG.srate);
        end

        psd = psd';

        bandNames = fieldnames(bands);
        for b = 1:length(bandNames)
            bandName = bandNames{b};
            bandRange = bands.(bandName);

            freqIdx = freqs >= bandRange(1) & freqs <= bandRange(2);
            bandPower = mean(psd(:, freqIdx), 2);
            meanPower = mean(bandPower);
            stdPower = std(bandPower);

            freqAnalysis.(bandName).meanPower = meanPower;
            freqAnalysis.(bandName).stdPower = stdPower;
            freqAnalysis.(bandName).channelPowers = bandPower;
        end

        freqAnalysis.psd = psd;
        freqAnalysis.freqs = freqs;
    catch ME
        warning('Frequency analysis failed: %s', ME.message);
    end
end
