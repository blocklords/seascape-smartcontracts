pragma solidity 0.6.7;

import "./../crowns/erc-20/contracts/CrownsToken/CrownsToken.sol";
import "./../openzeppelin/contracts/access/Ownable.sol";
import "./../openzeppelin/contracts/math/SafeMath.sol";
import "./../openzeppelin/contracts/utils/Counters.sol";


abstract contract NftLeaderboard is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

  /// @notice Tracking leaderboard rewards within game session.
  /// Nft Rush (this contract game) has a leaderboard
  struct Reward {
  uint256 sessionId;
  uint256 cws;
  }

  CrownsToken public crowns;


    /// @notice Game session. Smartcontract is active during the game session.
    /// Game session is active for a certain period of time only
    struct Session {
	uint256 interval;      // period between intervals
	uint256 period;        // duration of session
	uint256 startTime;     // unix timestamp when session starts
	uint256 generation;    // nft generation
	bool    spentWinnersSet;    // was all time winners set
	bool    mintedWinnersSet;
    }

    uint256 public lastSessionId;
    mapping(uint256 => Session) public sessions;


  uint256[10] public spentDailyAmounts;        // spent token leaderboard
  uint256[10] public spentAllTimeAmounts;
  uint256[10] public mintedDailyAmounts;       // minted nft amount leaderboard
  uint256[10] public mintedAllTimeAmounts;

    // struct: session id => timestamp
    mapping(uint256 => uint256) public spentDailyWinnersTime;                  // tracks the last daily winners set time.
                                                                          // be careful, if the daily winners setting doesn't set all 10 winners,
                                                                      // you wouldn't be able to set missed winners in a next round
  mapping(address => uint256) public spentDailyClaimables;            // tracks amount of claimable nft for each user
  mapping(address => Reward[]) public spentDailyRewards;        // stores a session id where user won an nft.

    // session id => addresses
    mapping(address => uint256) public spentAllTimeClaimables;          // tracks the amount of leaderboard winning in sessions for each user
    mapping(address => Reward[]) public spentAllTimeRewards;      // session id

    // struct: session id => timestamp
    mapping(uint256 => uint256) public mintedDailyWinnersTime;                  // tracks the last daily winners set time.
                                                                          // be careful, if the daily winners setting doesn't set all 10 winners,
                                                                          // you wouldn't be able to set missed winners in a next round
    mapping(address => uint256) public mintedDailyClaimables;            // tracks amount of claimable nft for each user
    mapping(address => Reward[]) public mintedDailyRewards;        // stores a session id where user won an nft.

    // session id => addresses
    mapping(address => uint256) public mintedAllTimeClaimables;          // tracks the amount of leaderboard winning in sessions for each user
    mapping(address => Reward[]) public mintedAllTimeRewards;      // session id


  event Rewarded(address indexed owner, uint256 sessionId, string rewardType, uint256 amount);


  function setAllRewards(uint256[10] memory _spentDaily, uint256[10] memory _spentAllTime, uint256[10] memory _mintedDaily, uint256[10] memory _mintedAllTime) public onlyOwner {
setDailySpents(_spentDaily);
setAllTimeSpents(_spentAllTime);
setDailyMinted(_mintedDaily);
setAllTimeMinted(_mintedAllTime);
  }

  function setAllSpents(uint256[10] memory _daily, uint256[10] memory _allTime) public onlyOwner {
setDailySpents(_daily);
setAllTimeSpents(_allTime);
  }

  function setAllMinted(uint256[10] memory _daily, uint256[10] memory _allTime) public onlyOwner {
setDailyMinted(_daily);
setAllTimeMinted(_allTime);
  }


  function setDailySpents(uint256[10] memory _rewards) public onlyOwner {
spentDailyAmounts = _rewards;
  }

  function setAllTimeSpents(uint256[10] memory _rewards) public onlyOwner {
spentAllTimeAmounts = _rewards;
  }

  function setDailyMinted(uint256[10] memory _rewards) public onlyOwner {
mintedDailyAmounts = _rewards;
  }

  function setAllTimeMinted(uint256[10] memory _rewards) public onlyOwner {
mintedAllTimeAmounts = _rewards;
  }

  function addDailySpentWinners(uint256 _sessionId, address[10] memory _winners, uint8 _amount) public onlyOwner {
require(isDailySpentWinnersAdded(_sessionId) == true, "NFT Rush: already set or too early");
require(_amount <= 10,                                 "NFT Rush: too many winners");

      if (_amount > 0) {
    uint256 _totalRewards = calculateTotalRewards(spentDailyAmounts, _amount);
          require(crowns.transferFrom(owner(), address(this), _totalRewards) == true, "NFT Rush: not enough CWS to give as a reward");

          for (uint i=0; i<_amount; i++) {
  Reward memory _reward = Reward(_sessionId, spentDailyAmounts[i]);
  spentDailyRewards[_winners[i]].push(_reward);

  // increase amount of daily rewards that msg.sender could claim
  spentDailyClaimables[_winners[i]] = spentDailyClaimables[_winners[i]].add(1);
          }
}

setDailySpentWinnersTime(_sessionId);
  }

  function addAllTimeSpentWinners(uint256 _sessionId, address[10] memory _winners, uint8 _amount) public onlyOwner {
require(isAllTimeSpentWinnersAdded(_sessionId) == false, "NFT Rush: all time winners set already");
require(_amount <= 10,                              "NFT Rush: too many winners");

if (_amount > 0) {
    uint256 _totalRewards = calculateTotalRewards(spentAllTimeAmounts, _amount);
          require(crowns.transferFrom(owner(), address(this), _totalRewards) == true, "NFT Rush: not enough CWS to give as a reward");

          for (uint i=0; i<_amount; i++) {
  Reward memory _reward = Reward(_sessionId, spentAllTimeAmounts[i]);
  spentAllTimeRewards[_winners[i]].push(_reward);

  // increase amount of daily rewards that msg.sender could claim
  spentAllTimeClaimables[_winners[i]] = spentAllTimeClaimables[_winners[i]].add(1);
          }
}

setAllTimeSpentWinnersTime(_sessionId);
  }

  function addDailyMintedWinners(uint256 _sessionId, address[10] memory _winners, uint8 _amount) public onlyOwner {
require(isDailyMintedWinnersAdded(_sessionId) == false, "NFT Rush: already set or too early");
require(_amount <= 10,                                  "NFT Rush: too many winners");

      if (_amount > 0) {
    uint256 _totalRewards = calculateTotalRewards(mintedDailyAmounts, _amount);
          require(crowns.transferFrom(owner(), address(this), _totalRewards) == true, "NFT Rush: not enough CWS to give as a reward");

          for (uint i=0; i<_amount; i++) {
  Reward memory _reward = Reward(_sessionId, mintedDailyAmounts[i]);
  mintedDailyRewards[_winners[i]].push(_reward);

  // increase amount of daily rewards that msg.sender could claim
  mintedDailyClaimables[_winners[i]] = mintedDailyClaimables[_winners[i]].add(1);
          }
}

setDailyMintedWinnersTime(_sessionId);
  }

  function addAllTimeMintedWinners(uint256 _sessionId, address[10] memory _winners, uint8 _amount) public onlyOwner {
require(isAllTimeMintedWinnersAdded(_sessionId) == false, "NFT Rush: all time winners set already");
require(_amount <= 10,                                    "NFT Rush: too many winners");

if (_amount > 0) {
    uint256 _totalRewards = calculateTotalRewards(mintedAllTimeAmounts, _amount);
          require(crowns.transferFrom(owner(), address(this), _totalRewards) == true, "NFT Rush: not enough CWS to give as a reward");

          for (uint i=0; i<_amount; i++) {
  Reward memory _reward = Reward(_sessionId, mintedAllTimeAmounts[i]);
  mintedAllTimeRewards[_winners[i]].push(_reward);

  // increase amount of daily rewards that msg.sender could claim
  mintedAllTimeClaimables[_winners[i]] = mintedAllTimeClaimables[_winners[i]].add(1);
          }
}

setAllTimeMintedWinnersTime(_sessionId);
  }

  //--------------------------------------------------
  // Only game user
  //--------------------------------------------------



    function claimDailySpent() public {
	require(spentDailyClaimables[_msgSender()] > 0, "NFT Rush: reward not found");

	uint256 _claimAmount = spentDailyClaimables[_msgSender()];
	Reward[] storage _reward = spentDailyRewards[_msgSender()];

	uint256 _sessionId = _reward[_claimAmount-1].sessionId;
	uint256 _amount = _reward[_claimAmount-1].cws;

	require(crowns.transfer(_msgSender(), _amount) == true, "NFT Rush: failed to reward CWS to winner");
	delete _reward[_claimAmount-1];
	spentDailyClaimables[_msgSender()] = _claimAmount.sub(1);

	emit Rewarded(msg.sender, _sessionId, "spent-daily", _amount);
    }

    function claimAllTimeSpent() public {
	require(spentAllTimeClaimables[_msgSender()] > 0, "NFT Rush: reward not found");

	uint256 _claimAmount = spentAllTimeClaimables[_msgSender()];
	Reward[] storage _reward = spentAllTimeRewards[_msgSender()];

	uint256 _sessionId = _reward[_claimAmount-1].sessionId;
	uint256 _amount = _reward[_claimAmount-1].cws;

	require(crowns.transfer(_msgSender(), _amount) == true, "NFT Rush: failed to reward CWS to winner");
	delete _reward[_claimAmount-1];
	spentAllTimeClaimables[_msgSender()] = _claimAmount.sub(1);

	emit Rewarded(msg.sender, _sessionId, "spent-alltime", _amount);
    }

    function claimDailyMinted() public {
	require(mintedDailyClaimables[_msgSender()] > 0, "NFT Rush: reward not found");

	uint256 _claimAmount = mintedDailyClaimables[_msgSender()];
	Reward[] storage _reward = mintedDailyRewards[_msgSender()];

	uint256 _sessionId = _reward[_claimAmount-1].sessionId;
	uint256 _amount = _reward[_claimAmount-1].cws;

	require(crowns.transfer(_msgSender(), _amount) == true, "NFT Rush: failed to reward CWS to winner");
	delete _reward[_claimAmount-1];
	mintedDailyClaimables[_msgSender()] = _claimAmount.sub(1);

	emit Rewarded(msg.sender, _sessionId, "minted-daily", _amount);
    }

    function claimAllTimeMinted() public {
	require(mintedAllTimeClaimables[_msgSender()] > 0, "NFT Rush: reward not found");

	uint256 _claimAmount = mintedAllTimeClaimables[_msgSender()];
	Reward[] storage _reward = mintedAllTimeRewards[_msgSender()];

	uint256 _sessionId = _reward[_claimAmount-1].sessionId;
	uint256 _amount = _reward[_claimAmount-1].cws;

	require(crowns.transfer(_msgSender(), _amount) == true, "NFT Rush: failed to reward CWS to winner");
	delete _reward[_claimAmount-1];
	mintedAllTimeClaimables[_msgSender()] = _claimAmount.sub(1);

	emit Rewarded(msg.sender, _sessionId, "minted-alltime", _amount);
    }


  //--------------------------------------------------
  // Public methods
  //--------------------------------------------------


  //--------------------------------------------------
  // Interval methods
  //--------------------------------------------------


    function isDailySpentWinnersAdded(uint256 _sessionId) internal view returns(bool) {
	return block.timestamp < spentDailyWinnersTime[_sessionId] + (1 days);
    }


    function setDailySpentWinnersTime(uint256 _sessionId) internal {
	spentDailyWinnersTime[_sessionId] = block.timestamp + (1 days);
    }

    function isAllTimeSpentWinnersAdded(uint256 _sessionId) internal view returns(bool) {
	Session storage _session = sessions[_sessionId];
	return isStartedFor(_sessionId) == false && _session.startTime > 0 && _session.spentWinnersSet == false;
    }


    function setAllTimeSpentWinnersTime(uint256 _sessionId) internal {
	sessions[_sessionId].spentWinnersSet = true;
    }

    function isDailyMintedWinnersAdded(uint256 _sessionId) internal view returns(bool) {
	return block.timestamp < mintedDailyWinnersTime[_sessionId] + (1 days);
    }


    function setDailyMintedWinnersTime(uint256 _sessionId) internal {
	mintedDailyWinnersTime[_sessionId] = block.timestamp + (1 days);
    }

    function isAllTimeMintedWinnersAdded(uint256 _sessionId) internal view returns(bool) {
	Session storage _session = sessions[_sessionId];
	return isStartedFor(_sessionId) == false && _session.startTime > 0 && _session.mintedWinnersSet == false;
    }


    function setAllTimeMintedWinnersTime(uint256 _sessionId) internal {
	sessions[_sessionId].mintedWinnersSet = true;
    }

    function calculateTotalRewards(uint256[10] memory _rewards, uint256 _amount) internal returns (uint256) {
	uint256 _totalReward = 0;
	for (uint i=0; i<_amount; i++) {
	    _totalReward = _totalReward.add(_rewards[i]);
	}

	return _totalReward;
    }

    function isStartedFor(uint256 _sessionId) internal view returns(bool) {
	if (now > sessions[_sessionId].startTime + sessions[_sessionId].period) {
	    return false;
	}

	return true;
    }


}
