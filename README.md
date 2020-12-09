# Terraform to deploy [BedrockConnect](https://github.com/Pugmatt/BedrockConnect) to Oracle Cloud

Oracle Cloud infra have a generous [always free tier](https://www.oracle.com/uk/cloud/free/#always-free) that gives you amongst other things a couple of vms, so I wrote some terraform and gubbins to run BedrockConnect and dnsmasq so my son and his mates can point their consoles at it as a dns resolver.

Once I've proved it stable I intend to remove my ssh keys so they can be confident that I'm not prying or doing anything else weird with their unrelated traffic/dns lookups since all the infra is code and I can't manipulate what is actually running.
