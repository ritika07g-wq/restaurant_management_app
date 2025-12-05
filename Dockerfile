# --- Stage 1: Build Flutter web app ---
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . /app/

RUN flutter pub get
RUN flutter build web --release

# --- Stage 2: Serve web app using Nginx ---
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
