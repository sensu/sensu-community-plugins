# Redacts sensitive event information
#
# Requires a Sensu setting snippet 'redact', containing the list of keys
# with sensitive values that need redacting, or for clients to have their
# own redact attribute. If both exist, the client's setting will be preferred.
# If neither exist, a base set is used.
#
# This is essentially taken from the Sensu 0.11 beta.
#
# Copyleft 2013 Yet Another Clever Name <admin@yacn.pw>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

module Sensu::Extension
  class Redact < Mutator

    def definition
      {
        type: 'extension',
        name: 'redact',
      }
    end

    def name
      definition[:name]
    end

    def description
      'Redacts sensitive information from events'
    end

    def run(event_data, settings)
      event = JSON.parse(event_data, symbolize_names: true)
      unless event[:client][:redact]
        keys = settings['redact'] unless settings['redact'].nil?
        keys ||= nil # just so we can pass the variable in to redact_sensitive
      else
        keys = event[:client][:redact]
      end
      redacted = redact_sensitive(event, keys)
      event = JSON.dump(redacted)
      yield(event, 0)
    end

    def redact_sensitive(hash, keys = nil)
      keys ||= %w[
        password passwd pass
        api_key api_token
        access_key secret_key
        private_key secret
      ]
      hash = hash.dup
      hash.each do |key, value|
        if keys.include?(key.to_s)
          hash[key] = 'REDACTED'
        elsif value.is_a?(Hash)
          hash[key] = redact_sensitive(value, keys)
        end
      end
      hash
    end

  end
end
