const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Governance System", function () {
  it("deploys Governor contract correctly", async function () {
    const Token = await ethers.getContractFactory("GovernanceToken");
    const token = await Token.deploy();
    await token.waitForDeployment();

    const Governor = await ethers.getContractFactory("MyGovernor");
    const governor = await Governor.deploy(await token.getAddress());
    await governor.waitForDeployment();

    expect(await governor.name()).to.equal("MyGovernor");
  });
});
