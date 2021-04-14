var NftStaking = artifacts.require("./NftStaking.sol");
var Crowns = artifacts.require("./CrownsToken.sol");
var Factory = artifacts.require("./NftFactory.sol");
var Nft = artifacts.require("./SeascapeNft.sol");


module.exports = function(deployer, network) {
	deployer.deploy(NftStaking, Crowns.address, Factory.address, Nft.address).then(function(){
	    console.log("Staking contract was deployed at address: "+NftStaking.address);
	    console.log("It is using Crowns (CWS) Token at address: "+Crowns.address);
	    console.log("To mint Nft it is using NFT Factory at address: "+Nft.address);

	});
};
