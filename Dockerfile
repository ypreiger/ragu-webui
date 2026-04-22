# syntax=docker/dockerfile:1
#
# Default container build for ragu-webui — Red Hat Universal Base Image 9 (RHEL-aligned).
#   podman build -t ragu-webui:latest .
#
# CUDA / bundled Ollama / legacy Debian multi-stage build: use Dockerfile.upstream (see .github/workflows/docker-build.yaml).
# Base images: registry.access.redhat.com (UBI; no subscription required for these content sets).

ARG USE_CUDA=false
ARG USE_OLLAMA=false
ARG USE_SLIM=true
ARG USE_CUDA_VER=cu128
ARG USE_EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
ARG USE_RERANKING_MODEL=""
ARG USE_AUXILIARY_EMBEDDING_MODEL=TaylorAI/bge-micro-v2
ARG BUILD_HASH=dev-build
ARG UID=1001
ARG GID=0

######## Frontend ########
FROM registry.access.redhat.com/ubi9/nodejs-20:latest AS build
ARG BUILD_HASH
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ENV APP_BUILD_HASH=${BUILD_HASH}
RUN npm run build

######## Runtime ########
FROM registry.access.redhat.com/ubi9/python-311:latest AS runtime
ARG USE_CUDA USE_OLLAMA USE_SLIM USE_CUDA_VER
ARG USE_EMBEDDING_MODEL USE_RERANKING_MODEL USE_AUXILIARY_EMBEDDING_MODEL
ARG UID GID
ARG BUILD_HASH

# UBI python image may default to a non-root user; root is required only for dnf/pip layers below.
# The container process must not run as UID 0: final USER is set after installs (OpenShift restricted-v2).
USER root

ENV PYTHONUNBUFFERED=1 \
    PORT=8080 \
    ENV=prod \
    USE_OLLAMA_DOCKER=${USE_OLLAMA} \
    USE_CUDA_DOCKER=${USE_CUDA} \
    USE_SLIM_DOCKER=${USE_SLIM} \
    USE_CUDA_DOCKER_VER=${USE_CUDA_VER} \
    USE_EMBEDDING_MODEL_DOCKER=${USE_EMBEDDING_MODEL} \
    USE_RERANKING_MODEL_DOCKER=${USE_RERANKING_MODEL} \
    USE_AUXILIARY_EMBEDDING_MODEL_DOCKER=${USE_AUXILIARY_EMBEDDING_MODEL} \
    OLLAMA_BASE_URL="/ollama" \
    OPENAI_API_BASE_URL="" \
    OPENAI_API_KEY="" \
    WEBUI_SECRET_KEY="" \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false \
    WHISPER_MODEL="base" \
    WHISPER_MODEL_DIR="/app/backend/data/cache/whisper/models" \
    RAG_EMBEDDING_MODEL="${USE_EMBEDDING_MODEL}" \
    RAG_RERANKING_MODEL="${USE_RERANKING_MODEL}" \
    AUXILIARY_EMBEDDING_MODEL="${USE_AUXILIARY_EMBEDDING_MODEL}" \
    SENTENCE_TRANSFORMERS_HOME="/app/backend/data/cache/embedding/models" \
    TIKTOKEN_ENCODING_NAME="cl100k_base" \
    TIKTOKEN_CACHE_DIR="/app/backend/data/cache/tiktoken" \
    HF_HOME="/app/backend/data/cache/embedding/models" \
    HOME=/app

RUN dnf install -y --nodocs \
      gcc gcc-c++ git make curl \
      openssl-devel libffi-devel \
      python3-devel \
      redhat-rpm-config \
      patch \
      zlib-devel \
      && dnf clean all

WORKDIR /app/backend

COPY --from=build /app/build /app/build
COPY --from=build /app/CHANGELOG.md /app/CHANGELOG.md
COPY --from=build /app/package.json /app/package.json
COPY ./backend/requirements.txt ./requirements.txt

RUN pip3 install --no-cache-dir uv \
 && if [ "$USE_CUDA" = "true" ]; then echo "USE_CUDA=true is not supported in the UBI Dockerfile; use Dockerfile.upstream (Debian/CUDA)." >&2; exit 1; fi \
 && pip3 install 'torch<=2.9.1' torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu --no-cache-dir \
 && uv pip install --system -r requirements.txt --no-cache-dir \
 && if [ "$USE_SLIM" != "true" ]; then \
      python -c "import os; from sentence_transformers import SentenceTransformer; SentenceTransformer(os.environ['RAG_EMBEDDING_MODEL'], device='cpu')"; \
      python -c "import os; from sentence_transformers import SentenceTransformer; SentenceTransformer(os.environ.get('AUXILIARY_EMBEDDING_MODEL', 'TaylorAI/bge-micro-v2'), device='cpu')"; \
      python -c "import os; from faster_whisper import WhisperModel; WhisperModel(os.environ['WHISPER_MODEL'], device='cpu', compute_type='int8', download_root=os.environ['WHISPER_MODEL_DIR'])"; \
      python -c "import os; import tiktoken; tiktoken.get_encoding(os.environ['TIKTOKEN_ENCODING_NAME'])"; \
      python -c "import nltk; nltk.download('punkt_tab')"; \
    fi \
 && mkdir -p /app/backend/data \
 && chown -R "${UID}:0" /app /app/backend/data \
 && chmod -R g=u /app /app/backend/data \
 && find /app -type d -exec chmod g+s {} + 2>/dev/null || true

COPY --chown=${UID}:0 ./backend .

EXPOSE 8080

# Runtime user (not root). OpenShift may run the container with another UID from the namespace range;
# /app is chown'd to ${UID}:0 with chmod g=u so the effective group retains read/execute on image layers.
USER ${UID}

ARG BUILD_HASH
ENV WEBUI_BUILD_VERSION=${BUILD_HASH} DOCKER=true

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${PORT:-8080}/health" >/dev/null || exit 1

CMD [ "bash", "start.sh" ]
