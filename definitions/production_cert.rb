define :production_cert do
  site = params[:name]

  execute "upgrade-#{site}" do
    command "rm -rf /etc/developer-ca/#{site} && ln -s /etc/letsencrypt/live/#{site} /etc/developer-ca/#{site}"
    action :nothing
  end

  certbot_certificate site do
    email params[:admin_email]
    notifies :execute, "upgrade-#{site}", :immediately
    notifies :reload, "service[nginx]", :immediately
  end
end

