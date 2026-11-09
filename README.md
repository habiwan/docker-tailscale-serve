# docker-tailscale-serve
Dynamically syncs 'tailscale serve' rules with running Docker containers.

when using tailscale to serve your docker container webuis via secure and let's encrypt cert it is simple, no stepca needed just one command.

the issue is when forgetting to stop these tailscale proxies, next reboot of the docker container will stall it. 

And if you are like me and use portainer a lot you will have forgotten the full run command, so stop and rm the docker container might leave you not knowing how to reinstate it the way it was.

If you never forget to tailscale serve --https=PORT off after you stop a container or reboot you machine, ok, walk away, my script does this for you...

I have not tested it when powering off but it is supposed to start before docker so should clean all rules.

The scipt does simply check for docker ports, and runs an https to http proxy. If portainer or authentik, it does https+insecure which makes it work without 503 errors...
