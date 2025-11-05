function launchJuanAnalyzer()
    % LAUNCHJUANANALYZER - Start the Juan Analyzer GUI
    %
    % This is a convenience launcher that adds the JuanAnalyzer folder
    % to the path and launches the application.

    % Get the directory where this script is located
    scriptDir = fileparts(mfilename('fullpath'));

    % Add JuanAnalyzer folder to path
    juanAnalyzerPath = fullfile(scriptDir, 'JuanAnalyzer');

    if exist(juanAnalyzerPath, 'dir')
        addpath(juanAnalyzerPath);
        fprintf('Added JuanAnalyzer to path: %s\n', juanAnalyzerPath);
    else
        error('JuanAnalyzer folder not found at: %s', juanAnalyzerPath);
    end

    % Call the actual launcher in the JuanAnalyzer folder
    run(fullfile(juanAnalyzerPath, 'launchJuanAnalyzer.m'));
end
