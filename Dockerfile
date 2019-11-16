FROM alpine:3.9

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

RUN adduser -D lutim
COPY --chown=lutim:lutim . /home/lutim

WORKDIR /home/lutim
RUN /bin/sh /home/lutim/docker/build.sh

USER lutim

ENTRYPOINT ["/bin/sh", "/home/lutim/docker/entrypoint.sh"]