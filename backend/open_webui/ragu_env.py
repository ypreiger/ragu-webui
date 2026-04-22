"""
Optional RAGU_* environment aliases for OpenShift / Red Hat OpenShift AI (KServe)
OpenAI-compatible inference (MaaS) and related endpoints.

Applied in main.py before open_webui.config is imported so os.environ is visible
to PersistentConfig defaults.
"""

from __future__ import annotations

import os


def apply_ragu_env_aliases() -> None:
    """Map RAGU_* variables to Open WebUI / OpenAI-compatible env names (setdefault only)."""

    disable_ollama = os.environ.get('RAGU_DISABLE_OLLAMA', '').lower() in ('1', 'true', 'yes')
    if disable_ollama:
        os.environ.setdefault('ENABLE_OLLAMA_API', 'false')

    public = os.environ.get('RAGU_PUBLIC_BASE_URL', '').strip()
    if public:
        os.environ.setdefault('WEBUI_URL', public.rstrip('/'))

    multi = os.environ.get('RAGU_LLM_BASE_URLS', '').strip()
    if multi:
        os.environ.setdefault('OPENAI_API_BASE_URLS', multi)
    else:
        llm = os.environ.get('RAGU_LLM_BASE_URL', '').strip()
        if llm:
            url = llm.rstrip('/')
            os.environ.setdefault('OPENAI_API_BASE_URL', url)

    llm_keys = os.environ.get('RAGU_LLM_API_KEYS', '').strip()
    if llm_keys:
        os.environ.setdefault('OPENAI_API_KEYS', llm_keys)
    else:
        llm_key = os.environ.get('RAGU_LLM_API_KEY', '').strip()
        if llm_key:
            os.environ.setdefault('OPENAI_API_KEY', llm_key)

    emb = os.environ.get('RAGU_EMBEDDING_BASE_URL', '').strip()
    if emb:
        os.environ.setdefault('RAG_OPENAI_API_BASE_URL', emb.rstrip('/'))

    emb_key = os.environ.get('RAGU_EMBEDDING_API_KEY', '').strip()
    if emb_key:
        os.environ.setdefault('RAG_OPENAI_API_KEY', emb_key)

    # Reserved for future ragu-api retrieval / ingest HTTP (not consumed by stock Open WebUI yet).
    _ = os.environ.get('RAGU_RAG_API_BASE_URL', '').strip()
