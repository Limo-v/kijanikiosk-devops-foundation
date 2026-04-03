# nologin Decision

I went with `/usr/sbin/nologin` instead of `/bin/false`. From what I understood both block login, but `nologin` kind of explains better what is happening. If someone checks users later, they can see this account is not for people logging in. I almost used `/bin/false` first, then changed it. I think this is clearer and still secure enough for service accounts.
