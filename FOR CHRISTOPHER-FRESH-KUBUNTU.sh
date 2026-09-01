Then:

chmod +x ~/CHRISTOPHER-FRESH-KUBUNTU.sh
~/CHRISTOPHER-FRESH-KUBUNTU.sh
After it finishes

Reboot.

Then:

~/AI-PC/Scripts/system-check.sh

Then do the two authentication steps:

openclaw onboard --install-daemon

and:

hermes setup --portal

Those aren't missing installation steps — they're account authorization. OpenClaw's current onboarding establishes provider authentication and the Gateway, while Hermes' current hermes setup --portal is its one-step OAuth/provider + Tool Gateway setup.

After that, OpenClaw becomes the conductor.

And I want to change one thing from the previous version: don't have the installation script try to fake the final "self-aware" AI by itself.

The fresh machine should install the infrastructure, then we give OpenClaw one master mission:

Inspect everything you have just been given. Understand the machine. Discover every installed AI tool, model, agent, service and capability. Fix anything that is broken. Build the Christopher AI Control Centre. Create Builder, Strategist, QA and Researcher. Make them communicate without using the human as a messenger. Test the entire system. Continue improving it until the Control Centre is genuinely usable.

That's where it becomes the system we've been designing rather than just a gigantic pile of AI packages.

OpenClaw's current Control UI is locally available on 127.0.0.1:18789, and its configuration lives under ~/.openclaw; its current installer also supports installing the Gateway daemon directly.

Hermes is also now a particularly strong addition because its current installer handles its own dependencies and its Tool Gateway includes web search, image generation, TTS and browser capabilities.
