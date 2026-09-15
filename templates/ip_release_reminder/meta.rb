template :ip_release_reminder do
  label 'IP release reminder'
  user_visibility true

  lang :en do
    from 'support@vpsfree.org'
    reply_to 'support@vpsfree.org'
    return_path 'support@vpsfree.org'
  end

  lang :cs do
    from 'podpora@vpsfree.cz'
    reply_to 'podpora@vpsfree.cz'
    return_path 'podpora@vpsfree.cz'
  end
end
