module V1
  class AuthApi < Roda
    include RequestHelpers

    route do |r|
      r.post do
        halt_request(403, 'This version of Kontena Master does not support user credential authentication') and return
      end
    end
  end
end
