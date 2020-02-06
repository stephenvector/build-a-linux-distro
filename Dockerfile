FROM ubuntu:latest
WORKDIR /build-linux-os
COPY ./build-a-linux-os.sh .
RUN chmod +x ./build-a-linux-os.sh
RUN apt update
RUN apt install build-essential -y
CMD [ "./build-a-linux-os.sh" ]
