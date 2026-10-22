#!/usr/bin/env bash
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --job-name=denoise
#SBATCH --time=10:00:00
#SBATCH --output=logs/denoise_v02_all_%j.out
#SBATCH --error=logs/denoise_%j.err

set -euo pipefail
mkdir -p logs

PROJ_DIR="YOUR_PATH_TO_PROJECT_FOLDER"
LIST_FILE="${PROJ_DIR}/YOUR_TXT_FILENAME.txt"
OUTPUT_QC="${PROJ_DIR}/YOUR_TXT_MOTION_QC_FILENAME.csv"
ses="ses-V02"

if [ ! -f "$LIST_FILE" ]; then
    echo "::: LIST FILE NOT EXIST :::"
    exit
fi

# --- Environment Setup ---
CONDA_BASE="/opt/anaconda"
ENV_PREFIX="/YOUR_CONDA_ENV_NAME"
source "${CONDA_BASE}/etc/profile.d/conda.sh" || eval "$(conda shell.bash hook)"
conda activate "${ENV_PREFIX}"
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}

# --- Paths ---
data_dir="YOUR_PATH_TO_RAW_DATA"
base_dir="YOUR_PATH_TO_PROCESSED_DATA"
f_info="hash-2afa9081_task-rest_dir-PA"

# --- Thresholds for whether to run 3dTproject ---
FD_THRESH="0.30"
MIN_KEEP_TRS=180
MIN_KEEP_PCT=60

# --- Initialize CSV Header ---
echo "sub_id,run,total_TRs,kept_TRs,censored_TRs,percent_retained,mean_FD,max_FD" > "$OUTPUT_QC"

while IFS= read -r subj || [[ -n "$subj" ]]; do
    subj=$(echo "$subj" | xargs)
    [[ -z "$subj" ]] && continue

    datadir="${data_dir}/${subj}/${ses}/func"
    output_dir_full=${base_dir}/${subj}/${ses}/cleaned_bold
    mkdir -p ${output_dir_full}

    echo "Begin running for :: $subj"

    if [[ ! -d "$datadir" ]]; then
        echo "   --> ERROR: Directory DOES NOT EXIST. Skipping."
        continue
    fi

    SPACE="T1w"
    SEARCH_PATTERN="${datadir}/${subj}_${ses}_${f_info}_run-*_space-${SPACE}_desc-preproc_bold.nii.gz"
    found_any=false

    for BOLD in $SEARCH_PATTERN; do
        [[ -e "$BOLD" ]] || continue
        found_any=true

        run=$(echo "$BOLD" | grep -oP 'run-\K[0-9]+' || echo "1")
        
        MASK="${datadir}/${subj}_${ses}_${f_info}_run-${run}_space-${SPACE}_desc-brain_mask.nii.gz"
        CUR_DIR=$(dirname "$BOLD")
        CONF="${CUR_DIR}/${subj}_${ses}_${f_info}_run-${run}_desc-confounds_timeseries.tsv"

        OUTBASE="${output_dir_full}/${subj}_${ses}_run${run}"
        CENS="${output_dir_full}/${subj}_${ses}_run${run}_censor_fd${FD_THRESH}.1D"
        NUIS="${output_dir_full}/${subj}_${ses}_run${run}_nuis.1D"
        OUTCLEAN="${output_dir_full}/${subj}_${ses}_run${run}_clean_tproj.nii.gz"

        # --- STEP 1: Calculation Logic (Needed for both new and skipped runs) ---
        if [[ ! -f "$CONF" ]]; then
            echo "      --> ERROR: Confounds file missing. Skipping run."
            continue
        fi

        # Generate nuisance/censor files if they don't exist
        if [[ ! -f "$CENS" || ! -f "$NUIS" ]]; then
            python3 make_nuis_and_censor.py \
              --confounds_tsv "$CONF" \
              --out_prefix "$OUTBASE" \
              --fd_thresh "$FD_THRESH" \
              --nan_fd_is_keep
        fi

        # --- Extract FD and Censor Stats ---
        TMP_FD="${output_dir_full}/tmp_${subj}_run${run}_fd.1D"
        awk -F'\t' -v col="framewise_displacement" 'NR==1{for(i=1;i<=NF;i++)if($i==col)c=i;if(!c)exit 1} NR>1{val=$c; if(val=="n/a"||val=="NaN"||val=="")val=0; print val}' "$CONF" > "$TMP_FD"

        read mean_fd max_fd <<< "$(awk 'BEGIN{sum=0;n=0;max=0}{v=$1+0; sum+=v; n++; if(n==1||v>max)max=v} END{if(n>0)printf "%.6f %.6f\n", sum/n, max; else printf "0 0\n"}' "$TMP_FD")"
        read total kept <<< "$(awk '{for(i=1;i<=NF;i++){total++; if($i==1)kept++}} END{print total+0, kept+0}' "$CENS")"
        
        rm -f "$TMP_FD"
        
        censored=$((total - kept))
        kept_pct=$(( kept * 100 / total ))
        percent_retained=$(awk -v k="$kept" -v t="$total" 'BEGIN { printf "%.2f", (k/t)*100 }')

        # --- STEP 2: Threshold Check ---
        if [[ "$kept" -lt "$MIN_KEEP_TRS" || "$kept_pct" -lt "$MIN_KEEP_PCT" ]]; then
            echo "      --> SKIP: Run ${run} failed QC (${percent_retained}% retained). Not saving to CSV."
            continue
        fi

        # --- STEP 3: Save to CSV and Run 3dTproject ---
        # If it reaches here, it passed the thresholds.
        echo "${subj},${run},${total},${kept},${censored},${percent_retained},${mean_fd},${max_fd}" >> "$OUTPUT_QC"

        if [[ -f "$OUTCLEAN" ]]; then
            # echo "   [SKIP 3dTproject] Run ${run} already processed and passed QC. Logged to CSV."
            # continue
            rm $OUTCLEAN
        fi

        echo "   [PROCEED] Running 3dTproject for ${subj} run ${run}"
        3dTproject \
          -input "$BOLD" \
          -mask "$MASK" \
          -polort 0 \
          -passband 0.008 0.1 \
          -ort "$NUIS" \
          -censor "$CENS" \
          -cenmode NTRP \
          -prefix "$OUTCLEAN"

    done

    if [[ "$found_any" = false ]]; then
        echo "   --> ERROR: No runs matched for $subj"
    fi

done < "$LIST_FILE"

echo "Summary (included runs only) saved to $OUTPUT_QC"