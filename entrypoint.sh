#!/bin/sh

echo "--- entrypoint.sh starting ---"
set -e
echo "Running database migrations..."
python manage.py migrate

echo "Starting server..."
exec "$@"