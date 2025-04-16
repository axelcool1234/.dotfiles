<!--toc:start-->
- [What Is Nix?](#what-is-nix)
  - [The Operating System](#the-operating-system)
  - [The Language](#the-language)
  - [The Package Manager](#the-package-manager)
- [Update Commands](#update-commands)
- [Rollback Command](#rollback-command)
- [Delete Broken Generations](#delete-generations)
- [Fresh Install](#fresh-install)
  - [Mismatched-Hash](#Mismatched-Hash)
  - [Post-Setup](#Post-Setup)
- [Lost Bootloader](#Lost-Bootloader)
- [Useful NixOS Resources:](#useful-nixos-resources)
<!--toc:end-->

# What Is Nix?
Nix refers to the holy trinity: An operating system, a programming language, and a package manager.

## The Operating System
- NixOS is a Linux distribution that's configured directly from these dotfiles, and can be rolled back upon a system breaking config change. This allows fearless tinkering!
- NixOS isn't FHS compliant, and cannot execute random binaries. However, there are workarounds for these two issues.
## The Language
- NixLang is a functional programming language which means it's pure and immutable. There is no state in a functional programming language.

## The Package Manager
- By far the best of the three is Nix the package manager. It allows declarative, rather than imperative, package management. This provides repoducibility among many systems, including even MacOS!
- An interesting (although not very useful for many) result that comes from this declarative structure is the fact that a system configured in this declarative way can survive bit rot. 
- Nix shells allow you to temporarily download packages for one time uses. The package manager will then garbage collect (at your discretion) and remove these packages. No longer do you have to worry about bloat accumulating from packages you forgot to remove!

# Update Commands
- nix flake update
- sudo nixos-rebuild switch --flake .#default
- home-manager switch --flake .#axelcool1234

# Rollback Command
- sudo nixos-rebuild switch --flake .#default --rollback

# Delete Generations
https://discourse.nixos.org/t/why-doesnt-nix-collect-garbage-remove-old-generations-from-efi-menu/17592/2

The following doens't work (or it kind of does). Keeping it here just in case.
- List generations: `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system`
- Switch to working generation: `sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation [generation number]`
- Delete generation(s): `sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations [generation number(s)]`
- Cleanup: `nix-collect-garbage -d`

# Fresh Install
Firstly... DON'T PANIC! This will be an easy transition - even if we only have the terminal (I'm assuming we start in the base home directory).
1. Execute `sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos`
2. Execute `sudo nix-channel --list` and ensure you only have the unstable branch as a channel. Call `sudo nix-channel --remove [name]` if that's not the case.
3. Execute `sudo nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager`
4. Execute `sudo nix-channel --update`
- This website has more information about installing home-manager (you shouldn't need this, but just in case!): 
  https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone
- To ensure it has been installed correctly, try "man home-configuration.nix" - this might only work after step 5.
5. Execute `nix-shell -p home-manager git`
6. Clone this repository - `git clone https://github.com/axelcool1234/.dotfiles.git`
7. Execute `cp /etc/nixos/hardware-configuration.nix .dotfiles/hosts/Legion-Laptop/hardware-configuration.nix`
7. Execute `cd .dotfiles`
8. Execute `nix flake update` (you may need to temporarily enable experimental features for the command)
9. Execute `sudo nixos-rebuild switch --flake .#default`
10. Execute `home-manager switch --flake .#axelcool1234`

## Mismatched Hash
If home-manager fails to install due to a mismatch in a hash, that means we need to update that hash. If you don't know where the mismatched hash is, I recommend:
1. Execute `nix-shell -p ripgrep`
2. Execute `rg` and then part of the name of the derivation with the mismatched hash. You should be able to find where it's located. 
3. Change the `sha256` of the derivation with the `sha256` the home-manager error outputted.
4. Try to execute `home-manager switch --flake .#axelcool1234` again.

Once this is all done, we can execute `reboot` and get into our system. It should be just as how you remembered it! Remember to commit and push these .dotfiles,
since you called `nix flake update`! You may need to do the post-setup steps to be able to properly commit and push these changes.

## Post-Setup
We need to make sure our github is configured with an SSH key so we can actually develop! Arguably, this step should be set up using something like sops Nix. At some point
I'll have to learn how to use that - or some other secret management system for Nix.
1. Execute `ssh-keygen`
2. Execute `cat` and wherever the result of the `ssh-keygen` was stored. We want the `.pub` file to be outputted, so we can copy it.
3. Paste the copied SSH key on github by going to Settings -> "SSH and GPG Keys" -> "New SSH Key" and then save the new SSH key
4. Execute `cd .dotfiles`
5. Execute `git remote set-url origin git@github.com:axelcool1234/.dotfiles.git`
6. Execute `git fetch`

You can now commit and push changes to the .dotfiles to GitHub!

# Lost Bootloader
Has your bootloader been wiped? Try this:
1. Boot up a live installation USB (as long as it's Linux this solution should work)
2. Execute `lsblk -o +LABEL` and identify your Linux root partition (the one with the most space) and the boot partition (should be something like 512 MB)
2. Execute `sudo mount /dev/[linux root partition] /mnt` 
3. Execute `sudo mount /dev/[linux boot partition] /mnt/boot`
4. `cd` to `/mnt`
5. Execute `cd /home/axelcool1234/.dotfiles`
6. Execute `sudo nixos-install --flake .#default`

Your bootloader should've been reinstalled. Now, when you reboot, GRUB (or whatever bootloader being used at the time) should start up.
Make sure to execute `nixos-switch` once you've booted into NixOS so that GRUB can be reconfigured.

For more information, I learned how to do this from this [discussion](https://www.reddit.com/r/NixOS/comments/183jlh5/comment/kapafke/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button).

# Useful NixOS Resources:
- https://mynixos.com/
  - Search for NixOS options, packages, categories (plus the website has some videos and tutorials)
- https://search.nixos.org/options
  - Search for NixOS options
- https://search.nixos.org/packages
  - Search for Nix packages
- https://www.nixhub.io/
  - Search for granular versions of Nix packages
- https://lazamar.co.uk/nix-versions/
  - Search for ALL versions of a Nix package and the revision you can download it from
- https://noogle.dev/
  - Search the NixLang library
