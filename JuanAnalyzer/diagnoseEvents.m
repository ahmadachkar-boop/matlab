function diagnoseEvents(mffFilePath)
    % DIAGNOSEEVENTS - Comprehensive diagnostic of MFF event structure
    %
    % Usage: diagnoseEvents('/path/to/your/file.mff')
    %
    % This will show you EXACTLY what's in your event structure

    fprintf('\n========================================\n');
    fprintf('EVENT STRUCTURE DIAGNOSTIC\n');
    fprintf('========================================\n\n');

    % Try different import methods
    fprintf('METHOD 1: Import with no event type specified\n');
    fprintf('------------------------------------------\n');
    try
        EEG1 = pop_mffimport(mffFilePath);
        diagnoseEEGEvents(EEG1, 'No event types specified');
    catch ME
        fprintf('ERROR: %s\n\n', ME.message);
    end

    fprintf('\n');

    fprintf('METHOD 2: Import with empty cell array\n');
    fprintf('------------------------------------------\n');
    try
        EEG2 = pop_mffimport(mffFilePath, {});
        diagnoseEEGEvents(EEG2, 'Empty cell array');
    catch ME
        fprintf('ERROR: %s\n\n', ME.message);
    end

    fprintf('\n');

    fprintf('METHOD 3: Import with comprehensive event type list\n');
    fprintf('------------------------------------------\n');
    eventTypes = {'code', 'label', 'labels', 'type', 'name', 'description', 'value', ...
                  'keys', 'mffkeys', 'sourceDevice', 'duration', 'beginTime', 'eventType'};
    try
        EEG3 = pop_mffimport(mffFilePath, eventTypes);
        diagnoseEEGEvents(EEG3, 'Comprehensive list');
    catch ME
        fprintf('ERROR: %s\n\n', ME.message);
    end

    fprintf('\n========================================\n');
    fprintf('DIAGNOSTIC COMPLETE\n');
    fprintf('========================================\n\n');
end

function diagnoseEEGEvents(EEG, methodName)
    fprintf('Import method: %s\n', methodName);

    if ~isfield(EEG, 'event') || isempty(EEG.event)
        fprintf('  NO EVENTS FOUND!\n');
        return;
    end

    events = EEG.event;
    fprintf('  Total events: %d\n', length(events));

    % Show all fields in event structure
    eventFields = fieldnames(events);
    fprintf('  Fields in event structure: %s\n', strjoin(eventFields, ', '));

    % For each field, show sample values
    fprintf('\n  Field Details:\n');
    for f = 1:length(eventFields)
        fieldName = eventFields{f};
        fprintf('    %s:\n', fieldName);

        % Show first 5 unique values
        uniqueVals = {};
        for i = 1:min(10, length(events))
            val = events(i).(fieldName);

            if isempty(val)
                strVal = '[empty]';
            elseif isnumeric(val)
                strVal = num2str(val);
            elseif ischar(val)
                strVal = strtrim(val);
            elseif isstring(val)
                strVal = char(val);
            elseif iscell(val)
                if ~isempty(val)
                    strVal = char(val{1});
                else
                    strVal = '[empty cell]';
                end
            else
                strVal = class(val);
            end

            if ~any(strcmp(uniqueVals, strVal))
                uniqueVals{end+1} = strVal;
            end

            if length(uniqueVals) >= 5
                break;
            end
        end

        fprintf('      Sample values: %s\n', strjoin(uniqueVals, ', '));
    end

    fprintf('\n');
end
