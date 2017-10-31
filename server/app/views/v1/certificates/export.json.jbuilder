json.id @certificate.to_path
json.subject @certificate.subject

json.certificate_pem @certificate.certificate
json.chain_pem @certificate.chain
json.private_key_pem @certificate.private_key
