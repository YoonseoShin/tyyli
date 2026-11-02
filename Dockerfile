FROM jaseci/jaclang:0.37.25

USER root
WORKDIR /app
COPY --chown=jac:jac . /app

USER jac
ENV PORT=10000 \
    PYTHONUNBUFFERED=1
EXPOSE 10000

# The mobile client is built separately. This container only exposes the Jac
# functions used for clothing analysis, outfit recommendations, and chat.
# Render runs containers on Kubernetes, but this API is intentionally
# stateless and does not use Jac accounts. Clear the platform marker so Jac can
# use its disposable embedded identity store instead of requiring Postgres.
ENTRYPOINT []
CMD ["/bin/sh", "-c", "unset KUBERNETES_SERVICE_HOST; exec jac run --no-takeover --serve --no-client --port \"${PORT}\" ai_server.jac"]
