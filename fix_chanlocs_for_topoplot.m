function EEG = fix_chanlocs_for_topoplot(EEG, options)
% Fix common channel location issues for topoplot with HydroCel GSN 128
%
% Usage:
%   EEG = fix_chanlocs_for_topoplot(EEG)
%   EEG = fix_chanlocs_for_topoplot(EEG, 'RemoveRef', true, 'RemoveFiducials', true)
%
% Options:
%   'RemoveRef' - Remove reference electrodes (default: false)
%   'RemoveFiducials' - Remove fiducial markers (default: true)
%   'ConvertCoords' - Convert Cartesian to polar (default: true)
%   'ScaleRadius' - Scale radii to fit within head (default: false)

    arguments
        EEG
        options.RemoveRef logical = false
        options.RemoveFiducials logical = true
        options.ConvertCoords logical = true
        options.ScaleRadius logical = false
    end

    if ~isfield(EEG, 'chanlocs') || isempty(EEG.chanlocs)
        error('No channel locations found in EEG structure');
    end

    fprintf('Fixing channel locations for topoplot...\n');
    originalCount = length(EEG.chanlocs);

    % Identify channels to remove
    keepMask = true(1, originalCount);
    labels = {EEG.chanlocs.labels};

    % Remove reference electrodes
    if options.RemoveRef
        refPatterns = {'VREF', 'REF', 'Ref', 'ref'};
        for i = 1:originalCount
            for p = 1:length(refPatterns)
                if ~isempty(labels{i}) && contains(labels{i}, refPatterns{p})
                    keepMask(i) = false;
                    fprintf('  Removing reference: %s\n', labels{i});
                end
            end
        end
    end

    % Remove fiducial markers
    if options.RemoveFiducials
        fidPatterns = {'Nasion', 'LPA', 'RPA', 'periauricular', 'Nz', 'Left periauricular', 'Right periauricular'};

        % Also check by type field if it exists
        if isfield(EEG.chanlocs, 'type')
            for i = 1:originalCount
                % Type 2 = fiducial marker
                if ~isempty(EEG.chanlocs(i).type) && isnumeric(EEG.chanlocs(i).type) && EEG.chanlocs(i).type == 2
                    keepMask(i) = false;
                    fprintf('  Removing fiducial (type=2): %s\n', labels{i});
                    continue;
                end

                % Check by name
                for p = 1:length(fidPatterns)
                    if ~isempty(labels{i}) && contains(labels{i}, fidPatterns{p}, 'IgnoreCase', true)
                        keepMask(i) = false;
                        fprintf('  Removing fiducial: %s\n', labels{i});
                        break;
                    end
                end
            end
        end
    end

    % Apply mask
    if sum(~keepMask) > 0
        EEG.chanlocs = EEG.chanlocs(keepMask);

        % Also remove from data if dimensions match
        if size(EEG.data, 1) == originalCount
            EEG.data = EEG.data(keepMask, :, :);
            EEG.nbchan = size(EEG.data, 1);
            fprintf('  Removed %d channels from data\n', sum(~keepMask));
        end
    end

    % Convert coordinates if needed
    if options.ConvertCoords
        hasTheta = isfield(EEG.chanlocs, 'theta') && ~all(cellfun(@isempty, {EEG.chanlocs.theta}));
        hasRadius = isfield(EEG.chanlocs, 'radius') && ~all(cellfun(@isempty, {EEG.chanlocs.radius}));

        if ~hasTheta || ~hasRadius
            fprintf('  Converting Cartesian to polar coordinates...\n');

            % Use EEGLAB's convertlocs if available
            if exist('convertlocs', 'file')
                EEG.chanlocs = convertlocs(EEG.chanlocs, 'cart2all');
            else
                % Manual conversion for 3D Cartesian to spherical
                for i = 1:length(EEG.chanlocs)
                    if isfield(EEG.chanlocs, 'X') && ~isempty(EEG.chanlocs(i).X)
                        x = EEG.chanlocs(i).X;
                        y = EEG.chanlocs(i).Y;
                        z = EEG.chanlocs(i).Z;

                        % Convert to spherical
                        [theta, phi, r] = cart2sph(x, y, z);

                        % Topoplot uses degrees and normalized radius
                        EEG.chanlocs(i).theta = rad2deg(theta);
                        EEG.chanlocs(i).radius = 0.5 - phi / pi;  % Simplified 2D projection

                        % Store spherical coords
                        EEG.chanlocs(i).sph_theta = rad2deg(theta);
                        EEG.chanlocs(i).sph_phi = rad2deg(phi);
                        EEG.chanlocs(i).sph_radius = r;
                    end
                end
                fprintf('  Manual coordinate conversion complete\n');
            end
        else
            fprintf('  Polar coordinates already exist\n');
        end
    end

    % Scale radius to fit within head boundary
    if options.ScaleRadius
        if isfield(EEG.chanlocs, 'radius')
            radii = [EEG.chanlocs.radius];
            maxRadius = max(radii(~isnan(radii)));

            if maxRadius > 0.5
                fprintf('  Scaling radii: max %.3f -> 0.5\n', maxRadius);
                scale = 0.5 / maxRadius;

                for i = 1:length(EEG.chanlocs)
                    if ~isnan(EEG.chanlocs(i).radius)
                        EEG.chanlocs(i).radius = EEG.chanlocs(i).radius * scale;
                    end
                end
            else
                fprintf('  No radius scaling needed (max = %.3f)\n', maxRadius);
            end
        end
    end

    fprintf('Final channel count: %d (removed %d)\n', length(EEG.chanlocs), originalCount - length(EEG.chanlocs));
end
