iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -i wlo1 -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A POSTROUTING -o wlp0s20f0u1 -j MASQUERADE
iptables -A FORWARD -i wlp0s20f0u1 -o wlo1 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlo1 -o wlp0s20f0u1 -j ACCEPT
