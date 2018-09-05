FROM node:4-alpine

LABEL maintainer="Red Cool Beans <maintainer@redcoolbeans.com>"

RUN npm install -g dockerlint \
 && npm cache clean

ENTRYPOINT ["dockerlint"]
CMD [ "-f", "/Dockerfile"]
