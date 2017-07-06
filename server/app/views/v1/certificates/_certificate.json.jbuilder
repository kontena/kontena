json.id certificate.id
json.domain certificate.domain
json.valid_until certificate.valid_until.to_s
json.alt_names certificate.alt_names
json.certificate_type certificate.cert_type
json.private_key_Secret certificate.private_key.name
json.certificate_secret certificate.certificate.name
json.certificate_bundle_secret certificate.certificate_bundle.name
