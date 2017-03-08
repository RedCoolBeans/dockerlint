FROM node:4-alpine

MAINTAINER Jasper Lievisse Adriaanse <jasper@redcoolbeans.com>

RUN npm install -g dockerlint \
 && npm cache clean

ENTRYPOINT ["dockerlint", "-f", "/Dockerfile"]
