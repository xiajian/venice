require 'time'

module Venice
  class Receipt
    MAX_RE_VERIFY_COUNT = 3

    # For detailed explanations on these keys/values, see
    # https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html#//apple_ref/doc/uid/TP40010573-CH106-SW1

    # The app’s bundle identifier.
    attr_reader :bundle_id

    # The app’s version number.
    attr_reader :application_version

    # The receipt for an in-app purchase.
    attr_reader :in_app

    # The version of the app that was originally purchased.
    attr_reader :original_application_version

    # The original purchase date
    attr_reader :original_purchase_date

    # The date that the app receipt expires.
    attr_reader :expires_at

    # Non-Documented receipt keys/values
    attr_reader :receipt_type
    attr_reader :adam_id
    attr_reader :download_id
    attr_reader :requested_at
    attr_reader :receipt_created_at

    # Original json response from AppStore
    attr_reader :original_json_response

    attr_accessor :latest_receipt_info

    # Information about the status of the customer's auto-renewable subscriptions
    attr_reader :pending_renewal_info

    def initialize(attributes = {})
      @original_json_response = attributes['original_json_response']

      @bundle_id = attributes['bundle_id']
      @application_version = attributes['application_version']
      @original_application_version = attributes['original_application_version']
      if attributes['original_purchase_date']
        @original_purchase_date = DateTime.parse(attributes['original_purchase_date'])
      end
      if attributes['expiration_date']
        @expires_at = Time.at(attributes['expiration_date'].to_i / 1000).to_datetime
      end

      @receipt_type = attributes['receipt_type']
      @adam_id = attributes['adam_id']
      @download_id = attributes['download_id']
      @requested_at = DateTime.parse(attributes['request_date']) if attributes['request_date']
      @receipt_created_at = DateTime.parse(attributes['receipt_creation_date']) if attributes['receipt_creation_date']

      @in_app = []
      if attributes['in_app']
        attributes['in_app'].each do |in_app_purchase_attributes|
          @in_app << InAppReceipt.new(in_app_purchase_attributes)
        end
      end

      @pending_renewal_info = []
      if original_json_response && original_json_response['pending_renewal_info']
        original_json_response['pending_renewal_info'].each do |pending_renewal_attributes|
          @pending_renewal_info << PendingRenewalInfo.new(pending_renewal_attributes)
        end
      end
    end

    def to_hash
      {
        bundle_id: @bundle_id,
        application_version: @application_version,
        original_application_version: @original_application_version,
        original_purchase_date: (@original_purchase_date.httpdate rescue nil),
        expires_at: (@expires_at.httpdate rescue nil),
        receipt_type: @receipt_type,
        adam_id: @adam_id,
        download_id: @download_id,
        requested_at: (@requested_at.httpdate rescue nil),
        receipt_created_at: (@receipt_created_at.httpdate rescue nil),
        in_app: @in_app.map(&:to_h),
        pending_renewal_info: @pending_renewal_info.map(&:to_h),
        latest_receipt_info: @latest_receipt_info
      }
    end
    alias_method :to_h, :to_hash

    def to_json
      to_hash.to_json
    end

    class << self
      def verify(data, options = {})
        verify!(data, options)
      rescue VerificationError, Client::TimeoutError => e 
        puts "e is #{e}"
        
        false
      end

      def verify!(data, options = {})
        # 这里需要添加一下配置环境
        enviroment = options.delete(:env)
        client = enviroment &&  enviroment == 'dev' ? Client.development : Client.production

        retry_count = 0
        begin
          client.verify!(data, options)
        rescue VerificationError => error
          case error.code
          when 21007
            client = Client.development
            retry
          when 21008
            client = Client.production
            retry
          else
            retry_count += 1
            if error.retryable? && retry_count <= MAX_RE_VERIFY_COUNT
              retry
            end

            raise error
          end
        rescue Net::ReadTimeout, Timeout::Error, OpenSSL::SSL::SSLError,
               Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPIPE
          # verifyReceipt is idempotent so we can retry it.
          # Net::Http has retry logic for some idempotent http methods but it verifyReceipt is POST.
          retry_count += 1
          retry if retry_count <= MAX_RE_VERIFY_COUNT
          raise
        end
      end

      alias :validate :verify
      alias :validate! :verify!
    end

    class VerificationError < StandardError
      attr_accessor :json

      def initialize(json)
        @json = json
      end

      def code
        Integer(json['status'])
      end

      def retryable?
        json['is_retryable']
      end

      def message
        case code
        when 21000
          'The App Store could not read the JSON object you provided.'
        when 21002
          'The data in the receipt-data property was malformed.'
        when 21003
          'The receipt could not be authenticated.'
        when 21004
          'The shared secret you provided does not match the shared secret on file for your account.'
        when 21005
          'The receipt server is not currently available.'
        when 21006
          'This receipt is valid but the subscription has expired. When this status code is returned to your server, the receipt data is also decoded and returned as part of the response.'
        when 21007
          'This receipt is a sandbox receipt, but it was sent to the production service for verification.'
        when 21008
          'This receipt is a production receipt, but it was sent to the sandbox service for verification.'
        when 21010
          'This receipt could not be authorized. Treat this the same as if a purchase was never made.'
        when 21100..21199
          'Internal data access error.'
        else
          "Unknown Error: #{code}"
        end
      end
    end
  end
end
