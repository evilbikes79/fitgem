require 'fitgem/version'
require 'fitgem/helpers'
require 'fitgem/errors'
require 'fitgem/users'
require 'fitgem/activities'
require 'fitgem/sleep'
require 'fitgem/water'
require 'fitgem/blood_pressure'
require 'fitgem/glucose'
require 'fitgem/heart_rate'
require 'fitgem/units'
require 'fitgem/foods'
require 'fitgem/friends'
require 'fitgem/body_measurements'
require 'fitgem/time_range'
require 'fitgem/devices'
require 'fitgem/notifications'
require 'fitgem/alarms'
require 'fitgem/badges'
require 'date'
require 'uri'

module Fitgem
  class Client
    API_VERSION = '1'
    EMPTY_BODY = ''

    # Sets or gets the api_version to be used in API calls
    #"
    # @return [String]
    attr_accessor :api_version

    # Sets or gets the api unit system to be used in API calls
    #
    # @return [String]
    #
    # @example Set this using the {Fitgem::ApiUnitSystem}
    #   client.api_unit_system = Fitgem::ApiUnitSystem.UK
    # @example May also be set in the constructor call
    #   client = Fitgem::Client {
    #     :consumer_key => my_key,
    #     :consumer_secret => my_secret,
    #     :token => fitbit_oauth_token,
    #     :secret => fitbit_oauth_secret,
    #     :unit_system => Fitgem::ApiUnitSystem.METRIC
    #   }
    attr_accessor :api_unit_system

    # Sets or gets the user id to be used in API calls
    #
    # @return [String]
    attr_accessor :user_id

    # Creates a client object to communicate with the fitbit API
    #
    # There are two primary ways to create a client: one if the current
    # fitbit user has not authenticated through fitbit.com, and another
    # if they have already authenticated and you have a stored
    # token/secret returned by fitbit after the user authenticated and
    # authorized your application.
    #
    # @param [Hash] opts The constructor options
    # @option opts [String] :consumer_key The consumer key (required for
    #   OAuth)
    # @option opts [String] :consumer_secret The consumer secret (required
    #   for OAuth)
    # @option opts [String] :token The token generated by fitbit during the OAuth
    #   handshake; stored and re-passed to the constructor to create a
    #   'logged-in' client
    # @option opts [String] :secret The secret generated by fitbit during the
    #   OAuth handshake; stored and re-passed to the constructor to
    #   create a 'logged-in' client
    # @option opts [String] :proxy A proxy URL to use for API calls
    # @option opts [String] :user_id The Fitbit user id of the logged-in
    #   user
    # @option opts [Symbol] :unit_system The unit system to use for API
    #   calls; use {Fitgem::ApiUnitSystem} to set during initialization.
    #   DEFAULT: {Fitgem::ApiUnitSystem.US}
    #
    # @example User has not yet authorized with fitbit
    #   client = Fitgem::Client.new { :consumer_key => my_key, :consumer_secret => my_secret }
    #
    # @example User has already authorized with fitbit, and we have a stored token/secret
    #   client = Fitgem::Client.new {
    #     :consumer_key => my_key,
    #     :consumer_secret => my_secret,
    #     :token => fitbit_oauth_token,
    #     :secret => fitbit_oauth_secret
    #   }
    #
    # @return [Client] A Fitgem::Client; may be in a logged-in state or
    #   ready-to-login state
    def initialize(opts)
      missing = [:consumer_key, :consumer_secret] - opts.keys
      if missing.size > 0
        raise Fitgem::InvalidArgumentError, "Missing required options: #{missing.join(',')}"
      end
      @consumer_key = opts[:consumer_key]
      @consumer_secret = opts[:consumer_secret]

      @token = opts[:token]
      @secret = opts[:secret]

      @proxy = opts[:proxy] if opts[:proxy]
      @user_id = opts[:user_id] || '-'

      @api_unit_system = opts[:unit_system] || Fitgem::ApiUnitSystem.US
      @api_version = API_VERSION
    end

    # Finalize authentication and retrieve an oauth access token
    #
    # @param [String] token The OAuth token
    # @param [String] secret The OAuth secret
    # @param [Hash] opts Additional data
    # @option opts [String] :oauth_verifier The verifier token sent by
    #   fitbit after user has logged in and authorized the application.
    #   Is included in the body of the callback request, if there was
    #   one.  Otherwise is shown onscreen for the user to copy/paste
    #   back into your application.  See {https://wiki.fitbit.com/display/API/OAuth-Authentication-API} for more information.
    #
    # @return [OAuth::AccessToken] An oauth access token; this is not
    #   needed to make API calls, since it is stored internally.  It is
    #   returned so that you may make general OAuth calls if need be.
    def authorize(token, secret, opts={})
      request_token = OAuth::RequestToken.new(consumer, token, secret)
      @access_token = request_token.get_access_token(opts)
      @token = @access_token.token
      @secret = @access_token.secret
      @access_token
    end

    # Reconnect to the fitbit API with a stored oauth token and oauth
    # secret
    #
    # This method should be used if you have previously directed a user
    # through the OAuth process and received a token and secret that
    # were stored for later use.  Using +reconnect+ you can
    # 'reconstitute' the access_token required for API calls without
    # needing the user to go through the OAuth process again.
    #
    # @param [String] token The stored OAuth token
    # @param [String] secret The stored OAuth secret
    #
    # @return [OAuth::AccessToken] An oauth access token; this is not
    #   needed to make API calls, since it is stored internally.  It is
    #   returned so that you may make general OAuth calls if need be.
    def reconnect(token, secret)
      @access_token = nil
      @token = token
      @secret = secret
      access_token
    end

    # Get the current state of the client
    #
    # @return True if api calls may be made, false if not
    def connected?
      !@access_token.nil?
    end

    # Get an oauth request token
    #
    # @param [Hash] opts Request token request data; can be used to
    #   override default endpoint information for the oauth process
    # @return [OAuth::RequestToken]
    def request_token(opts={})
      consumer.get_request_token(opts)
    end

    # Get an authentication request token
    #
    # @param [Hash] opts Additional request token request data
    # @return [OAuth::RequestToken]
    def authentication_request_token(opts={})
      consumer.options[:authorize_path] = '/oauth/authenticate'
      request_token(opts)
    end

    private

      def consumer
        @consumer ||= OAuth::Consumer.new(@consumer_key, @consumer_secret, {
          :site => 'https://api.fitbit.com',
          :proxy => @proxy
        })
      end

      def access_token
        @access_token ||= OAuth::AccessToken.new(consumer, @token, @secret)
      end

      def get(path, headers={})
        extract_response_body raw_get(path, headers)
      end

      def raw_get(path, headers={})
        headers.merge!('User-Agent' => "fitgem gem v#{Fitgem::VERSION}", 'Accept-Language' => @api_unit_system)
        uri = "/#{@api_version}#{path}"
        access_token.get(uri, headers)
      end

      def post(path, body='', headers={})
        extract_response_body raw_post(path, body, headers)
      end

      def raw_post(path, body='', headers={})
        headers.merge!('User-Agent' => "fitgem gem v#{Fitgem::VERSION}", 'Accept-Language' => @api_unit_system)
        uri = "/#{@api_version}#{path}"
        access_token.post(uri, body, headers)
      end

      def delete(path, headers={})
        extract_response_body raw_delete(path, headers)
      end

      def raw_delete(path, headers={})
        headers.merge!('User-Agent' => "fitgem gem v#{Fitgem::VERSION}", 'Accept-Language' => @api_unit_system)
        uri = "/#{@api_version}#{path}"
        access_token.delete(uri, headers)
      end

      def extract_response_body(resp)
        resp.nil? || resp.body.nil? ? {} : JSON.parse(resp.body)
      end
  end
end
