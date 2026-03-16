import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config({ path: "../.env" });
dotenv.config(); // also load local .env for DEPLOYER_PRIVATE_KEY

const SEPOLIA_RPC_URL = process.env.NEXT_PUBLIC_RPC_URL || "https://api.web3auth.io/infura-service/v1/0xaa36a7/BHNYAKq2NMUoOfLnUCGcivEVFUIiRuR3pScDzRKNt-BmbJkv_qxuscTvBdiV3dpQDAR46RIEOfaWE3CQqX3kZxI";
const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000001";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.28",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
            evmVersion: "cancun",
        },
    },
    networks: {
        sepolia: {
            url: SEPOLIA_RPC_URL,
            accounts: [DEPLOYER_PRIVATE_KEY],
            chainId: 11155111,
        },
        hardhat: {
            chainId: 31337,
        },
    },
    paths: {
        sources: "./src",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts",
    },
};

export default config;
