import '@nomicfoundation/hardhat-toolbox-viem'
import '@nomicfoundation/hardhat-verify'
import 'dotenv/config'
import { HardhatUserConfig } from 'hardhat/config'

const DEPLOYER_KEY = process.env.DEPLOYER_KEY

if (!DEPLOYER_KEY) throw new Error('DEPLOYER_KEY must be set')

const config: HardhatUserConfig = {
  networks: {
    mainnet: {
      url: 'https://eth.drpc.org',
      accounts: [DEPLOYER_KEY],
    },
    localhost: {
      accounts: [DEPLOYER_KEY],
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.21',
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000,
          },
        },
      },
    ],
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || '',
    },
  },
  paths: {
    sources: './src',
  },
}

export default config
