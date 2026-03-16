// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {WhisprPayroll} from "./WhisprPayroll.sol";

/**
 * @title WhisprPayrollFactory
 * @notice Deploys and tracks WhisprPayroll instances — one per organization.
 *         Deployed once globally on Sepolia.
 */
contract WhisprPayrollFactory is ZamaEthereumConfig, Ownable {
    // ── Storage ─────────────────────────────────────────────────────────
    address public tokenAddress; // ConfidentialUSDC

    mapping(address => address[]) private employerPayrolls; // employer → payroll contracts
    address[] private allPayrolls; // every deployed contract
    mapping(address => bool) private isDeployedPayroll; // quick lookup

    // ── Events ──────────────────────────────────────────────────────────
    event PayrollCreated(
        address indexed payrollContract,
        address indexed employer,
        uint256 timestamp
    );
    event TokenAddressUpdated(address indexed newTokenAddress);

    // ── Errors ──────────────────────────────────────────────────────────
    error ZeroAddress();
    error TokenNotConfigured();

    // ── Constructor ─────────────────────────────────────────────────────
    constructor(address _owner) Ownable(_owner) {}

    // ── Token Configuration ─────────────────────────────────────────────

    /**
     * @notice Set the ConfidentialUSDC address. Called once after cUSDC deployment.
     */
    function setTokenAddress(address _tokenAddress) external onlyOwner {
        if (_tokenAddress == address(0)) revert ZeroAddress();
        tokenAddress = _tokenAddress;
        emit TokenAddressUpdated(_tokenAddress);
    }

    // ── Deploy Payroll ──────────────────────────────────────────────────

    /**
     * @notice Deploy a new WhisprPayroll for an organization.
     * @param _employer The org owner whose cUSDC funds payroll.
     * @return payrollAddress The deployed contract address.
     */
    function createPayroll(
        address _employer
    ) external returns (address payrollAddress) {
        if (_employer == address(0)) revert ZeroAddress();
        if (tokenAddress == address(0)) revert TokenNotConfigured();

        WhisprPayroll payroll = new WhisprPayroll(_employer, tokenAddress);
        payrollAddress = address(payroll);

        employerPayrolls[_employer].push(payrollAddress);
        allPayrolls.push(payrollAddress);
        isDeployedPayroll[payrollAddress] = true;

        emit PayrollCreated(payrollAddress, _employer, block.timestamp);
    }

    // ── Registry Queries ────────────────────────────────────────────────

    function getPayrollContracts(
        address _employer
    ) external view returns (address[] memory) {
        return employerPayrolls[_employer];
    }

    function getPayrollContractCount() external view returns (uint256) {
        return allPayrolls.length;
    }

    function getPayrollContractAt(
        uint256 _index
    ) external view returns (address) {
        return allPayrolls[_index];
    }

    function isWhisprPayroll(address _address) external view returns (bool) {
        return isDeployedPayroll[_address];
    }
}
