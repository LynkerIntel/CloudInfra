# DOCKER RUN COMMAND

FROM python:3.8-alpine as foundation

RUN apk update && apk upgrade && apk add --no-cache git

# Set up container
FROM foundation as basis

# CLONE GIT REPO TO CREATE METADATA
RUN git clone --depth 1 -b realization_validation https://github.com/JordanLaserGit/ngen-cal.git \
    && cd ./ngen-cal/python/ngen_conf \
    && pip install --upgrade pip \
    && pip install -e .

ENV CATCH_SUB=""
ENV NEX_SUB=""

# Validate config files
CMD ["python", "ngen-cal/python/conf_metadata.py"] 