class PortraitMailer < ApplicationMailer
  default from: 'Jeremy at OKNOTOK <jeremy@oknotok.com>',
          reply_to: 'jeremy@oknotok.com'

  def portrait_ready(sitting)
    # Only need the heroes URL since we can't match sessions reliably
    @heroes_url = heroes_url

    mail(
      to: sitting.email,
      subject: "Your Shock Collar Portrait from Burning Man is ready!"
    )
  end
end