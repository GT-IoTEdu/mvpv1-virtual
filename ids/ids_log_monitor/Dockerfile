FROM python:3.12-slim
WORKDIR /ids/ids_log_monitor
RUN pip install --no-cache-dir 'fastapi>=0.115' 'uvicorn[standard]>=0.30'
COPY sse_server.py monitor.py ./
EXPOSE 8001
CMD ["uvicorn", "sse_server:app", "--host", "0.0.0.0", "--port", "8001"]
