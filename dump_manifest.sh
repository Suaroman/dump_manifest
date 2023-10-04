#!/bin/bash
# Author: gregorys

if ! command -v jq >/dev/null 2>&1; then
    sudo apt-get update > /dev/null 2>&1
    sudo apt-get install -y jq > /dev/null 2>&1
    # Check if jq was successfully installed; if not, exit with an error message
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error installing jq. Exiting."
        exit 1
    fi
fi

json_file="/etc/hdinsight-agent/manifest.json"
encrypted_manifest=$(jq -r '.encrypted_manifest' $json_file)
crt_file="/usr/lib/hdinsight-common/certs/signing_cert.crt"
HEADER=$'MIME-Version: 1.0\nContent-Disposition: attachment; filename="Certificates.p7m"\nContent-Type: application/x-pkcs7-mime; name="Certificates.p7m"\nContent-Transfer-Encoding: base64\n\n'
ENCRYPTED=$(echo "$encrypted_manifest" | fold -w65 | paste -sd\\n -)
verify_output=$(openssl cms -verify -in <( echo "$HEADER$ENCRYPTED" ) -noverify -certfile "$crt_file")
encrypting_certificate_thumbprint=$(jq -r '.encrypting_certificate_thumbprint' $json_file)
src_file="/var/lib/waagent/$encrypting_certificate_thumbprint.prv"
dest_file="/usr/lib/hdinsight-common/certs/cluster_cert.prv"
cp $src_file $dest_file
chmod 644 $dest_file
sudo chown root:hadoop $dest_file
ENCRYPTED=$(echo "$verify_output" | fold -w65 | paste -sd\\n -)

script_dir=$(dirname "$0")
output_file="$script_dir/decrypted.json"
openssl cms -decrypt -inkey "$dest_file" -in <( echo "$HEADER$ENCRYPTED" ) > "$output_file"

zip "$output_file.zip" "$output_file" > /dev/null 2>&1

if [ -f "$output_file.zip" ]; then
    echo "Successfully created $output_file.zip"
else
    echo "Failed to create $output_file.zip"
fi

rm "$output_file"
