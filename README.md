# OrangeVault Protocol

**Decentralized Bitcoin-backed liquidity vaults with automated yield generation on Stacks**

OrangeVault is a **non-custodial DeFi protocol** that enables Bitcoin holders to participate in yield-bearing strategies without relinquishing ownership. Users lock STX in **time-locked vaults** that generate sustainable yield through protocol-governed parameters.

The protocol is deployed on **Stacks Layer 2**, inheriting Bitcoin’s security while offering programmable, transparent, and decentralized vault management.

---

## 🌐 System Overview

* **Users** deposit STX into vaults with a chosen lock duration (minimum 144 blocks ≈ 24h).
* Deposits accrue yield based on protocol’s **base APY** (default 8%).
* Yield is distributed in STX, with a **protocol fee** (default 2%) deducted at claim.
* Users can **claim rewards**, **extend lock duration**, or **withdraw** their vault after maturity.
* Protocol maintains **global statistics** (TVL, vault count, APY, fee).
* Governance functions allow the **contract owner** to adjust protocol parameters.

---

## 🔑 Key Features

* **Non-custodial**: Users retain vault ownership at all times.
* **Transparent rewards**: On-chain calculation of APY-based accrual.
* **Time-locked vaults**: Flexible durations, ensuring sustainable participation.
* **Automated yield claims**: Rewards can be claimed without unlocking principal.
* **Protocol fee mechanism**: Sustainable treasury through fee collection.
* **Governance-ready**: Adjustable parameters (APY, fees).

---

## 📐 Contract Architecture

### **Core Data Variables**

* `total-value-locked` → Tracks cumulative STX in protocol.
* `vault-counter` → Sequential identifier for vault creation.
* `protocol-fee-percentage` → Fee in basis points (max 10%).
* `base-apy` → Default APY in basis points (e.g., 800 = 8%).

### **Maps**

* **Vaults** → Stores metadata for each vault:

  * `owner`
  * `amount`
  * `deposit-block`
  * `lock-until-block`
  * `last-claim-block`
  * `is-active`

* **User-vault-ids** → Maps each user to a list of their vault IDs.

* **Accumulated-rewards** → Tracks total historical rewards earned per vault.

---

## ⚙️ Data Flow (High-level)

1. **Vault Creation**

   * User calls `create-vault(amount, lock-blocks)`.
   * STX is transferred to contract, vault is registered, TVL increments.

2. **Reward Accrual**

   * Rewards are calculated via `calculate-rewards(vault-id)` using block difference since last claim.

3. **Claiming Rewards**

   * User calls `claim-rewards(vault-id)`.
   * Protocol deducts fee → net rewards sent to vault owner.
   * Updates last claim block and accumulated rewards.

4. **Withdrawal**

   * After maturity (`lock-until-block`), user can withdraw.
   * Rewards are auto-claimed, then principal is returned.
   * Vault marked inactive, TVL decrements.

5. **Governance Adjustments**

   * `set-base-apy` → adjusts base APY.
   * `set-protocol-fee` → adjusts fee % (capped at 10%).

---

## 📊 Protocol Parameters

| Parameter                 | Default | Description                        |
| ------------------------- | ------- | ---------------------------------- |
| `min-lock-period`         | 144     | Minimum lock (≈ 24h)               |
| `base-apy`                | 800     | Default APY = 8%                   |
| `protocol-fee-percentage` | 200     | Fee = 2% (basis points: 200/10000) |
| `vault-list-size`         | 100     | Max vaults tracked per user        |

---

## 🛠️ Public Functions

* `create-vault(amount, lock-blocks)` → Creates a new vault.
* `claim-rewards(vault-id)` → Claims accrued rewards.
* `withdraw-vault(vault-id)` → Withdraws principal + rewards after maturity.
* `extend-lock(vault-id, additional-blocks)` → Extends lock period.

---

## 🛡️ Governance Functions

* `set-base-apy(new-apy)` → Adjusts global APY.
* `set-protocol-fee(new-fee)` → Adjusts fee % (max 10%).

---

## 📈 Example Flow

1. Alice locks **1,000 STX** for 10,000 blocks.
2. Vault ID `#5` created → accrues ~8% APY.
3. After 5,000 blocks, Alice calls `claim-rewards(5)` → receives rewards minus fee.
4. After 10,000 blocks, Alice withdraws → receives 1,000 STX principal + remaining rewards.

---

## 🧩 Future Extensions

* Dynamic yield strategies via protocol-managed liquidity pools.
* DAO governance to replace centralized contract-owner.
* Multi-asset support (sBTC, stablecoins).
* Composable integrations with other DeFi protocols on Stacks.

---

## 📜 License

MIT License. Use at your own risk. Protocol is experimental and unaudited.
