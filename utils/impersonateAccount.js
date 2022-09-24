import { ethers, network } from "hardhat";

const impersonateAccount = async (
  oldAddress,
  addressToImpersonate
) => {
  await network.provider.request({
    method: "hardhat_stopImpersonatingAccount",
    params: [oldAddress],
  });
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [addressToImpersonate],
  });
  const signer = await ethers.getSigner(
    addressToImpersonate
  );
  return signer;
};

export default impersonateAccount;
