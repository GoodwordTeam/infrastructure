FROM tobikodata/sqlmesh:latest

# Copy your working configuration
COPY config.yaml /app/config.yaml

# Set environment variables
ENV SQLMESH_CONFIG_PATH=/app/config.yaml

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1
