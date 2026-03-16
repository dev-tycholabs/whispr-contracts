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
 * @title ConfidentialUSDT (cUSDT)
 * @notice ERC-7984 confidential token wrapping Sepolia USDT at 1:1 ratio.
 *         All balances and transfer amounts are encrypted via Zama fhEVM.
 *
 * Flow:
 *   1. User approves USDT spend → calls wrap() → receives cUSDT (encrypted balance)
 *   2. Confidential transfers between users via confidentialTransfer()
 *   3. Users call unwrap() → finalizeUnwrap() to get USDT back
 */
contract ConfidentialUSDT is
    ZamaEthereumConfig,
    ERC7984ERC20Wrapper,
    Ownable2Step
{
    // ── Constructor ─────────────────────────────────────────────────────
    constructor(
        address _underlyingUSDT,
        address _owner
    )
        ERC7984("Confidential USDT", "cUSDT", "")
        ERC7984ERC20Wrapper(IERC20(_underlyingUSDT))
        Ownable(_owner)
    {}

    // ── View helpers ────────────────────────────────────────────────────

    /// @notice Returns the underlying USDT contract address.
    function underlyingUSDT() external view returns (address) {
        return address(underlying());
    }
}
