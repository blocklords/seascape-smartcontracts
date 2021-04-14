var NftStaking = artifacts.require("./NftStaking.sol");
var Crowns = artifacts.require("./CrownsToken.sol");
var Factory = artifacts.require("./NftFactory.sol");
var Nft = artifacts.require("./SeascapeNft.sol");


function getRandomInt(max) {
  return Math.floor(Math.random() * Math.floor(max));
}


contract("Game 3: Nft Staking", async accounts => {

  //game data
  let period = 604800;
  let generation = 0;
  let totalReward = web3.utils.toWei("10", "ether");;
  let depositAmount = web3.utils.toWei("30", "ether");
  let bonusPercent = 10;

  // imported contracts
  let nftStaking = null;
  let crowns = null;
  let factory = null;
  let nft = null;

  //session & accounts data
  let lastSessionId = null;
  let player = null;
  let gameOwner = null;
  let signature = null;

  //token & slot data
  let index = 0;
  let nftId = 1;
  let sp = 100;
  let nftIdSlot = new Array(3);
  nftIdSlot.fill(0);

  //digital signatures
  async function signNft(nftId,sp) {

    let quality = getRandomInt(5) + 1;
    //v, r, s related stuff
    let bytes32 = web3.eth.abi.encodeParameters(["uint256", "uint256"],[nftId,sp]);
    let data = web3.utils.keccak256(bytes32);
    let hash = await web3.eth.sign(data, gameOwner);

    let r = hash.substr(0,66);
    let s = "0x" + hash.substr(66,64);
    let v = parseInt(hash.substr(130), 16);
    if (v < 27) {
        v += 27;
    }
    return [v, r, s];
  }

  async function signBonus(bonusPercent, nftIdSlot1, nftIdSlot2, nftIdSlot3) {

    let quality = getRandomInt(5) + 1;
    //v, r, s related stuff
    let bytes32 = web3.eth.abi.encodeParameters(["uint256", "uint256", "uint256", "uint256"],
      [bonusPercent, nftIdSlot1, nftIdSlot2, nftIdSlot3]);
    let data = web3.utils.keccak256(bytes32);
    let hash = await web3.eth.sign(data, gameOwner);

    let r = hash.substr(0,66);
    let s = "0x" + hash.substr(66,64);
    let v = parseInt(hash.substr(130), 16);
    if (v < 27) {
        v += 27;
    }
    return [v, r, s];
  }


  // before player starts, need a few things prepare.
  // one of things to allow nft to be minted by nft factory
  it("1. should link nft, nft factory and nft staking contracts", async () => {
    nftStaking = await NftStaking.deployed();
    factory = await Factory.deployed();
    nft = await Nft.deployed();
    gameOwner = accounts[0];

    await nft.setFactory(factory.address);
    await factory.addGenerator(nftStaking.address, {from: gameOwner});
  });

  //does not wait a week to see if session is closed
  it("2. should start a game session (event) for 1 week", async () => {
    player = accounts[0];

    let startTime = Math.floor(Date.now()/1000) + 5;

    crowns = await Crowns.deployed();
    await crowns.transfer(nftStaking.address, depositAmount, {from: player});

    await nftStaking.startSession(totalReward, period,  startTime, generation, {from: player});

    lastSessionId = await nftStaking.lastSessionId();
    assert.equal(lastSessionId, 1, "session id is expected to be 1");
  });

  it("3. starting a session while there is another session should fail", async () => {
    let startTime = Math.floor(Date.now()/1000) + 5;

    try{
      await nftStaking.startSession(totalReward, period,  startTime, generation, {from: player});
    }catch(e){
      assert.equal(e.reason, "Seascape Staking: Can't start when session is active", "startSession() should return an error.");
    }
  });

  it("3.1 should mint 1 nft token", async () => {
    //check nft user balance before
    let balanceBefore = await nft.balanceOf(player);

    //mint.js
    web3.eth.getAccounts(function(err,res) {accounts = res;});
    let granted = await factory.isGenerator(accounts[0]);
    if (!granted) {
        let res = await factory.addGenerator(accounts[0]);
    } else {
      //replace with throw errror
	     console.log(`Account ${accounts[0]} was already granted a permission`);
    }
    let owner = player;
    let generation = 0;
    let quality = 1;
    //mint 2 tokens of each quality

      await factory.mintQuality(owner, generation, quality);


    //check nft user balance after
    let balanceAfter = await nft.balanceOf(player);
    assert.equal(parseInt(balanceAfter), parseInt(balanceBefore)+1, "1 Nft token should be minted");
  });

  it("4. should deposit first nft to game contract (deposit method)", async () => {
    signature = await signNft(nftId,sp);

    //ERC721 approve and deposit token to contract
    await nft.approve(nftStaking.address, nftId);
    let approved = await nft.getApproved(nftId);
    console.log(approved);
    console.log(nftStaking.address);

    await nftStaking.deposit(lastSessionId, nftId, sp, signature[0], signature[1], signature[2], {from: player});

    // check nft contract balance after
    balanceAfter = await nftStaking.balances(lastSessionId, player, index);
    nftIdSlot[index] = parseInt(balanceAfter.nftId);
	  assert.equal(balanceAfter.nftId, nftId, "Deposited nftId should be" +nftId);
  });


});
