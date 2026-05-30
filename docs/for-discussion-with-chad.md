# For discussion with Chad

- **Set up the Windows laptop to dual-boot into Linux?** Fun and fast for dev work, but eventually we do need software that runs on Windows — so keep Windows available rather than wiping it.

- **Try to get Chrome Remote Desktop working.** Neill will make a single Google account that we share just for this auth purpose.

- **What's the big picture?**

* A computer where you can let Claude loose to build and configure things quickly, without fear that it's going to mess up your critical systems or leak secrets
* plus the ability for whoever is helping you to log in and manage that machine.
* plus the ability for claude to log in and manage that system remotely (under the guidance of whoever's helping you)

Remote Desktop Server is not installed (nor installable) on windows 11 home

The only ways to change that:

1. Upgrade Windows 11 Home → Pro (~$99 from Microsoft directly via Settings → System → Activation). Adds the RDP
   server natively. Stable, supported, never breaks on updates. Best option if you're going to do this regularly.
2. RDP Wrapper - omitted. hacky.
3. A different protocol entirely. AnyDesk, RustDesk, Parsec — these aren't RDP, but provide equivalent remote-control functionality on Home without modification. Most polished free one is AnyDesk in my experience. No Google account needed (which addresses the concern that pushed you away from CRD).
