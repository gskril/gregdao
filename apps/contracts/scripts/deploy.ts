import hre from 'hardhat'
import { encodeAbiParameters } from 'viem/utils'

import { generateSaltAndDeploy } from './lib/create2'

async function main() {
  const contractName = 'GregToken'

  const constructorArguments = [
    '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // initialOwner (default hardhat account)
    '0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401', // nameWrapperAddress (mainnet deployment)
  ] as const

  const encodedArgs = encodeAbiParameters(
    [{ type: 'address' }, { type: 'address' }],
    constructorArguments
  )

  const { address } = await generateSaltAndDeploy({
    vanity: '0x92e9',
    encodedArgs,
    contractName,
    caseSensitive: false,
    startingIteration: 0,
  })

  console.log(`Deployed ${contractName} to ${address}`)

  try {
    // Wait 30 seconds for block explorers to index the deployment
    await new Promise((resolve) => setTimeout(resolve, 30_000))
    await hre.run('verify:verify', { address, constructorArguments })
  } catch (error) {
    console.error(error)
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
