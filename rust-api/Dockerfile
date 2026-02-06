# Stage 1: 의존성 캐시 레이어
FROM rust:alpine AS deps
RUN apk add --no-cache musl-dev
WORKDIR /app
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Stage 2: 소스 빌드
FROM deps AS builder
COPY src ./src
RUN touch src/main.rs && cargo build --release

# Stage 3: 경량 런타임
FROM alpine
RUN apk add --no-cache ca-certificates && \
    adduser -D -u 1000 appuser
COPY --from=builder /app/target/release/rust-api /usr/local/bin/rust-api
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1
CMD ["rust-api"]
