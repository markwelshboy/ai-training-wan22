FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    VENV_DIR=/opt/venv \
    CONDA_DIR=/opt/conda \
    CONDA_ENV_NAME=diffusion-pipe

# ---- OS + Python + basic tools ----
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.12 python3.12-venv python3.12-dev \
        python3-pip \
        libgl1 libglib2.0-0 build-essential \
        gcc g++ cmake \
        curl ffmpeg ninja-build git aria2 git-lfs wget vim \
        jq ca-certificates gzip bzip2 unzip tmux gawk coreutils \
        net-tools rsync ncurses-base bash-completion \
        less nano \
        openssh-server \
        nodejs npm \
    && mkdir -p /run/sshd \
    && git lfs install --system \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && python3.12 -m venv "${VENV_DIR}" \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH="${VENV_DIR}/bin:${PATH}"

# ---- Core Python tooling for venv (shared by MUSUBI / MUSUBI_GUI / TOOLKIT) ----
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
      "torch==2.7.1" "torchvision==0.22.1" "torchaudio==2.7.1" \
        --index-url https://download.pytorch.org/whl/cu128 && \
    pip install \
      packaging setuptools wheel \
      "huggingface_hub[cli]" \
      jupyterlab jupyterlab-lsp \
      jupyter-server jupyter-server-terminals \
      ipykernel jupyterlab_code_formatter \
      matplotlib pynvml tensorboard wandb \
      ascii-magic prompt-toolkit

# -------------------------------------------------------------------
# MUSUBI WAN 2.2 GUI (venv)
# -------------------------------------------------------------------
WORKDIR /opt
RUN git clone https://github.com/PGCRT/musubi-tuner_Wan2.2_GUI.git

WORKDIR /opt/musubi-tuner_Wan2.2_GUI
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -e .

# -------------------------------------------------------------------
# Generic MUSUBI trainer (venv, kohya-ss/musubi-tuner)
# -------------------------------------------------------------------
WORKDIR /opt
RUN git clone https://github.com/kohya-ss/musubi-tuner.git

WORKDIR /opt/musubi-tuner
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -e .

# Optional extras for MUSUBI (already mostly covered above, but explicit)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install ascii-magic matplotlib tensorboard prompt-toolkit

# -------------------------------------------------------------------
# AI-Toolkit (venv)
# -------------------------------------------------------------------
WORKDIR /opt
RUN git clone https://github.com/ostris/ai-toolkit.git

WORKDIR /opt/ai-toolkit
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Pre-install UI npm deps (build happens at runtime via npm script)
WORKDIR /opt/ai-toolkit/ui
RUN npm install

# -------------------------------------------------------------------
# Diffusion Pipe (Conda env)
# -------------------------------------------------------------------
WORKDIR /opt

# Miniconda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    /bin/bash /tmp/miniconda.sh -b -p "${CONDA_DIR}" && \
    rm /tmp/miniconda.sh

ENV PATH="${VENV_DIR}/bin:${CONDA_DIR}/bin:${PATH}"

# TOS (best-effort)
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

# Create diffusion-pipe env
RUN conda create -y -n "${CONDA_ENV_NAME}" python=3.12

# Clone diffusion-pipe repo with submodules (code baked into image)
RUN git clone --recurse-submodules https://github.com/tdrussell/diffusion-pipe /opt/diffusion-pipe

WORKDIR /opt/diffusion-pipe

# Install torch inside conda env
RUN --mount=type=cache,target=/root/.cache/pip \
    conda run -n "${CONDA_ENV_NAME}" bash -lc \
      'pip install torch torchvision --index-url https://download.pytorch.org/whl/cu128'

# requirements.txt but skip flash-attn (we'll live without it)
RUN sed '/^[Ff]lash[-_]attn/d' requirements.txt > requirements_no_flash.txt

RUN --mount=type=cache,target=/root/.cache/pip \
    conda run -n "${CONDA_ENV_NAME}" bash -lc \
      'pip install -r requirements_no_flash.txt'

RUN conda clean --all --yes

# ============================
# Final image
# ============================
FROM base AS final

ENV VENV_DIR=/opt/venv \
    CONDA_DIR=/opt/conda \
    CONDA_ENV_NAME=diffusion-pipe \
    PATH="/opt/venv/bin:/opt/conda/bin:${PATH}"

RUN mkdir -p /workspace

# Bring in start_script.sh from this repo
WORKDIR /opt/ai-training-wan22
COPY src/start_script.sh /start_script.sh
RUN chmod +x /start_script.sh

CMD ["/start_script.sh"]
