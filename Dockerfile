# `python-base` sets up all our shared environment variables
FROM python:3.13.1-slim AS python-base

    # python
ENV PYTHONUNBUFFERED=1 \
    # prevents python creating .pyc files
    PYTHONDONTWRITEBYTECODE=1 \
    \
    # pip
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    \
    # poetry
    # https://python-poetry.org/docs/configuration/#using-environment-variables
    POETRY_VERSION=2.1.4 \
    # make poetry install to this location
    POETRY_HOME="/opt/poetry" \
    # make poetry create the virtual environment in the project's root
    # it gets named `.venv`
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    # do not ask any interactive question
    POETRY_NO_INTERACTION=1 \
    \
    # paths
    # this is where our requirements + virtual environment will live
    PYSETUP_PATH="/opt/pysetup" \
    VENV_PATH="/opt/pysetup/.venv"


# prepend poetry and venv to path
ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"

# Instala dependências do sistema
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        # deps for installing poetry
        curl \
        # deps for building python deps
        build-essential \
        # dependências para compilar psycopg2
        libpq-dev \
        gcc \
        # --- NOVO: Adiciona o utilitário dos2unix ---
        dos2unix

# install poetry - respects $POETRY_VERSION & $POETRY_HOME
RUN curl -sSL https://install.python-poetry.org | python3 -

# NOTA: Removi a linha 'pip install psycopg2'.
# O Poetry deve cuidar disso através do seu `pyproject.toml`.
# As dependências de build (libpq-dev, gcc) já estão instaladas.

# copy project requirement files here to ensure they will be cached.
WORKDIR $PYSETUP_PATH
COPY poetry.lock pyproject.toml ./

# quicker install as runtime deps are already installed
RUN poetry install --no-root

# Mudar para o diretório da aplicação
WORKDIR /app

# --- NOVO: Adicionar o script de entrypoint ---
# Copia o script para a imagem
COPY ./entrypoint.sh /app/entrypoint.sh

# --- NOVO: Corrige line endings usando dos2unix ---
# Esta é uma forma mais robusta de garantir que o script
# tenha o formato de final de linha do Unix (LF).
RUN dos2unix /app/entrypoint.sh

# Torna o script executável
RUN chmod +x /app/entrypoint.sh
# ----------------------------------------------

# Copia o restante do código da aplicação
COPY . /app/

EXPOSE 8000

# --- NOVO: Define o entrypoint ---
# Este script rodará as migrações e DEPOIS o CMD
ENTRYPOINT ["/app/entrypoint.sh"]

# O comando padrão para rodar (será passado para o entrypoint.sh)
# ATENÇÃO: 'runserver' é apenas para desenvolvimento.
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]

# --- RECOMENDADO PARA PRODUÇÃO ---
# 1. Adicione `gunicorn` ao seu `pyproject.toml` com `poetry add gunicorn`
# 2. Comente o CMD acima e descomente o abaixo.
# 3. Substitua 'seu_projeto_wsgi' pelo nome da pasta do seu projeto (que contém o wsgi.py)
# CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "seu_projeto_wsgi.wsgi:application"]