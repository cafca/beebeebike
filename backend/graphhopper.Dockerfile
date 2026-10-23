# syntax=docker/dockerfile:1.7
#
# Thin layer over upstream GraphHopper that bakes in our routing rules.
# Built and pushed by .github/workflows/cd.yml so prod doesn't depend on
# host-side custom_models files.

FROM israelhikingmap/graphhopper:latest
COPY backend/custom_models/ /custom_models/

# Distrust roots that cross-signed the compromised eMudhra intermediates
# (Oct 2026) in both the system store and the JDK's own cacerts; fail the
# build if either still contains them.
RUN sed -i -E 's#^(mozilla/(emSign_ECC_Root_CA_-_G3|Comodo_AAA_Services_root)\.crt)$#!\1#' /etc/ca-certificates.conf \
    && update-ca-certificates --fresh >/dev/null \
    && ! ls /etc/ssl/certs | grep -qE 'emSign_ECC_Root_CA_-_G3|Comodo_AAA_Services_root' \
    && keytool -list -v -cacerts -storepass changeit \
       | awk '/^Alias name: /{a=substr($0,13)} /^Owner: .*(emSign ECC Root CA - G3|AAA Certificate Services)/{print a}' \
       | while IFS= read -r a; do keytool -delete -cacerts -storepass changeit -alias "$a"; done \
    && ! keytool -list -v -cacerts -storepass changeit | grep -qE '^Owner: .*(emSign ECC Root CA - G3|AAA Certificate Services)'
