# Ragu deployment on OpenShift (RHOAI 3.x)

**GitOps:** the **`ragu-webui`** workload is applied by **Argo CD** from **`ypreiger/ragu-builder`**, path **`openshift-bootstrap/app/webui/`** (see that repo’s **`docs/RHOAI_INFERENCE_URLS.md`**).

## Environment aliases (`RAGU_*`)

Before `open_webui.config` is loaded, **`backend/open_webui/ragu_env.py`** maps optional variables:

| Variable | Maps to (if set) |
|----------|------------------|
| **`RAGU_LLM_BASE_URL`** | **`OPENAI_API_BASE_URL`** |
| **`RAGU_LLM_BASE_URLS`** | **`OPENAI_API_BASE_URLS`** (semicolon-separated) |
| **`RAGU_LLM_API_KEY`** | **`OPENAI_API_KEY`** |
| **`RAGU_LLM_API_KEYS`** | **`OPENAI_API_KEYS`** |
| **`RAGU_EMBEDDING_BASE_URL`** | **`RAG_OPENAI_API_BASE_URL`** |
| **`RAGU_EMBEDDING_API_KEY`** | **`RAG_OPENAI_API_KEY`** |
| **`RAGU_PUBLIC_BASE_URL`** | **`WEBUI_URL`** |
| **`RAGU_DISABLE_OLLAMA`** `true` | **`ENABLE_OLLAMA_API`** `false` |

Upstream **`ghcr.io/open-webui/open-webui`** images do **not** ship this file; use the **stock** `OPENAI_*` / `RAG_OPENAI_*` keys in the ConfigMap, or build/push this fork and point **`kustomization.yaml` `images:`** at your image.

**`RAGU_RAG_API_BASE_URL`** is reserved for a future **`ragu-api`** HTTP surface.

## Building the fork image

```bash
docker build -t quay.io/<org>/ragu-webui:<tag> .
docker push quay.io/<org>/ragu-webui:<tag>
```

Then in **ragu-builder** `openshift-bootstrap/app/webui/kustomization.yaml`, set `images[].newName` / `newTag` to that reference.
