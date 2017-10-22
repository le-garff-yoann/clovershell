FROM perl:5.26

MAINTAINER Yoann Le Garff (le-garff-yoann) <pe.weeble@yahoo.fr>

COPY . /opt/clovershell-server

WORKDIR /opt/clovershell-server

RUN \
    apt-get install -y libpq-dev && \
    cpanm --installdeps -n .

ENV MOJO_MODE production

EXPOSE 8080 8443

CMD [ "hypnotoad", "-f", "script/clovershell" ]
