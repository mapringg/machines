#!/usr/bin/env bash
# ubuntu.sh — desktop, 931GB NVMe, user mapring, hostname `ubuntu`
# Ubuntu 26.04.1 LTS Desktop, stock GNOME. Safe to re-run.
#
# MANUAL STEPS — do these first, they can't be scripted:
#   BIOS      see README — shared with windows.ps1
#   Installer LUKS encryption on, ext4, hostname `ubuntu`
#            (delete all partitions on BOTH disks during the Windows install first,
#             so Windows can't hijack an EFI partition on this drive)
#   After     sign in to 1Password; point Déjà Dup at the external drive;
#             set Ubuntu as the default boot entry
#
set -euo pipefail

# --- everything below is filled in as the machine is built ---
# Installs: tailscale, 1password, ghostty, docker, mise, tmux
# Firefox, Thai input (ibus) and Déjà Dup already ship with Ubuntu.
