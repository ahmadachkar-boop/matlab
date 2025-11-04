function availableFields = getAvailableEventFields(EEG)
    % GETAVAILABLEEVENTFIELDS - Detect which event fields are available in EEG data
    %
    % Input:
    %   EEG - EEG structure
    %
    % Output:
    %   availableFields - Cell array of field names that exist and have data

    availableFields = {};

    % Check if EEG has events
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        return;
    end

    events = EEG.event;

    % Common event field names to check
    commonFields = {'type', 'code', 'label', 'labels', 'name', 'description', 'value'};

    % Check which fields exist and have non-empty values
    for i = 1:length(commonFields)
        fieldName = commonFields{i};

        if isfield(events, fieldName)
            % Check if at least one event has a non-empty value for this field
            hasData = false;
            for j = 1:length(events)
                if ~isempty(events(j).(fieldName))
                    hasData = true;
                    break;
                end
            end

            if hasData
                availableFields{end+1} = fieldName;
            end
        end
    end

    fprintf('Found %d event fields with data: %s\n', length(availableFields), strjoin(availableFields, ', '));
end
