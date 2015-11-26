module Kontena::Cli::Etcd
  module Common

    def validate_key
      abort("Invalid key, did you mean /#{key} ?") unless key[0] == '/'
    end
  end
end
