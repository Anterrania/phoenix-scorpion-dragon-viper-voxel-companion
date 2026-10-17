---
title: Aethel Coin Exchange
slug: aethel-coin-exchange
tags: [economy, aethel-coin, aec, exchange, lindex, legal]
audience: all
status: partial
updated: 2026-10-17
sources: [scripts/economy/currency_exchange.gd, scripts/economy/marketplace.gd, data/economy/marketplace_exchange_model.json, data/economy/land_and_fees.json]
ticket: WIKI-5
---

# Aethel Coin Exchange (AEX)

> **Partial.** The order matching code exists as a scaffold. It is **not in the app UI**, and trades don't settle to wallets yet.

> ⚠ **LEGAL REVIEW REQUIRED.** Aethel Coin (AEC) and the exchange must get legal and compliance review **before going live**. That covers money-transmitter licensing, KYC/AML, sanctions screening, tax reporting and app-store payment rules. Until then, AEC is a closed game currency: no cash-out, and it is not crypto.

## What it is
- Like Second Life's Lindex: players post buy and sell orders for AEC.
- Today the scaffold is in-game only. There is no real money.

## Orders
| Part | Status | How |
|---|---|---|
| Buy order (bid) | partial | Quantity and price. Highest price first. |
| Sell order (ask) | partial | Quantity and price. Lowest price first. |
| Matching | partial | Matches while best bid ≥ best ask. The trade fills at the ask price. |
| Market vs limit orders | planned | In the data model only. |
| Order status (open, partial, filled, cancelled) | planned | |
| Settlement to wallet | planned | Ledger TODO. |
| Exchange screen in app | planned | No button yet. |

## Market rate
- **Planned:** the last fill price, shown on an OHLC chart (1h / 1d / 1w).
- No live rate exists. There is no rate in USD.

## Fees
- **0.5% per trade** (50 basis points) in the scaffold. The fee is **burned**, which removes AEC from the game.
- Final fee: **Planned**. Awaiting the owner's input.

## Limits
- **Built:** you can't buy a Marketplace item without enough AEC ("not enough Aethel Coin").
- **Planned:** per-day trade limits, minimum order size and account checks. None are set.

## Ties to land & uploads
- Land and uploads are priced in AEC. **All prices are placeholders.** The data model has no server yet.
- Upload fee: charged per mesh, texture, sound or animation upload. Free for the owner/admin.
- Land: parcel, homestead, region and planet tiers, each with a buy price and a monthly fee.
- Plan: players buy AEC on the exchange to pay land and upload fees. Those fees, and the trade fee, are sinks.

## What works now
- Local wallet on your phone.
- **MENU › 👜 Wardrobe › List on Marketplace** saves a local draft listing.

See also: [Economy](economy.md) · [Economy Metrics](economy-metrics.md)
