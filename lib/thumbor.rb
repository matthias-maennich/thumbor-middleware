# frozen_string_literal: true

module Thumbor
  class Middleware
    def initialize(app, options = {})
      @app, @options = app, options
    end

    # Rack call interface.
    # (pecautionary dup the middleware instance for thread safety reasons)
    def call(env)
      dup._call(env)
    end

    #
    # Will be called in the middleware chain by Rack with the environment of the request.
    # If the request matches the thumbor service namespace, the chain will be intercepted
    # and be processed as a thumbor request.
    #
    def _call(env)
      return request_image(env) if thumbor_request?(env)
      @app.call(env)
    end

    #
    # @return [Boolean] +true+ if the request matches the service namespace
    #
    def thumbor_request?(env)
      env['PATH_INFO'] =~ @options[:service_namespace]
    end

    #
    # @return [Rack::Response] the response that will be returned after requesting the image
    #
    #   If the request to the thumbor server was successfull, the response will
    #   simply be forwarded. In case of the thumbor service being unavailable,
    #   a response with the status of 502 (Bad Gateway) will be returned.
    #   A timeout will be responded with a 408 (Request Timeout)
    #   Every other invalid request will responded with a 404 (Not Found)
    #
    def request_image(env)
      uri = build_thumbor_uri(env)
      req = Net::HTTP::Get.new(uri.request_uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      response = http.request(req)
      Rack::Response.new(response.body, response.code, response.header)
    rescue Errno::ECONNREFUSED
      Rack::Response.new('', 502, {})
    rescue Timeout::Error
      Rack::Response.new('', 408, {})
    rescue Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPHeaderSyntaxError, Net::ProtocolError
      Rack::Response.new('', 404, {})
    end

    #
    # @return [URI] The final URI the thumber service can be called on
    #
    def build_thumbor_uri(env)
      URI.parse([@options[:base_url], url_path(env)].join('/'))
    end

    #
    # @return [String] the assembled URL Path to call the thumbor service with
    #
    #   Action:
    #     Via the action param you can define how the image processing should behave.
    #     resize: the image will be auto-resized (shrinked) to fit in an
    #             imaginary box of the dimensions of the given format.
    #     clip:   Resizes and crops the image to fit in the given format.
    #             This action should be used if you are sure about the exact
    #             format you want to have.
    #             By default smart-cropping will be applied to the image.
    #
    #   Format:
    #     The format identifier that gets matched to the dimensions to be applied.
    #     Available formats must be specified as a hash via @options[:formats]
    #
    #   Smart:
    #     Thumbors smart detection will try to find important spots in the picture
    #     to offer the best results for cropping and resizing.
    #     https://github.com/thumbor/thumbor/wiki/Usage#smart-cropping
    #     Smart detection is enabled by default and can be disabled via the GET param `smart=false`
    #
    def url_path(env)
      params        = Rack::Utils.parse_nested_query(env['QUERY_STRING'])
      requested_url = CGI.escape(params['url'])
      requested_format = @options.dig(:formats, params['format'])
      smart = params['smart'] == 'false' ? nil : 'smart'

      case params['action']
      when 'resize'
        ['fit-in', requested_format, requested_url].compact.join('/')
      when 'clip'
        [requested_format, smart, requested_url].compact.join('/')
      else
        requested_url
      end
    end
  end
end
