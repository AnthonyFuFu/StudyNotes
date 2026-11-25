FROM harbor.com/base_image/python:3.14-trixie AS builder

WORKDIR /zensical

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY zensical.toml ./
COPY docs ./docs

RUN zensical build

FROM harbor.com/base_image/nginx:stable_v2

COPY --from=builder /zensical/site /usr/share/nginx/html
COPY nginx-custom.conf /etc/nginx/conf.d/default.conf

RUN sed -E -i \
   -e 's|^[[:space:]]*pid[[:space:]]+[^;]+;|pid /tmp/nginx.pid;|' \
   -e '/^[[:space:]]*user[[:space:]]+[^;]+;/d' \
   /etc/nginx/nginx.conf \
   && grep -q '^pid /tmp/nginx.pid;$' /etc/nginx/nginx.conf \
   && groupadd --gid 1001 appgroup \
   && useradd --uid 1001 \
      --gid 1001 \
      --no-create-home \
      --shell /usr/sbin/nologin \
      appuser \
   && mkdir -p \
      /tmp/client_temp \
      /tmp/proxy_temp \
      /tmp/fastcgi_temp \
      /tmp/uwsgi_temp \
      /tmp/scgi_temp \
   && chown -R 1001:1001 \
      /usr/share/nginx/html \
      /tmp \
      /etc/nginx \
      /var/cache/nginx \
      /var/log/nginx \
      /var/run

USER 1001:1001

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]