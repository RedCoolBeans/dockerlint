FROM node:4-slim

MAINTAINER Jasper Lievisse Adriaanse <jasper@redcoolbeans.com>

RUN npm install -g dockerlint

ENTRYPOINT ["dockerlint", "-f", "/Dockerfile"]
