class SendgridEvent < ActiveRecord::Base
  
  before_save  :normalize_email
  after_create :queue
  
  SENDGRID_ATTRIBUTES = ['event',
                         'email',
                         'category',
                         'reason',
                         'response',
                         'attempt',
                         'event_type',
                         'status',
                         'url',
                         'timestamp']
  
  def queue
    Delayed::Job.enqueue(self)
  end
    
  def to_ampersand_separated_s
     sendgrid_data = SENDGRID_ATTRIBUTES.map do |variable|
       sendgrid_value = self.send(variable)
       "#{variable}=#{sendgrid_value}" if sendgrid_value
     end.compact.join('&')
     URI.escape(sendgrid_data)
  end
  
  def normalize_email
    self.email = self.email.gsub(/[\<\>]/,'').strip
  end
  
  def url_to_post
    return nil if category.nil?
    site, model = self.category.split('#') # "example.org#model"
    return nil if site.nil? or site == "none"
    "#{site}/sendgrid_event"
  end
  
  def perform
    return false if self.url_to_post.nil?
    Curl::Easy::http_post(self.url_to_post,self.to_ampersand_separated_s)
    return true
  end
  
end