# Create docker validation image
docker build --no-cache -t ngen_validation ./docker/validation/

# Create docker metadata image 
docker build -t ngen_metadata ./docker/metadata/