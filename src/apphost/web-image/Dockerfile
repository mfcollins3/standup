# syntax=docker/dockerfile:1

# The image that is deployed to Azure Container Apps.
#
# This Dockerfile adds nothing to the web app's image. It is only
# `FROM <the published image>`, and exists so that `aspire deploy` treats the web
# app as an image it builds. Aspire then pushes the image to the Azure Container
# Registry that it provisions, and gives the Container App permission to pull it
# from there. Aspire does not do this for an image that it did not build.
#
# The image is the one that .github/workflows/container.yml publishes to GHCR, and
# the deploy workflow passes its digest in WEB_IMAGE, for example:
#
#   ghcr.io/<owner>/standup-web@sha256:<digest>
#
# Pinning the digest means that what is deployed is exactly what was published.
# The default is only used when the file is built by hand, without a build argument.
ARG WEB_IMAGE=ghcr.io/mfcollins3/standup-web:latest
FROM ${WEB_IMAGE}
