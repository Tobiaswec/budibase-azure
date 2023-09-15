FROM budibase/budibase-aas:latest

RUN sed -i 's/listen\s\+80 default_server;/listen 10000 default_server;/' /etc/nginx/sites-available/default && \
    sed -i 's/listen\s\+\[::\]:80 default_server;/listen [::]:10000 default_server;/' /etc/nginx/sites-available/default
