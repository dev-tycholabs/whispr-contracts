import { ethers } from "hardhat";

/**
 * Wraps USDT into cUSDT and sends it directly to a recipient.
 *
 * The ERC7984ERC20Wrapper.wrap(to, amount) accepts any recipient address,
 * so we can wrap directly to the target — no need for encrypted transfer.
 */
async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Using deployer:", deployer.address);

    const CUSDT_ADDRESS = "0x9770b4Fe0a3fF951d0b9F898FbdFa432b168b968";
    const USDT_ADDRESS = "0x7169D38820dfd117C3FA1f22a697dBA58d90BA06";
    const RECIPIENT = "0x50225a18De8ce4525199B41FB1FE88b937783b32";
    const AMOUNT = ethers.parseUnits("10", 6); // 10 USDT (6 decimals)

    const usdt = await ethers.getContractAt(
        ["function approve(address,uint256) returns (bool)", "function balanceOf(address) view returns (uint256)", "function allowance(address,address) view returns (uint256)"],
        USDT_ADDRESS,
        deployer,
    );

    const cUsdt = await ethers.getContractAt(
        ["function wrap(address to, uint256 amount)"],
        CUSDT_ADDRESS,
        deployer,
    );

    // Check USDT balance
    const balance = await usdt.balanceOf(deployer.address);
    console.log("Deployer USDT balance:", ethers.formatUnits(balance, 6));
    if (balance < AMOUNT) {
        throw new Error(`Insufficient USDT. Have ${ethers.formatUnits(balance, 6)}, need ${ethers.formatUnits(AMOUNT, 6)}`);
    }

    // Step 1: Approve cUSDT contract to spend USDT
    console.log("\n1. Approving USDT spend...");
    const allowance = await usdt.allowance(deployer.address, CUSDT_ADDRESS);
    if (allowance < AMOUNT) {
        const approveTx = await usdt.approve(CUSDT_ADDRESS, AMOUNT);
        await approveTx.wait();
        console.log("   Approved:", approveTx.hash);
    } else {
        console.log("   Already approved, skipping.");
    }

    // Step 2: Wrap USDT → cUSDT directly to recipient
    console.log(`\n2. Wrapping ${ethers.formatUnits(AMOUNT, 6)} USDT → cUSDT to ${RECIPIENT}...`);
    const wrapTx = await cUsdt.wrap(RECIPIENT, AMOUNT);
    await wrapTx.wait();
    console.log("   Wrap tx:", wrapTx.hash);

    console.log("\n=== Done ===");
    console.log(`${ethers.formatUnits(AMOUNT, 6)} cUSDT sent to ${RECIPIENT}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
