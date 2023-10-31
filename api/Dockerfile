FROM python:3.10

WORKDIR /code

COPY requirements.txt .

RUN apt-get update && \
    apt-get install -y gcc musl-dev && \
    pip install --no-cache-dir -r requirements.txt && \
    apt-get remove -y gcc musl-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

COPY . .

CMD [ "python", "./app.py" ]