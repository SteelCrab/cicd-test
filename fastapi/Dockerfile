FROM python:3.14-alpine

WORKDIR /app

# 의존성 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


COPY . .

# 포트8000
EXPOSE 8000

# uvicorn으로 실행
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
