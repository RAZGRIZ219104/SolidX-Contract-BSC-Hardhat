import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { experimentalAddHardhatNetworkMessageTraceHook } from "hardhat/config";

describe("Escrow Contract Test", function () {
  async function deploy() {
    const [owner] = await ethers.getSigners();

    const quote = await ethers.deployContract("Quote");
    await quote.waitForDeployment();
    console.log("Quote deployed to address:", await quote.getAddress());

    const dealContract = await ethers.deployContract(
      "DealContract",
      [
        "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d", // USDC
        "0xA76A6cC7fa9ab055b6101d443FD975520eb8cC75", // SOLIDX
      ],
      {
        libraries: {
          Quote: await quote.getAddress(),
        },
      }
    );
    await dealContract.waitForDeployment();
    console.log(
      "DealContract deployed to address:",
      await dealContract.getAddress()
    );

    const serviceEscrow = await ethers.deployContract(
      "ServiceEscrow",
      [
        "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d", // USDC
        "0xA76A6cC7fa9ab055b6101d443FD975520eb8cC75", // SOLIDX
      ],
      {
        libraries: {
          Quote: await quote.getAddress(),
        },
      }
    );
    await serviceEscrow.waitForDeployment();
    console.log(
      "ServiceEscrow deployed to address:",
      await serviceEscrow.getAddress()
    );

    return { owner, quote, dealContract, serviceEscrow };
  }

  describe("Quote Test", function () {
    it("5 DAI to SOLIDX", async function () {
      const { quote, dealContract, serviceEscrow } = await loadFixture(deploy);

      const USDC = "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d";
      const USDT = "0x55d398326f99059fF775485246999027B3197955";
      const WETH = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"; // WBNB in fact
      console.log(await dealContract.getUSDCtoSOLIDX());
      // expect(await ballot.chairperson()).to.equal(chairperson.address);
      // expect(await dealContract.owner()).to.equal(await serviceEscrow.owner());
    });
  });

  // describe("Deploy Test", function () {
  //   it("Should assign Chairperson Address", async function () {
  //     const { chairperson, ballot } = await loadFixture(deploy);

  //     expect(await ballot.chairperson()).to.equal(chairperson.address);
  //   });

  //   it("Should assign Proposal Names", async function () {
  //     const { proposalNames, ballot } = await loadFixture(deploy);
  //     expect((await ballot.proposals(0)).name).to.equal(proposalNames[0]);
  //   });
  // });

  // describe("Giving Right to Voter Test", function () {
  //   it("Should be reverted if not Chairperson", async function () {
  //     const { voter1, voter2, ballot } = await loadFixture(deploy);

  //     await expect(
  //       ballot.connect(voter1).giveRightToVoter(voter2.address)
  //     ).to.be.revertedWith("Only chairperson can give right to vote.");
  //   });

  //   it("Should be Weight increased before running giveRightToVoter", async function () {
  //     const { voter1, ballot } = await loadFixture(deploy);

  //     expect((await ballot.voters(voter1.address)).weight).to.equal(0);
  //     await ballot.giveRightToVoter(voter1.address);
  //     expect((await ballot.voters(voter1.address)).weight).to.equal(1);
  //   });

  //   it("Should be reverted if Voter Weight > 0", async function () {
  //     const { voter1, ballot } = await loadFixture(deploy);

  //     await ballot.giveRightToVoter(voter1.address);
  //     await expect(ballot.giveRightToVoter(voter1.address)).to.be.revertedWith(
  //       "The voter already got right."
  //     );
  //   });

  //   it("Should be reverted if Voter voted", async function () {
  //     const { voter1, ballot } = await loadFixture(deploy);

  //     await ballot.giveRightToVoter(voter1.address);
  //     await ballot.connect(voter1).vote(0);
  //     await expect(ballot.giveRightToVoter(voter1.address)).to.be.revertedWith(
  //       "The voter already voted."
  //     );
  //   });
  // });

  // describe("Voting Test", function () {
  //   it("Should be proposal votecount increased after voting", async function () {
  //     const { voter1, ballot } = await loadFixture(deploy);

  //     await ballot.giveRightToVoter(voter1.address);
  //     expect((await ballot.proposals(0)).voteCount).to.equal(0);
  //     await ballot.connect(voter1).vote(0);
  //     expect((await ballot.proposals(0)).voteCount).to.equal(1);
  //   });
  // });
});
