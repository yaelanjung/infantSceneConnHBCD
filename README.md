A fine-grained cortical blueprint for three scene systems in newborns

This repository contains preprocessing and analysis scripts associated with the manuscript:

Jung et al. (2026). A fine-grained cortical blueprint for three scene systems in newborns. Nature Communications.

The study examines the functional connectivity organization of scene-selective cortical regions in newborns and adults, as well as developmental changes in scene-network and scene–hippocampal connectivity across infancy.


Repository contents:
preprocessing:
denoising.sbatch: Denoising and nuisance regression for resting-state fMRI data.
register_roi.sbatch: Transformation and registration of cortical regions of interest (ROIs) to individual participant space.

connectivity:
save_timecourse_to_csv.sbatch: Extraction of ROI time series and calculation of pairwise functional connectivity
connectivity_rsa.r: Representational similarity analysis (RSA) comparing neural connectivity patterns with hypothesized models of scene-system organization.

stats:
model_comparison.r: statistical testing on the rsa results between different models (Fig. 3)
developmental_analysis.r: Linear mixed-effects analyses of developmental changes in connectivity among scene-selective regions (Fig. 7)

Data availability:
Infant neuroimaging data were obtained from the HEALthy Brain and Child Development (HBCD) Study. Access to these data is available through the NIH Brain Development Cohorts Data Hub, subject to data-use approval.
Numerical source data underlying the figures are provided with the associated publication.

Usage:
Scripts are organized by analysis type. Users should update the directory paths defined at the beginning of each script to match their local computing environment.
The scripts were developed for the original research computing environment and may require adjustments to file paths, dependencies, and input file organization.

Software dependencies:
Analyses were conducted using Bash and R, together with relevant neuroimaging software.
Software versions and additional dependencies are documented in the manuscript's Methods and Reporting Summary.

Citation: If you use this code, please cite the associated publication.
Code archive DOI:https://doi.org/10.5281/zenodo.23577258