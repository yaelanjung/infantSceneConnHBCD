#!/usr/bin/env bash
#SBATCH --job-name=roi_to_native
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G

set -euo pipefail
mkdir -p logs

code_dir="YOUR_PATH_TO_CODE_FOLDER"
LIST_FILE="${code_dir}/YOUR_FILE_NAME_FOR_LIST.txt"

data_dir="YOUR_PATH_TO_RAW_DATA"
base_dir="YOUR_PATH_TO_PROCESSED_DATA"
ROI_MNI_DIR="/YOUR_PATH_TO_MNI_TEMPLATES/"
ses="ses-V02"

if [[ ! -f "$LIST_FILE" ]]; then    
    echo "TEXT FILE NOT THERE: $LIST_FILE"
    exit
fi

# --- Environment Setup ---
CONDA_BASE="/opt/anaconda"
ENV_PREFIX="YOUR_CONDA_ENV_NAME"
source "${CONDA_BASE}/etc/profile.d/conda.sh" || eval "$(conda shell.bash hook)"
conda activate "${ENV_PREFIX}"
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}

ROIS=(
  "lPPA" "rPPA"
  "lOPA" "rOPA"
  "lRSC" "rRSC"
  "lSPL" "rSPL")

tail -n +2 "$LIST_FILE" | cut -d, -f1 | tr -d '\r' | sort -u | while read -r subj_id || [[ -n "$subj_id" ]]; do
    
    subj_id=$(echo "$subj_id" | xargs)
    [[ -z "$subj_id" ]] && continue

    echo "Checking subject: $subj_id" >&2

    ROI_NATIVE_DIR="${base_dir}/${subj_id}/${ses}/masks"
    mkdir -p "$ROI_NATIVE_DIR"

    anatdir="${data_dir}/${subj_id}/${ses}/anat"

    T1W=$(ls -1 "${anatdir}/${subj_id}"*_desc-preproc_T1w.nii.gz 2>/dev/null | head -n 1 || true)
    XFM=$(ls -1 "${anatdir}/${subj_id}"*_from-MNI152NLin6Asym_to-T1w_mode-image_xfm.h5 2>/dev/null | head -n 1 || true)

    if [[ -z "$T1W" || ! -f "$T1W" ]]; then
        echo "  --> ERROR: native T1w not found"
        continue
    fi

    if [[ -z "$XFM" || ! -f "$XFM" ]]; then
        echo "  --> ERROR: MNI152NLin6Asym_to-T1w transform not found"
        continue
    fi

    echo "  T1w: $T1W"
    echo "  XFM: $XFM"

    for roi in "${ROIS[@]}"; do
        
        roi_file="parcel_${roi}_nlin_asym.nii.gz"
        ROI_MNI="${ROI_MNI_DIR}/${roi_file}"
        [[ -f "$ROI_MNI" ]] || { echo "  --> WARNING: missing ROI $ROI_MNI"; continue; }

        ROI_NATIVE="${ROI_NATIVE_DIR}/${subj_id}_${ses}_${roi}_space-T1w.nii.gz"

        echo "  Warping $(basename "$ROI_MNI") -> $(basename "$ROI_NATIVE")"
        if [[ ! -f "$ROI_NATIVE" ]]; then

            antsApplyTransforms \
            -d 3 \
            -i "$ROI_MNI" \
            -r "$T1W" \
            -o "$ROI_NATIVE" \
            -n GenericLabel \
            -t "$XFM"

            if [[ -f "$ROI_NATIVE" ]]; then
                echo "    Wrote: $ROI_NATIVE"
            else
                echo "    --> ERROR: failed to create $ROI_NATIVE"
            fi
        else
            echo " FILE ALREADY EXIST: $ROI_NATIVE "
        fi
    done

done 

echo "Finished at: $(date)"