# Build stage
FROM swift:5.9-jammy as builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy source code
WORKDIR /build
COPY Package.* ./
COPY Sources ./Sources
COPY Tests ./Tests

# Build the package
RUN swift build -c release

# Runtime stage
FROM swift:5.9-jammy-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the built executable
WORKDIR /app
COPY --from=builder /build/.build/release/anthropic-cli /app/

# Create a non-root user
RUN useradd -m -u 1000 anthropic
USER anthropic

# Set the entrypoint
ENTRYPOINT ["/app/anthropic-cli"]