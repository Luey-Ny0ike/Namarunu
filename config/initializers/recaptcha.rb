Recaptcha.configure do |config|
  config.site_key   = ENV.fetch("RECAPTCHA_v3_SITE_KEY", "test-site-key")
  config.secret_key = ENV.fetch("RECAPTCHA_v3_SECRET_KEY", "test-secret-key")
end
