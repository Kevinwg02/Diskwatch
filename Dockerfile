FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV TERM=xterm-256color

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    util-linux \
    procps \
    coreutils \
    curl \
    nano \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt /tmp/requirements.txt
RUN pip3 install --break-system-packages -r /tmp/requirements.txt

WORKDIR /app
COPY app/ .

CMD ["/bin/bash"]
