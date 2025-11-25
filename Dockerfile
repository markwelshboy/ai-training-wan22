FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8

# ---- OS + Python 3.12 + basic tools ----
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
        openssh-server && \
    mkdir -p /run/sshd && \
    git lfs install --system && \
    ln -sf /usr/bin/python3.12 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    python3.12 -m venv /opt/venv && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:$PATH"

# ---- Core Python tooling + torch (cu128 nightly) ----
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --pre torch torchvision \
        --index-url https://download.pytorch.org/whl/nightly/cu128

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install packaging setuptools wheel "huggingface_hub==0.36.0"

# ---- Runtime libs + jupyter + onyxruntime-gpu + matplotlib + tensorboard + wandb ----
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
        jupyterlab jupyterlab-lsp \
        jupyter-server jupyter-server-terminals \
        ipykernel jupyterlab_code_formatter \
        onnxruntime-gpu matplotlib pynvml tensorboard wandb

# -------------------------------------------------------------------
# ---- Musubi Tuner WAN 2.2 GUI install ----
# -------------------------------------------------------------------
WORKDIR /opt

RUN git clone https://gitHub.com/PGCRT/musubi-tuner_Wan2.2_GUI.git

WORKDIR /opt/musubi-tuner_Wan2.2_GUI

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -e .

# -------------------------------------------------------------------
# ---- Install AI-toolkit ----
# -------------------------------------------------------------------
WORKDIR /opt

RUN git clone https://github.com/ostris/ai-toolkit.git

WORKDIR /opt/ai-toolkit

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# -------------------------------------------------------------------
# ---- Install Diffusion Pipe (Uses Miniconda - deactivate venv) ----
# -------------------------------------------------------------------
#-- Download and Install Miniconda (into /opt/conda)
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    /bin/bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh

#-- Configure environment
ENV PATH="/opt/conda/bin:$PATH"

#-- Initialize Conda (will also happen in start.sh)
RUN conda init bash && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

#-- Clean up (remove unnecessary files to reduce the image size.)
RUN conda clean --all --yes

WORKDIR /opt

#-- Clone the repo
RUN git clone --recurse-submodules https://github.com/tdrussell/diffusion-pipe

#-- Create the environment (after accepting TOS)
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

RUN conda create -n diffusion-pipe python=3.12 && \
    . /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    conda activate diffusion-pipe

#-- Install torch (not part of requirements)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install torch torchvision

WORKDIR /opt/diffusion-pipe

#-- Install diffusion-pipe
RUN pip install -r requirements.txt

# ============================
# Final runtime image
# ============================
FROM base AS final

ENV PATH="/opt/venv/bin:$PATH"
ENV PATH="/opt/conda/bin:$PATH"

# Make sure /workspace exists (Vast will usually mount over it)
RUN mkdir -p /workspace

# Thin startup wrapper – this is where you’ll hook your big shell later
COPY src/start_script.sh /start_script.sh
RUN chmod +x /start_script.sh

CMD ["/start_script.sh"]
