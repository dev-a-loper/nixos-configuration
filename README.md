Here is an improved README with more details about using the NixOS configuration:

# My personal NixOS configuration

This repository contains my personal NixOS configuration files. Before using this configuration, you will need:

## Secret management

- A `./vars/secrets.<username>.nix` file containing sensitive information like API keys. Key entries include (see `system/userInfo.nix` for the full schema):
  - `proxies` / `defaultProxy` - Attrset of proxy shell scripts (each listens on port 1080) and the default proxy name
  - `OPENAI_API_KEY` - OpenAI's API key
  - `location` - an attributeset of Latitude and longitude of your current location (for praytimes and redshift)
- A hardware configuration file at `./vars/hardware-configuration.nix` for your system (not needed for building the ISO file)

You can build the configuration for different systems:

## Home Desktop

```bash
sudo nixos-rebuild switch --flake .#nixos-home-desktop --impure # For home PC
```

## Laptop

```bash
sudo nixos-rebuild switch --flake .#nixos-laptop --impure # For laptop
```

## ISO File

```bash
sudo nixos-rebuild switch --flake .#iso --impure # For the ISO file
```

## installation steps

- make a bootable nixos iso ( it can be the iso built with this configuration itself in this case we have less files needed for download)
- boot iso in system
- create needed partitions
- mount needed partitions to /mnt and /mnt/boot ( and any other partition )
- generate nixos configuration with `nixos-generate-config --root /mnt`
- copy `/mnt/etc/nixos/hardware-configuration.nix` to `./vars/hardware-configuration.nix` in the repository
- add your secrets file to `./vars/secrets.<username>.nix`
- run `sudo nixos-install --flake path:./#<system-name> --impure`
- wait for installation

## Usb installation

this configuration contains a file (./hosts/usb.nix) which is a configuration for installing the os on the usb (not iso but complete installation) with disk encryption
for this purpose we first need to use disko to partition the system and mount stuff

```sh
sudo nix run github:nix-community/disko -- --mode disko hosts/usb-disko.nix
```

adding a password for the disk encryption

```sh
echo -n "some-super-secure-password" > /tmp/secret.key
```

and installing the os:

```sh
sudo nixos-install --flake path:./#usb --impure --root /mnt
```

and have fun :)

### A few steps after installation

altough almost everything is preconfigured there are still a few things left to do

- logging in to telegram and other apps
- setting telegram cofigurations ( its not feasible to configure it through nix stuff)
- enabling web extensions ( they are already installed but its necessary to configure them and enable them )
- setting up v2raya proxies
- logging github using gh
- and probably more
