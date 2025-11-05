function [icasig, A, W] = fastica(mixedsig, varargin)
    % FASTICA - Fast Independent Component Analysis
    %
    % This is a simplified implementation of the FastICA algorithm.
    % For the full-featured version, download from:
    % https://research.ics.aalto.fi/ica/fastica/
    %
    % Usage:
    %   [icasig, A, W] = fastica(mixedsig)
    %   [icasig, A, W] = fastica(mixedsig, 'param', value, ...)
    %
    % Inputs:
    %   mixedsig - Mixed signals (rows = signals, columns = samples)
    %
    % Optional Parameters:
    %   'approach'    - 'symm' or 'defl' (default: 'symm')
    %   'numOfIC'     - Number of ICs to extract (default: all)
    %   'g'           - Nonlinearity: 'pow3', 'tanh', 'gauss' (default: 'tanh')
    %   'maxNumIterations' - Max iterations (default: 1000)
    %   'epsilon'     - Convergence threshold (default: 0.0001)
    %   'verbose'     - 'on' or 'off' (default: 'off')
    %   'stabilization' - 'on' or 'off' (default: 'on')
    %   'finetune'    - Fine-tuning (default: 'off')
    %
    % Outputs:
    %   icasig - Independent components (rows = ICs, columns = samples)
    %   A      - Mixing matrix
    %   W      - Unmixing matrix
    %
    % Reference:
    %   Hyvärinen, A., & Oja, E. (2000). Independent component analysis:
    %   algorithms and applications. Neural Networks, 13(4-5), 411-430.

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'mixedsig', @isnumeric);
    addParameter(p, 'approach', 'symm', @ischar);
    addParameter(p, 'numOfIC', [], @isnumeric);
    addParameter(p, 'g', 'tanh', @ischar);
    addParameter(p, 'maxNumIterations', 1000, @isnumeric);
    addParameter(p, 'epsilon', 0.0001, @isnumeric);
    addParameter(p, 'verbose', 'off', @ischar);
    addParameter(p, 'stabilization', 'on', @ischar);
    addParameter(p, 'finetune', 'off', @ischar);

    parse(p, mixedsig, varargin{:});
    params = p.Results;

    %% Initialize
    X = double(mixedsig);
    [n, m] = size(X);  % n = number of signals, m = number of samples

    if isempty(params.numOfIC)
        numOfIC = n;
    else
        numOfIC = min(params.numOfIC, n);
    end

    verbose = strcmp(params.verbose, 'on');

    if verbose
        fprintf('FastICA: Extracting %d independent components from %d mixed signals\n', numOfIC, n);
    end

    %% Step 1: Center the data
    meanX = mean(X, 2);
    X = X - repmat(meanX, 1, m);

    %% Step 2: Whiten the data
    if verbose
        fprintf('FastICA: Whitening data...\n');
    end

    covMatrix = cov(X');
    [E, D] = eig(covMatrix);

    % Sort eigenvalues in descending order
    [~, order] = sort(diag(D), 'descend');
    E = E(:, order);
    D = D(order, order);

    % Whitening matrix
    whiteningMatrix = diag(1 ./ sqrt(diag(D) + eps)) * E';
    dewhiteningMatrix = E * diag(sqrt(diag(D) + eps));

    % Whitened data
    Z = whiteningMatrix * X;

    %% Step 3: Choose nonlinearity
    switch lower(params.g)
        case 'pow3'
            g = @(u) u.^3;
            g_prime = @(u) 3*u.^2;
        case 'tanh'
            g = @(u) tanh(u);
            g_prime = @(u) 1 - tanh(u).^2;
        case 'gauss'
            g = @(u) u .* exp(-u.^2/2);
            g_prime = @(u) (1 - u.^2) .* exp(-u.^2/2);
        otherwise
            g = @(u) tanh(u);
            g_prime = @(u) 1 - tanh(u).^2;
    end

    %% Step 4: Run FastICA
    if verbose
        fprintf('FastICA: Running %s approach...\n', params.approach);
    end

    if strcmpi(params.approach, 'defl')
        % Deflation approach (one-by-one)
        W = zeros(numOfIC, n);

        for i = 1:numOfIC
            if verbose && mod(i, 5) == 0
                fprintf('FastICA: Extracting component %d/%d...\n', i, numOfIC);
            end

            % Initialize randomly
            w = randn(n, 1);
            w = w / norm(w);

            % Iterate
            for iter = 1:params.maxNumIterations
                w_old = w;

                % FastICA update rule
                w = mean(repmat(g(w' * Z), n, 1) .* Z, 2) - mean(g_prime(w' * Z)) * w;

                % Orthogonalization (Gram-Schmidt)
                if i > 1
                    w = w - W(1:i-1, :)' * (W(1:i-1, :) * w);
                end

                % Normalize
                w = w / norm(w);

                % Check convergence
                if abs(abs(w' * w_old) - 1) < params.epsilon
                    if verbose
                        fprintf('FastICA: Component %d converged in %d iterations\n', i, iter);
                    end
                    break;
                end

                % Check for non-convergence
                if iter == params.maxNumIterations
                    warning('FastICA: Component %d did not converge in %d iterations', i, params.maxNumIterations);
                end
            end

            W(i, :) = w';
        end

    else
        % Symmetric approach (all at once)
        % Initialize randomly
        W = randn(numOfIC, n);
        W = W * inv(W * W')^(1/2);  % Orthogonalize

        for iter = 1:params.maxNumIterations
            W_old = W;

            % FastICA update for all components
            hypTan = g(W * Z);
            hypTan_deriv = g_prime(W * Z);

            W = (hypTan * Z') / m - repmat(mean(hypTan_deriv, 2), 1, n) .* W;

            % Symmetric orthogonalization
            W = W * inv(W * W')^(1/2);

            % Check convergence
            delta = max(max(abs(abs(W * W_old') - eye(numOfIC))));

            if delta < params.epsilon
                if verbose
                    fprintf('FastICA: Converged in %d iterations (delta = %.6f)\n', iter, delta);
                end
                break;
            end

            if verbose && mod(iter, 100) == 0
                fprintf('FastICA: Iteration %d, delta = %.6f\n', iter, delta);
            end
        end

        if iter == params.maxNumIterations
            warning('FastICA: Did not converge in %d iterations', params.maxNumIterations);
        end
    end

    %% Step 5: Compute outputs
    % Unmixing matrix in original space
    W = W * whiteningMatrix;

    % Mixing matrix
    A = pinv(W);

    % Independent components
    icasig = W * X;

    if verbose
        fprintf('FastICA: Complete! Extracted %d independent components\n', size(icasig, 1));
    end
end
