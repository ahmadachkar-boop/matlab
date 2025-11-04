function eventInfo = detectEEGEvents(EEG, preferredField)
    % DETECTEEGEVENTS - Detect and categorize event markers in EEG data
    %
    % Input:
    %   EEG - EEG structure
    %   preferredField - (Optional) Preferred event field to use ('type', 'code', 'label', etc.)
    %
    % Output:
    %   eventInfo - Structure containing:
    %     .hasEvents - Boolean, true if events found
    %     .numEvents - Total number of events
    %     .eventTypes - Cell array of unique event types
    %     .eventCounts - Array of counts for each type
    %     .events - Original event structure
    %     .description - Human-readable description
    %     .fieldUsed - The field that was used for event types

    % Handle optional parameter
    if nargin < 2
        preferredField = '';
    end

    eventInfo = struct();
    eventInfo.hasEvents = false;
    eventInfo.numEvents = 0;
    eventInfo.eventTypes = {};
    eventInfo.eventCounts = [];
    eventInfo.events = [];
    eventInfo.description = 'No events detected';
    eventInfo.fieldUsed = '';

    % Check if EEG has events
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        return;
    end

    events = EEG.event;
    eventInfo.numEvents = length(events);
    eventInfo.events = events;

    % Extract event types
    % If preferred field specified, use only that; otherwise try common fields
    if ~isempty(preferredField)
        type_fields = {preferredField};
    else
        % Prioritize singular 'label' before plural 'labels' (matches getAvailableEventFields)
        type_fields = {'label', 'code', 'type', 'labels', 'name', 'description'};
    end

    event_labels = cell(1, length(events));

    for i = 1:length(events)
        label = '';

        % Try to find the event type from various fields
        for f = 1:length(type_fields)
            field = type_fields{f};
            if isfield(events, field) && length(events) >= i
                value = events(i).(field);

                % Handle empty values
                if isempty(value)
                    continue;
                end

                % Handle different data types and ensure single string
                if isnumeric(value)
                    % Convert scalar or vector to string
                    if isscalar(value)
                        label = num2str(value);
                    else
                        label = mat2str(value);
                    end
                elseif ischar(value)
                    % Flatten multi-row char arrays to single string
                    if size(value, 1) > 1
                        label = strtrim(value(1, :));  % Take first row and trim
                    else
                        label = strtrim(value);  % Trim whitespace
                    end
                elseif isstring(value)
                    % Convert string to char, handling arrays
                    if numel(value) > 1
                        label = char(value(1));  % Take first element
                    else
                        label = char(value);
                    end
                elseif iscell(value)
                    % Handle cell arrays
                    if ~isempty(value)
                        % Recursively handle the first cell element
                        first_elem = value{1};
                        if isnumeric(first_elem)
                            label = num2str(first_elem);
                        elseif ischar(first_elem)
                            if size(first_elem, 1) > 1
                                label = first_elem(1, :);
                            else
                                label = first_elem;
                            end
                        elseif isstring(first_elem)
                            label = char(first_elem);
                        else
                            label = char(first_elem);
                        end
                    end
                end

                % Final safety check: ensure label is a simple 1D char array
                if ~isempty(label) && ~ischar(label)
                    try
                        label = char(label);
                    catch
                        label = '';
                    end
                end
                if ischar(label) && size(label, 1) > 1
                    label = label(1, :);  % Force to single row
                end

                if ~isempty(label)
                    % Track which field was successfully used
                    if isempty(eventInfo.fieldUsed)
                        eventInfo.fieldUsed = field;
                    end
                    break;
                end
            end
        end

        % If no label found, use generic label
        if isempty(label)
            label = sprintf('Event_%d', i);
        end

        event_labels{i} = label;
    end

    % Validate all labels are simple strings
    for i = 1:length(event_labels)
        label = event_labels{i};

        if ~ischar(label)
            try
                label = char(label);
            catch
                label = sprintf('Event_%d', i);
            end
        end

        % Ensure single row
        if size(label, 1) > 1
            label = strtrim(label(1, :));
        end

        % Trim any whitespace
        if ischar(label)
            label = strtrim(label);
        end

        % Ensure it's actually a valid char array (not empty)
        if isempty(label)
            label = sprintf('Event_%d', i);
        end

        % Store back
        event_labels{i} = label;
    end

    % Count unique event types using manual grouping (more robust than unique())
    % unique() can fail with cell arrays of variable-length char arrays
    fprintf('Grouping events manually...\n');
    unique_types = {};
    counts = [];

    for i = 1:length(event_labels)
        found = false;
        for j = 1:length(unique_types)
            if strcmp(event_labels{i}, unique_types{j})
                counts(j) = counts(j) + 1;
                found = true;
                break;
            end
        end
        if ~found
            unique_types{end+1} = event_labels{i};
            counts(end+1) = 1;
            fprintf('  Found new type: ''%s''\n', event_labels{i});
        end
    end

    fprintf('Total unique event types: %d\n', length(unique_types));

    % Sort by count (descending)
    [counts_sorted, sort_idx] = sort(counts, 'descend');
    unique_types_sorted = unique_types(sort_idx);

    eventInfo.hasEvents = true;
    eventInfo.eventTypes = unique_types_sorted;
    eventInfo.eventCounts = counts_sorted;

    % Create description
    if length(unique_types_sorted) == 1
        eventInfo.description = sprintf('%d events of type ''%s''', ...
            eventInfo.numEvents, unique_types_sorted{1});
    elseif length(unique_types_sorted) <= 5
        % List all types if 5 or fewer
        type_list = strjoin(cellfun(@(t, c) sprintf('%s(%d)', t, c), ...
            unique_types_sorted, num2cell(counts_sorted), 'UniformOutput', false), ', ');
        eventInfo.description = sprintf('%d events: %s', eventInfo.numEvents, type_list);
    else
        % Just show top 3 if more than 5 types
        type_list = strjoin(cellfun(@(t, c) sprintf('%s(%d)', t, c), ...
            unique_types_sorted(1:3), num2cell(counts_sorted(1:3)), 'UniformOutput', false), ', ');
        eventInfo.description = sprintf('%d events across %d types (top 3: %s)', ...
            eventInfo.numEvents, length(unique_types_sorted), type_list);
    end

    fprintf('Event Detection Summary:\n');
    fprintf('  Total events: %d\n', eventInfo.numEvents);
    fprintf('  Unique event types: %d\n', length(eventInfo.eventTypes));
    fprintf('  All detected markers:\n');
    for i = 1:length(eventInfo.eventTypes)
        fprintf('    %d. %s: %d occurrences\n', i, eventInfo.eventTypes{i}, eventInfo.eventCounts(i));
    end
    fprintf('\n');
end
