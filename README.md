# qdos-devel docker image

As setting up old versions of gcc gets harder as the future goes on here
is a Dockerfile that sets up qdos-gcc in a i386 debian buster (10.10)
container.

It also sets up xtc68 as well from the latest source from github.

Also included is make/qlzip/unzip/vim so actual development can
be carried out in the container.

## Building

on an i386 machine if you have an older version of docker

    docker build . -t qdos-devel:latest

If you have a docker that support buildx multi platform, you can build
multiple platforms at once as a cross compile.

    docker buildx build --tag <user>/<label>:<version> --platform linux/amd64,linux/386,linux/arm/v7 --push .

Obviously you can fill in your own details above, or remove the --push if you
don't want to push to docker hub.

## Using

For example using the docker image to build the wander game for qdos

    git clone https://github.com/SinclairQL/wander
    cd wander
    git checkout qdos-port
    cd ..
    docker run -v `pwd`/wander:qdos/wander -it qdos-devel:latest bash

You should now be in the container in the directory /qdos/

    cd wander
    make CC=qdos-gcc
    make deploy

This should make a Wander.zip which can be used in an emulator.

