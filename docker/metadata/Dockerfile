# docker run -e CATCH_CONF="/ngen/ngen/data/$n1" -e NEX_CONF="/ngen/ngen/data/$n2" -e REALIZATION="/ngen/ngen/data/$n3" -v $workdir:/ngen/ngen/data ngen_conf_val

FROM python:3.8-alpine as foundation

RUN apk update && apk upgrade && apk add --no-cache git

# Set up container
FROM foundation as basis
RUN git clone --depth 1 -b metadata https://github.com/JordanLaserGit/ngen-cal.git \
    && cd ./ngen-cal/python/ngen_conf \
    && pip install --upgrade pip \
    && pip install -e .

ENV CATCH_SUB=""
ENV NEX_SUB=""

# Validate config files
CMD ["python", "./ngen-cal/python/conf_metadata.py"] 