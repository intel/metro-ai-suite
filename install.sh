#!/bin/bash
set -e  # Exit on error

##############################################################################
# 1. Source the .env file to get CASE (or other environment variables).
#    Make sure .env contains a line like: Case="Smart_Tolling"
##############################################################################
if [ ! -f ".env" ]; then
    echo "Error: .env file not found in current directory!"
    exit 1
fi
# shellcheck disable=SC1091
source .env

# The environment variable must be named `Case` inside .env
if [ -z "$Case" ]; then
    echo "Error: 'Case' variable not found in .env!"
    exit 1
fi

echo "Detected Case: $Case"

##############################################################################
# 2. Create/Activate a Python virtual environment to avoid pip system issues
##############################################################################
VENV_DIR="$HOME/ri2-venv"  # or pick another name/path if you wish

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python virtual environment at $VENV_DIR ..."
    python3 -m venv "$VENV_DIR"
fi

echo "Activating Python virtual environment..."
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"

# Upgrade pip to ensure smooth installs
pip install --upgrade pip

##############################################################################
# 3. Locate and parse the model.txt
#    Expecting lines like:
#      yolov10s yolo
#      license-plate-recognition-barrier-0007 omz
#      vehicle-attributes-recognition-barrier-0039 omz
##############################################################################
MODEL_TXT="usecase/${Case}/model.txt"

if [ ! -f "$MODEL_TXT" ]; then
    echo "Error: $MODEL_TXT not found!"
    deactivate
    exit 1
fi

YOLO_MODEL=""
OMZ_MODELS=()

while read -r line; do
    # Skip empty lines or comments
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    MODEL_NAME=$(echo "$line" | awk '{print $1}')
    MODEL_TYPE=$(echo "$line" | awk '{print $2}')

    if [ "$MODEL_TYPE" = "yolo" ]; then
        YOLO_MODEL="$MODEL_NAME"
    elif [ "$MODEL_TYPE" = "omz" ]; then
        OMZ_MODELS+=("$MODEL_NAME")
    fi
done < "$MODEL_TXT"

echo "Found YOLO model: $YOLO_MODEL"
echo "Found OMZ models: ${OMZ_MODELS[@]}"

##############################################################################
# 4. Process YOLO model (if any)
##############################################################################
if [ -n "$YOLO_MODEL" ]; then
    echo ">>> Processing YOLO model: $YOLO_MODEL"

    # Install YOLO and OpenVINO for the conversion
    pip install ultralytics==8.3.50 openvino==2025.0.0

    # By default, yolo export expects <model_name>.pt to be in the current dir
    if [ ! -f "${YOLO_MODEL}.pt" ]; then
        echo "Warning: ${YOLO_MODEL}.pt not found in current directory. If not local, ultralytics will try to download."
    fi

    # Export YOLO model to OpenVINO format
    echo "Exporting ${YOLO_MODEL} to OpenVINO..."
    yolo export model="${YOLO_MODEL}.pt" format=openvino

    # The export typically creates a folder <model_name>_openvino_model
    EXPORTED_DIR="${YOLO_MODEL}_openvino_model"
    if [ ! -d "$EXPORTED_DIR" ]; then
        echo "Error: Expected folder $EXPORTED_DIR not found after export!"
        deactivate
        exit 1
    fi

    # Remove old folder in evam/models/public if it exists, then move the new folder
    if [ -d "evam/models/public/${YOLO_MODEL}" ]; then
        rm -rf "evam/models/public/${YOLO_MODEL}"
    fi
    mkdir -p evam/models/public
    mv "$EXPORTED_DIR" "evam/models/public/${YOLO_MODEL}"

    # ------------------------------------------------------------------------
    # Attempt the sed update on the model XML file (line 11172 => YOLO => yolo_v10)
    XML_FILE="evam/models/public/${YOLO_MODEL}/${YOLO_MODEL}.xml"
    if [ -f "$XML_FILE" ]; then
        sed -i '11172s/YOLO/yolo_v10/' "$XML_FILE" || true
        echo "XML file updated for ${YOLO_MODEL} (if line 11172 existed)."
    else
        echo "Warning: XML file not found for ${YOLO_MODEL}"
    fi
    # ------------------------------------------------------------------------

    # Create a FP32 subfolder inside the YOLO model folder
    mkdir -p "evam/models/public/${YOLO_MODEL}/FP32"

    # If the .pt file exists, move it to FP32
    if [ -f "${YOLO_MODEL}.pt" ]; then
        mv "${YOLO_MODEL}.pt" "evam/models/public/${YOLO_MODEL}/FP32/"
    fi

    # Move the bin, xml, yaml into the FP32 folder (if they exist)
    mv "evam/models/public/${YOLO_MODEL}/${YOLO_MODEL}.xml" "evam/models/public/${YOLO_MODEL}/FP32/" 2>/dev/null || true
    mv "evam/models/public/${YOLO_MODEL}/${YOLO_MODEL}.bin" "evam/models/public/${YOLO_MODEL}/FP32/" 2>/dev/null || true
    mv "evam/models/public/${YOLO_MODEL}/"*.yaml "evam/models/public/${YOLO_MODEL}/FP32/" 2>/dev/null || true

    # Finally, move everything to usecase/${Case}/evam/models/public
    if [ -d "usecase/${Case}/evam/models/public/${YOLO_MODEL}" ]; then
        rm -rf "usecase/${Case}/evam/models/public/${YOLO_MODEL}"
    fi
    mkdir -p "usecase/${Case}/evam/models/public"
    mv "evam/models/public/${YOLO_MODEL}" "usecase/${Case}/evam/models/public/"
fi

##############################################################################
# 5. Process OMZ models (if any)
##############################################################################
if [ ${#OMZ_MODELS[@]} -gt 0 ]; then
    echo ">>> Processing OMZ models: ${OMZ_MODELS[@]}"

    # We will reuse the same venv, so just ensure we have openvino-dev
    pip install "openvino-dev[onnx,tensorflow,pytorch]"

    # Clone DL Streamer if not already present
    if [ ! -d "dlstreamer" ]; then
        git clone https://github.com/dlstreamer/dlstreamer.git
    else
        echo "dlstreamer directory already exists. Skipping clone."
    fi

    # Prepare to download models
    export MODELS_PATH="$HOME/intel/models"
    mkdir -p "$MODELS_PATH"

    pushd dlstreamer/samples > /dev/null

    # Overwrite models_omz_samples.lst with only the OMZ models from model.txt
    echo "Overwriting models_omz_samples.lst with OMZ models..."
    > models_omz_samples.lst
    for model in "${OMZ_MODELS[@]}"; do
        echo "$model" >> models_omz_samples.lst
    done

    # Download models
    echo "Downloading OMZ models..."
    ./download_omz_models.sh

    popd > /dev/null

    # Merge 'public' into 'intel' (if public exists)
    if [ -d "$HOME/intel/models/public" ]; then
        echo "Merging public models into intel folder..."
        mkdir -p "$HOME/intel/models/intel"
        for item in "$HOME/intel/models/public/"*; do
            base_item=$(basename "$item")
            target="$HOME/intel/models/intel/$base_item"
            if [ -e "$target" ]; then
                echo "Removing existing $target to overwrite."
                rm -rf "$target"
            fi
            mv "$item" "$target"
        done
        rm -rf "$HOME/intel/models/public"
    fi

    # Move the final models directly into usecase/<Case>/evam/models/intel/ (flattening the structure)
    mkdir -p "usecase/${Case}/evam/models/intel"
    if [ -d "$HOME/intel/models/intel" ]; then
        for item in "$HOME/intel/models/intel/"*; do
            base_item=$(basename "$item")
            target="usecase/${Case}/evam/models/intel/$base_item"
            if [ -e "$target" ]; then
                echo "Removing existing $target to overwrite."
                rm -rf "$target"
            fi
            mv "$item" "$target"
        done
        rm -rf "$HOME/intel/models/intel"
    else
        echo "Warning: $HOME/intel/models/intel not found. Download may have failed."
    fi

    # Download model_proc JSON files from DL Streamer GitHub for each OMZ model
    for model in "${OMZ_MODELS[@]}"; do
        MODEL_PROC_URL="https://github.com/dlstreamer/dlstreamer/blob/master/samples/gstreamer/model_proc/intel/${model}.json?raw=true"
        DEST_DIR="usecase/${Case}/evam/models/intel/${model}"
        mkdir -p "$DEST_DIR"

        echo "Downloading model proc for ${model}..."
        curl -L -o "${DEST_DIR}/${model}.json" "${MODEL_PROC_URL}" || \
            echo "Warning: Could not download model proc for ${model}"
    done
fi

##############################################################################
# 6. Remove the dlstreamer, evam folder (if it exists), deactivate the virtual env
#    and finish
##############################################################################
if [ -d "dlstreamer" ]; then
    echo "Removing dlstreamer folder..."
    rm -rf dlstreamer
fi

if [ -d "evam" ]; then
    echo "Removing evam folder..."
    rm -rf evam
fi

deactivate
echo "=== All tasks completed successfully. ==="
