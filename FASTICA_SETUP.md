# FastICA Integration Guide

## Overview

FastICA has been integrated into your EEG analysis pipeline as an alternative to EEGLAB's runica algorithm. FastICA is often faster and can provide better separation of independent components.

## Installation

1. **Download FastICA**
   - Get it from: https://research.ics.aalto.fi/ica/fastica/
   - Or use the version you already downloaded

2. **Add to MATLAB Path**
   ```matlab
   addpath('/path/to/fastica');  % Replace with your FastICA location
   savepath;  % Save for future sessions
   ```

3. **Verify Installation**
   ```matlab
   test_fastica_integration
   ```

## Usage

### Automatic (Recommended)

The system automatically uses FastICA if available:

- **JuanAnalyzer GUI**: Automatically uses FastICA
- **Command Line**: Will use FastICA when you call `launchJuanAnalyzer()`

No code changes needed! The system detects FastICA and uses it automatically.

### Manual Usage

```matlab
% Load your EEG data
EEG = pop_loadset('mydata.set');

% Run FastICA
EEG = runFastICA_EEG(EEG);

% Continue with ICLabel
EEG = pop_iclabel(EEG, 'default');
EEG = pop_icflag(EEG, [0 0; 0.9 1; 0.9 1; 0.9 1; 0.9 1; 0.9 1; 0 0]);
```

### Advanced Options

```matlab
% Symmetric approach (default, faster)
EEG = runFastICA_EEG(EEG, 'approach', 'symm');

% Deflation approach (sequential)
EEG = runFastICA_EEG(EEG, 'approach', 'defl');

% Different nonlinearity functions
EEG = runFastICA_EEG(EEG, 'g', 'tanh');   % Default
EEG = runFastICA_EEG(EEG, 'g', 'gauss');  % For super-Gaussian
EEG = runFastICA_EEG(EEG, 'g', 'pow3');   % Cubic nonlinearity

% Custom number of components
EEG = runFastICA_EEG(EEG, 'numOfIC', 25);

% Verbose output
EEG = runFastICA_EEG(EEG, 'verbose', 'on');
```

## What Changed

### Files Modified

1. **JuanAnalyzer.m** (line 440)
   - Now tries FastICA first
   - Falls back to runica if FastICA unavailable

### Files Added

1. **runFastICA_EEG.m**
   - Wrapper function for FastICA
   - Handles EEGLAB structure compatibility
   - Populates all required ICA fields

2. **test_fastica_integration.m**
   - Verification script
   - Tests FastICA installation
   - Compares performance with runica

3. **FASTICA_SETUP.md** (this file)

## Compatibility

FastICA output is fully compatible with:
- ✅ ICLabel (artifact classification)
- ✅ pop_subcomp (component removal)
- ✅ pop_selectcomps (manual review)
- ✅ All EEGLAB ICA visualization tools

## Algorithm Comparison

| Feature | FastICA | runica |
|---------|---------|--------|
| Speed | ⚡ Faster | Slower |
| Convergence | Fast | Moderate |
| Accuracy | High | High |
| Memory | Lower | Higher |
| Defaults | Good | Good |

## Troubleshooting

### "FastICA not found"
```matlab
% Check if fastica is in path
which fastica

% If empty, add to path
addpath('/path/to/fastica');
savepath;
```

### "FastICA returned empty result"
Try adjusting parameters:
```matlab
% Increase max iterations
EEG = runFastICA_EEG(EEG, 'maxIter', 2000);

% Try different nonlinearity
EEG = runFastICA_EEG(EEG, 'g', 'pow3');

% Use deflation approach
EEG = runFastICA_EEG(EEG, 'approach', 'defl');
```

### "Dimension mismatch"
This usually means bad data. Check:
```matlab
% Ensure data has no NaN or Inf
any(isnan(EEG.data(:)))
any(isinf(EEG.data(:)))

% Check data dimensions
size(EEG.data)
```

## Performance Tips

1. **Faster Processing**
   - Use 'symm' approach (default)
   - Reduce numOfIC if you don't need all components
   - Turn off verbose mode in GUI

2. **Better Separation**
   - Try different 'g' functions for different data types
   - Use 'defl' for sequential extraction
   - Increase maxIter for difficult datasets

## Examples

### Example 1: Quick Analysis
```matlab
EEG = pop_loadset('data.set');
EEG = runFastICA_EEG(EEG);  % Use defaults
```

### Example 2: Custom Parameters
```matlab
EEG = pop_loadset('data.set');
EEG = runFastICA_EEG(EEG, ...
    'approach', 'symm', ...
    'g', 'tanh', ...
    'numOfIC', 30, ...
    'verbose', 'on');
```

### Example 3: Full Pipeline
```matlab
% Load data
EEG = pop_loadset('data.set');

% Preprocess
EEG = pop_resample(EEG, 250);
EEG = pop_eegfiltnew(EEG, 'locutoff', 0.5);
EEG = pop_reref(EEG, []);

% Run FastICA
EEG = runFastICA_EEG(EEG, 'verbose', 'off');

% Auto-classify and remove artifacts
EEG = pop_iclabel(EEG, 'default');
EEG = pop_icflag(EEG, [0 0; 0.9 1; 0.9 1; 0.9 1; 0.9 1; 0.9 1; 0 0]);
bad_comps = find(EEG.reject.gcompreject);
EEG = pop_subcomp(EEG, bad_comps, 0);
```

## References

- FastICA algorithm: Hyvärinen & Oja (2000)
- EEGLAB ICA: Delorme & Makeig (2004)
- ICLabel: Pion-Tonachini et al. (2019)

## Support

If you encounter issues:
1. Run `test_fastica_integration` to verify installation
2. Check MATLAB version (R2018b+ recommended)
3. Ensure FastICA is in path
4. Try with sample data first

---

**Ready to use!** Just run `launchJuanAnalyzer()` and FastICA will be automatically used if available.
