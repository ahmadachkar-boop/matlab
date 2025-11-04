function [fieldNames, fieldInfo] = getAvailableEventFields(EEG)
    % GETAVAILABLEEVENTFIELDS - Detect which event fields are available in EEG data
    %
    % Input:
    %   EEG - EEG structure
    %
    % Output:
    %   fieldNames - Cell array of field names that exist and have data
    %   fieldInfo - Struct array with detailed info about each field:
    %               .name - Field name
    %               .uniqueMarkers - Cell array of unique marker values
    %               .numUnique - Number of unique markers
    %               .preview - Short preview string for display

    fieldNames = {};
    fieldInfo = struct('name', {}, 'uniqueMarkers', {}, 'numUnique', {}, 'preview', {});

    % Check if EEG has events
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        return;
    end

    events = EEG.event;

    % Common event field names to check (prioritize singular 'label' before plural 'labels')
    commonFields = {'label', 'code', 'type', 'labels', 'name', 'description', 'value'};

    % Check which fields exist and have non-empty values
    for i = 1:length(commonFields)
        fieldName = commonFields{i};

        if isfield(events, fieldName)
            % Extract all unique values from this field
            uniqueMarkers = {};

            for j = 1:length(events)
                value = events(j).(fieldName);

                if isempty(value)
                    continue;
                end

                % Convert to string representation
                if isnumeric(value)
                    strValue = strtrim(num2str(value));
                elseif ischar(value)
                    % Handle multi-row char arrays
                    if size(value, 1) > 1
                        strValue = strtrim(value(1, :));
                    else
                        strValue = strtrim(value);
                    end
                elseif isstring(value)
                    strValue = strtrim(char(value));
                elseif iscell(value)
                    if ~isempty(value)
                        strValue = strtrim(char(value{1}));
                    else
                        continue;
                    end
                else
                    strValue = strtrim(char(value));
                end

                % Add to unique list if not already present (case-sensitive)
                if ~isempty(strValue)
                    if ~any(strcmp(uniqueMarkers, strValue))
                        uniqueMarkers{end+1} = strValue;
                    end
                end
            end

            if ~isempty(uniqueMarkers)
                % Create preview string
                numMarkers = length(uniqueMarkers);
                if numMarkers <= 3
                    % Show all markers
                    preview = sprintf('%s (%d markers: %s)', fieldName, numMarkers, strjoin(uniqueMarkers, ', '));
                else
                    % Show first 3 markers + "..."
                    preview = sprintf('%s (%d markers: %s, ...)', fieldName, numMarkers, strjoin(uniqueMarkers(1:3), ', '));
                end

                % Store info
                info = struct();
                info.name = fieldName;
                info.uniqueMarkers = uniqueMarkers;
                info.numUnique = numMarkers;
                info.preview = preview;

                fieldNames{end+1} = fieldName;
                fieldInfo(end+1) = info;
            end
        end
    end

    fprintf('\n=== Available Event Fields ===\n');
    fprintf('Found %d fields with event data:\n\n', length(fieldNames));
    for i = 1:length(fieldInfo)
        fprintf('Field %d: %s\n', i, fieldInfo(i).name);
        fprintf('  Unique markers (%d): %s\n', fieldInfo(i).numUnique, strjoin(fieldInfo(i).uniqueMarkers, ', '));
        fprintf('\n');
    end
end
