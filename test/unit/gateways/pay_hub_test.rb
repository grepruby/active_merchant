require 'test_helper'

class PayHubTest < Test::Unit::TestCase
  def setup
    @gateway = PayHubGateway.new(add_credentials)
    @credit_card = credit_card('371449635398431', credit_card_params)
    @amount = 200
    @options = optional_params
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_or_authorize_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_match(/^SUCCESS/, response.message.to_s)
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_purchase_or_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_match(/^SUCCESS/, response.message.to_s)
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.capture(123)

    assert_success response
    assert response.test?
    assert_match(/^TRANSACTION CAPTURED SUCCESSFULLY/, response.message.to_s)
  end

  def test_unsuccessful_capture
    @gateway.expects(:ssl_request).returns(failed_capture_response)

    response = @gateway.capture(123, {:amount => 200})

    assert !response.success?
    assert response.test?
    assert_match(/^UNABLE TO CAPTURE/, response.message.to_s)
  end


  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void(479)

    assert_success response
    assert response.test?
    assert_match(/^SUCCESS/, response.message.to_s)
  end

  def test_unsuccessful_void
    @gateway.expects(:ssl_request).returns(failed_void_response)

    assert response = @gateway.void(123)

    assert response.test?
    assert_failure response
    assert_match(/^Unable to void previous transaction./, response.message.to_s)
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.void(123)

    assert_success response
    assert response.test?
    assert_match(/^SUCCESS/, response.message.to_s)
  end

  def test_unsuccessful_refund
    @gateway.expects(:ssl_request).returns(failed_refund_response)

    assert response = @gateway.refund(123)

    assert response.test?
    assert_failure response
    assert_match(/^Unable to refund the previous transaction./, response.message.to_s)
  end

  def test_invalid_raw_response
    @gateway.expects(:ssl_request).returns(invalid_json_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)

    assert_failure response
    assert_match(/^Invalid response received from the Payhub API/, response.message.to_s)
  end

  def test_invalid_number
    @gateway.expects(:ssl_request).returns(response_for_error_codes('14'))

    response = @gateway.purchase(@amount, @credit_card, optional_params)

    assert response.test?
    assert_match(PayHubGateway::STANDARD_ERROR_CODE_MAPPING['14'] ,response.error_code)
  end

  def test_invalid_expiry_date
    @gateway.expects(:ssl_request).returns(response_for_error_codes('80'))

    response = @gateway.purchase(@amount, @credit_card, optional_params)

    assert response.test?
    assert_match(PayHubGateway::STANDARD_ERROR_CODE_MAPPING['80'] ,response.error_code)
  end

  def test_invalid_cvc
    @gateway.expects(:ssl_request).returns(response_for_error_codes('82'))

    response = @gateway.purchase(@amount, @credit_card, optional_params)

    assert response.test?
    assert_match(PayHubGateway::STANDARD_ERROR_CODE_MAPPING['82'] ,response.error_code)
  end

  def test_expired_card
    @gateway.expects(:ssl_request).returns(response_for_error_codes('82'))

    response = @gateway.purchase(@amount, @credit_card, optional_params)

    assert response.test?
    assert_match(PayHubGateway::STANDARD_ERROR_CODE_MAPPING['82'] ,response.error_code)
  end

  def test_card_declined
    ['05', '61', '62', '65', '93'].each do |error_code|
      @gateway.expects(:ssl_request).returns(response_for_error_codes(error_code))

      response = @gateway.purchase(@amount, @credit_card, optional_params)

      assert response.test?
      assert_match(PayHubGateway::STANDARD_ERROR_CODE_MAPPING[error_code] ,response.error_code)
    end
  end

  def test_call_issuer
    ['01', '02'].each do |error_code|
      @gateway.expects(:ssl_request).returns(response_for_error_codes(error_code))

      response = @gateway.purchase(@amount, @credit_card, optional_params)

      assert response.test?
      assert_match(PayHubGateway::STANDARD_ERROR_CODE_MAPPING[error_code] ,response.error_code)
    end
  end

  def test_pickup_card
    ['04', '07', '41', '43'].each do |error_code|
      @gateway.expects(:ssl_request).returns(response_for_error_codes(error_code))

      response = @gateway.purchase(@amount, @credit_card, optional_params)

      assert response.test?
      assert_match(PayHubGateway::STANDARD_ERROR_CODE_MAPPING[error_code] ,response.error_code)
    end
  end

  def test_avs_codes
    PayHubGateway::AVS_CODE_TRANSLATOR.keys.each do |code|
      @gateway.expects(:ssl_request).returns(response_for_avs_codes(code))

      response = @gateway.purchase(@amount, @credit_card, optional_params)

      assert response.test?
      assert_match(code ,response.avs_result['code'])
    end
  end

  def test_cvv_codes
    PayHubGateway::CVV_CODE_TRANSLATOR.keys.each do |code|
      @gateway.expects(:ssl_request).returns(response_for_cvv_codes(code))

      response = @gateway.purchase(@amount, @credit_card, optional_params)

      assert response.test?
      assert_match(code ,response.cvv_result['code'])
      assert_match(PayHubGateway::CVV_CODE_TRANSLATOR[code] ,response.cvv_result['message'])
    end
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_request).returns(failed_purchase_or_authorize_response)

    @gateway.options.merge!({:mode => 'live', :test => false})

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert !response.success?
    assert !response.test?
  end

  def test_unsuccessful_authorize
    @gateway.expects(:ssl_request).returns(failed_purchase_or_authorize_response)

    @gateway.options.merge!({:mode => 'live', :test => false})

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert !response.success?
    assert !response.test?
  end

  private

  def failed_void_response
    <<-RESPONSE
    {
    "CARD_TOKEN_NO": "9999000000001705",
    "AVS_RESULT_CODE": "N",
    "TRANSACTION_ID": "7525",
    "CUSTOMER_ID": "136",
    "VERIFICATION_RESULT_CODE": "M",
    "RESPONSE_CODE": "4073",
    "RISK_STATUS_RESPONSE_CODE": "",
    "TRANSACTION_DATE_TIME": "110914 101145",
    "RISK_STATUS_RESPONSE_TEXT": "",
    "APPROVAL_CODE": "TAS725",
    "BATCH_ID": "420",
    "RESPONSE_TEXT": "Unable to void previous transaction.",
    "CIS_NOTE": ""
    }
    RESPONSE
  end

  def failed_refund_response
    <<-RESPONSE
    {
    "CARD_TOKEN_NO": "",
    "AVS_RESULT_CODE": "",
    "TRANSACTION_ID": "",
    "CUSTOMER_ID": "",
    "VERIFICATION_RESULT_CODE": "",
    "RESPONSE_CODE": "4074",
    "RISK_STATUS_RESPONSE_CODE": "",
    "TRANSACTION_DATE_TIME": "",
    "RISK_STATUS_RESPONSE_TEXT": "",
    "APPROVAL_CODE": "",
    "BATCH_ID": "",
    "RESPONSE_TEXT": "Unable to refund the previous transaction.",
    "CIS_NOTE": ""
    }
    RESPONSE
  end

  def response_for_cvv_codes(code)
    <<-RESPONSE
    {
    "RESPONSE_CODE": "00",
    "RESPONSE_TEXT": "SUCCESS",
    "VERIFICATION_RESULT_CODE": "#{code}"
    }
    RESPONSE
  end

  def response_for_avs_codes(code)
    <<-RESPONSE
    {
    "RESPONSE_CODE": "00",
    "RESPONSE_TEXT": "SUCCESS",
    "AVS_RESULT_CODE": "#{code}"
    }
    RESPONSE
  end

  def response_for_error_codes(error_code)
    <<-RESPONSE
    {
    "RESPONSE_CODE": "#{error_code}",
    "RESPONSE_TEXT": "#{PayHubGateway::STANDARD_ERROR_CODE_MAPPING[error_code]}"
    }
    RESPONSE
  end

  def successful_purchase_or_authorize_response
    <<-RESPONSE
    {
    "CARD_TOKEN_NO": "9999000000001033",
    "AVS_RESULT_CODE": "N",
    "TRANSACTION_ID":  "479",
    "CUSTOMER_ID": "18",
    "VERIFICATION_RESULT_CODE": "M",
    "RESPONSE_CODE": "00",
    "RISK_STATUS_RESPONSE_CODE": "",
    "TRANSACTION_DATE_TIME": #{Time.now.year + 1},
    "RISK_STATUS_RESPONSE_TEXT": "",
    "APPROVAL_CODE": "TAS214",
    "BATCH_ID": "97",
    "RESPONSE_TEXT": "SUCCESS",
    "CIS_NOTE": ""
    }
    RESPONSE
  end

  def failed_purchase_or_authorize_response
    <<-RESPONSE
    {
    "CARD_TOKEN_NO": "",
    "AVS_RESULT_CODE": "",
    "TRANSACTION_ID": "",
    "CUSTOMER_ID": "",
    "VERIFICATION_RESULT_CODE": "",
    "RESPONSE_CODE": "4008",
    "RISK_STATUS_RESPONSE_CODE": "",
    "TRANSACTION_DATE_TIME": "",
    "RISK_STATUS_RESPONSE_TEXT"=>"",
    "APPROVAL_CODE"=>"",
    "BATCH_ID"=>"",
    "RESPONSE_TEXT"=>"Invalid API Username.  Please contact the merchant.",
    "CIS_NOTE"=>""
    }
    RESPONSE
  end

  def successful_void_response
    <<-RESPONSE
    {
    "CARD_TOKEN_NO": "9999000000001705",
    "AVS_RESULT_CODE": "0",
    "TRANSACTION_ID": "7522",
    "CUSTOMER_ID": "136",
    "VERIFICATION_RESULT_CODE": "",
    "RESPONSE_CODE": "00",
    "RISK_STATUS_RESPONSE_CODE": "",
    "TRANSACTION_DATE_TIME": "2014-11-07 21:55:34",
    "RISK_STATUS_RESPONSE_TEXT": "",
    "APPROVAL_CODE": "TAS444",
    "BATCH_ID": "416",
    "RESPONSE_TEXT": "SUCCESS",
    "CIS_NOTE": ""
    }
    RESPONSE
  end

  def successful_refund_response
    <<-RESPONSE
    {
    "CARD_TOKEN_NO": "9999000000001034",
    "AVS_RESULT_CODE": "0",
    "TRANSACTION_ID": "7523",
    "CUSTOMER_ID": "",
    "VERIFICATION_RESULT_CODE": "",
    "RESPONSE_CODE": "00",
    "RISK_STATUS_RESPONSE_CODE": "",
    "TRANSACTION_DATE_TIME": "2014-11-07 21:58:35",
    "RISK_STATUS_RESPONSE_TEXT": "",
    "APPROVAL_CODE": "      ",
    "BATCH_ID": "417",
    "RESPONSE_TEXT": "SUCCESS",
    "CIS_NOTE": ""
    }
    RESPONSE
  end

  def successful_capture_response
    <<-RESPONSE
    {
    "BATCH_ID": "428",
    "RESPONSE_TEXT": "TRANSACTION CAPTURED SUCCESSFULLY",
    "RESPONSE_CODE": "00"
    }
    RESPONSE
  end

  def failed_capture_response
    <<-RESPONSE
    {
    "RESPONSE_TEXT": "UNABLE TO CAPTURE",
    "RESPONSE_CODE": "4075"
    }
    RESPONSE
  end

  def invalid_json_response
    <<-RESPONSE
    "foo" =>  "bar"
    RESPONSE
  end

  def add_credentials
    {
      :orgid => "123456",
      :username => "abc123DEF",
      :password => "abc123DEF",
      :tid => '123'
    }
  end

  def credit_card_params
    {
      :first_name => 'Bob',
      :last_name => 'Bobsen',
      :month => '06',
      :year => '2020',
      :verification_value => '9997'
    }
  end

  def optional_params
    {
      :first_name => 'Garry',
      :last_name => 'Barry',
      :phone => '9179328589',
      :email => 'abcsss@mailinator.com',
      :address =>
      {
        :address1 => '123 ahappy St.',
        :address2 => 'Abca',
        :city => 'aHappy City',
        :state => 'CA',
        :zip => '94901'
      }
    }
  end
end
