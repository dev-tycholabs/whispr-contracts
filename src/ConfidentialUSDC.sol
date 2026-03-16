// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.27;

import {ZamaEthereumConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import {
    ERC7984
} from "@openzeppelin/confidential-contracts/token/ERC7984/ERC7984.sol";
import {
    ERC7984ERC20Wrapper
} from "@openzeppelin/confidential-contracts/token/ERC7984/extensions/ERC7984ERC20Wrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    Ownable2Step,
    Ownable
} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title ConfidentialUSDC (cUSDC)
 * @notice ERC-7984 confidential token wrapping Sepolia USDC at 1:1 ratio.
 *         All balances and transfer amounts are encrypted via Zama fhEVM.
 *
 * Flow:
 *   1. Employer approves USDC spend → calls wrap() → receives cUSDC (encrypted balance)
 *   2. Payroll contract (as operator) transfers cUSDC to employees
 *   3. Employees call unwrap() → finalizeUnwrap() to get USDC back
 */
contract ConfidentialUSDC is
    ZamaEthereumConfig,
    ERC7984ERC20Wrapper,
    Ownable2Step
{
    // ── Constructor ─────────────────────────────────────────────────────
    constructor(
        address _underlyingUSDC,
        address _owner
    )
        ERC7984("Confidential USDC", "cUSDC", "")
        ERC7984ERC20Wrapper(IERC20(_underlyingUSDC))
        Ownable(_owner)
    {}

    // ── View helpers ────────────────────────────────────────────────────

    /// @notice Returns the underlying USDC contract address.
    function underlyingUSDC() external view returns (address) {
        return address(underlying());
    }
}
