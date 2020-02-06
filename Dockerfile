FROM debian:latest

WORKDIR /build-linux-os
COPY . .
RUN chmod +x ./build-a-linux-os.sh
RUN apt-get install build-essential
CMD [ "./build-a-linux-os.sh" ]
