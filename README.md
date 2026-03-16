# Whispr Contracts

Smart contracts for **Whispr** — a confidential payroll platform powered by fully homomorphic encryption (FHE). Employee salaries and payment amounts are encrypted on-chain using [Zama's fhEVM](https://docs.zama.ai/fhevm), so no one can see how much anyone gets paid unless explicitly authorized.

Built on Ethereum Sepolia with [ERC-7984](https://eips.ethereum.org/EIPS/eip-7984) confidential tokens and OpenZeppelin's confidential contracts.

---

## How It Works

```
Employer                          Blockchain                         Employee
   │                                  │                                  │
   ├── approve USDC ─────────────────►│                                  │
   ├── wrap() ───────────────────────►│  USDC → cUSDC (encrypted)       │
   ├── setOperator(payroll) ─────────►│  grant payroll contract access   │
   ├── addEmployee(wallet) ──────────►│                                  │
   ├── setSalary(encrypted) ─────────►│  salary stored as euint64        │
   ├── executeBatchPayroll() ────────►│  cUSDC transferred to employees  │
   │                                  │                                  │
   │                                  │◄── requestUnwrap() ──────────────┤
   │                                  │◄── finalizeUnwrap() ─────────────┤
   │                                  │  cUSDC → USDC (decrypted)  ─────►│
```

All balances and transfer amounts remain encrypted on-chain. Only authorized parties can decrypt values client-side via the Zama Relayer SDK.

---

## Contracts

| Contract | Description |
|---|---|
| `ConfidentialUSDC` | ERC-7984 wrapper that converts USDC → cUSDC (encrypted). 1:1 ratio. |
| `WhisprPayroll` | Per-organization payroll contract. Stores encrypted salaries, manages roles, executes batch payments. |
| `WhisprPayrollFactory` | Deploys and tracks `WhisprPayroll` instances — one per organization. |

### ConfidentialUSDC

ERC-7984 confidential token wrapping standard USDC. Key operations:

- `wrap(amount)` — deposit USDC, receive encrypted cUSDC
- `requestUnwrap()` → `finalizeUnwrap()` — two-step unwrap (async FHE decryption)
- `confidentialTransfer()` — transfer encrypted amounts between users
- `setOperator(payrollContract, true, expiration)` — authorize payroll contract to pull funds
- `confidentialBalanceOf(address)` — returns encrypted balance handle (ACL-gated decryption)

### WhisprPayroll

Deployed per organization via the factory. Features:

- Role-based access control (Owner / Admin / Payroll Manager / Viewer)
- Encrypted salary storage with ACL-gated decryption
- Batch payroll execution (all employees or specific groups)
- Employee management (add, remove, activate/deactivate)
- Payroll history and audit trail
- Emergency pause/unpause

### WhisprPayrollFactory

Global singleton that deploys payroll contracts:

- `createPayroll(employer)` — deploy a new `WhisprPayroll` for an organization
- `isWhisprPayroll(address)` — verify a contract was deployed by this factory
- Registry of all deployed contracts by employer

---

## Role Hierarchy

```
DEFAULT_ADMIN_ROLE (Owner)
  └── ADMIN_ROLE
        ├── PAYROLL_MANAGER_ROLE
        └── VIEWER_ROLE
```

| Role | Permissions |
|---|---|
| Owner | Full control. Set token, pause/unpause, manage admins. |
| Admin | Add/remove employees, set salaries, manage managers and viewers. |
| Payroll Manager | Execute batch payroll only. Cannot see salary amounts. |
| Viewer | Read-only on-chain presence. No write access. |

See [`docs/ROLES.md`](docs/ROLES.md) for the full breakdown.

---

## Salary Privacy (ACL)

When a salary is set, FHE access control grants decryption rights to:

| Who | Can Decrypt |
|---|---|
| Contract itself | Needs salary for transfer computation |
| Employer (Owner) | Sees all salaries |
| Employee | Sees their own salary |
| Admin who set it | Sees the salary they configured |
| Payroll Manager | Cannot see amounts — can only trigger execution |

---

## Tech Stack

- **Solidity 0.8.28** (Cancun EVM)
- **Hardhat** — compilation, testing, deployment
- **Zama fhEVM** (`@fhevm/solidity` 0.9.1) — encrypted computation
- **OpenZeppelin Contracts** (v5.3.0) — AccessControl, Ownable, Pausable
- **OpenZeppelin Confidential Contracts** (v0.3.1) — ERC-7984 token wrapper
- **TypeScript** — deployment scripts and type bindings

---

## Project Structure

```
whispr-contracts/
├── src/                          # Solidity contracts
│   ├── ConfidentialUSDC.sol      # cUSDC wrapper (ERC-7984)
│   ├── WhisprPayroll.sol         # Per-org payroll contract
│   └── WhisprPayrollFactory.sol  # Factory for deploying payroll contracts
├── scripts/                      # Deployment & utility scripts
│   └── deploy.ts                 # Deploy cUSDC + Factory to Sepolia
├── specs/                        # Detailed contract specifications
│   ├── 01_CONFIDENTIAL_USDC.md
│   ├── 02_WHISPR_PAYROLL.md
│   └── 03_WHISPR_PAYROLL_FACTORY.md
├── docs/
│   └── ROLES.md                  # Role hierarchy documentation
├── test/                         # Test files
├── typechain-types/              # Auto-generated TypeScript bindings
├── hardhat.config.ts
├── package.json
└── tsconfig.json
```

---

## Getting Started

### Prerequisites

- Node.js (v18+)
- npm

### Install

```bash
npm install
```

### Compile

```bash
npm run compile
```

### Test

```bash
npm run test
```

### Deploy to Sepolia

1. Copy the environment template:

```bash
cp .env.example .env
```

2. Add your deployer private key to `.env`:

```
DEPLOYER_PRIVATE_KEY="your_private_key_here"
```

3. Deploy:

```bash
npm run deploy:sepolia
```

This deploys `ConfidentialUSDC` and `WhisprPayrollFactory`, configures the factory with the cUSDC address, and outputs the contract addresses to add to your frontend `.env`.

---

## Deployment Flow (End-to-End)

1. **Deploy contracts** — `ConfidentialUSDC` + `WhisprPayrollFactory`
2. **Configure factory** — `factory.setTokenAddress(cUSDCAddress)`
3. **Create organization** — `factory.createPayroll(employerWallet)` → returns payroll contract address
4. **Fund payroll** — `usdc.approve()` → `cUSDC.wrap(amount)` → `cUSDC.setOperator(payrollContract, true, expiration)`
5. **Add employees** — `payroll.addEmployee(wallet)` → `payroll.setSalary(wallet, encryptedSalary, proof)`
6. **Execute payroll** — `payroll.executeBatchPayroll()`

---

## Key Addresses (Sepolia)

| Asset | Address |
|---|---|
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` |

---

## License

BSD-3-Clause-Clear
