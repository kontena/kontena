json.id @certificate.to_path
json.subject @certificate.subject

json.certificate @certificate.certificate
json.chain @certificate.chain
json.private_key @certificate.private_key
