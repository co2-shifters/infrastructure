FROM python:3.10

WORKDIR /code

COPY requirements.txt .

RUN apk add --no-cache gcc musl-dev linux-headers && \
    pip install -r requirements.txt && \
    apk del gcc musl-dev linux-headers

COPY . .

CMD [ "python", "./app.py" ]