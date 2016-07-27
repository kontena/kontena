module Docker
  remove_const :API_VERSION if defined? Docker::API_VERSION
  API_VERSION = '1.22' # Docker 1.10+
end
