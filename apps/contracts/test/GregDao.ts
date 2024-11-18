import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { expect } from 'chai'
import hre from 'hardhat'

const deploy = async () => {
  const contract = await hre.viem.deployContract('GregToken', [
    '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // initialOwner (default hardhat account)
  ])

  return { contract }
}

describe('Tests', function () {
  it('should return the contract name', async function () {
    const { contract } = await loadFixture(deploy)

    const contractName = await contract.read.name()
    expect(contractName).to.equal('Greg')
  })

  it('should return true for eligible names', async function () {
    const { contract } = await loadFixture(deploy)
    const names = ['greg.eth', 'gregskril.eth', 'higreg.eth', 'agregb.eth']

    for (const name of names) {
      const label = name.split('.')[0]
      const isEligible = await contract.read.isEligible([name])
      expect(isEligible).to.deep.equal([true, label])
    }
  })

  it('should return false for ineligible names', async function () {
    const { contract } = await loadFixture(deploy)
    const names = ['name.eth', 'sub.greg.eth', 'gregskril.com']

    for (const name of names) {
      const isEligible = await contract.read.isEligible([name])
      expect(isEligible).to.deep.equal([false, ''])
    }
  })
})
