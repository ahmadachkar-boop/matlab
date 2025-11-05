function diagnose_chanlocs(EEG)
% Diagnose channel location issues for topoplot
% Usage: diagnose_chanlocs(EEG)

    if nargin < 1
        error('Please provide an EEG structure: diagnose_chanlocs(EEG)');
    end

    fprintf('\n=== Channel Location Diagnostic ===\n\n');

    % Check if chanlocs exists
    if ~isfield(EEG, 'chanlocs') || isempty(EEG.chanlocs)
        fprintf('❌ ERROR: No channel locations found!\n');
        return;
    end

    nChans = length(EEG.chanlocs);
    fprintf('Total channels in chanlocs: %d\n', nChans);
    fprintf('Total data channels: %d\n', EEG.nbchan);

    if nChans ~= EEG.nbchan
        fprintf('⚠️  WARNING: Mismatch between chanlocs (%d) and data channels (%d)\n', ...
            nChans, EEG.nbchan);
    end

    % Check coordinate fields
    fprintf('\n--- Coordinate Fields ---\n');
    hasX = isfield(EEG.chanlocs, 'X') && ~all(cellfun(@isempty, {EEG.chanlocs.X}));
    hasY = isfield(EEG.chanlocs, 'Y') && ~all(cellfun(@isempty, {EEG.chanlocs.Y}));
    hasZ = isfield(EEG.chanlocs, 'Z') && ~all(cellfun(@isempty, {EEG.chanlocs.Z}));
    hasTheta = isfield(EEG.chanlocs, 'theta') && ~all(cellfun(@isempty, {EEG.chanlocs.theta}));
    hasRadius = isfield(EEG.chanlocs, 'radius') && ~all(cellfun(@isempty, {EEG.chanlocs.radius}));

    fprintf('Cartesian (X,Y,Z): %s, %s, %s\n', ...
        yn(hasX), yn(hasY), yn(hasZ));
    fprintf('Polar (theta,radius): %s, %s\n', yn(hasTheta), yn(hasRadius));

    if ~hasTheta || ~hasRadius
        fprintf('⚠️  WARNING: Missing polar coordinates needed for topoplot\n');
        fprintf('   Run: EEG = pop_chanedit(EEG, ''convert'', ''cart2all'');\n');
    end

    % Check for reference/fiducial electrodes
    fprintf('\n--- Channel Types ---\n');
    if isfield(EEG.chanlocs, 'type')
        types = {EEG.chanlocs.type};
        uniqueTypes = unique(types(~cellfun(@isempty, types)));
        for i = 1:length(uniqueTypes)
            count = sum(strcmp(types, uniqueTypes{i}));
            fprintf('Type "%s": %d channels\n', uniqueTypes{i}, count);
        end
    else
        fprintf('No type field found\n');
    end

    % Check labels for reference/fiducial indicators
    labels = {EEG.chanlocs.labels};
    refPatterns = {'VREF', 'Cz', 'REF', 'Ref'};
    fidPatterns = {'Nasion', 'LPA', 'RPA', 'periauricular', 'Nz'};

    refChans = [];
    fidChans = [];
    for i = 1:length(labels)
        for p = 1:length(refPatterns)
            if ~isempty(labels{i}) && contains(labels{i}, refPatterns{p}, 'IgnoreCase', true)
                refChans = [refChans i];
            end
        end
        for p = 1:length(fidPatterns)
            if ~isempty(labels{i}) && contains(labels{i}, fidPatterns{p}, 'IgnoreCase', true)
                fidChans = [fidChans i];
            end
        end
    end

    if ~isempty(refChans)
        fprintf('⚠️  Reference channels detected: ');
        fprintf('%s ', labels{refChans});
        fprintf('\n   These should not be in data channels for plotting\n');
    end

    if ~isempty(fidChans)
        fprintf('✓ Fiducial markers found: ');
        fprintf('%s ', labels{fidChans});
        fprintf('\n  (These are OK if marked as type=2)\n');
    end

    % Check for peripheral electrodes (outside typical head boundary)
    if hasRadius
        radii = [EEG.chanlocs.radius];
        radii = radii(~isnan(radii));

        fprintf('\n--- Radius Distribution ---\n');
        fprintf('Min radius: %.3f\n', min(radii));
        fprintf('Max radius: %.3f\n', max(radii));
        fprintf('Mean radius: %.3f\n', mean(radii));

        % Count electrodes outside typical plotting radius
        outsideHead = sum(radii > 0.5);
        if outsideHead > 0
            fprintf('⚠️  %d electrodes beyond head boundary (radius > 0.5)\n', outsideHead);
            fprintf('   These may not display with intrad=0.5\n');

            % Show which ones
            outsideIdx = find(radii > 0.5);
            if length(outsideIdx) <= 20
                fprintf('   Electrodes: ');
                for i = 1:length(outsideIdx)
                    if ~isempty(labels{outsideIdx(i)})
                        fprintf('%s(%.2f) ', labels{outsideIdx(i)}, radii(outsideIdx(i)));
                    end
                end
                fprintf('\n');
            end
        else
            fprintf('✓ All electrodes within head boundary\n');
        end
    end

    % Check Z coordinates for peripheral/neck electrodes
    if hasZ
        zVals = [EEG.chanlocs.Z];
        zVals = zVals(~isnan(zVals));

        fprintf('\n--- Vertical Position (Z) ---\n');
        fprintf('Z range: %.2f to %.2f\n', min(zVals), max(zVals));

        belowHorizon = sum(zVals < -5);
        if belowHorizon > 0
            fprintf('⚠️  %d electrodes far below head plane (Z < -5)\n', belowHorizon);
            fprintf('   These are likely neck/face electrodes\n');
        end
    end

    % Test topoplot
    fprintf('\n--- Topoplot Test ---\n');
    try
        % Create test data
        testData = randn(length(EEG.chanlocs), 1);

        % Try plotting
        figure('Visible', 'off');
        topoplot(testData, EEG.chanlocs, ...
            'electrodes', 'on', ...
            'style', 'map');
        close(gcf);

        fprintf('✓ Basic topoplot successful\n');
    catch ME
        fprintf('❌ Topoplot failed: %s\n', ME.message);
    end

    fprintf('\n=== End Diagnostic ===\n\n');
end

function str = yn(val)
    if val
        str = '✓';
    else
        str = '✗';
    end
end
