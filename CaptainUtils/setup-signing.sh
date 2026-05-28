#!/bin/bash
# Create a stable self-signed code-signing identity for CaptainUtils.
#
# Why: macOS TCC (Accessibility permission) identifies an app by its code
# signature. Ad-hoc signing (codesign -s -) produces a new signature hash on
# every build, so every rebuild looks like a brand-new app and the Accessibility
# grant is lost. Signing with a stable self-signed certificate keeps the app's
# "designated requirement" constant across rebuilds (it references this cert,
# not the per-build hash), so you grant Accessibility once and it persists.
#
# Run once:  ./setup-signing.sh
# Then `make build` signs with this identity automatically.

set -euo pipefail

IDENTITY_NAME="CaptainUtils Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY_NAME"; then
    echo "Signing identity '$IDENTITY_NAME' already exists. Nothing to do."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $IDENTITY_NAME
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

echo "Generating self-signed code-signing certificate (valid 10 years)..."
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null

# macOS `security import` needs the legacy PKCS12 MAC/cipher. OpenSSL 3.x
# defaults to a newer MAC that fails to verify, so force legacy algorithms.
# A throwaway password is used because some macOS versions reject empty-password p12.
P12_PASS="captainutils"
P12_FLAGS="-keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg SHA1"
if openssl pkcs12 -help 2>&1 | grep -q -- "-legacy"; then
    P12_FLAGS="$P12_FLAGS -legacy"
fi
openssl pkcs12 -export -out "$TMP/identity.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$IDENTITY_NAME" -passout "pass:$P12_PASS" $P12_FLAGS 2>/dev/null

echo "Importing into login keychain..."
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$P12_PASS" -T /usr/bin/codesign

echo ""
echo "Done. Created code-signing identity '$IDENTITY_NAME':"
security find-identity -v -p codesigning | grep "$IDENTITY_NAME" || true
echo ""
echo "Note: the first time you build, codesign may ask for keychain access."
echo "Click 'Always Allow' to avoid the prompt on future builds."
echo "After your next 'make install', grant Accessibility ONE final time."
echo "It will persist across all future rebuilds."
