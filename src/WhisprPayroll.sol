// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import {FHE, euint64, externalEuint64} from "@fhevm/solidity/lib/FHE.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Minimal interface for cUSDC operator transfers.
interface IConfidentialToken {
    function confidentialTransferFrom(
        address from,
        address to,
        euint64 amount
    ) external returns (euint64);
}

/**
 * @title WhisprPayroll
 * @notice Per-organization payroll contract. Stores encrypted salaries,
 *         manages team roles, and executes batch cUSDC payments.
 *
 * Roles (maps to Whispr Team page):
 *   DEFAULT_ADMIN_ROLE → Owner   (full control)
 *   ADMIN_ROLE         → Admin   (employees + salaries + payroll)
 *   PAYROLL_MANAGER    → Manager (execute payroll only)
 *   VIEWER_ROLE        → Viewer  (on-chain presence, no writes)
 */
contract WhisprPayroll is ZamaEthereumConfig, AccessControl, Pausable {
    // ── Roles ───────────────────────────────────────────────────────────
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAYROLL_MANAGER_ROLE =
        keccak256("PAYROLL_MANAGER_ROLE");
    bytes32 public constant VIEWER_ROLE = keccak256("VIEWER_ROLE");

    // ── Storage ─────────────────────────────────────────────────────────
    address public employer; // org owner — funds are pulled from this address
    address public token; // ConfidentialUSDC address

    mapping(address => euint64) private salaries;
    mapping(address => bool) private activeEmployees;
    mapping(address => bool) private deactivatedEmployees;
    address[] private employeeList;

    uint256 public payrollCount;

    struct PayrollRecord {
        uint256 timestamp;
        uint256 employeeCount;
        address executedBy;
    }
    mapping(uint256 => PayrollRecord) public payrolls;

    // ── Events ──────────────────────────────────────────────────────────
    event EmployeeAdded(address indexed employee);
    event EmployeeRemoved(address indexed employee);
    event EmployeeStatusToggled(address indexed employee, bool active);
    event SalarySet(address indexed employee);
    event PayrollExecuted(
        uint256 indexed payrollId,
        uint256 employeeCount,
        address indexed executedBy,
        uint256 timestamp
    );
    event TokenSet(address indexed token);

    // ── Errors ──────────────────────────────────────────────────────────
    error NotAnEmployee(address account);
    error AlreadyEmployee(address account);
    error NoSalarySet(address employee);
    error TokenNotSet();
    error NoEmployeesToPay();
    error ZeroAddress();

    // ── Constructor ─────────────────────────────────────────────────────
    constructor(address _employer, address _token) {
        if (_employer == address(0)) revert ZeroAddress();

        employer = _employer;
        token = _token;

        // Role hierarchy setup — employer gets every role at deploy
        _grantRole(DEFAULT_ADMIN_ROLE, _employer);
        _grantRole(ADMIN_ROLE, _employer);
        _grantRole(PAYROLL_MANAGER_ROLE, _employer);
        _grantRole(VIEWER_ROLE, _employer);

        // ADMIN_ROLE administers PAYROLL_MANAGER and VIEWER
        _setRoleAdmin(PAYROLL_MANAGER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(VIEWER_ROLE, ADMIN_ROLE);
        // DEFAULT_ADMIN_ROLE administers ADMIN_ROLE (default behavior)
    }

    // ── Employee Management ─────────────────────────────────────────────

    function addEmployee(address _employee) external onlyRole(ADMIN_ROLE) {
        if (_employee == address(0)) revert ZeroAddress();
        if (activeEmployees[_employee]) revert AlreadyEmployee(_employee);

        activeEmployees[_employee] = true;
        employeeList.push(_employee);

        emit EmployeeAdded(_employee);
    }

    function removeEmployee(address _employee) external onlyRole(ADMIN_ROLE) {
        if (!activeEmployees[_employee]) revert NotAnEmployee(_employee);

        activeEmployees[_employee] = false;
        deactivatedEmployees[_employee] = false;
        // Clear salary — old ciphertext handle becomes stale
        salaries[_employee] = FHE.asEuint64(0);

        emit EmployeeRemoved(_employee);
    }

    /**
     * @notice Toggle an employee between active and deactivated.
     *         Deactivated employees keep their salary but are skipped during payroll.
     */
    function toggleEmployeeStatus(
        address _employee
    ) external onlyRole(ADMIN_ROLE) {
        if (!activeEmployees[_employee]) revert NotAnEmployee(_employee);

        deactivatedEmployees[_employee] = !deactivatedEmployees[_employee];

        emit EmployeeStatusToggled(_employee, !deactivatedEmployees[_employee]);
    }

    /**
     * @notice Returns true if the employee is deactivated (still on roster but skipped in payroll).
     */
    function isDeactivated(address _employee) external view returns (bool) {
        return deactivatedEmployees[_employee];
    }

    function getEmployees() external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < employeeList.length; i++) {
            if (activeEmployees[employeeList[i]]) count++;
        }

        address[] memory active = new address[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < employeeList.length; i++) {
            if (activeEmployees[employeeList[i]]) {
                active[idx++] = employeeList[i];
            }
        }
        return active;
    }

    function getEmployeeCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < employeeList.length; i++) {
            if (activeEmployees[employeeList[i]]) count++;
        }
        return count;
    }

    function isEmployee(address _account) external view returns (bool) {
        return activeEmployees[_account];
    }

    // ── Salary Management ───────────────────────────────────────────────

    /**
     * @notice Set or update an employee's encrypted salary.
     * @dev ACL grants: contract (for payroll), employer, employee, and the caller.
     */
    function setSalary(
        address _employee,
        externalEuint64 _encryptedSalary,
        bytes calldata _inputProof
    ) external onlyRole(ADMIN_ROLE) {
        if (!activeEmployees[_employee]) revert NotAnEmployee(_employee);

        euint64 salary = FHE.fromExternal(_encryptedSalary, _inputProof);

        salaries[_employee] = salary;

        // ACL: who can decrypt this salary
        FHE.allowThis(salary); // contract needs it for transfers
        FHE.allow(salary, employer); // org owner always sees salaries
        FHE.allow(salary, _employee); // employee sees their own
        FHE.allow(salary, token); // cUSDC token needs it for confidentialTransferFrom
        if (msg.sender != employer) {
            FHE.allow(salary, msg.sender); // admin who set it can see it
        }

        emit SalarySet(_employee);
    }

    /**
     * @notice Returns the encrypted salary handle. Only ACL-permitted addresses
     *         can decrypt it via the Relayer SDK.
     */
    function getEncryptedSalary(
        address _employee
    ) external view returns (euint64) {
        return salaries[_employee];
    }

    // ── Payroll Execution ───────────────────────────────────────────────

    /**
     * @notice Execute payroll for ALL active employees with set salaries.
     */
    function executeBatchPayroll()
        external
        onlyRole(PAYROLL_MANAGER_ROLE)
        whenNotPaused
    {
        if (token == address(0)) revert TokenNotSet();

        address[] memory toPay = _getPayableEmployees();
        if (toPay.length == 0) revert NoEmployeesToPay();

        _executePayments(toPay);
    }

    /**
     * @notice Execute payroll for a specific list of employees (group-based).
     * @param _employees Array of employee addresses to pay.
     */
    function executeBatchPayroll(
        address[] calldata _employees
    ) external onlyRole(PAYROLL_MANAGER_ROLE) whenNotPaused {
        if (token == address(0)) revert TokenNotSet();
        if (_employees.length == 0) revert NoEmployeesToPay();

        // Validate all addresses
        for (uint256 i = 0; i < _employees.length; i++) {
            if (!activeEmployees[_employees[i]])
                revert NotAnEmployee(_employees[i]);
            if (deactivatedEmployees[_employees[i]])
                revert NotAnEmployee(_employees[i]);
            if (!FHE.isInitialized(salaries[_employees[i]]))
                revert NoSalarySet(_employees[i]);
        }

        _executePayments(_employees);
    }

    function _executePayments(address[] memory _employees) private {
        IConfidentialToken cToken = IConfidentialToken(token);

        for (uint256 i = 0; i < _employees.length; i++) {
            euint64 salary = salaries[_employees[i]];
            cToken.confidentialTransferFrom(employer, _employees[i], salary);
        }

        payrollCount++;
        payrolls[payrollCount] = PayrollRecord({
            timestamp: block.timestamp,
            employeeCount: _employees.length,
            executedBy: msg.sender
        });

        emit PayrollExecuted(
            payrollCount,
            _employees.length,
            msg.sender,
            block.timestamp
        );
    }

    function _getPayableEmployees() private view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < employeeList.length; i++) {
            address emp = employeeList[i];
            if (
                activeEmployees[emp] &&
                !deactivatedEmployees[emp] &&
                FHE.isInitialized(salaries[emp])
            ) {
                count++;
            }
        }

        address[] memory result = new address[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < employeeList.length; i++) {
            address emp = employeeList[i];
            if (
                activeEmployees[emp] &&
                !deactivatedEmployees[emp] &&
                FHE.isInitialized(salaries[emp])
            ) {
                result[idx++] = emp;
            }
        }
        return result;
    }

    // ── Configuration ───────────────────────────────────────────────────

    function setToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_token == address(0)) revert ZeroAddress();
        token = _token;
        emit TokenSet(_token);
    }

    // ── Readiness Check ─────────────────────────────────────────────────

    /**
     * @notice Returns true if the contract is ready to execute payroll:
     *         token set, and at least one employee with a salary.
     */
    function isPayrollReady() external view returns (bool) {
        if (token == address(0)) return false;

        for (uint256 i = 0; i < employeeList.length; i++) {
            address emp = employeeList[i];
            if (
                activeEmployees[emp] &&
                !deactivatedEmployees[emp] &&
                FHE.isInitialized(salaries[emp])
            ) {
                return true;
            }
        }
        return false;
    }

    // ── Payroll History ─────────────────────────────────────────────────

    function getPayrollInfo(
        uint256 _payrollId
    )
        external
        view
        returns (uint256 timestamp, uint256 employeeCount, address executedBy)
    {
        PayrollRecord memory record = payrolls[_payrollId];
        return (record.timestamp, record.employeeCount, record.executedBy);
    }

    // ── Emergency Controls ──────────────────────────────────────────────

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
