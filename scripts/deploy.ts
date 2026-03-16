import { ethers } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying with:", deployer.address);

    // ── 1. ConfidentialUSDC ─────────────────────────────────────────────
    // Replace with actual Sepolia USDC address
    const SEPOLIA_USDC = process.env.SEPOLIA_USDC_ADDRESS || "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238";

    const ConfidentialUSDC = await ethers.getContractFactory("ConfidentialUSDC");
    const cUSDC = await ConfidentialUSDC.deploy(SEPOLIA_USDC, deployer.address);
    await cUSDC.waitForDeployment();
    const cUSDCAddress = await cUSDC.getAddress();
    console.log("ConfidentialUSDC deployed:", cUSDCAddress);

    // ── 2. WhisprPayrollFactory ─────────────────────────────────────────
    const Factory = await ethers.getContractFactory("WhisprPayrollFactory");
    const factory = await Factory.deploy(deployer.address);
    await factory.waitForDeployment();
    const factoryAddress = await factory.getAddress();
    console.log("WhisprPayrollFactory deployed:", factoryAddress);

    // ── 3. Configure factory with token address ─────────────────────────
    const tx = await factory.setTokenAddress(cUSDCAddress);
    await tx.wait();
    console.log("Factory token address set to:", cUSDCAddress);

    // ── Summary ─────────────────────────────────────────────────────────
    console.log("\n=== Deployment Complete ===");
    console.log("NEXT_PUBLIC_CONFIDENTIAL_TOKEN_ADDRESS=" + cUSDCAddress);
    console.log("NEXT_PUBLIC_PAYROLL_FACTORY_ADDRESS=" + factoryAddress);
    console.log("\nAdd these to your .env file.");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
