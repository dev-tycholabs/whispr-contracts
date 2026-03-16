# Contract 3: WhisprPayrollFactory

## Overview

A factory contract that deploys new `WhisprPayroll` instances — one per organization. When an employer creates an organization in the Whispr app, the frontend calls this factory to deploy a dedicated payroll contract and stores the resulting address in Supabase (`organizations.payroll_contract_address`).

**Inherits:** `ZamaEthereumConfig`
**Deployed:** Once, globally on Sepolia
**Purpose:** Deploy and track WhisprPayroll contracts

---

## Features

### 1. Deploy Payroll Contract

- Called by: Anyone (any employer creating an org)
- `createPayroll(address employer)` — deploys a new `WhisprPayroll` instance
- The `employer` address becomes the `DEFAULT_ADMIN_ROLE` holder (owner) of the new payroll contract
- The ConfidentialUSDC token address is automatically set on the new contract (factory knows it)
- Returns the deployed contract address
- Emits `PayrollCreated(address payrollContract, address employer, uint256 timestamp)`

### 2. Token Address Configuration

- `setTokenAddress(address cUSDCAddress)` — sets the ConfidentialUSDC address used for all new deployments
- Called once after ConfidentialUSDC is deployed
- Only callable by the factory owner
- All subsequently deployed payroll contracts will reference this token

### 3. Registry of Deployed Contracts

#### By Employer
- `getPayrollContracts(address employer) → address[]` — returns all payroll contracts deployed by an employer
- Maps to the multi-org model: one employer can have multiple organizations, each with its own payroll contract

#### By Index
- `getPayrollContractCount() → uint256` — total number of deployed contracts
- `getPayrollContractAt(uint256 index) → address` — get contract address by index
- Useful for admin/analytics purposes

#### Validation
- `isWhisprPayroll(address) → bool` — check if an address was deployed by this factory
- Prevents spoofing — the frontend can verify a contract address is legitimate before interacting

### 4. Ownership

- Factory has a single owner (the Whispr deployer)
- Owner can:
  - Set/update the ConfidentialUSDC token address
  - No other special powers — anyone can deploy payroll contracts
- Uses OpenZeppelin `Ownable`

---

## Storage

```
address public tokenAddress;                              // ConfidentialUSDC address
mapping(address => address[]) private employerPayrolls;   // employer → their payroll contracts
address[] private allPayrolls;                            // all deployed contracts
mapping(address => bool) private isDeployedPayroll;       // address → was deployed by factory
```

---

## Functions Summary

| Function | Access | Description |
|----------|--------|-------------|
| `createPayroll(address employer) → address` | Public | Deploy new WhisprPayroll for an org |
| `setTokenAddress(address cUSDC)` | Owner | Set ConfidentialUSDC address |
| `getPayrollContracts(address employer) → address[]` | Public | List employer's payroll contracts |
| `getPayrollContractCount() → uint256` | Public | Total deployed contracts |
| `getPayrollContractAt(uint256 index) → address` | Public | Get contract by index |
| `isWhisprPayroll(address) → bool` | Public | Verify contract authenticity |
| `tokenAddress() → address` | Public | Get configured cUSDC address |

---

## Events

| Event | When |
|-------|------|
| `PayrollCreated(address indexed payrollContract, address indexed employer, uint256 timestamp)` | New payroll contract deployed |
| `TokenAddressUpdated(address newTokenAddress)` | cUSDC address changed |

---

## Deployment Flow (End-to-End)

```
1. Deploy ConfidentialUSDC (wrapping Sepolia USDC)
   → Get cUSDC address

2. Deploy WhisprPayrollFactory
   → Call factory.setTokenAddress(cUSDCAddress)
   → Store factory address in constants.ts as PAYROLL_FACTORY_ADDRESS

3. Employer creates organization in Whispr app
   → Frontend calls factory.createPayroll(employerWallet)
   → Factory deploys new WhisprPayroll
   → Returns payroll contract address
   → Frontend saves address to Supabase (organizations.payroll_contract_address)
   → Frontend saves address to constants/env

4. Employer funds payroll
   → usdc.approve(cUSDCAddress, amount)
   → cUSDC.wrap(amount)
   → cUSDC.setOperator(payrollContractAddress, true, expiration)

5. Employer adds employees + sets salaries
   → payroll.addEmployee(wallet)
   → payroll.setSalary(wallet, encryptedSalary, proof)

6. Employer executes payroll
   → payroll.executeBatchPayroll(employeeAddresses)
   → cUSDC transfers from employer to each employee
```

---

## Integration with Whispr Frontend

| Frontend Location | Contract Interaction |
|---|---|
| Organization Setup (OrganizationSetup.tsx) | `factory.createPayroll(employerWallet)` → save returned address to Supabase |
| Create New Org (AppShell.tsx org switcher) | Same as above |
| Org Settings — Contract Address | Auto-populated from factory deployment, read-only display |
| Verify contract (any page) | `factory.isWhisprPayroll(address)` before interacting |

---

## Dependencies

- `@openzeppelin/contracts` — `Ownable`
- `@fhevm/solidity` — `ZamaEthereumConfig`
- `WhisprPayroll` — the contract bytecode to deploy
