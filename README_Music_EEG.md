# Music EEG analysis — MATLAB

Two independent MATLAB entry scripts reproduce the main-manuscript and supplementary analyses. Run either script from the MATLAB Editor or command window. Local functions below each script are required implementation helpers; the entry points themselves are scripts and require no function arguments.

## Files

- `Music_EEG_Main_Analysis.m`: main figures and primary statistical validation (stripe width 0.18).
- `Music_EEG_Supplementary_Analysis.m`: supplementary figures S01–S06, matched stripe sensitivity, and renewal diagnostics.

## Requirements

Place `MDEAcorrected.m`, `read_set_file.m`, and `CS_reliability_test_scaling_series_Strength.m` on the MATLAB path. The Signal Processing Toolbox is required. EEG files must match `D*_B*_T*_ICApruned.set`. The scripts search standard user folders and can prompt for the EEG directory.

## Run

```matlab
Music_EEG_Main_Analysis
Music_EEG_Supplementary_Analysis
```

Run these separately; each performs its own analysis. The supplementary script optionally supports reusing a previous matched-stripe result folder through `existingResultsFolder` near the top of the script.

Outputs are saved to timestamped folders under Downloads. Main figures appear in `FIGURES/MAIN`; supplementary figures appear in `UNIFIED_PUBLICATION/SUPPLEMENTARY`.

## Notes

The primary signed effect is `CS(task) - CS(Rest)`. The supplementary survival plots use nominal fitting bounds `[2,20]` and shared x-axis limits `[1,100]`. Random illustrative examples may differ between runs.

The scripts have not been executed in MATLAB in this release. Verify numerical results and figure exports against the manuscript before publishing the repository. Do not upload participant-level EEG files unless data-sharing permission has been established.
