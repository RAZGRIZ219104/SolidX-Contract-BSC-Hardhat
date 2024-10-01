import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const INFURA_API_KEY = "9035dd7723dc40ef9181c62592494061";
const BSC_PRIVATE_KEY =
  "d7d61b55853fe16838d6f85d52a04a6b8fabe835dc8a6a465e1cb6e09b117e9f";
const BSCSCAN_API_KEY = "A2XTV3VJM2T2KDU71PH8WD395J6H2WM9HW";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [`0x${BSC_PRIVATE_KEY}`],
    },
    BSC: {
      url: "https://bsc-dataseed.bnbchain.org/",
      chainId: 56,
      accounts: [`0x${BSC_PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: BSCSCAN_API_KEY,
  },
  sourcify: {
    enabled: true,
  },
};

export default config;
