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
        TotalStages             double = 7
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
            % Run the full analysis pipeline

            provider = app.ProviderDropdown.Value;

            % Stage 1: Load data
            updateProgress(app, 1, 'Loading EEG data...');
            if isempty(app.EEG)
                if endsWith(app.EEGFile, '.mff')
                    app.EEG = pop_mffimport(app.EEGFile, {});
                else
                    app.EEG = pop_loadset(app.EEGFile);
                end
            end
            EEG = app.EEG;
            EEG_original = EEG;

            % Stage 2: Check bad channels (warn but keep)
            updateProgress(app, 2, 'Checking channel quality...');
            badChans = [];
            try
                chanStats = zeros(EEG.nbchan, 1);
                for ch = 1:EEG.nbchan
                    chanStats(ch) = kurtosis(EEG.data(ch, :));
                end
                badChans = find(abs(chanStats) > 5);
            catch
            end

            % Stage 3: AI event detection
            updateProgress(app, 3, sprintf('🤖 AI-powered event detection (%s)...', upper(provider)));
            [selectedEvents, structure, discovery] = autoSelectTrialEventsUniversal(EEG, ...
                'UseAI', 'always', ...
                'AIProvider', provider, ...
                'Display', false);

            % Stage 4: Preprocessing
            updateProgress(app, 4, 'Preprocessing (filtering, re-referencing)...');
            EEG = pop_resample(EEG, 250);
            EEG = pop_eegfiltnew(EEG, 'locutoff', 0.1, 'plotfreqz', 0);
            EEG = pop_eegfiltnew(EEG, 'hicutoff', 30, 'plotfreqz', 0);
            EEG = pop_reref(EEG, []);

            % Stage 5: Epoching
            updateProgress(app, 5, 'Extracting epochs and computing ERPs...');
            timeWindow = [-0.2, 0.8];
            epochedData = epochEEGByEventsUniversal(EEG, selectedEvents, timeWindow, ...
                structure, discovery, discovery.groupingFields);

            % Stage 6: ERP component analysis
            updateProgress(app, 6, 'Analyzing ERP components (N250, N400, P600)...');
            erpAnalysis = analyzeERPComponentsGUI(epochedData, timeWindow);

            % Stage 7: Frequency analysis
            updateProgress(app, 7, 'Analyzing frequency bands...');
            freqAnalysis = analyzeFrequencyBandsGUI(EEG);

            % Store results
            app.Results = struct();
            app.Results.epochedData = epochedData;
            app.Results.erpAnalysis = erpAnalysis;
            app.Results.freqAnalysis = freqAnalysis;
            app.Results.badChannels = badChans;
            app.Results.structure = structure;
            app.Results.discovery = discovery;
            app.Results.selectedEvents = selectedEvents;
            app.Results.EEG = EEG;
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
            pause(0.2);
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
            summary{end+1} = '  ANALYSIS SUMMARY';
            summary{end+1} = '========================================';
            summary{end+1} = '';
            summary{end+1} = sprintf('Event types detected: %d', length(results.selectedEvents));
            summary{end+1} = sprintf('Total epochs: %d', sum([results.epochedData.numEpochs]));

            if ~isempty(results.badChannels)
                summary{end+1} = sprintf('⚠ Bad channels (kept): %d', length(results.badChannels));
            else
                summary{end+1} = '✓ All channels good';
            end

            summary{end+1} = '';
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

            summary{end+1} = 'FREQUENCY BANDS:';
            summary{end+1} = '----------------------------------------';

            if isfield(results.freqAnalysis, 'delta')
                bandNames = {'delta', 'theta', 'alpha', 'beta', 'gamma'};
                for b = 1:length(bandNames)
                    bandName = bandNames{b};
                    if isfield(results.freqAnalysis, bandName)
                        summary{end+1} = sprintf('%s: %.2f μV²/Hz', ...
                            upper(bandName), results.freqAnalysis.(bandName).meanPower);
                    end
                end
            end

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

    erpAnalysis = struct();

    for i = 1:length(epochedData)
        if epochedData(i).numEpochs == 0
            continue;
        end

        erpGlobal = mean(epochedData(i).avgERP, 1);

        [n250Amp, n250Lat] = min(erpGlobal(n250Idx));
        n250LatTime = timeVector(n250Idx);
        n250LatTime = n250LatTime(n250Lat);

        [n400Amp, n400Lat] = min(erpGlobal(n400Idx));
        n400LatTime = timeVector(n400Idx);
        n400LatTime = n400LatTime(n400Lat);

        [p600Amp, p600Lat] = max(erpGlobal(p600Idx));
        p600LatTime = timeVector(p600Idx);
        p600LatTime = p600LatTime(p600Lat);

        erpAnalysis(i).condition = epochedData(i).eventType;
        erpAnalysis(i).n250.amplitude = n250Amp;
        erpAnalysis(i).n250.latency = n250LatTime;
        erpAnalysis(i).n400.amplitude = n400Amp;
        erpAnalysis(i).n400.latency = n400LatTime;
        erpAnalysis(i).p600.amplitude = p600Amp;
        erpAnalysis(i).p600.latency = p600LatTime;
        erpAnalysis(i).numEpochs = epochedData(i).numEpochs;
    end
end

function freqAnalysis = analyzeFrequencyBandsGUI(EEG)
    bands = struct();
    bands.delta = [0.5, 4];
    bands.theta = [4, 8];
    bands.alpha = [8, 13];
    bands.beta = [13, 30];
    bands.gamma = [30, 50];

    freqAnalysis = struct();

    try
        [psd, freqs] = pwelch(EEG.data', [], [], [], EEG.srate);
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
