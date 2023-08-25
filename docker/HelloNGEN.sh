#!/bin/bash
workdir="${1:-/ngen}"
cd ${workdir}
set -e
echo "Working directory is :" 
pwd
echo -e "\n"

case $option in 
  "Run NextGen model framework in serial mode")
    /dmod/bin/ngen-serial $n1 all $n2 all $n3 
  ;;
  "Run NextGen model framework in parallel mode")
    mpirun -n $procs /dmod/bin/ngen-parallel $n1 all $n2 all $n3 $(pwd)/partitions_$procs.json
  ;;
esac

echo "Would you like to continue?"
PS3="Select an option (type a number): "
options=("Interactive-Shell" "Copy output data from container to local machine" "Exit")
select option in "${options[@]}"; do
  case $option in
    "Interactive-Shell")
      echo "Starting a shell, simply exit to stop the process."
      cd ${workdir}
      /bin/bash
      break
      ;;
    "Copy output data from container to local machine")
      [ -d /ngen/ngen/data/outputs ] || mkdir /ngen/ngen/data/outputs
      # Loop through all of the .csv files in the /ngen/ngen/data directory
      for i in /ngen/ngen/data/*.csv; do
        # Check if the file exists
        if [[ -f $i ]]; then
          # Move the file to the /ngen/ngen/data/outputs directory
          mv "$i" /ngen/ngen/data/outputs
        fi
      done
      # Loop through all of the .parquet files in the /ngen/ngen/data directory
      for i in /ngen/ngen/data/*.parquet; do
        # Check if the file exists
        if [[ -f $i ]]; then
          # Move the file to the /ngen/ngen/data/outputs directory
          mv "$i" /ngen/ngen/data/outputs
        fi
      done
      # Loop through all of the .json files in the /ngen/ngen/data directory
      for i in /ngen/ngen/data/*.json; do
        # Check if the file exists
        if [[ -f $i ]]; then
          # Move the file to the /ngen/ngen/data/outputs directory
          mv "$i" /ngen/ngen/data/outputs
        fi
      done
      break
      ;;
    "Exit")
      echo "Have a nice day."
      break
      ;;
    *) 
      echo "Invalid option $REPLY"
      ;;
  esac
done
exit
