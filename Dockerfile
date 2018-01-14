# Dockerfile, watson-intu/Self build for Jetson TX2 (aarch64), using debian:jessie
# Usage: 
#   docker build -f Dockerfile -t openhorizon/cogwerx-$ARCH-self:<version> .    # (standard full size container)
#   docker build --squash -f Dockerfile -t openhorizon/cogwerx-$ARCH-self:<version> --build-arg mode="dev" .  # (slim container)

FROM debian:jessie
MAINTAINER dyec@us.ibm.com

ENV ARCH=x86_64

# Build arg "mode": (blank=standard full size container, "dev": to be used with experimental "docker --squash", for min container size)
ARG mode

# Required for web UI
EXPOSE 9443

RUN apt-get update && apt-get install -y apt-utils
RUN apt-get install -y \
  alsa-utils \
  build-essential \
  cmake \
  curl \
  git \
  libpng12-dev \
  usbutils \
  gettext \
  unzip \
  wget

## Grab self code
RUN mkdir -p /root/src/chrod
RUN git clone --branch edge --recursive https://github.com/chrod/self.git /root/src/chrod/self

# Install pip, python-dev libssl-dev, opencv-dev, py-opencv, LXDE & deps
RUN apt-get install -y libssl-dev \
  python-pip \
  python2.7-dev \
  libopencv-dev \
  python-opencv \
  libboost-all-dev

# Pip install python deps (qibuild, numpy)
RUN pip install --upgrade pip
RUN pip install qibuild numpy

# Build Self (default config)
WORKDIR /root/src/chrod/self
COPY tc_install.sh /root/src/chrod/self/scripts/tc_install.sh
RUN mkdir -p /root/src/chrod/self/packages
RUN ./scripts/build_linux.sh

## Self Setup
## Edit ALSA config (set sound card to #2: USB card, after webcam (#1))
COPY alsa.conf /usr/share/alsa/alsa.conf

## Clean up all files but essential Self binaries
RUN /bin/bash -c "if [ 'x$mode' != 'dev' ] ; then pip uninstall -y qibuild && apt -y purge python-pip usbutils gettext unzip cmake build-essential; fi"
RUN /bin/bash -c "if [ 'x$mode' != 'dev' ] ; then ls /root/src/chrod/self | grep -v bin | xargs rm -rf; fi"
RUN /bin/bash -c "if [ 'x$mode' != 'dev' ] ; then apt-get -y autoremove; fi"


##############
## Configure and run Self with your own creds:
# cd <self config dir>
# copy in bootstrap.json file
# Run self:
# docker run -it --rm --privileged -p 9443:9443 -v $PWD:/configs openhorizon/cogwerx-$ARCH-self:<version> /bin/bash -c "ln -s -f /configs/bootstrap.json bin/linux/etc/shared/; ln -s -f /configs/alsa.conf /usr/share/alsa/; bin/linux/run_self.sh"
