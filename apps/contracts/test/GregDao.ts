import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { expect } from 'chai'
import hre from 'hardhat'

const deploy = async () => {
  const contract = await hre.viem.deployContract('GregToken', [
    '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // initialOwner (default hardhat account)
    '0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401', // nameWrapperAddress (mainnet deployment)
  ])

  return { contract }
}

describe('Tests', function () {
  it('should return the contract name', async function () {
    const { contract } = await loadFixture(deploy)

    const contractName = await contract.read.name()
    expect(contractName).to.equal('Greg')
  })
})
