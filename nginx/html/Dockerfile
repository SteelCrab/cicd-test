FROM nginx:alpine

# 설정 파일
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

WORKDIR /usr/share/nginx/html

# 기존 파일 삭제 및 html 폴더 내용 복사
RUN rm -rf ./*
COPY --chown=nginx:nginx . .

# 환경 변수 설정
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
