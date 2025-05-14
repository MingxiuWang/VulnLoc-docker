#!/bin/bash
set -e  # Exit on any error

# === CONFIGURATION ===
target_cve="cve_2016_5314"
base_folder="$HOME/workspace"
out_folder="$base_folder/outputs"
code_folder="$base_folder/code"
venv_path="$base_folder/venv"

# === SETUP VENV ===
if [ ! -d "$venv_path" ]; then
    echo "Creating Python virtual environment at $venv_path"
    python3 -m venv "$venv_path"
fi

echo "Activating virtual environment..."
source "$venv_path/bin/activate"

# === OPTIONAL: Install required Python packages ===
echo "Installing required Python packages in virtual environment..."
pip install --upgrade pip
pip install numpy==1.16.6 pyelftools

# === SETUP OUTPUT DIRECTORIES ===
mkdir -p "$out_folder"
echo "Created folder -> $out_folder"

cve_folder="$out_folder/$target_cve"
mkdir -p "$cve_folder"
echo "Created folder -> $cve_folder"

# === COPY CONFIG FILE ===
cp ./config.ini "$code_folder"

# === FUZZING ===
echo "The default number of processes is 10. VulnLoc will adjust it according to the number of CPUs on the local machine."
echo "The default timeout is 4h. You can change the timeout in ./code/fuzz.py"
echo "Execution progress is written to fuzz.log in the output folder. It will not appear in the terminal."
echo "Please do not terminate the execution until VulnLoc timeouts automatically."

cd "$code_folder"
python fuzz.py --config_file ./config.ini --tag "$target_cve"
echo "Finish fuzzing ..."

# === EXTRACT RESULTS ===
cve_out_folder=$(find "$out_folder/$target_cve" -maxdepth 1 -name 'output_*' -not -path '*/\.*' -type d | head -n 1)
echo "Output Folder: $cve_out_folder"

target_fuzz_path="$cve_out_folder/fuzz.log"
poc_hash=$(sed '19q;d' "$target_fuzz_path" | awk '{print $NF}')

# === PATCH LOCALIZATION ===
python patchloc.py \
    --config_file ./config.ini \
    --tag "$target_cve" \
    --func calc \
    --out_folder "$cve_out_folder" \
    --poc_trace_hash "$poc_hash" \
    --process_num 10

echo "✅ All done."
