import { ethers } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying cUSDT with:", deployer.address);

    // Sepolia USDT address
    const SEPOLIA_USDT = "0x7169D38820dfd117C3FA1f22a697dBA58d90BA06";

    const ConfidentialUSDT = await ethers.getContractFactory("ConfidentialUSDT");
    const cUSDT = await ConfidentialUSDT.deploy(SEPOLIA_USDT, deployer.address);
    await cUSDT.waitForDeployment();
    const cUSDTAddress = await cUSDT.getAddress();

    console.log("\n=== cUSDT Deployment Complete ===");
    console.log("ConfidentialUSDT deployed:", cUSDTAddress);
    console.log("\nImport this token in the Whispr Wallet using the contract address above.");
    console.log("Mark it as a confidential token (ERC-7984) when importing.");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
