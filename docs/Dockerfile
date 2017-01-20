FROM nginx:1-alpine

COPY nginx/nginx.vh.default.conf /etc/nginx/conf.d/default.conf
COPY _book /usr/share/nginx/html/docs
RUN chmod 755 /usr/share/nginx/html/docs/gitbook/*
