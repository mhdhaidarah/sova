<p align="center">
  <img src="sova-logo.svg" width="112" alt="Sova logo">
</p>

<h1 align="center">Sova</h1>
<p align="center"><b>SecuryTik Overlay &amp; VPN Automation</b><br>
Join every branch and every remote employee into one private network — through one hub you own.</p>

<p align="center">
  <a href="https://sova.securytik.com">Website</a> ·
  <a href="https://sova.securytik.com/docs">Docs</a> ·
  <a href="https://sova.securytik.com/pricing">Pricing</a> ·
  <a href="https://github.com/mhdhaidarah/sova/releases/latest">Latest release</a>
</p>

---

## Why Sova

Most branch offices sit behind NAT with no public IP. Sova turns a small Ubuntu VPS into the **hub** of your
network: every MikroTik branch dials out to it, every remote employee connects to it, and everything can
reach everything else **as if they were in the same building** — real addresses, no NAT inside the fleet.

| | |
|---|---|
| 🏢 **Site-to-site** | Each branch gets its own block (`10.<site>.0.0/16`) and one subnet per purpose — servers, users, printers, cameras — at the same third octet everywhere. |
| 🔀 **Dynamic routing** | OSPF over the tunnels: add a branch later and every other branch learns it by itself. The hub only accepts a branch's own addresses. |
| 🛡️ **Two tunnels per branch** | WireGuard first, L2TP/IPsec as automatic backup. |
| 📋 **Paste-ready RouterOS scripts** | Fill in a site, paste one line into the MikroTik terminal. Idempotent — paste again any time. |
| 🧑‍💻 **Remote access** | WireGuard (QR code) or native L2TP/IPsec. *Corporate* (split tunnel) or *Full passthrough* (all traffic via the hub). Per-user access to sites and subnet types. |
| 🔒 **Policies & DNS** | Allow/deny rules between any subnets, enforced at the hub. Internal DNS names for every site. |
| 📈 **Monitoring & alerts** | Tunnel latency, loss, traffic, route checks, site-down alerts to Telegram, WhatsApp and email. Editable dashboards. |
| 🛠️ **Manager** | Monitor and control the branch MikroTiks: health, time zone, DNS, updates, website & app filtering, bulk actions. |
| 🔌 **API & webhooks** | REST API with scoped tokens; signed webhooks for sites, users and alerts. |
| ☁️ **Cloudflare Tunnel** | Put the panel on your own domain in one step. |

## Install

On a fresh **Ubuntu 24.04 or 26.04** VPS with a public IP (1 vCPU / 1 GB RAM is enough for small fleets):

```bash
curl -fsSL https://sova.securytik.com/install.sh | sudo bash
```

**github.com blocked in your country?** The command above detects it and switches to the SecuryTik
mirror by itself — or install straight from the mirror (same installer, nothing fetched from GitHub):

```bash
curl -fsSL https://dl.securytik.com/sova-install.sh | sudo bash
```

The installer sets up the hub (WireGuard, FRR, strongSwan, xl2tpd, nftables, unbound), PostgreSQL, the panel
behind nginx with a Let's Encrypt certificate, and prints the panel address and the first admin password.

Open the panel → **Sites → + Site** → add its subnets → paste the one-line command into the branch MikroTik.

## Plans

| Plan | Sites | Remote users | Price |
|---|---|---|---|
| Free | 2 | 1 | Free |
| Lite | 5 | 3 | 30 USDT / month |
| Pro | 10 | 6 | 50 USDT / month |
| Max | 20 | 12 | 100 USDT / month |
| Unlimited | ∞ | ∞ | 175 USDT / month |

Yearly billing gets two months free. Every requested plan is **approved for one month free** to try it.

## Updates

Sova checks for signed releases daily and updates itself from **System → Update**.

## Forgot the admin password?

On the hub, as root (the tool is in [`tools/`](tools/sova-reset-admin-password.sh)):

```bash
curl -fsSL -o sova-reset-admin-password.sh \
  https://raw.githubusercontent.com/mhdhaidarah/sova/main/tools/sova-reset-admin-password.sh
sudo bash sova-reset-admin-password.sh --list   # list the superadmin accounts
sudo bash sova-reset-admin-password.sh          # reset (asks for the new password twice)
```

It changes only that account's password (and re-enables the account) — no site, tunnel or user data.

---

<p align="center">Sova is a <a href="https://securytik.com">SecuryTik</a> product. This repository holds the compiled
releases; the source is closed. © 2026 SecuryTik.</p>
