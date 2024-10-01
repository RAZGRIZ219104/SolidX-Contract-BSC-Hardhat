import { ethers } from "hardhat";

async function main() {
  // const quote = await ethers.deployContract("Quote");
  // await quote.waitForDeployment();
  // console.log("Quote deployed to address:", await quote.getAddress());

  // const dealContract = await ethers.deployContract(
  //   "DealContract",
  //   [
  //     "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d", // USDC
  //     "0xA76A6cC7fa9ab055b6101d443FD975520eb8cC75", // SOLIDX
  //   ],
  //   {
  //     libraries: {
  //       Quote: "0x1E0d201b83bEaa6b4230D25CC5429d2b5D395fe2",
  //     },
  //   }
  // );
  // await dealContract.waitForDeployment();
  // console.log(
  //   "DealContract deployed to address:",
  //   await dealContract.getAddress()
  // );

  const serviceEscrow = await ethers.deployContract(
    "ServiceEscrow",
    [
      "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d", // USDC
      "0xA76A6cC7fa9ab055b6101d443FD975520eb8cC75", // SOLIDX
    ],
    {
      libraries: {
        Quote: "0x1E0d201b83bEaa6b4230D25CC5429d2b5D395fe2",
      },
    }
  );
  await serviceEscrow.waitForDeployment();
  console.log(
    "ServiceEscrow deployed to address:",
    await serviceEscrow.getAddress()
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
