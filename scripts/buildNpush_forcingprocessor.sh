# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--aws-acct-id)
      AWS_ACCT_ID="$2"
      shift 2
      ;;
    -i|--image-name)
      IMAGE_NAME="$2"
      shift 2
      ;;
    -r|--repo-name)
      REPO_NAME="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --update_image)
      UPDATE_IMAGE="$2"
      shift 2
      ;;
    --build_image)
      BUILD_IMAGE="$2"
      shift 2      
      ;;      
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

echo "AWS_ACCT_ID: $AWS_ACCT_ID"
echo "IMAGE_NAME: $IMAGE_NAME"
echo "REPO_NAME: $REPO_NAME"
echo "REGION: $REGION"
echo "BUILD_IMAGE: $BUILD_IMAGE"
echo "UPDATE_IMAGE: $UPDATE_IMAGE"

# build docker image
if [[ ${BUILD_IMAGE} == "TRUE" ]]; then
  echo "Building docker image ${REPO_NAME}"
  docker build --no-cache -t ${IMAGE_NAME} ./docker/forcingprocessor/
else
  echo "Not building the image!"
fi

# Validate aws credentials
echo "Validating credentials"
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin "${AWS_ACCT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Tag the image
echo "Tagging docker image as ${IMAGE_NAME}"
docker tag ${IMAGE_NAME} "${AWS_ACCT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_NAME}"

# Push the image
echo "Pushing ${IMAGE_NAME} to ${AWS_ACCT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"
docker push "${AWS_ACCT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_NAME}"

# Update the function code
if [[ ${UPDATE_IMAGE} == "TRUE" ]] || [[ ${BUILD_IMAGE} == "TRUE" ]]; then
  echo "Updating function code"
  aws lambda update-function-code \
      --function-name  forcingprocessor \
      --image-uri "${AWS_ACCT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${IMAGE_NAME}" \
      --region ${REGION}
  exit 1
else
  exit 1
fi
