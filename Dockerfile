FROM ubuntu:latest
WORKDIR /build-linux-os
COPY ./build-a-linux-os.sh .
RUN chmod +x ./build-a-linux-os.sh
RUN apt-get update
RUN apt-get install shellcheck wget build-essential bison flex xz-utils gnupg2 ninja-build python3 python3-pip python3-setuptools python3-wheel -y
CMD ["shellcheck", "./build-a-linux-os.sh"]
CMD [ "./build-a-linux-os.sh" ]
