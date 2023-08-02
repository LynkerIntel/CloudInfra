#!/bin/bash

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# Underline
UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White

# Reset
Color_Off='\033[0m'       # Text Reset

download_s3_objects() {
    local source="$1"
    local destination="$2"
    local aws_access_key_id="$3"
    local aws_secret_access_key="$4"
    
    read -rp "Would you like to list all of the objects in this bucket? (yes/no): " LIST_BUCKET
    
    if [ "$LIST_BUCKET" == "yes" ]; then
        if [[ $3 != '' ]]; then
            AWS_ACCESS_KEY_ID=$aws_access_key_id AWS_SECRET_ACCESS_KEY=$aws_secret_access_key aws s3 ls "$source"
        else
            aws s3 ls "$source"
        fi
    fi

    read -rp "Are you sure you want to download all of these objects? (yes/no): " DL_BUCKET

    if [ "$DL_BUCKET" == "yes" ]; then
        if [[ $3 != '' ]]; then
            AWS_ACCESS_KEY_ID=$aws_access_key_id AWS_SECRET_ACCESS_KEY=$aws_secret_access_key aws s3 cp "$source" "$destination" --recursive
        else
            aws s3 cp "$source" "$destination" --recursive
        fi

    else
        echo -e "Exiting program"
        exit 1
    fi
}

set -e

echo -e "\n"
echo "========================================================="
echo -e "${BWhite} Welcome to CIROH-UA:NextGen National Water Model App! ${Color_Off}"
echo "========================================================="
echo -e "\n"
echo -e "NextGen requires the locations of input files:\n"

echo -e "${BBlue}forcings${Color_Off} folder contains the hydrofabric input data for your model(s)."
echo -e "${BGreen}config${Color_Off} folder has all the configuration related files for the model."
echo -e "${BPurple}outputs${Color_Off} is where the output files are copied to when the model finish the run"


# Locate input files. Download if needed
declare -A choices
declare -A input_paths
declare -A directories
directories["forcings"]="forcings"
directories["config"]="config"

for directory in "${!directories[@]}"; do

    if [ "${directory}" == "forcings" ]; then
        dir_color=$BBlue
    elif [ "${directory}" == "config" ]; then
        dir_color=$BGreen
    fi

    echo -e "\nSelect storage type for ${dir_color}${directory}${Color_Off} directory:"
    PS3="Choice: "  
    select choice in "Local" "Bucket"; do
        case $choice in
            Local)
                read -rp "Enter the local path to the ${directory} directory: " LOCAL_PATH
                input_paths["${directory}"]=$LOCAL_PATH
                break
                ;;
            Bucket)
                local_files=("$(pwd)/data/${directory}/*")
                local_folder=${local_files%??}
                if [ "$(ls -A $local_folder)" ]; then
                    read -rp "It looks like downloaded bucket forcings already exist. Do you want to overwrite this folder? (yes/no): " OVERWRITE
                    if [ "$OVERWRITE" == "no" ]; then
                        echo "Exiting the program. Please move this data and restart -> ${local_folder}"
                        exit 1
                    else
                        echo "Cleaning ${local_folder}..."
                        rm -rf ${local_folder}
                        mkdir -p ${local_folder}
                    fi
                else
                    mkdir -p ${local_folder}
                fi

                read -rp "Enter the cloud bucket URI for ${directory}: " BUCKET_URI

                # In the future we can implement more cloud provider functions
                S3="s3://"
                if [[ "$BUCKET_URI" != *"$S3"* ]]; then
                    echo "NextGen currently only supports aws s3 buckets!"
                    exit 1
                fi

                read -rp "Does accessing the bucket require any additional credentials? (yes/no): " BUCKET_CREDENTIALS

                if [ "$BUCKET_CREDENTIALS" == "yes" ]; then
                
                    read -rp "Enter access key ID: " ACCESS_KEY_ID
                    read -rp "Enter secret access key: " SECRET_ACCESS_KEY

                    download_s3_objects $BUCKET_URI $local_folder $ACCESS_KEY_ID $SECRET_ACCESS_KEY
                                       
                else
                    download_s3_objects $BUCKET_URI $local_folder
                fi

                input_paths["${directory}"]=$local_folder

                ;;
            *)
                echo "Invalid choice, please select again."
                ;;
        esac
    done
done

# Assert that forcings and configs are in the same directory
forcings_parent=$(dirname ${input_paths["forcings"]} )
config_parent="$(dirname ${input_paths["config"]} )"
if [ $forcings_parent != $config_parent ]; then
    echo -e "forcings and config folders must have the same parent folder."
    exit 1
fi

HOST_DATA_PATH=$forcings_parent
echo -e "Outputs will be placed in $forcings_parent/outputs"

Forcings_Count=$(ls ${input_paths["forcings"]} | wc -l)
Config_Count=$(ls ${input_paths["config"]} | wc -l)
Outputs_Count=$(ls "${HOST_DATA_PATH}/outputs" | wc -l)

#Validate paths exist:
[ -d "$HOST_DATA_PATH/forcings" ] && echo -e "${BBlue}forcings${Color_Off} exists. $Forcings_Count forcings found." || echo -e "Error: Directory $HOST_DATA_PATH/${BBlue}forcings${Color_Off} does not exist."
[ -d "$HOST_DATA_PATH/outputs" ] && echo -e "${BPurple}outputs${Color_Off} exists. $Outputs_Count outputs found." || echo -e "Error: Directory $HOST_DATA_PATH/${BPurple}outputs${Color_Off} does not exist, but will be created if you choose to copy the outputs after the run." 
[ -d "$HOST_DATA_PATH/config" ] && echo -e "${BGreen}config${Color_Off} exists. $Config_Count configs found." || echo -e "Error: Directory $HOST_DATA_PATH/${BGreen}config${Color_Off} does not exist."

echo -e "\n"

if [ $Outputs_Count -gt 0 ]; then
    echo -e "${UYellow}Cleanup Process: This step will delete all files in the outputs folder: $HOST_DATA_PATH/outputs! Be Careful.${Color_Off}"
    PS3="Select an option (type a number): "
    options=("Delete output files and run fresh" "Continue without cleaning" "Exit")
    select option in "${options[@]}"; do
        case $option in
            "Delete output files and run fresh")
                echo "Cleaning Outputs folder for fresh run"
                echo "Starting Cleanup of Files:"
		echo "Cleaning Up $Outputs_Count Files"
                rm -f "$HOST_DATA_PATH/outputs"/*
                break
                ;;
            "Continue without cleaning")
                echo "Happy Hydro Modeling."
                break
                ;;
            "Exit")
                echo "Have a nice day!"
		exit 0
                ;;
            *)
                echo "Invalid option $REPLY. Please select again."
                ;;
        esac
    done
else
    echo -e "Outputs directory is empty and model is ready for run."
fi

# NGen config selection
echo -e "\n"
echo -e "${UPurple}NGEN CONFIG FILE OPTIONS:${Color_Off}"
HYDRO_FABRIC_CATCHMENTS=$(find $HOST_DATA_PATH -iname "*catchment*.geojson")
HYDRO_FABRIC_NEXUS=$(find $HOST_DATA_PATH -iname "*nexus*.geojson")
NGEN_REALIZATIONS=$(find $HOST_DATA_PATH -iname "*realization*.json")
echo -e "${UGreen}Found these Catchment files:${Color_Off}" && sleep 1 && echo "$HYDRO_FABRIC_CATCHMENTS"
echo -e "${UGreen}Found these Nexus files:${Color_Off}" && sleep 1 && echo "$HYDRO_FABRIC_NEXUS"
echo -e "${UGreen}Found these Realization files:${Color_Off}" && sleep 1 && echo "$NGEN_REALIZATIONS"
echo -e "\n"

generate_partition () {
  # $1 catchment json file
  # $2 nexus json file
  # $3 number of partitions
  /dmod/bin/partitionGenerator $1 $2 partitions_$3.json $3 '' ''
}

echo -e "${UPurple}NGEN RUN SELECTION:${Color_Off}"
PS3="Select an option (type a number): "
options=("Run NextGen model framework in serial mode" "Run NextGen model framework in parallel mode" "Run Bash shell" "Exit")
select option in "${options[@]}"; do
  case $option in
    "Run NextGen model framework in serial mode")
      echo -e "\n"
      read -p "Enter the hydrofabric catchment file path from above: " n1
      echo "$n1 selected"
      read -p "Enter the hydrofabric nexus file path from above: " n2
      echo "$n2 selected"
      read -p "Enter the Realization file path from above: " n3
      echo "$n3 selected"
      echo ""
      echo ""
      echo "Your NGEN run command is /dmod/bin/ngen-serial $n1 \"\" $n2 \"\" $n3"
      break
      ;;
    "Run NextGen model framework in parallel mode")
      echo -e "\n"
      read -p "Enter the hydrofabric catchment file path: " n1
      echo "$n1 selected"
      read -p "Enter the hydrofabric nexus file path: " n2
      echo "$n2 selected"
      read -p "Enter the Realization file path: " n3
      echo "$n3 selected"
      procs=$(nproc)
      procs=2 #for now, just make this 2...
      generate_partition $n1 $n2 $procs
      echo ""
      echo ""
      echo "Your NGEN run command is mpirun -n $procs /dmod/bin/ngen-parallel $n1 \"\" $n2 \"\" $n3 $(pwd)/partitions_$procs.json"
      break
      ;;
    "Run Bash shell")
      echo "Starting a shell, simply exit to stop the process."
      cd ${workdir}
      /bin/bash
      ;;
    "Exit")
      exit 0
      ;;
    *) 
      echo "Invalid option $REPLY"
      ;;
  esac
done

# Validate selected configs
catch_base=$(basename $n1)
nexus_base=$(basename $n2)
reali_base=$(basename $n3)
echo -e "${UPurple}VALIDATING CONFIGURATION FILES...:${Color_Off}"
if docker run -v ${input_paths["config"]}:/ngen/data -e CATCH_CONF="/ngen/data/$catch_base" -e NEX_CONF="/ngen/data/$nexus_base" -e REALIZATION="/ngen/data/$reali_base" -v $workdir:/ngen/ngen/data ngen_conf_val:latest ; then
echo "NGen configs are valid"
else
echo "One of the selected configs is not valid!"
exit
fi

# Generate metadata
echo -e "${UPurple}GENERATING METADATA...:${Color_Off}"
if docker run -v ${input_paths["config"]}:/ngen/data -e CATCH_CONF="/ngen/data/$catch_base" -e NEX_CONF="/ngen/data/$nexus_base" -e REALIZATION="/ngen/data/$reali_base" -v $workdir:/ngen/ngen/data ngen_inabox_metadata:latest ; then
echo "NGen configs are valid"
else
echo "One of the selected configs is not valid!"
exit
fi


#Detect Arch
AARCH=$(uname -a)
echo -e "\n"
echo -e "Detected ISA = $AARCH" 
if docker --version ; then
	echo "Docker found"
else 
	echo "Docker not found"
fi 
echo -e "\n"

PS3="Select an option (type a number): "
options=("Run NextGen Model using docker" "Exit")
select option in "${options[@]}"; do
  case $option in
   "Run NextGen Model using docker")
      echo "Pulling NextGen docker image and running the model"
      break
      ;;
    Exit)
      echo "Have a nice day!"
      exit 0
      ;;
    *) 
      echo "Invalid option $REPLY, 1 to continue and 2 to exit"
      ;;
  esac
done
echo -e "\n"

if uname -a | grep arm64 || uname -a | grep aarch64 ; then

docker pull awiciroh/ciroh-ngen-image:latest-arm
echo -e "Pulled awiciroh/ciroh-ngen-image:latest-arm image"
IMAGE_NAME=awiciroh/ciroh-ngen-image:latest-arm
else

docker pull awiciroh/ciroh-ngen-image:latest-x86
echo -e "Pulled awiciroh/ciroh-ngen-image:latest-x86 image"
IMAGE_NAME=awiciroh/ciroh-ngen-image:latest-x86
fi

echo "If your model didn't run, or encountered an error, try checking the Forcings paths in the Realizations file you selected."
echo "Your model run is beginning!"
echo ""

echo -e "\n"
echo -e "Running NextGen docker container..."
echo -e "Mounting local host directory $HOST_DATA_PATH to /ngen/ngen/data within the container."
docker run --rm -it -v $HOST_DATA_PATH:/ngen/ngen/data $IMAGE_NAME /ngen/ngen/data/

Final_Outputs_Count=$(ls $HOST_DATA_PATH/outputs | wc -l)

echo -e "$Final_Outputs_Count new outputs created."
echo -e "Any copied files can be found here: $HOST_DATA_PATH/outputs"
echo -e "Thank you for running NextGen In A Box: National Water Model! Have a nice day!"
exit 0
