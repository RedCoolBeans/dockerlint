FROM node:4-alpine

MAINTAINER Jasper Lievisse Adriaanse <jasper@redcoolbeans.com>

COPY . /dockerlint
WORKDIR /dockerlint

RUN npm install -g coffee-script \
 && make js \
 && npm install -g \
 && npm cache clean

ENTRYPOINT ["dockerlint"]
ENTRYPOINT ["-f", "/Dockerfile"]
