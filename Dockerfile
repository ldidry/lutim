FROM alpine:3.15

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Lets Upload That Image" \
      org.label-schema.url="https://lutim.fiat-tux.fr/" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://framagit.org/fiat-tux/hat-softwares/lutim" \
      org.label-schema.vendor="Luc Didry" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

RUN adduser -D lutim \
 && addgroup lutim root

COPY . /home/lutim
RUN chmod -R g+rwX /home/lutim

WORKDIR /home/lutim
RUN apk --no-cache add perl~=5 \
                       libpq~=14 \
                       perl-crypt-rijndael~=1 \
                       perl-io-socket-ssl~=2 \
                       perl-net-ssleay~=1 \
                       su-exec~=0.2 \
                       shared-mime-info~=2 \
                       libretls~=3 \
                       imagemagick~=7 \
                       imagemagick-perlmagick~=7 \
                       bash~=~5 \
 && apk --no-cache add --virtual .build-deps build-base~=0.5 \
                                             perl-utils~=5 \
                                             perl-dev~=5 \
                                             postgresql14-dev~=14 \
                                             vim~=8 \
                                             wget~=1 \
                                             zlib-dev~=1 \
 && cpan notest Carton Config::FromHash \
 && carton install --without test \
 && apk del .build-deps \
 && rm -rf /var/cache/apk/* /root/.cpan*

USER lutim
EXPOSE 8080

ENTRYPOINT ["/bin/sh", "/home/lutim/docker/entrypoint.sh"]
