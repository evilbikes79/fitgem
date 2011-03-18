require 'fitbit/users'
require 'fitbit/activities'
require 'fitbit/units'

module Fitbit
  class Client
    
    attr_accessor :api_version
    attr_accessor :api_unit_system
    
    def initialize(options = {})
      @consumer_key = options[:consumer_key]
      @consumer_secret = options[:consumer_secret]
      @token = options[:token]
      @secret = options[:secret]
      @proxy = options[:proxy]
      @api_unit_system = Fitbit::ApiUnitSystem.US
      @api_version = "1"
    end

    def authorize(token, secret, options = {})
      request_token = OAuth::RequestToken.new(
        consumer, token, secret
      )
      @access_token = request_token.get_access_token(options)
      @token = @access_token.token
      @secret = @access_token.secret
      @access_token
    end

    def show(username)
      get("/users/show/#{username}.json")
    end

    # Returns the string "ok" in the requested format with a 200 OK HTTP status code.
    def test
      get("/help/test.json")
    end

    def request_token(options={})
      consumer.get_request_token(options)
    end

    def authentication_request_token(options={})
      consumer.options[:authorize_path] = '/oauth/authenticate'
      request_token(options)
    end

    private

      def consumer
        @consumer ||= OAuth::Consumer.new(
          @consumer_key,
          @consumer_secret,
          { :site => 'http://api.fitbit.com', :request_endpoint => @proxy }
        )
      end

      def access_token
        @access_token ||= OAuth::AccessToken.new(consumer, @token, @secret)
      end

      def get(path, headers={})
        headers.merge!("User-Agent" => "fitbit gem v#{Fitbit::VERSION}", "Accept-Language" => @api_unit_system)
        oauth_response = access_token.get("/#{@api_version}#{path}", headers)
        JSON.parse(oauth_response.body)
      end

      def post(path, body='', headers={})
        headers.merge!("User-Agent" => "fitbit gem v#{Fitbit::VERSION}", "Accept-Language" => @api_unit_system)
        oauth_response = access_token.post("/#{@api_version}#{path}", body, headers)
        JSON.parse(oauth_response.body)
      end

      def delete(path, headers={})
        headers.merge!("User-Agent" => "fitbit gem v#{Fitbit::VERSION}", "Accept-Language" => @api_unit_system)
        oauth_response = access_token.delete("/#{@api_version}#{path}", headers)
        JSON.parse(oauth_response.body)
      end
  end
end