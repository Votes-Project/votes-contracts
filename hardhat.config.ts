import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@truffle/dashboard-hardhat-plugin";

import { etherscan as etherscanKey } from "./apiKeys.json";

const config: HardhatUserConfig = {
  solidity: "0.8.18",
  defaultNetwork: "truffleDashboard",
  etherscan: {
    apiKey: etherscanKey
  }
};

export default config;
