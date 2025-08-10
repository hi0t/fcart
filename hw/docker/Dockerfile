FROM ubuntu:22.04

ENV PATH="$PATH:/diamond/bin/lin64:/diamond/questasim/bin"
ENV LM_LICENSE_FILE=/diamond/license/license.dat

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates sudo wget unzip nano \
    libx11-6 libx11-xcb1 libfontconfig1 libglib2.0-0 libsm6 libxrender1 \
    libxext6 libxft2 libgl1 libgstreamer-plugins-base1.0-0 libsqlite3-0 \
    libxcomposite1 libgraphite2-3 \
    && rm -rf /var/lib/apt/lists/*

ARG USER_NAME
RUN groupadd $USER_NAME && \
    useradd -s /bin/bash --gid $USER_NAME -m $USER_NAME && \
    echo $USER_NAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USER_NAME && \
    chmod 0440 /etc/sudoers.d/$USER_NAME

RUN ln -s /proc/mounts /etc/mtab
RUN mkdir /dist && cd /dist && \
    wget --progress=bar:force:noscroll https://files.latticesemi.com/Diamond/3.14/3.14.0.75.2_Diamond_lin.zip && \
    unzip 3.14.0.75.2_Diamond_lin.zip && \
    ./3.14.0.75.2_Diamond_lin.run --console --prefix /diamond && \
    cd / && rm -rf /dist
