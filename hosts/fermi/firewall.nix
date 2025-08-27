{ ... }:

{
  # Open ports in the firewall.
  networking.firewall = {
    enable = true;
    allowPing = false;
    allowedTCPPortRanges = [ ];
    allowedUDPPortRanges = [ ];
  };

  networking.nftables.enable = true;

  networking.nftables.ruleset = ''
    table inet filter {
      chain input {
        type filter hook input priority 0;

        # allow loopback
        iif lo accept

        # allow established/related
        ct state established,related accept

        # allow SSH only from shell servers
        tcp dport 22 ip saddr 155.98.65.56 accept
        tcp dport 22 ip saddr 155.98.65.57 accept

        # drop everything else
        drop
      }
    }
  '';
}
