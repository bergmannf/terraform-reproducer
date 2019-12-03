users:
  - name: ${username}
    groups: users
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
    ${authorized_keys}

# Inject the public keys
ssh_authorized_keys:
${authorized_keys}

runcmd:
  # workaround for bsc#1119397 . If this is not called, /etc/resolv.conf is empty
  - netconfig -f update
  # Workaround for bsc#1138557 . Disable root and password SSH login
  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
  - sed -i -e '/^#ChallengeResponseAuthentication/s/^.*$/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  - sed -i -e '/^#PasswordAuthentication/s/^.*$/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sshd -t || echo "ssh syntax failure"
  - systemctl restart sshd