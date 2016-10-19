module V1
  class AuthApi < Roda
    include RequestHelpers

    route do |r|
      r.post do
        if r.user_agent.to_s.start_with?('kontena-cli')
          halt_request(403, 'This version of Kontena Master does not support user credential authentication. You need to upgrade your Kontena CLI.')
        else
          halt_request(403, 'This version of Kontena Master does not support user credential authentication.')
        end
      end
    end
  end
end
