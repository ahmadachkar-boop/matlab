function selectedEvents = filterEventsByPattern(eventTypes, varargin)
% FILTEREVENTBYPATTERN Automatically filter event types by patterns
%
% Usage:
%   selectedEvents = filterEventsByPattern(eventTypes)
%   selectedEvents = filterEventsByPattern(eventTypes, 'Name', Value, ...)
%
% Inputs:
%   eventTypes     - Cell array of event type strings
%
% Optional Name-Value Pairs:
%   'Pattern'      - String or cell array of patterns to match (default: 'EVNT_TRSP')
%                    Supports wildcards using regular expressions
%   'Conditions'   - Cell array of condition codes to match (e.g., {'SG23', 'SKG1', 'KG1'})
%                    If specified, only events containing these conditions are returned
%   'MatchAny'     - If true, match any pattern/condition; if false, match all (default: true)
%   'CaseSensitive'- Case-sensitive matching (default: false)
%
% Outputs:
%   selectedEvents - Cell array of filtered event type strings
%
% Examples:
%   % Select all EVNT_TRSP events
%   events = filterEventsByPattern(EEG.event, 'Pattern', 'EVNT_TRSP');
%
%   % Select events with specific conditions
%   events = filterEventsByPattern(EEG.event, 'Conditions', {'SG23', 'SKG1', 'KG1', 'G23', 'G45'});
%
%   % Select EVNT_TRSP events with specific conditions
%   events = filterEventsByPattern(EEG.event, 'Pattern', 'EVNT_TRSP', ...
%                                  'Conditions', {'SG23', 'SKG1'});

% Parse inputs
p = inputParser;
addRequired(p, 'eventTypes');
addParameter(p, 'Pattern', 'EVNT_TRSP', @(x) ischar(x) || iscellstr(x) || isstring(x));
addParameter(p, 'Conditions', {}, @(x) iscellstr(x) || isstring(x));
addParameter(p, 'MatchAny', true, @islogical);
addParameter(p, 'CaseSensitive', false, @islogical);
parse(p, eventTypes, varargin{:});

pattern = p.Results.Pattern;
conditions = p.Results.Conditions;
matchAny = p.Results.MatchAny;
caseSensitive = p.Results.CaseSensitive;

% Convert to cell array if needed
if ~iscell(eventTypes)
    eventTypes = {eventTypes};
end
if ischar(pattern) || isstring(pattern)
    pattern = {char(pattern)};
end
if ischar(conditions) || isstring(conditions)
    conditions = {char(conditions)};
end

% Extract unique event types from event structure
if isstruct(eventTypes)
    uniqueTypes = {};
    for i = 1:length(eventTypes)
        evt = eventTypes(i);
        % Try different field names
        if isfield(evt, 'type')
            typeStr = evt.type;
        elseif isfield(evt, 'label')
            typeStr = evt.label;
        elseif isfield(evt, 'code')
            typeStr = evt.code;
        else
            continue;
        end

        % Convert to string
        if isnumeric(typeStr)
            typeStr = num2str(typeStr);
        elseif iscell(typeStr)
            typeStr = typeStr{1};
        end

        uniqueTypes{end+1} = strtrim(char(typeStr));
    end
    eventTypes = unique(uniqueTypes);
end

% Initialize selection mask
numEvents = length(eventTypes);
selectedMask = false(numEvents, 1);

% Apply pattern matching
if ~isempty(pattern)
    for i = 1:numEvents
        eventType = eventTypes{i};

        % Check each pattern
        patternMatch = false;
        for j = 1:length(pattern)
            pat = pattern{j};
            if caseSensitive
                patternMatch = patternMatch || contains(eventType, pat);
            else
                patternMatch = patternMatch || contains(lower(eventType), lower(pat));
            end
        end

        selectedMask(i) = patternMatch;
    end
end

% Apply condition filtering
if ~isempty(conditions)
    conditionMask = false(numEvents, 1);

    for i = 1:numEvents
        eventType = eventTypes{i};

        % Check each condition
        condMatch = false;
        for j = 1:length(conditions)
            cond = conditions{j};
            if caseSensitive
                condMatch = condMatch || contains(eventType, cond);
            else
                condMatch = condMatch || contains(lower(eventType), lower(cond));
            end
        end

        conditionMask(i) = condMatch;
    end

    % Combine with pattern mask
    if isempty(pattern)
        selectedMask = conditionMask;
    else
        if matchAny
            selectedMask = selectedMask | conditionMask;
        else
            selectedMask = selectedMask & conditionMask;
        end
    end
end

% Return selected events
selectedEvents = eventTypes(selectedMask);

% Display summary
fprintf('Event filtering summary:\n');
fprintf('  Total events: %d\n', numEvents);
fprintf('  Selected events: %d\n', sum(selectedMask));
if ~isempty(pattern)
    fprintf('  Pattern(s): %s\n', strjoin(pattern, ', '));
end
if ~isempty(conditions)
    fprintf('  Condition(s): %s\n', strjoin(conditions, ', '));
end
fprintf('\n');

end
