FROM perl:5.28

MAINTAINER Yoann Le Garff (le-garff-yoann) <pe.weeble@yahoo.fr>

COPY . /opt/clovershell

WORKDIR /opt/clovershell

RUN \
    apt-get install -y libpq-dev && \
    cpanm --installdeps -n .

ENV MOJO_MODE production

EXPOSE 8080 8443

CMD [ "hypnotoad", "-f", "script/clovershell" ]
