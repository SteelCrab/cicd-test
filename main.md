# FastAPI Hello World

간단한 FastAPI 애플리케이션

## 설치

```bash
pip install -r requirements.txt
```

## 실행

```bash
python main.py
```

또는 uvicorn 직접 실행:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

## 엔드포인트

- `GET /` - "Hello World" 메시지 반환

## 테스트

```bash
curl http://localhost:8000/
```

응답:
```json
{"message": "Hello World"}
```
