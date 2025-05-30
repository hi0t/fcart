FROM ubuntu:22.04

ENV PATH="$PATH:/diamond/bin/lin64:/diamond/questasim/bin:/arm-gnu-toolchain/bin"
ENV PIP_ROOT_USER_ACTION=ignore
ENV LM_LICENSE_FILE=/diamond/license/license.dat

RUN DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && \
    apt-get install -y git autoconf ninja-build python3-pip pkg-config wget unzip \
    libx11-6 libx11-xcb1 libfontconfig1 libglibd-2.0-0 libsm6 libxrender1 \
    libxext6 libgl1 libgstreamer-plugins-base1.0-0 libsqlite3-0 \
    libxcomposite1 libgraphite2-3 lsb-release libxft2

RUN pip install meson

COPY --from=verilator/verilator:v5.036 /usr/local/bin/ /usr/local/bin/
COPY --from=verilator/verilator:v5.036 /usr/local/share/ /usr/local/share/

WORKDIR /dist

RUN wget https://files.latticesemi.com/Diamond/3.14/3.14.0.75.2_Diamond_lin.zip && \
    unzip 3.14.0.75.2_Diamond_lin.zip
RUN ./3.14.0.75.2_Diamond_lin.run --console --prefix /diamond

RUN git clone https://github.com/universal-ctags/ctags.git && \
    cd ctags && \
    git checkout v6.2.0 && \
    ./autogen.sh && \
    ./configure && \
    make -j$(nproc) && \
    make install

RUN wget -O - https://github.com/chipsalliance/verible/releases/download/v0.0-4007-g98bdb38a/verible-v0.0-4007-g98bdb38a-linux-static-x86_64.tar.gz | \
    tar -xz -C /usr/local/bin --strip-components=2 --wildcards --no-anchored 'verible-verilog-format'

RUN mkdir /arm-gnu-toolchain && \
    wget -O - https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi.tar.xz | \
    tar -xJ -C /arm-gnu-toolchain --strip-components=1

RUN cd ~ && rm -rf /dist
