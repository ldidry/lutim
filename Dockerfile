FROM alpine:3.15

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Let's Upload That Image" \
      org.label-schema.url="https://lut.im/" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://git.framasoft.org/luc/lutim" \
      org.label-schema.vendor="Luc Didry" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

RUN adduser -D lutim \
 && addgroup lutim root

COPY . /home/lutim
RUN chmod -R g+rwX /home/lutim

WORKDIR /home/lutim
RUN apk --update add perl libpq perl-crypt-rijndael perl-io-socket-ssl perl-net-ssleay su-exec shared-mime-info libretls imagemagick imagemagick-perlmagick \
 && apk --update add --virtual .build-deps build-base perl-utils perl-dev postgresql14-dev vim wget zlib-dev \
 && cpan notest Carton Config::FromHash \
 && carton install --without test \
 && apk del .build-deps \
 && rm -rf /var/cache/apk/* /root/.cpan*

USER lutim
EXPOSE 8080

ENTRYPOINT ["/bin/sh", "/home/lutim/docker/entrypoint.sh"]