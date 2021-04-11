const { assert } = require("chai");

let LpMining = artifacts.require("LpMining");
let LpToken = artifacts.require("LpToken");
let Crowns = artifacts.require("CrownsToken");
let Nft = artifacts.require("SeascapeNft");
let Factory = artifacts.require("NftFactory");

contract("Game 1: Lp Mining", async accounts => {
    // Sample data to use for game
    let totalReward = web3.utils.toWei('1000', 'ether');    // CWS amount to share
    let period = 1000;                                     // seconds
    let startTime = null;                                  // defined in test unit, asynchrounues functions
                                                           // may invalidate the predefined time
    let generation = 0;
    let depositAmount = web3.utils.toWei('50', 'ether');

    // Game credentials used in multiple test units
    let sessionId = null;
    let lpMining = null;
    let lpToken = null;
    let crowns = null;
    let nft = null;
    let factory = null;

    //declare 2 users
    let user1 = accounts[1];
    let user2 = accounts[2];

    //--------------------------------------------------

    // Before using the game contract, we should start the game session.
    // Before starting game session we should transfer CWS token to contract balance.
    // CWS in contract balance is required for game session award.
    it("should transfer the CWS into contract", async () => {
	crowns = await Crowns.deployed();
	lpMining = await LpMining.deployed();

	await crowns.transfer(lpMining.address, totalReward, {from: accounts[0]});

	let balance = await crowns.balanceOf.call(lpMining.address);
	assert.equal(balance, totalReward, "Lp Mining contract balance should match to total reward");
    });


    //--------------------------------------------------

    // Before using the game contract, we should start the game session.
    it("should start a session that lasts "+period+" seconds", async () => {
	lpToken = await LpToken.deployed();
	startTime = Math.floor(Date.now()/1000) + 2;

        await lpMining.startSession(lpToken.address, totalReward, period, startTime, generation,
				      {from: accounts[0]})

	sessionId = await lpMining.lastSessionIds.call(lpToken.address);

	assert.equal(sessionId, 1, "Started session id expected to be 1");
    });

    //---------------------------------------------------

    // Testing as a player. However,
    // before playing, player should have some LP token.
    // Sending from LP minter to player
    it("should transfer some fake LP CWS-ETH token to player", async () => {
	let from = accounts[0];

	await lpToken.transfer(player1, web3.utils.toWei('15', 'ether'), {from: from});
  await lpToken.transfer(player2, web3.utils.toWei('10', 'ether'), {from: from});

	let balance = await lpToken.balanceOf.call(player1);
	assert.equal(balance, web3.utils.toWei('15', 'ether'), "Lp Token balance of player1 is not what expected");
  balance = await lpToken.balanceOf.call(player2);
  assert.equal(balance, web3.utils.toWei('10', 'ether'), "Lp Token balance of player2 is not what expected");

    });

    //--------------------------------------------------

    // Depositing LP token to Smartcontract.
    // However, before deposit, it should be approved to Smartcontract
    it("should approve to deposit some token", async() => {
  //player1
	await lpToken.approve(lpMining.address, web3.utils.toWei('15', 'ether'), {from: player1});

	let allowance = await lpToken.allowance.call(player1, lpMining.address);
	assert.equal(allowance, web3.utils.toWei('15', 'ether'), "Deposit amount of Lp Tokens were not allowed to be transferred");

  //player2
  await lpToken.approve(lpMining.address, web3.utils.toWei('10', 'ether'), {from: player2});

  allowance = await lpToken.allowance.call(player2, lpMining.address);
	assert.equal(allowance, web3.utils.toWei('10', 'ether'), "Deposit amount of Lp Tokens were not allowed to be transferred");
    });

    //--------------------------------------------------

    it("should deposit a staking token by a player", async() => {
        //player1
        await lpMining.deposit(sessionId, web3.utils.toWei('10', 'ether'), {from: player1});

        let session = await lpMining.sessions.call(sessionId);

        let balance = await lpMining.stakedBalanceOf.call(sessionId, player1);
        console.log(JSON.parse(JSON.stringify(session)));
        console.log(JSON.parse(JSON.stringify(balance)));
        console.log(`balance deosited to ${balance}`);

        assert.equal(balance, web3.utils.toWei('10', 'ether'), "Player1 Balance in Lp Mining expected to be 10");

        //player2
        await lpMining.deposit(sessionId, web3.utils.toWei('10', 'ether'), {from: player2});
        balance = await lpMining.stakedBalanceOf.call(sessionId, player2);
        assert.equal(balance, web3.utils.toWei('10', 'ether'), "Player2 Balance in Lp Mining expected to be 10");

        //player1 again
        await lpMining.deposit(sessionId, web3.utils.toWei('5', 'ether'), {from: player1});
        balance = await lpMining.stakedBalanceOf.call(sessionId, player1);
        assert.equal(balance, web3.utils.toWei('15', 'ether'), "Player1 Balance in Lp Mining expected to be 15");
    });

    //--------------------------------------------------

    // After deposit, wait for some time to produce staking result.
    it("should produce some Crowns for staked Lp token", async() => {
        let session = await lpMining.sessions.call(sessionId);
        let balance = await lpMining.balances.call(sessionId, player1);
        let time1 = parseInt(new Date()/1000);

        console.log(JSON.parse(JSON.stringify(session)));
        console.log(JSON.parse(JSON.stringify(balance)));
        console.log('Calculating all time sum of reward per token:');
        console.log(`  previously claimed per token: ${session.claimedPerToken}`);
        console.log(`  previous time: ${time1}`);
        console.log(`  previous update of interest: ${session.lastInterestUpdate}`);
        console.log(`  interest per token: ${session.interestPerToken}`)
		  let claimedPerToken = parseInt(session.claimedPerToken) +
			(time1 - (session.lastInterestUpdate) * session.interestPerToken);

    	let interest = (balance.amount * claimedPerToken - balance.claimedPerToken)/1e18;
        console.log(`Claimed per Token: ${claimedPerToken} and interest ${interest}`)



        let cwsBalance = await lpMining.claimable.call(sessionId, player);
        console.log(`Earnable balance of the user in 1 second: ${cwsBalance}`);

        let wait = 2 * 1000; // milliseconds
            await new Promise(resolve => setTimeout(resolve, wait));

        let stakedBalance = await lpMining.claimable.call(sessionId, player);
        console.log(`Earnable balance of the user: ${stakedBalance/1e18}`);

        assert.equal(stakedBalance > cwsBalance, true, "Claimables after some time should be increased");
    });

    //--------------------------------------------------

    // Player should claim CWS
    it("should claim some Crowns", async() => {
	let player = accounts[1];
        let _lpMining = lpMining;

	try {
	    await _lpMining.claim(sessionId, {from: player});
	} catch(e) {
	    assert.fail('Nothing was generated to claim');
	    return;
	}
    });


    it("should withdraw all Lp Tokens", async() => {
        let player = accounts[1];
        await lpMining.withdraw(sessionId, depositAmount, {from: player});

        balance = await lpMining.stakedBalanceOf.call(sessionId, player);
        assert.equal(balance, 0, "Withdrawn Lp Token amount should be 0");
        });

        it("should fail to claim any token without LP token", async() => {
        let player = accounts[1];

        try {
            await lpMining.claim(sessionId, {from: player});
        } catch(e) {
            return assert.equal(e.reason, "Seascape Staking: No deposit was found");
        }

        assert.fail();
    });

});
