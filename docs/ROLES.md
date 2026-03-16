# WhisprPayroll — Roles & Permissions

## Role Hierarchy

```
DEFAULT_ADMIN_ROLE (Owner)
  └── ADMIN_ROLE
        ├── PAYROLL_MANAGER_ROLE
        └── VIEWER_ROLE
```

> The hierarchy controls who can **grant/revoke** roles, not who inherits permissions. Each role's permissions are independent.

---

## Roles

### DEFAULT_ADMIN_ROLE (Owner)

The contract deployer (employer). Holds full control over the contract.

| Action | Function |
|---|---|
| Set payment token | `setToken(address)` |
| Pause contract | `pause()` |
| Unpause contract | `unpause()` |
| Grant/revoke Admin role | inherited from OpenZeppelin AccessControl |

### ADMIN_ROLE (Admin)

Manages employees, salaries, and lower roles.

| Action | Function |
|---|---|
| Add employee | `addEmployee(address)` |
| Remove employee | `removeEmployee(address)` |
| Activate/deactivate employee | `toggleEmployeeStatus(address)` |
| Set encrypted salary | `setSalary(address, externalEuint64, bytes)` |
| Grant/revoke Payroll Manager role | inherited from OpenZeppelin AccessControl |
| Grant/revoke Viewer role | inherited from OpenZeppelin AccessControl |

### PAYROLL_MANAGER_ROLE (Manager)

Executes payroll. Cannot manage employees or salaries.

| Action | Function |
|---|---|
| Pay all active employees | `executeBatchPayroll()` |
| Pay specific employees | `executeBatchPayroll(address[])` |

### VIEWER_ROLE (Viewer)

On-chain presence only. No write permissions.

| Action | Function |
|---|---|
| — | Read-only access, no gated functions |

---

## Notes

- The employer receives **all four roles** at deploy time.
- An Admin cannot execute payroll unless also granted `PAYROLL_MANAGER_ROLE`.
- The employer can revoke all roles because they hold both `DEFAULT_ADMIN_ROLE` and `ADMIN_ROLE`.
