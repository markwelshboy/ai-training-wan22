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
        curl ffmpeg ninja-build git aria2 git-lfs wget vim nano less \
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

# ---- Musubi Tuner WAN 2.2 GUI install ----
WORKDIR /opt

RUN git clone https://gitHub.com/PGCRT/musubi-tuner_Wan2.2_GUI.git

WORKDIR /opt/musubi-tuner_Wan2.2_GUI

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -e .

# ============================
# Final runtime image
# ============================
FROM base AS final

ENV PATH="/opt/venv/bin:$PATH"

# Make sure /workspace exists (Vast will usually mount over it)
RUN mkdir -p /workspace

# Thin startup wrapper – this is where you’ll hook your big shell later
COPY src/start_script.sh /start_script.sh
RUN chmod +x /start_script.sh

CMD ["/start_script.sh"]
