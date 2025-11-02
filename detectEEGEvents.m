function eventInfo = detectEEGEvents(EEG)
    % DETECTEEGEVENTS - Detect and categorize event markers in EEG data
    %
    % Input:
    %   EEG - EEG structure
    %
    % Output:
    %   eventInfo - Structure containing:
    %     .hasEvents - Boolean, true if events found
    %     .numEvents - Total number of events
    %     .eventTypes - Cell array of unique event types
    %     .eventCounts - Array of counts for each type
    %     .events - Original event structure
    %     .description - Human-readable description

    eventInfo = struct();
    eventInfo.hasEvents = false;
    eventInfo.numEvents = 0;
    eventInfo.eventTypes = {};
    eventInfo.eventCounts = [];
    eventInfo.events = [];
    eventInfo.description = 'No events detected';

    % Check if EEG has events
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        return;
    end

    events = EEG.event;
    eventInfo.numEvents = length(events);
    eventInfo.events = events;

    % Extract event types
    % Try different field names that commonly contain event types
    type_fields = {'type', 'code', 'label', 'name', 'description'};
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

                % Handle different data types
                if isnumeric(value)
                    % Convert scalar or vector to string
                    if isscalar(value)
                        label = num2str(value);
                    else
                        label = mat2str(value);
                    end
                elseif ischar(value)
                    label = value;
                elseif isstring(value)
                    label = char(value);
                elseif iscell(value)
                    % Handle cell arrays
                    if ~isempty(value)
                        label = char(value{1});
                    end
                end

                if ~isempty(label)
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

    % Count unique event types (use case-sensitive comparison)
    try
        [unique_types, ~, idx] = unique(event_labels, 'stable');
        counts = histc(idx, 1:length(unique_types));
    catch ME
        % Fallback if unique fails
        fprintf('Warning: unique() failed, using manual grouping: %s\n', ME.message);
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
            end
        end
    end

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

    fprintf('Event Detection:\n');
    fprintf('  Total events: %d\n', eventInfo.numEvents);
    fprintf('  Event types: %d\n', length(eventInfo.eventTypes));
    for i = 1:min(5, length(eventInfo.eventTypes))
        fprintf('    %s: %d events\n', eventInfo.eventTypes{i}, eventInfo.eventCounts(i));
    end
    if length(eventInfo.eventTypes) > 5
        fprintf('    ... and %d more types\n', length(eventInfo.eventTypes) - 5);
    end
end
