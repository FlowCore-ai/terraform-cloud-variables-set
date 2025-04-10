FROM alpine:3.21

LABEL "com.github.actions.name"="tf-cloud-var-set"
LABEL "com.github.actions.description"="Add/update variable in a Terraform Cloud Workspace"
LABEL "com.github.actions.icon"="refresh-cw"
LABEL "com.github.actions.color"="green"

LABEL version="1.0.0"
LABEL maintainer="FlowCore AI Ltd. <info@flowcore.ai>"

RUN apk update && apk add --no-cache jq=1.7.1-r0 curl=8.12.1-r1

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# ENTRYPOINT ["/entrypoint.sh"]
