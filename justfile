set shell := ["bash", "-uc"]

dev-image := "ttyd-dev"
dev-container-name := "ttyd-dev"
volume-name := dev-container-name + "-home"

build: start-container
    if [[ $(hostname) == {{ dev-container-name }} ]]; then \
        bash build.sh build_ttyd ; \
    else \
        docker exec -ti {{ dev-container-name }} bash build.sh build_ttyd ; \
    fi

attach: start-container
    docker exec -ti {{ dev-container-name }} bash

start-container:
    if [[ -z $(docker ps -q -f name={{ dev-container-name }}) ]] && [[ $(hostname) != {{ dev-container-name }} ]]; then \
        cm script docker ensure_volume {{ volume-name }} ; \
        docker run -d --rm --init -v {{ justfile_directory() }}:{{ justfile_directory() }} \
            -w {{ justfile_directory() }} \
            -v {{ volume-name }}:/root/ --network=host --entrypoint tail \
            --name {{ dev-container-name }} \
            --hostname {{ dev-container-name }} \
            {{ dev-image }} -f /dev/null ; \
    fi

stop-container:
    docker stop {{ dev-container-name }}

build-image:
    docker build . --platform linux/amd64 -f Dockerfile.build -t {{ dev-image }}
