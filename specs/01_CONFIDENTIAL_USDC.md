# Contract 1: ConfidentialUSDC

## Overview

An ERC-7984 confidential token that wraps Sepolia USDC at a 1:1 ratio. Employers deposit standard USDC and receive cUSDC (Confidential USDC) with fully encrypted balances. Employees who receive cUSDC as salary can unwrap it back to standard USDC.

**Inherits:** `ZamaEthereumConfig`, `ERC7984ERC20Wrapper`
**Token Name:** Confidential USDC
**Token Symbol:** cUSDC
**Underlying Asset:** USDC on Ethereum Sepolia
**Ratio:** 1 USDC = 1 cUSDC (1:1, accounting for decimal conversion via `rate()`)

---

## Features

### 1. Wrap USDC → cUSDC
- Employer calls `approve(confidentialUSDCAddress, amount)` on the USDC contract
- Then calls `wrap(amount)` on ConfidentialUSDC
- USDC is transferred from employer to the wrapper contract
- Equivalent cUSDC is minted to the employer's address as an encrypted balance
- The employer's `confidentialBalanceOf()` increases by the wrapped amount (encrypted)

### 2. Unwrap cUSDC → USDC
- Employee (or anyone holding cUSDC) calls `requestUnwrap(encryptedAmount, inputProof)`
- This initiates an async decryption request (FHE decryption is not instant)
- Once decryption completes, the user calls `finalizeUnwrap(requestId)`
- The wrapper burns the cUSDC and transfers the equivalent USDC back to the user
- Two-step process because FHE decryption requires the Gateway/KMS

### 3. Confidential Transfers
- All transfers use encrypted amounts — `confidentialTransfer(to, encryptedAmount, inputProof)`
- Balances are never visible on-chain in plaintext
- The ERC-7984 standard handles ACL automatically on transfers:
  - Sender's balance ciphertext: sender has access
  - Recipient's balance ciphertext: recipient has access

### 4. Operator System (for Payroll Contract)
- Employer calls `setOperator(payrollContractAddress, true, expiration)` on cUSDC
- This allows the WhisprPayroll contract to call `confidentialTransferFrom()` on behalf of the employer
- The payroll contract can then pull cUSDC from the employer and distribute to employees
- Operator approval has an expiration timestamp for security
- Employer can revoke operator access at any time with `setOperator(payrollContract, false, 0)`

### 5. Encrypted Balance Queries
- `confidentialBalanceOf(address)` returns `euint64` — an encrypted handle
- Only the address owner (and anyone they've granted ACL access) can decrypt it
- Used by the frontend to show encrypted balance on dashboards
- Decryption happens client-side via the Zama Relayer SDK (`userDecrypt()`)

### 6. Decimal Handling
- Standard USDC has 6 decimals (1 USDC = 1,000,000 units)
- ERC-7984 uses `euint64` for all amounts
- The `rate()` function from `ERC7984ERC20Wrapper` handles the conversion
- Example: wrapping 5000 USDC (5000 * 10^6 = 5,000,000,000 raw units) → mints equivalent cUSDC as euint64

---

## Functions Summary

| Function | Access | Description |
|----------|--------|-------------|
| `wrap(uint256 amount)` | Public | Deposit USDC, receive cUSDC |
| `requestUnwrap(externalEuint64 amount, bytes inputProof)` | Public | Start unwrap (async decryption) |
| `finalizeUnwrap(uint256 requestId)` | Public | Complete unwrap after decryption |
| `confidentialTransfer(address to, externalEuint64 amount, bytes inputProof)` | Public | Transfer cUSDC (encrypted input) |
| `confidentialTransfer(address to, euint64 amount)` | Public | Transfer cUSDC (already encrypted) |
| `confidentialTransferFrom(address from, address to, euint64 amount)` | Operator | Operator transfer (used by payroll contract) |
| `setOperator(address operator, bool approved, uint256 expiration)` | Public | Grant/revoke operator with expiry |
| `confidentialBalanceOf(address account)` | Public | Returns encrypted balance handle |
| `confidentialApprove(address spender, externalEuint64 amount, bytes inputProof)` | Public | Set encrypted allowance |

---

## Events

| Event | When |
|-------|------|
| `ConfidentialTransfer(address from, address to)` | On any cUSDC transfer (amounts not in event — they're encrypted) |
| `Wrap(address account, uint256 usdcAmount)` | When USDC is wrapped to cUSDC |
| `UnwrapRequest(uint256 requestId, address account)` | When unwrap is requested |
| `UnwrapFinalized(uint256 requestId, address account, uint256 usdcAmount)` | When unwrap completes |

---

## Integration with Whispr Frontend

| Frontend Location | Contract Interaction |
|---|---|
| Employer deposits funds | `usdc.approve()` → `cUSDC.wrap(amount)` |
| Employer dashboard — balance | `cUSDC.confidentialBalanceOf(employer)` → `userDecrypt()` |
| Employee dashboard — wallet balance | `cUSDC.confidentialBalanceOf(employee)` → `userDecrypt()` |
| Employee withdraws to USDC | `cUSDC.requestUnwrap()` → wait → `cUSDC.finalizeUnwrap()` |
| Employer grants payroll contract access | `cUSDC.setOperator(payrollAddress, true, expiration)` |

---

## Dependencies

- `@openzeppelin/confidential-contracts` — `ERC7984ERC20Wrapper`
- `@fhevm/solidity` — `ZamaEthereumConfig`, `FHE`, `euint64`
- Sepolia USDC contract address (underlying ERC-20)
