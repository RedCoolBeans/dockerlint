FROM node:4-alpine

MAINTAINER Red Cool Beans <maintainer@redcoolbeans.com>

RUN npm install -g dockerlint \
 && npm cache clean

ENTRYPOINT ["dockerlint", "-f", "/Dockerfile"]
