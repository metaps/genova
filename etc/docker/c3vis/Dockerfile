FROM node:4.1
MAINTAINER "Naomichi Yamakita" <n.yamakita@gmail.com>

ARG AWS_REGION
ARG AWS_ACCESS_KEY
ARG AWS_SECRET_KEY

RUN mkdir -p /data/c3vis
WORKDIR /data/c3vis

RUN git clone https://github.com/ExpediaDotCom/c3vis.git . && npm -d install
RUN mkdir /root/.aws

COPY ./credentials /root/.aws/credentials
COPY ./aws_config.json ./aws_config.json

RUN cat /root/.aws/credentials | \
  awk '{gsub("\\$\{AWS_ACCESS_KEY\}", "'${AWS_ACCESS_KEY}'"); gsub("\\$\{AWS_SECRET_KEY\}", "'${AWS_SECRET_KEY}'"); print $0}' >> /root/.aws/credentials.tmp && \
  mv /root/.aws/credentials.tmp /root/.aws/credentials
RUN cat ./aws_config.json | \
  awk '{gsub("\\$\{AWS_REGION\}", "'${AWS_REGION}'"); print $0}' >> ./aws_config.json.tmp && \
  mv ./aws_config.json.tmp ./aws_config.json

CMD ["npm", "start"]
