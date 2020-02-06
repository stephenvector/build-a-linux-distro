FROM ubuntu:latest
WORKDIR /build-linux-os
COPY ./build-a-linux-os.sh .
RUN chmod +x ./build-a-linux-os.sh
RUN apt-get install build-essential
CMD [ "./build-a-linux-os.sh" ]
