<!--toc:start-->
- [What Is Nix?](#what-is-nix)
  - [The Operating System](#the-operating-system)
  - [The Language](#the-language)
  - [The Package Manager](#the-package-manager)
- [Update Commands](#update-commands)
- [Rollback Command](#rollback-command)
- [Fresh Install](#fresh-install)
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

# Fresh Install
Firstly... DON'T PANIC! This will be an easy transition - even if we only have the terminal!
1. Execute `sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos`
2. Execute `sudo nix-channel --list` and ensure you only have the unstable branch as a channel. Call `sudo nix-channel --remove [name]` if that's not the case.
3. Execute `sudo nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager`
4. Execute `sudo nix-channel --update`
- This website has more information about installing home-manager (you shouldn't need this, but just in case!): 
  https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone
- To ensure it has been installed correctly, try "man home-configuration.nix" - this might only work after step 5.
5. Execute `nix-shell -p home-manager git`
6. Clone this repository
7. Execute `cp /etc/nixos/hardware-configuration.nix .dotfiles/hosts/Legion-Laptop/hardware-configuration.nix`
7. Execute `cd .dotfiles`
8. Execute `nix flake update` (you may need to temporarily enable experimental features for the command)
9. Execute `sudo nixos-rebuild switch --flake .#default`
10. Execute `home-manager switch --flake .#axelcool1234`

If home-manager fails to install due to a mismatch in a hash, that means we need to update that hash. If you don't know where the mismatched hash is, I recommend:
1. Execute `nix-shell -p ripgrep`
2. Execute `rg` and then part of the name of the derivation with the mismatched hash. You should be able to find where it's located. 
3. Change the `sha256` of the derivation with the `sha256` the home-manager error outputted.
4. Try to execute `home-manager switch --flake .#axelcool1234` again.

Once this is all done, we can execute `reboot` and get into our system. It should be just as how you remembered it! Remember to commit and push these .dotfiles,
since you called `nix flake update`!

# Useful NixOS Resources:
- https://mynixos.com/
  - Great for browsing options from NixOS and Home-manager
- https://search.nixos.org/packages
  - Great for searching for available packages
- https://noogle.dev/
  - Great for searching the NixLang library
