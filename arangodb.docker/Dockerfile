FROM alpine:3.7
MAINTAINER Max Neunhoeffer <max@arangodb.com>

RUN apk update && apk add nodejs pwgen && npm install -g foxx-cli
COPY install.tar.gz /install.tar.gz
COPY setup.sh /setup.sh
RUN cd / && tar xzvf install.tar.gz && rm /install.tar.gz && /setup.sh

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 8529
CMD [ "arangod" ]
