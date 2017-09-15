json.certificates @certificates do |certificate|
  json.partial! 'app/views/v1/certificates/certificate', certificate: certificate
end