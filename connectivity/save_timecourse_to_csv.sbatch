#!/usr/bin/env bash
#SBATCH --job-name=roi_ts
#SBATCH --time=08:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G

mkdir -p logs
set -euo pipefail

PROJ_DIR="/YOUR_PATH_TO_PROJECT_DIRECTORY"

echo "Script started at: $(date)"
# --- Environment Setup ---
CONDA_BASE="/opt/anaconda"
ENV_PREFIX="/YOUR_CONDA_ENV_NAME"
source "${CONDA_BASE}/etc/profile.d/conda.sh" || eval "$(conda shell.bash hook)"
conda activate "${ENV_PREFIX}"

# --- Define paths ---
basedir="YOUR_PATH_TO_DATA"
ses="ses-V03"
QC_CSV="${PROJ_DIR}/txt_files/motion_stats_V03_all.csv"

echo ": start now! yay! :"

# edit these ROI names to match your actual filenames
 ROIS=(
  "lPPA" "rPPA"
  "lOPA" "rOPA"
  "lRSC" "rRSC"
  "lSPL" "rSPL")

# --- Processing Loop ---
tail -n +2 "$QC_CSV" | while IFS=, read -r subj_id run total_TRs kept_TRs censored_TRs percent_retained mean_FD max_FD; do
    
    # skip header
    [[ "$subj_id" == "subj_id" ]] && continue

    echo ">>> Current Subject: $subj_id (Run: $run, Pct: $percent_retained)"

    # Paths
    data_dir="${basedir}/${subj_id}/${ses}/cleaned_bold"
    mask_dir="${basedir}/${subj_id}/${ses}/masks"
    output_dir="${basedir}/${subj_id}/${ses}/time_series"
    mkdir -p "$output_dir"
    
    # Target Merged File
    PARTICIPANT_CSV="${output_dir}/${subj_id}_${ses}_v1_timeseries.csv"
    
    if [ -f "$PARTICIPANT_CSV" ]; then
        rm ${PARTICIPANT_CSV}
        echo "remove the old one to rewrite the existing file"
    fi
    
    data_fn="${data_dir}/${subj_id}_${ses}_run${run}_clean_tproj.nii.gz"
    mask_base="${mask_dir}/${subj_id}_${ses}"

    if [[ ! -f "$data_fn" ]]; then
        echo "    File Missing: $data_fn"
        continue
    fi

    # Unique Temp Dir for this specific run
    TMPDIR="${output_dir}/tmp_run${run}"
    mkdir -p "$TMPDIR"

    valid_rois=()
   
    if [[ ! -f "$PARTICIPANT_CSV" ]]; then
        # 1. Extract ROI Data
        for ROI in "${ROIS[@]}"; do    
            mask_fn="${mask_base}_${ROI}_space-T1w.nii.gz"

            if [[ ! -f "$mask_fn" ]]; then
                echo "  Missing ROI mask: $ROI | ${mask_fn}"
                continue
            fi
            resampled_mask=${mask_dir}/${subj_id}_${ROI}_res.nii.gz
            
            if [[ ! -f "$resampled_mask" ]]; then
                echo "      Resampling mask for $ROI..."
                3dresample \
                    -master "${data_fn}" \
                    -prefix "${resampled_mask}" \
                    -input "${mask_fn}"
            else
                echo "      Using existing resampled mask for $ROI"
            fi

            # Extract mean timeseries
            3dmaskave -quiet -mask "$resampled_mask" "$data_fn" > "${TMPDIR}/${ROI}.1D"
            valid_rois+=("$ROI")
        done

        # 2. Append to Participant CSV
        if [[ ${#valid_rois[@]} -gt 0 ]]; then
            # Write Header ONLY if the file doesn't exist yet
            if [[ ! -f "$PARTICIPANT_CSV" ]]; then
                {
                    printf "sub_id,run,TR"
                    for ROI in "${valid_rois[@]}"; do printf ",%s" "$ROI"; done
                    printf "\n"
                } > "$PARTICIPANT_CSV"
            fi

            # Paste columns, then use awk to insert sub_id and run_id at the start of every line
            paste -d, \
                <(awk '{print NR}' "${TMPDIR}/${valid_rois[0]}.1D") \
                $(for ROI in "${valid_rois[@]}"; do printf "%s " "${TMPDIR}/${ROI}.1D"; done) | \
                awk -v subj="$subj_id" -v r="$run" -F, 'BEGIN{OFS=","} {print subj, r, $0}' >> "$PARTICIPANT_CSV"

            echo "      Success: Data appended to $(basename "$PARTICIPANT_CSV")"
        fi

        rm -rf "$TMPDIR"

    else
         echo "  File already exisit ::  "$PARTICIPANT_CSV"  "
    fi

done

echo "::: Finished at $(date) ::: "