function [selectedEventTypes, structure, discovery] = autoSelectTrialEventsUniversal(EEG, varargin)
% AUTOSELECTTRIALEVENTSUNIVERSAL - Universal automatic event selection
%
% This function automatically detects event structure, discovers fields,
% and intelligently groups trial events by condition. Works with ANY
% dataset format with zero user configuration required.
%
% Usage:
%   selectedEvents = autoSelectTrialEventsUniversal(EEG)
%   [selectedEvents, structure, discovery] = autoSelectTrialEventsUniversal(EEG, ...)
%
% Inputs:
%   EEG - EEGLAB EEG structure with events
%
% Optional Name-Value Pairs:
%   'Conditions'   - Cell array of condition codes to include (default: all)
%   'GroupBy'      - Override auto-detected grouping fields
%   'ExcludePractice' - Exclude practice trials (default: true)
%   'Display'      - Show summary table (default: true)
%
% Outputs:
%   selectedEventTypes - Cell array of grouped condition labels
%   structure - Detected event structure information
%   discovery - Discovered field information

    % Parse inputs
    p = inputParser;
    addRequired(p, 'EEG', @isstruct);
    addParameter(p, 'Conditions', {}, @(x) iscellstr(x) || isstring(x) || isempty(x));
    addParameter(p, 'GroupBy', {}, @(x) iscellstr(x) || isempty(x));
    addParameter(p, 'ExcludePractice', true, @islogical);
    addParameter(p, 'Display', true, @islogical);
    parse(p, EEG, varargin{:});

    conditions = p.Results.Conditions;
    groupByOverride = p.Results.GroupBy;
    excludePractice = p.Results.ExcludePractice;
    displayResults = p.Results.Display;

    fprintf('\n========================================\n');
    fprintf('UNIVERSAL AUTO-EVENT SELECTION\n');
    fprintf('========================================\n\n');

    %% PHASE 1: Auto-detect event structure
    structure = detectEventStructure(EEG);

    if strcmp(structure.format, 'unknown') || structure.confidence < 0.3
        warning('Could not confidently detect event structure. Trying bracket format...');
        structure.format = 'bracket';
        structure.eventPattern = 'EVNT_TRSP';  % Fallback for your data
    end

    %% PHASE 2: Discover and analyze fields
    discovery = discoverEventFields(EEG, structure);

    if isempty(discovery.groupingFields)
        warning('No grouping fields auto-detected. Events may not have structured metadata.');
        % Fallback: group by raw event type
        structure.format = 'simple';
    end

    % Override grouping fields if specified
    if ~isempty(groupByOverride)
        fprintf('Note: Overriding auto-detected grouping fields\n');
        fprintf('  Auto-detected: %s\n', strjoin(discovery.groupingFields, ', '));
        fprintf('  User override: %s\n', strjoin(groupByOverride, ', '));
        groupByFields = groupByOverride;
    else
        groupByFields = discovery.groupingFields;
    end

    fprintf('\n========================================\n');
    fprintf('PARSING AND GROUPING EVENTS\n');
    fprintf('========================================\n');
    fprintf('Format: %s\n', structure.format);
    fprintf('Grouping by: %s\n', strjoin(groupByFields, ', '));
    if excludePractice
        fprintf('Excluding practice: yes\n');
    end
    fprintf('----------------------------------------\n\n');

    %% PHASE 3: Parse all events and extract condition labels
    fprintf('Step 1: Parsing events...\n');

    conditionLabels = {};
    originalEventTypes = {};
    eventIndices = [];

    for i = 1:length(EEG.event)
        evt = EEG.event(i);

        if ~isfield(evt, 'type')
            continue;
        end

        eventType = char(evt.type);

        % Check if event matches pattern (if one was detected)
        if ~isempty(structure.eventPattern)
            if ~contains(eventType, structure.eventPattern, 'IgnoreCase', true)
                continue;
            end
        end

        % Parse the event to get condition label
        condLabel = parseEventUniversal(evt, structure, discovery, groupByFields);

        if ~isempty(condLabel)
            conditionLabels{end+1} = condLabel;
            originalEventTypes{end+1} = eventType;
            eventIndices(end+1) = i;
        end
    end

    fprintf('  ✓ Parsed %d matching events\n', length(conditionLabels));

    if isempty(conditionLabels)
        error('No events could be parsed! Check your data or try manual configuration.');
    end

    %% PHASE 4: Exclude practice trials
    if excludePractice && ~isempty(discovery.practicePatterns)
        fprintf('\nStep 2: Excluding practice trials...\n');

        keepMask = true(length(originalEventTypes), 1);
        for i = 1:length(originalEventTypes)
            for p = 1:length(discovery.practicePatterns)
                if contains(originalEventTypes{i}, discovery.practicePatterns{p}, 'IgnoreCase', true)
                    keepMask(i) = false;
                    break;
                end
            end
        end

        beforeCount = length(conditionLabels);
        conditionLabels = conditionLabels(keepMask);
        originalEventTypes = originalEventTypes(keepMask);
        eventIndices = eventIndices(keepMask);
        afterCount = length(conditionLabels);

        fprintf('  ✓ Excluded %d practice trials (%d remaining)\n', ...
            beforeCount - afterCount, afterCount);
    else
        fprintf('\nStep 2: Skipping practice exclusion\n');
    end

    %% PHASE 5: Get unique conditions
    fprintf('\nStep 3: Identifying unique conditions...\n');
    uniqueConditions = unique(conditionLabels);
    fprintf('  ✓ Found %d unique condition groups\n', length(uniqueConditions));

    %% PHASE 6: Filter by specified conditions (if any)
    if ~isempty(conditions)
        fprintf('\nStep 4: Filtering by specified conditions...\n');
        fprintf('  Target conditions: %s\n', strjoin(conditions, ', '));

        keepMask = false(length(conditionLabels), 1);
        for i = 1:length(conditionLabels)
            for j = 1:length(conditions)
                if contains(conditionLabels{i}, conditions{j}, 'IgnoreCase', true)
                    keepMask(i) = true;
                    break;
                end
            end
        end

        beforeCount = length(conditionLabels);
        conditionLabels = conditionLabels(keepMask);
        originalEventTypes = originalEventTypes(keepMask);
        eventIndices = eventIndices(keepMask);
        afterCount = length(conditionLabels);

        uniqueConditions = unique(conditionLabels);

        fprintf('  ✓ Kept %d events in %d condition groups\n', ...
            afterCount, length(uniqueConditions));
    else
        fprintf('\nStep 4: Using all detected conditions\n');
    end

    %% PHASE 7: Count trials per condition
    fprintf('\nStep 5: Counting trials per condition...\n');
    conditionCounts = zeros(length(uniqueConditions), 1);
    for i = 1:length(uniqueConditions)
        conditionCounts(i) = sum(strcmp(conditionLabels, uniqueConditions{i}));
    end

    % Return the unique condition labels
    selectedEventTypes = uniqueConditions;

    %% Display summary
    fprintf('\n========================================\n');
    fprintf('SELECTION SUMMARY\n');
    fprintf('========================================\n');
    fprintf('Total events in file:     %d\n', length(EEG.event));
    fprintf('Matching events:          %d\n', length(conditionLabels));
    fprintf('Unique condition groups:  %d\n', length(uniqueConditions));
    fprintf('========================================\n\n');

    % Display detailed table
    if displayResults && ~isempty(selectedEventTypes)
        fprintf('CONDITION GROUPS:\n');
        fprintf('%-40s %10s\n', 'Condition', 'Trials');
        fprintf('%s\n', repmat('-', 1, 55));

        % Sort by count (descending)
        [sortedCounts, sortIdx] = sort(conditionCounts, 'descend');
        sortedConditions = selectedEventTypes(sortIdx);

        totalTrials = sum(sortedCounts);
        avgTrials = mean(sortedCounts);

        for i = 1:length(sortedConditions)
            fprintf('%-40s %10d\n', sortedConditions{i}, sortedCounts(i));
        end

        fprintf('%s\n', repmat('-', 1, 55));
        fprintf('%-40s %10d\n', 'TOTAL', totalTrials);
        fprintf('%-40s %10.1f\n', 'AVERAGE per condition', avgTrials);
        fprintf('\n');

        % Show warnings
        lowCountThreshold = 10;
        lowCountConditions = sum(sortedCounts < lowCountThreshold);
        if lowCountConditions > 0
            fprintf('⚠ WARNING: %d condition(s) have fewer than %d trials\n', ...
                lowCountConditions, lowCountThreshold);
            fprintf('  Consider using broader grouping (fewer fields)\n\n');
        end

        % Show quality metrics
        fprintf('Quality Metrics:\n');
        fprintf('  Format detection confidence: %.0f%%\n', structure.confidence * 100);
        fprintf('  Fields discovered: %d\n', length(discovery.fields));
        fprintf('  Grouping fields used: %d\n', length(groupByFields));
        fprintf('  Average trials per condition: %.1f\n', avgTrials);
        fprintf('  Min trials: %d | Max trials: %d\n', min(sortedCounts), max(sortedCounts));
        fprintf('\n');
    end
end
