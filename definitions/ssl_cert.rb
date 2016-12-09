define :ssl_cert, name: nil, owner: nil do
  attributes = node[cookbook_name]

  env = attributes[:env] || node.dev_ca.env

  if env != "production"
    user = params[:owner] || attributes[:user] || "root"
    site = params[:name]

    cert_path = "/etc/developer-ca/#{site}"

    directory cert_path do
      action :create
      recursive true
      owner user
      group user
      mode "1640"
    end

    %w{fullchain.pem privkey.pem}.each do |file|
      cookbook_file "#{cert_path}/#{file}" do
        source "#{site}.#{file}"
        owner user
        mode "0640"
      end
    end
  end
end

