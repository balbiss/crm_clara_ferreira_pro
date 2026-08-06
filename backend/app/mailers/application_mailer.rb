class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('SMTP_USER', 'suporte@clarajoias.com.br')
  layout "mailer"
end
