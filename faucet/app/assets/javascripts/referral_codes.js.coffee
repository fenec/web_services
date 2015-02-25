@ReferralCodesPoller =
  poll: ->
    setTimeout @request, 5000

  request: ->
      $.get($('#referral_codes').data('url'))

$ ->
  ReferralCodesPoller.poll()
