# Contract 2: WhisprPayroll

## Overview

The core payroll contract deployed per organization. Stores encrypted employee salaries, manages team role-based access control, and executes batch payroll payments using cUSDC. Each organization gets its own instance deployed via the WhisprPayrollFactory.

**Inherits:** `ZamaEthereumConfig`, `AccessControl`
**Deployed by:** `WhisprPayrollFactory`
**One instance per:** Organization

---

## Features

### 1. Role-Based Access Control (Team Page Integration)

Maps directly to the Team page roles in the Whispr frontend.

| On-chain Role | Constant | Team Page Role | Permissions |
|---|---|---|---|
| `DEFAULT_ADMIN_ROLE` | (built-in) | Owner | Everything. Grant/revoke all roles. Only role that can manage admins. |
| `ADMIN_ROLE` | `keccak256("ADMIN_ROLE")` | Admin | Add/remove employees, set/update salaries, execute payroll, manage payroll_managers and viewers |
| `PAYROLL_MANAGER_ROLE` | `keccak256("PAYROLL_MANAGER_ROLE")` | Payroll Manager | Execute payroll only |
| `VIEWER_ROLE` | `keccak256("VIEWER_ROLE")` | Viewer | No write functions. On-chain presence only for potential future ACL grants |

Role hierarchy:
- `DEFAULT_ADMIN_ROLE` is the admin of `ADMIN_ROLE`
- `ADMIN_ROLE` is the admin of `PAYROLL_MANAGER_ROLE` and `VIEWER_ROLE`
- Owner can revoke any role at any time via `revokeRole(role, address)`
- Admins can grant/revoke payroll_manager and viewer roles

### 2. Employee Management

#### Add Employee
- Called by: `ADMIN_ROLE` or higher
- `addEmployee(address employee)` — registers an employee wallet address in the contract
- Stores the employee in an on-chain mapping and array
- Employee must be added before a salary can be set

#### Remove Employee
- Called by: `ADMIN_ROLE` or higher
- `removeEmployee(address employee)` — deactivates an employee
- Clears their encrypted salary
- They can no longer receive payroll payments

#### Get Employees
- `getEmployees()` — returns array of all active employee addresses
- `isEmployee(address)` — check if an address is a registered active employee
- `getEmployeeCount()` — returns count of active employees

### 3. Encrypted Salary Management

#### Set Salary
- Called by: `ADMIN_ROLE` or higher
- `setSalary(address employee, externalEuint64 encryptedSalary, bytes calldata inputProof)`
- Converts the encrypted input: `FHE.fromExternal(encryptedSalary, inputProof)`
- Stores as `euint64` in `mapping(address => euint64) salaries`
- Sets ACL permissions:
  - `FHE.allowThis(salary)` — contract can use it for payroll computation
  - `FHE.allow(salary, owner)` — org owner can always decrypt
  - `FHE.allow(salary, employee)` — employee can decrypt their own salary
  - `FHE.allow(salary, msg.sender)` — the admin who set it can decrypt

#### Update Salary
- Same function as `setSalary()` — overwrites the previous encrypted value
- New ACL permissions are set on the new ciphertext
- Old ciphertext handle becomes stale (ACL on old handle remains but it's no longer referenced)

#### Get Encrypted Salary
- `getEncryptedSalary(address employee) → euint64`
- Returns the encrypted salary handle
- Only addresses with ACL access (owner, employee, setting admin) can decrypt it via the Relayer SDK

### 4. Batch Payroll Execution

#### Execute Payroll (All Employees)
- Called by: `PAYROLL_MANAGER_ROLE` or higher
- `executeBatchPayroll()` — pays all active employees with set salaries
- For each employee:
  1. Reads their `euint64` salary from storage
  2. Calls `cUSDC.confidentialTransferFrom(employer, employee, salary)` using operator permissions
- The payroll contract must be set as an operator on the employer's cUSDC balance beforehand
- Emits `PayrollExecuted(uint256 payrollId, uint256 employeeCount, uint256 timestamp)`

#### Execute Payroll (Specific Employees)
- Called by: `PAYROLL_MANAGER_ROLE` or higher
- `executeBatchPayroll(address[] calldata employees)` — pays only the specified employees
- Used for group-based payroll (frontend filters employees by group, passes the addresses)
- Same transfer logic as above but only for the provided list
- Validates each address is a registered active employee with a set salary

#### Payroll Tracking
- `payrollCount` — total number of payroll executions
- `getPayrollInfo(uint256 payrollId) → (uint256 timestamp, uint256 employeeCount, address executedBy)`
- On-chain record of each payroll run for audit trail

### 5. Funding & Token Reference

#### Set Token Address
- Called at initialization (by factory) or by owner
- `setToken(address cUSDCAddress)` — sets the ConfidentialUSDC token contract address
- The payroll contract needs to know which token to transfer

#### Employer Address
- `employer()` — returns the employer (org owner) address
- This is the address from which cUSDC is pulled during payroll
- Set at deployment by the factory

#### Check Readiness
- `isPayrollReady()` — returns true if:
  - Token address is set
  - Payroll contract is an approved operator on the employer's cUSDC
  - At least one employee has a salary set

### 6. Emergency Controls

#### Pause
- Called by: `DEFAULT_ADMIN_ROLE` (owner) only
- `pause()` / `unpause()` — halts all payroll execution
- Employee/salary management still works while paused
- Uses OpenZeppelin `Pausable`

---

## Storage

```
mapping(address => euint64) private salaries;       // employee → encrypted salary
mapping(address => bool) private activeEmployees;    // employee → is active
address[] private employeeList;                      // all employee addresses
address public employer;                             // org owner who funds payroll
address public token;                                // ConfidentialUSDC address
uint256 public payrollCount;                         // total payroll executions
mapping(uint256 => PayrollRecord) public payrolls;   // payroll history
```

---

## Functions Summary

| Function | Access | Description |
|----------|--------|-------------|
| `addEmployee(address)` | ADMIN_ROLE | Register employee wallet |
| `removeEmployee(address)` | ADMIN_ROLE | Deactivate employee |
| `setSalary(address, externalEuint64, bytes)` | ADMIN_ROLE | Set/update encrypted salary |
| `getEncryptedSalary(address) → euint64` | Public (ACL-gated decryption) | Get salary ciphertext handle |
| `executeBatchPayroll()` | PAYROLL_MANAGER_ROLE | Pay all active employees |
| `executeBatchPayroll(address[])` | PAYROLL_MANAGER_ROLE | Pay specific employees |
| `getEmployees() → address[]` | Public | List active employees |
| `getEmployeeCount() → uint256` | Public | Count active employees |
| `isEmployee(address) → bool` | Public | Check if registered |
| `setToken(address)` | DEFAULT_ADMIN_ROLE | Set cUSDC token address |
| `isPayrollReady() → bool` | Public | Check if payroll can execute |
| `grantRole(bytes32, address)` | Role admin | Grant team role |
| `revokeRole(bytes32, address)` | Role admin | Revoke team role (instant) |
| `pause()` / `unpause()` | DEFAULT_ADMIN_ROLE | Emergency stop |

---

## Events

| Event | When |
|-------|------|
| `EmployeeAdded(address employee)` | Employee registered |
| `EmployeeRemoved(address employee)` | Employee deactivated |
| `SalarySet(address employee)` | Salary set/updated (amount NOT in event — encrypted) |
| `PayrollExecuted(uint256 payrollId, uint256 employeeCount, address executedBy, uint256 timestamp)` | Batch payroll completed |
| `TokenSet(address token)` | cUSDC address configured |
| `RoleGranted(bytes32 role, address account, address sender)` | Team member role granted (from AccessControl) |
| `RoleRevoked(bytes32 role, address account, address sender)` | Team member role revoked (from AccessControl) |

---

## ACL Pattern for Salaries

When `setSalary(employee, encryptedSalary, proof)` is called:

```
FHE.allowThis(salary)           → Contract can read salary for payroll transfers
FHE.allow(salary, employer)     → Org owner can always decrypt
FHE.allow(salary, employee)     → Employee can decrypt their own salary
FHE.allow(salary, msg.sender)   → The admin who set it can decrypt
```

This means:
- Employee sees only their own salary
- Employer sees all salaries
- Admin who set a salary can see that salary
- Payroll managers cannot see salary amounts — they can only trigger execution
- Viewers see nothing

---

## Integration with Whispr Frontend

| Frontend Location | Contract Interaction |
|---|---|
| Add Employee (EmployerEmployees.tsx) | `payroll.addEmployee(walletAddress)` + `payroll.setSalary(wallet, encrypted, proof)` |
| Update Salary (EmployerEmployees.tsx) | `payroll.setSalary(wallet, newEncrypted, proof)` |
| Deactivate Employee | `payroll.removeEmployee(walletAddress)` |
| Execute Payroll (EmployerPayroll.tsx) | `payroll.executeBatchPayroll(employeeAddresses)` |
| Decrypt Salary — Employer | `payroll.getEncryptedSalary(emp)` → `userDecrypt()` via Relayer SDK |
| Decrypt Salary — Employee | `payroll.getEncryptedSalary(myAddress)` → `userDecrypt()` via Relayer SDK |
| Invite Team Member (Team.tsx) | `payroll.grantRole(ROLE, memberWallet)` |
| Remove Team Member (Team.tsx) | `payroll.revokeRole(ROLE, memberWallet)` |
| Change Team Role (Team.tsx) | `payroll.revokeRole(oldRole, wallet)` + `payroll.grantRole(newRole, wallet)` |
| Org Settings — Contract Address | Auto-populated after factory deployment |

---

## Dependencies

- `@openzeppelin/contracts` — `AccessControl`, `Pausable`
- `@fhevm/solidity` — `ZamaEthereumConfig`, `FHE`, `euint64`, `externalEuint64`
- `ConfidentialUSDC` — the cUSDC token contract (for `confidentialTransferFrom`)
