function discovery = discoverEventFields(EEG, structure)
% DISCOVEREVENTFIELDS - Automatically discover and analyze event fields
%
% This function scans all events to find available fields, their values,
% and automatically determines which fields are good for grouping conditions
% vs which are trial-specific metadata.
%
% Inputs:
%   EEG - EEGLAB EEG structure
%   structure - Output from detectEventStructure()
%
% Outputs:
%   discovery - Struct containing:
%     .fields - Cell array of field names
%     .fieldStats - Statistics for each field
%     .groupingFields - Recommended fields for grouping
%     .excludeFields - Fields to exclude (trial-specific)
%     .practicePatterns - Auto-detected practice trial patterns
%     .valueMappings - Auto-detected value mappings (e.g., y->word)

    discovery = struct();
    discovery.fields = {};
    discovery.fieldStats = struct();
    discovery.groupingFields = {};
    discovery.excludeFields = {};
    discovery.practicePatterns = {};
    discovery.valueMappings = struct();

    fprintf('=== AUTO-DISCOVERING EVENT FIELDS ===\n');
    fprintf('Analyzing %d events...\n', length(EEG.event));

    % Sample events for analysis (use more if dataset is small)
    if length(EEG.event) <= 500
        sampleSize = length(EEG.event);
    else
        sampleSize = min(500, length(EEG.event));
    end
    sampleIndices = round(linspace(1, length(EEG.event), sampleSize));

    % Parse events based on detected format
    allFieldData = struct();

    for i = sampleIndices
        evt = EEG.event(i);

        if ~isfield(evt, 'type')
            continue;
        end

        eventType = char(evt.type);

        % Extract fields based on format
        switch structure.format
            case 'bracket'
                fields = parseBracketFields(eventType);

            case 'fields'
                fields = parseStructFields(evt);

            case 'delimiter'
                fields = parseDelimiterFields(eventType);

            case 'simple'
                % Simple codes don't have subfields
                fields = struct('type', eventType);

            otherwise
                % Try bracket format as fallback
                fields = parseBracketFields(eventType);
                if isempty(fieldnames(fields))
                    fields = parseStructFields(evt);
                end
        end

        % Store values for each field
        fieldNames = fieldnames(fields);
        for f = 1:length(fieldNames)
            fieldName = fieldNames{f};
            fieldValue = fields.(fieldName);

            if ~isfield(allFieldData, fieldName)
                allFieldData.(fieldName) = {};
            end

            allFieldData.(fieldName){end+1} = fieldValue;
        end
    end

    % Analyze each field
    fprintf('\nField Analysis:\n');
    fprintf('%-20s %12s %12s %20s\n', 'Field', 'Unique Vals', 'Cardinality', 'Classification');
    fprintf('%s\n', repmat('-', 1, 70));

    fieldNames = fieldnames(allFieldData);
    discovery.fields = fieldNames;

    for f = 1:length(fieldNames)
        fieldName = fieldNames{f};
        values = allFieldData.(fieldName);

        % Compute statistics
        uniqueValues = unique(values);
        numUnique = length(uniqueValues);
        cardinality = numUnique / length(values);  % Ratio of unique to total

        % Store stats
        discovery.fieldStats.(fieldName) = struct();
        discovery.fieldStats.(fieldName).uniqueValues = uniqueValues;
        discovery.fieldStats.(fieldName).numUnique = numUnique;
        discovery.fieldStats.(fieldName).cardinality = cardinality;
        discovery.fieldStats.(fieldName).sampleValues = values(1:min(5, length(values)));

        % Classify field
        % Low cardinality (< 0.3) = good for grouping
        % High cardinality (> 0.7) = trial-specific, exclude
        % Medium cardinality = optional grouping

        if cardinality < 0.3 && numUnique >= 2 && numUnique <= 20
            classification = '✓ CONDITION';
            discovery.groupingFields{end+1} = fieldName;
        elseif cardinality > 0.7 || numUnique > 50
            classification = '✗ TRIAL-SPECIFIC';
            discovery.excludeFields{end+1} = fieldName;
        else
            classification = '? OPTIONAL';
        end

        % Special handling for common field names
        fieldLower = lower(fieldName);

        % Exclude EEG metadata fields (never use for grouping)
        metadataPatterns = {'description', 'classid', 'label', 'sourcedevice', 'name', ...
                           'tracktype', 'begintime', 'endtime', 'relativebegintime', ...
                           'age', 'exp', 'hand', 'sex', 'subj', 'backup', 'urevent'};
        isMetadata = false;
        for mp = 1:length(metadataPatterns)
            if contains(fieldLower, metadataPatterns{mp})
                isMetadata = true;
                break;
            end
        end

        if isMetadata
            classification = '✗ METADATA';
            if ~ismember(fieldName, discovery.excludeFields)
                discovery.excludeFields{end+1} = fieldName;
            end
            % Remove from grouping if it was added
            discovery.groupingFields = discovery.groupingFields(~strcmp(discovery.groupingFields, fieldName));
            fprintf('%-20s %12d %11.2f%% %20s\n', ...
                fieldName, numUnique, cardinality * 100, classification);
            continue;
        end

        % Trial-specific patterns
        if contains(fieldLower, {'trial', 'trl', 'obs', 'rep', 'response', 'rt', 'time', 'cel', 'latency'})
            classification = '✗ TRIAL-SPECIFIC';
            if ~ismember(fieldName, discovery.excludeFields)
                discovery.excludeFields{end+1} = fieldName;
            end
            % Remove from grouping if it was added
            discovery.groupingFields = discovery.groupingFields(~strcmp(discovery.groupingFields, fieldName));
        end

        % Condition-specific patterns (but exclude 'code' without mffkey prefix - that's EEG metadata)
        if contains(fieldLower, {'cond', 'condition', 'stim', 'stimulus', 'task'}) && cardinality < 0.5
            if ~ismember(fieldName, discovery.groupingFields) && numUnique >= 2
                classification = '✓ CONDITION';
                discovery.groupingFields{end+1} = fieldName;
            end
        end

        fprintf('%-20s %12d %11.2f%% %20s\n', ...
            fieldName, numUnique, cardinality * 100, classification);

        % Detect practice trial patterns
        if contains(fieldLower, {'practice', 'prac', 'training', 'train'})
            for v = 1:length(uniqueValues)
                val = uniqueValues{v};
                if ~isempty(val) && ~strcmp(val, '?') && ~strcmp(val, '0')
                    discovery.practicePatterns{end+1} = val;
                end
            end
        end

        % Detect common value mappings
        if ismember(fieldName, discovery.groupingFields)
            discovery.valueMappings.(fieldName) = detectValueMappings(uniqueValues, fieldName);
        end
    end

    fprintf('%s\n\n', repmat('-', 1, 70));

    % Prioritize grouping fields (put most important first)
    discovery.groupingFields = prioritizeGroupingFields(discovery.groupingFields, discovery.fieldStats);

    % Auto-detect additional practice patterns
    discovery.practicePatterns = [discovery.practicePatterns, ...
        {'Prac', 'PracSlow', 'Practice', 'Training', '_a_', '_s_', '_w_', '_s1_'}];
    discovery.practicePatterns = unique(discovery.practicePatterns);

    fprintf('Recommendations:\n');
    fprintf('  Group by: %s\n', strjoin(discovery.groupingFields, ', '));
    fprintf('  Exclude: %s\n', strjoin(discovery.excludeFields, ', '));
    if ~isempty(discovery.practicePatterns)
        fprintf('  Practice patterns: %s\n', strjoin(discovery.practicePatterns(1:min(5, end)), ', '));
    end
    fprintf('======================================\n\n');
end


function fields = parseBracketFields(eventType)
    % Parse bracket notation: [key: value, ...]
    fields = struct();

    if contains(eventType, '[') && contains(eventType, ']')
        startIdx = strfind(eventType, '[');
        endIdx = strfind(eventType, ']');
        if ~isempty(startIdx) && ~isempty(endIdx)
            bracketContent = eventType(startIdx(1)+1:endIdx(1)-1);

            pairs = strsplit(bracketContent, ',');
            for i = 1:length(pairs)
                pair = strtrim(pairs{i});
                colonIdx = strfind(pair, ':');
                if ~isempty(colonIdx)
                    key = strtrim(pair(1:colonIdx(1)-1));
                    value = strtrim(pair(colonIdx(1)+1:end));

                    % Clean up key names
                    key = regexprep(key, '[^a-zA-Z0-9]', '');

                    if ~isempty(key)
                        fields.(key) = value;
                    end
                end
            end
        end
    end
end


function fields = parseStructFields(evt)
    % Parse EEG.event fields directly
    fields = struct();

    basicFields = {'type', 'latency', 'duration', 'urevent', 'epoch'};
    eventFields = fieldnames(evt);

    for i = 1:length(eventFields)
        fieldName = eventFields{i};
        if ~ismember(fieldName, basicFields)
            value = evt.(fieldName);
            if ischar(value) || isstring(value)
                fields.(fieldName) = char(value);
            elseif isnumeric(value)
                fields.(fieldName) = num2str(value);
            end
        end
    end
end


function fields = parseDelimiterFields(eventType)
    % Parse delimiter-separated format: prefix_field1_field2_...
    fields = struct();

    % Try underscore first
    if contains(eventType, '_')
        parts = strsplit(eventType, '_');
    elseif contains(eventType, '-')
        parts = strsplit(eventType, '-');
    else
        return;
    end

    % Create generic field names
    for i = 1:length(parts)
        fieldName = sprintf('field%d', i);
        fields.(fieldName) = parts{i};
    end
end


function mappings = detectValueMappings(uniqueValues, fieldName)
    % Auto-detect common value mappings
    mappings = struct();

    fieldLower = lower(fieldName);

    for i = 1:length(uniqueValues)
        val = uniqueValues{i};
        if isempty(val)
            continue;
        end

        % Common boolean mappings
        if strcmp(val, 'y') || strcmp(val, 'Y')
            if contains(fieldLower, {'word', 'code', 'lex'})
                mappings.y = 'word';
            elseif contains(fieldLower, {'verb'})
                mappings.y = 'verb';
            else
                mappings.y = 'yes';
            end
        elseif strcmp(val, 'n') || strcmp(val, 'N')
            if contains(fieldLower, {'word', 'code', 'lex'})
                mappings.n = 'nonword';
            elseif contains(fieldLower, {'verb'})
                mappings.n = 'nonverb';
            else
                mappings.n = 'no';
            end
        end

        % Numeric boolean - prefix with 'n' to make valid field names
        if strcmp(val, '1')
            mappings.n1 = 'yes';
        elseif strcmp(val, '0')
            mappings.n0 = 'no';
        end
    end
end


function prioritized = prioritizeGroupingFields(fields, stats)
    % Prioritize fields for grouping (condition fields first, then modifiers)

    if isempty(fields)
        prioritized = {};
        return;
    end

    priorities = zeros(length(fields), 1);

    for i = 1:length(fields)
        fieldName = fields{i};
        fieldLower = lower(fieldName);

        % SUPER HIGH PRIORITY: mffkey fields (experimental variables)
        isMffkey = startsWith(fieldLower, 'mffkey_');

        % Highest priority: mffkey condition fields
        if isMffkey && contains(fieldLower, {'cond', 'condition'})
            priorities(i) = 150;
        % Very high priority: mffkey code/word fields
        elseif isMffkey && contains(fieldLower, {'code', 'word', 'lex'})
            priorities(i) = 140;
        % High priority: other mffkey experimental variables
        elseif isMffkey && contains(fieldLower, {'verb', 'phon', 'sylb', 'freq', 'task'})
            priorities(i) = 130;
        % Medium-high: any other mffkey field (experimental)
        elseif isMffkey
            priorities(i) = 110;
        % Medium: non-mffkey condition fields
        elseif contains(fieldLower, {'cond', 'condition', 'stim', 'stimulus'})
            priorities(i) = 100;
        % Lower: code/word fields without mffkey prefix
        elseif contains(fieldLower, {'code', 'word', 'lex', 'status'})
            priorities(i) = 80;
        % Low: modifier fields
        elseif contains(fieldLower, {'verb', 'phon', 'sylb', 'freq'})
            priorities(i) = 70;
        % Very low: task/type fields (often metadata)
        elseif contains(fieldLower, {'task', 'type', 'category'})
            priorities(i) = 60;
        % Lowest: everything else
        else
            priorities(i) = 50;
        end

        % Bonus for low cardinality (more discriminative)
        if isfield(stats, fieldName)
            cardinality = stats.(fieldName).cardinality;
            priorities(i) = priorities(i) + (1 - cardinality) * 10;
        end
    end

    [~, sortIdx] = sort(priorities, 'descend');
    prioritized = fields(sortIdx);

    % Limit to top 2-3 fields by default (avoid over-fragmentation)
    % Keep top 2 if both are high priority (>120), otherwise top 3
    if length(prioritized) > 2
        if priorities(sortIdx(1)) > 120 && priorities(sortIdx(2)) > 120
            % Keep just the top 2 high-priority mffkey fields
            prioritized = prioritized(1:2);
        elseif length(prioritized) > 3
            % Otherwise limit to top 3
            prioritized = prioritized(1:3);
        end
    end
end
