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
- By far the best of the three is Nix the package manager. This allows declarative, rather than imperative, package management. This repoducibility among many systems, including even MacOS!
- An interesting (although not very useful for many) result that comes from this declarative structure is the fact that a system configured in this declarative way can survive bit rot. 
- Nix shells allow you to temporarily download packages for one time uses. The package manager will then garbage collect (at your discretion) and remove these packages. No longer do you have to worry about bloat accumulating from packages you forgot to remove!

# Update Commands
- nix flake update
- sudo nixos-rebuild switch --flake .#default
- home-manager switch --flake .#axelcool1234

# Rollback Command
- sudo nixos-rebuild switch --flake .#default --rollback


# Fresh Install
https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone
- Go to Standalone installation
- Copy the commands for the unstable channel
- To ensure it has been installed correctly, try "man home-configuration.nix"

# Useful NixOS Resources:
- https://mynixos.com/
- https://search.nixos.org/packages
