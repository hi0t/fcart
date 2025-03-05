FROM ubuntu:22.04

ENV PATH="$PATH:/diamond/bin/lin64"
ENV PIP_ROOT_USER_ACTION=ignore

ARG USER_ID=1000
ARG GROUP_ID=1000
RUN groupadd -g $GROUP_ID user
RUN useradd -u $USER_ID -g $GROUP_ID user

RUN DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && \
    apt-get install -y wget unzip libx11-6 libx11-xcb1 libfontconfig1 \
    libglibd-2.0-0 libsm6 libxrender1 libxext6 libgl1 libgstreamer-plugins-base1.0-0 \
    libsqlite3-0 libxcomposite1 libgraphite2-3 lsb-release \
    python3-pip

WORKDIR /dist

RUN wget --progress=bar:force:noscroll https://files.latticesemi.com/Diamond/3.14/3.14.0.75.2_Diamond_lin.zip 2>&1 && \
    unzip 3.14.0.75.2_Diamond_lin.zip
RUN ./3.14.0.75.2_Diamond_lin.run --console --prefix /diamond
RUN rm 3.14.0.75.2_Diamond_lin.zip 3.14.0.75.2_Diamond_lin.run

RUN pip install cocotb
