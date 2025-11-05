function conditionLabel = parseEventConditions(eventStruct, groupingFields)
    % PARSEEVENTCONDITIONS - Extract meaningful condition labels from complex event structures
    %
    % This function parses event structures to extract experimental condition
    % information while ignoring trial-specific metadata (like trial number,
    % response time, observation number, etc.)
    %
    % Inputs:
    %   eventStruct - Event structure from EEG.event
    %   groupingFields - Cell array of field names to use for grouping
    %                    Default: {'Cond', 'Code'} for basic condition grouping
    %                    Options: 'Cond', 'Code', 'Phon', 'Verb', 'Sylb', 'TskB'
    %
    % Output:
    %   conditionLabel - String label for this condition (e.g., 'G23_word')
    %
    % Example:
    %   label = parseEventConditions(EEG.event(1), {'Cond', 'Code', 'Verb'})
    %   % Returns: 'G23_word_verb' or 'SG23_nonword_nonverb'

    if nargin < 2
        % Default grouping by condition and word status
        groupingFields = {'Cond', 'Code'};
    end

    % Initialize empty label
    conditionLabel = '';

    % Check if event has the expected structure
    % Events from MFF import may have keys/data fields
    if ~isfield(eventStruct, 'type')
        return;
    end

    % Parse the event type string to extract structured data
    eventType = eventStruct.type;

    % Look for pattern like: [cel#: 14, obs#: 1, Cond: a, TskB: Prac, ...]
    % This is embedded in the type string
    if contains(eventType, '[') && contains(eventType, ']')
        % Extract the bracketed section
        startIdx = strfind(eventType, '[');
        endIdx = strfind(eventType, ']');
        if ~isempty(startIdx) && ~isempty(endIdx)
            bracketContent = eventType(startIdx(1)+1:endIdx(1)-1);

            % Parse key-value pairs
            pairs = strsplit(bracketContent, ',');
            conditionData = struct();

            for i = 1:length(pairs)
                pair = strtrim(pairs{i});
                colonIdx = strfind(pair, ':');
                if ~isempty(colonIdx)
                    key = strtrim(pair(1:colonIdx(1)-1));
                    value = strtrim(pair(colonIdx(1)+1:end));

                    % Clean up key names (remove special chars)
                    key = regexprep(key, '[^a-zA-Z0-9]', '');

                    conditionData.(key) = value;
                end
            end

            % Build condition label from requested fields
            labelParts = {};

            for f = 1:length(groupingFields)
                field = groupingFields{f};

                if isfield(conditionData, field)
                    value = conditionData.(field);

                    % Convert Code field to readable format
                    if strcmp(field, 'Code')
                        if strcmp(value, 'y')
                            value = 'word';
                        elseif strcmp(value, 'n')
                            value = 'nonword';
                        end
                    end

                    % Convert Verb field to readable format
                    if strcmp(field, 'Verb')
                        if strcmp(value, 'y')
                            value = 'verb';
                        elseif strcmp(value, 'n')
                            value = 'nonverb';
                        else
                            value = ['verb' value];
                        end
                    end

                    % Skip question marks and zeros (missing data)
                    if ~strcmp(value, '?') && ~strcmp(value, '0')
                        labelParts{end+1} = value;
                    end
                end
            end

            % Combine parts with underscore
            if ~isempty(labelParts)
                conditionLabel = strjoin(labelParts, '_');
            end
        end
    end

    % If no label was extracted, return empty
    if isempty(conditionLabel)
        conditionLabel = '';
    end
end
