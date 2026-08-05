FROM alpine:3.19

# Install dependencies needed for tools
RUN apk add --no-cache curl ca-certificates bash

# Install Syft
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Install Grype
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Verify installation
RUN syft --version && grype --version

CMD ["sh"]
