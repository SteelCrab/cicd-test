FROM nginx:alpine

# 설정 파일 복사
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

WORKDIR /usr/share/nginx/html

# 기존 기본 파일 삭제
RUN rm -rf ./*

# 정적 리소스 복사 (html 폴더의 모든 내용을 루트로)
COPY --chown=nginx:nginx html/ .
COPY --chown=nginx:nginx images/ ./images/

# 환경 변수 설정
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
