pragma solidity 0.6.7;

import "./../openzeppelin/contracts/access/Ownable.sol";
import "./../openzeppelin/contracts/math/SafeMath.sol";
import "./../openzeppelin/contracts/utils/Counters.sol";
import "./../seascape_nft/NftTypes.sol";
import "./../seascape_nft/NftFactory.sol";
import "./Crowns.sol";
import "./Leaderboard.sol";
import "./GameSession.sol";


contract NftRush is Ownable, GameSession, Crowns, Leaderboard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using NftTypes for NftTypes;

    NftFactory nftFactory;    
    
    uint256 private minDeposit;

    
    /// @notice Tracking player data within game session
    struct Balance {
	uint256 amount;
	uint256 mintedTime;
    }


    mapping(uint256 => mapping(address => Balance)) public balances;
    mapping(uint256 => mapping(address => uint)) public depositTime;


    event Spent(address indexed owner, uint256 sessionId,
		uint256 balanceAmount, uint256 prevMintedTime, uint256 amount);
    event Minted(address indexed owner, uint256 sessionId, uint256 nftId);

	
    constructor(address _crowns, address _factory, uint256 _minDeposit) public {
	nftFactory = NftFactory(_factory);

	setCrowns(_crowns);		

	minDeposit = _minDeposit;
    }

    
    //--------------------------------------------------
    // Only owner
    //--------------------------------------------------

    /// @notice Starts a staking session for a finit _period of
    /// time, starting from _startTime. The _totalReward of
    /// CWS tokens will be distributed in every second. It allows to claim a
    /// a _generation Seascape NFT.
    /// @param _interval duration between claims
    /// @param _period session duration
    /// @param _startTime session start time in unix timestamp
    /// @param _generation Seascape Nft generation that is given as a reward
    function startSession(uint256 _interval, uint256 _period, uint256 _startTime, uint256 _generation) external onlyOwner {
	if (lastSessionId > 0) {
	    require(isStartedFor(lastSessionId)==false,
		    "NFT Rush: Can't start when session is active");
	}

	uint256 _sessionId = _startSession(_interval, _period, _startTime, _generation);
	_setWinners(_sessionId, _startTime);
	
	emit SessionStarted(_sessionId, _startTime, _startTime + _period, _generation);
    }

    
    /// @notice Sets a NFT factory that will mint a token for stakers
    function setNftFactory(address _address) external onlyOwner {
	nftFactory = NftFactory(_address);
    }


    function setMinDeposit(uint256 _deposit) external onlyOwner {
	minDeposit = _deposit;
    }

    //--------------------------------------------------
    // Only game user
    //--------------------------------------------------

    /// @notice Spend _amount of LP token
    /// of type _token into Staking contract.
    function spend(uint256 _sessionId, uint256 _amount) external {
	require(_amount >= minDeposit,     "NFT Rush: Amount to deposit should be greater than min deposit");
	require(_sessionId > 0,           "NFT Rush: Session is not started yet!");
	require(isStartedFor(_sessionId), "NFT Rush: Session is finished");

	require(crowns.balanceOf(msg.sender) >= _amount,
		"NFT Rush: Not enough CWS to deposit");
	require(crowns.spendFrom(msg.sender, _amount) == true,
		"NFT Rush: Failed to transfer CWS into contract");

	Balance storage _balance  = balances[_sessionId][msg.sender];

	_balance.amount = _balance.amount.add(_amount);
	
	depositTime[_sessionId][msg.sender]    = block.timestamp;
       
        emit Spent(msg.sender, _sessionId, _balance.amount, _balance.mintedTime, _amount);
    }


    /// @dev mints an nft
    function mint(uint256 _sessionId, uint8 _v, bytes32 _r, bytes32 _s, uint8 _quality) public {
	Session storage _session = sessions[_sessionId];
	Balance storage _balance = balances[_sessionId][msg.sender];

	require(_balance.amount > 0, "NFT Rush: No deposit was found");

	/// Validation of quality
	// message is generated as owner + amount + last time stamp + quality
	bytes memory _prefix = "\x19Ethereum Signed Message:\n32";
	bytes32 _messageNoPrefix = keccak256(abi.encodePacked(msg.sender, _balance.amount, _balance.mintedTime, _quality));

	bytes32 _message = keccak256(abi.encodePacked(_prefix, _messageNoPrefix));

	address _recover = ecrecover(_message, _v, _r, _s);

	require(_recover == owner(),
		"NFT Rush: Quality verification failed");

	require(_balance.mintedTime == 0 || (_balance.mintedTime + _session.interval < block.timestamp),
		"NFT Rush: not enough interval since last minted time");
	
        uint256 _tokenId = nftFactory.mintQuality(msg.sender, _session.generation, _quality);
	require(_tokenId > 0, "NFT Rush: failed to mint a token");
	

	_balance.mintedTime = block.timestamp;
	_balance.amount = 0;

	emit Minted(msg.sender, _sessionId, _tokenId);
    }

    //--------------------------------------------------
    // Public methods
    //--------------------------------------------------


    //--------------------------------------------------
    // Interval methods
    //--------------------------------------------------    
}
