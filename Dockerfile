FROM ubuntu:latest
WORKDIR /build-linux-os
COPY ./build-a-linux-os.sh .
RUN chmod +x ./build-a-linux-os.sh
RUN apt-get update
RUN apt-get install wget build-essential bison flex xz-utils gnupg2 ninja-build meson -y
CMD [ "./build-a-linux-os.sh" ]
