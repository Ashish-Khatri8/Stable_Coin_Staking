// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "./PriceAggregator.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";


/// @title Staking_Multi_V1
/// @author Ashish Khatri
contract Staking_Multi_V1 is ReentrancyGuardUpgradeable {

    /// @dev Admin address.
    address private admin;
    
    using SafeERC20Upgradeable for IERC20Upgradeable;
    /// @dev ERC20 reward token => BlazeToken.
    IERC20Upgradeable public rewardToken;

    /// @dev Chainlink aggregator.
    PriceAggregator priceAggregator;   

    /// @dev An array of addresses of ERC20 tokens supported for staking.
    address[] public supportedTokens;

    /// @dev An array of addresses for Token/USD chainlink data feed contracts.
    address[] public priceFeedContracts;

    /// @dev Event to emit when tokens are staked.
    event Tokens_Staked(address indexed by, address indexed tokenAddress, uint256 indexed amount, uint256 time);
    
    /// @dev Event to emit when tokens are unstaked.
    event Tokens_UnStaked(address indexed by, address indexed tokenAddress, uint256 indexed amount, uint256 time);
    
    /// @dev Event to emit when Reward tokens are sent to an address on unstaking tokens.
    event RewardTokensSent(address indexed to, uint256 indexed amount);

    /**
     * @dev Checks whether address has enough tokens to stake and is trying to stake a supported token.
     * @param _tokenAddressIndex Index of token address in supportedTokens array user is trying to stake.
     * @param _amount Amount of tokens to stake.
     */
    modifier preStakingValidation(uint8 _tokenAddressIndex, uint256 _amount) {
        require(
            _tokenAddressIndex < supportedTokens.length,
            "Staking_Multi_V1: Token not supported for staking."
        );
        require(
            IERC20Upgradeable(supportedTokens[_tokenAddressIndex]).balanceOf(msg.sender) >= _amount,
            "Staking_Multi_V1: Insufficient token balance."
        );
        _;
    }

    /// @dev Struct to store an user's stake.
    struct Stake {
        uint256 stakedAmount;
        uint256 lastTimeTokensStaked;
        uint256 rewardAmount;
        uint256 lastTimeRewardsClaimed;
    }

    /// @dev Mapping addresses to a mapping of uint8 to Stake, 
    /// where uint8 is the index of supportedTokens array.
    mapping(address => mapping(uint8 => Stake)) public userStakes;


    /**
     * @dev Works like constructor as it runs only once and sets the required values.
     * @param _rewardTokenAddress Address of ERC20 token that will be used to pay staking reward.
     * @param _priceAggregatorAddress Address of PriceAggregator contract which is used to get token's current USD value.
     * @param _supportedTokens An array of addresses containing addresses of all tokens supported for staking.
     * @param _priceFeedContracts An array of addresses containing addresses of data feed contracts for all supported Token/USD pairs.
     */
    function initialize(
        address _adminAddress,
        address _rewardTokenAddress, 
        address _priceAggregatorAddress,
        address[] memory _supportedTokens,
        address[] memory _priceFeedContracts
    ) public initializer {
        require(_rewardTokenAddress != address(0), "Null address cannot be reward token.");
        admin = _adminAddress;
        rewardToken = IERC20Upgradeable(_rewardTokenAddress);
        priceAggregator = PriceAggregator(_priceAggregatorAddress);
        supportedTokens = _supportedTokens;
        priceFeedContracts = _priceFeedContracts;
    }


    /**
     * @dev Adds support for staking additional tokens.
     * @param _tokenAddress Address of new token to be supported for staking.
     * @param _priceFeedContractAddress Address of chainlink price feed contract for the token.
     */
    function addTokenSupport(address _tokenAddress, address _priceFeedContractAddress) public {
        require(msg.sender == admin, "Staking_Multi_V1: Not the admin!");
        supportedTokens.push(_tokenAddress);
        priceFeedContracts.push(_priceFeedContractAddress);
    }


    /**
     * @notice Function to stake tokens.
     * @dev Stakes the specified amount of tokens.
     * @param _tokenAddressIndex Index of token address in supportedTokens array.
     * @param _amount Amount of tokens to stake.
     */
    function stakeTokens(
        uint8 _tokenAddressIndex,
        uint256 _amount
    ) public preStakingValidation(_tokenAddressIndex, _amount) nonReentrant {
        // Get the user's stake's storage variable.
        Stake storage stake = userStakes[msg.sender][_tokenAddressIndex];

        // Increment the rewardAmount for the previously staked tokens.
        stake.rewardAmount += _calculateRewardTokens(_tokenAddressIndex, stake.stakedAmount, block.timestamp - stake.lastTimeTokensStaked);

        // Increment the total amount of tokens staked.
        stake.stakedAmount += _amount;

        // Set the lastTimeTokensStaked variable to current time.
        stake.lastTimeTokensStaked = block.timestamp;

        // If lastTimeRewardsClaimed is 0, => user had no stake earlier, thus set it to current time too.
        if (stake.lastTimeRewardsClaimed == 0) {
            stake.lastTimeRewardsClaimed = block.timestamp;
        }

        // Emit the Tokens_Staked event.
        emit Tokens_Staked(msg.sender, supportedTokens[_tokenAddressIndex], _amount, block.timestamp);

        // Transfer the tokens from user to itself.
        IERC20Upgradeable(supportedTokens[_tokenAddressIndex]).safeTransferFrom(msg.sender, address(this), _amount);
        
    }


    /**
     * @notice Function to unstake tokens.
     * @dev Unstakes the specified amount of tokens
     * @param _tokenAddressIndex Index of token address in supportedTokens array.
     * @param _unstakeAmount Amount of tokens to unstake.
     */
    function unstakeTokens(uint8 _tokenAddressIndex, uint256 _unstakeAmount) public nonReentrant {
        // Check whether user is not trying to unstake more tokens than they have staked.
        require(
            userStakes[msg.sender][_tokenAddressIndex].stakedAmount >= _unstakeAmount,
            "Staking_Multi_V1: Unstake amount exceeds staked amount."
        );

        // Get the user's stake's storage variable.
        Stake storage stake = userStakes[msg.sender][_tokenAddressIndex];

        // First, increment the rewardAmount in reference to the time when rewardTokens were last claimed.
        stake.rewardAmount += _calculateRewardTokens(_tokenAddressIndex, _unstakeAmount, block.timestamp - stake.lastTimeRewardsClaimed);
        
        // Then, get the amount of reward tokens to send to user depending upon the _unstakeAmount.
        uint256 rewardTokensToSend = (_unstakeAmount * stake.rewardAmount) / stake.stakedAmount;

        // Decrease the stakedAmount by the amount of unstaked tokens.
        stake.stakedAmount -= _unstakeAmount;

        // Decrease the rewardAmount by the number of tokens that are being sent to user as reward.
        stake.rewardAmount -= rewardTokensToSend;

        if (stake.stakedAmount == 0) {
            // Set the lastTimeRewardsClaimed and lastTimeTokensStaked, both to 0,
            // if user has unstaked all of their staked tokens.
            stake.lastTimeRewardsClaimed = 0;
            stake.lastTimeTokensStaked = 0;
        } else {
            // Else, Set the lastTimeRewardsClaimed to current time.
            stake.lastTimeRewardsClaimed = block.timestamp;
        }
            
        // Emit the Tokens_UnStaked event.
        emit Tokens_UnStaked(msg.sender, supportedTokens[_tokenAddressIndex], _unstakeAmount, block.timestamp);
        // Transfer the tokens to the user.
        IERC20Upgradeable(supportedTokens[_tokenAddressIndex]).transfer(msg.sender, _unstakeAmount);

        // Emit the RewardTokensSent event.
        emit RewardTokensSent(msg.sender, rewardTokensToSend);
        // Transfer the rewardTokens => BlazeToken to the user.
        rewardToken.transfer(msg.sender, rewardTokensToSend);
    }


    /**
     * @dev Calculates the reward tokens for an amount of tokens unstaked at a particular time,
     *  depending upon rate and perks.
     * @param _tokenAddressIndex Index of token address in supportedTokens array.
     * @param _amount Amount of tokens for which to calculate the reward tokens.
     * @param _time Time Duration for which reward tokens are being calculated.
     * @return Number of reward tokens.
     */
    function _calculateRewardTokens(
        uint8 _tokenAddressIndex,
        uint256 _amount,
        uint256 _time
    ) internal view returns(uint256) {
        /*
            Reward tokens calculated as:
                interestRate(perks included) * unstakeAmount * timeElapsedSinceTokensStaked / (100 * 365 days)
        */
        return (_getInterestRate(_tokenAddressIndex, _time) * _amount * _time) / (100 * 365 days);
    }


    /**
     * @dev Returns the interest rate for reward tokens depending upon the time elapsed since tokens were staked,
        including the perks based upon the dollar value of the number of tokens staked.
     * @param _timeElapsed Time that has elapsed since tokens in current Stake object were staked by the user.
     * @param _tokenAddressIndex Index of token address in supportedTokens array.
     * @return The interest rate for reward tokens including the perks for dollar value of staked tokens.
     */
    function _getInterestRate(uint8 _tokenAddressIndex, uint256 _timeElapsed) internal view returns(uint8) {
        if (_timeElapsed < 31 days)
            return 0;
        else if (_timeElapsed < 183 days)
            return 5 + _getPerks(_tokenAddressIndex);
        else if (_timeElapsed < 365 days)
            return 10 + _getPerks(_tokenAddressIndex);
        else
            return 15 + _getPerks(_tokenAddressIndex);
    }


    /**
     * @dev Uses the chainlink aggregator to get dollar value of staked tokens.
     * @dev Index of token address in supportedTokens array.
     * @return The additional perk/ interest rate based upon the dollar value of tokens staked.
     */
    function _getPerks(uint8 _tokenAddressIndex) internal view returns(uint8) {
        uint256 stakedAmountValueInDollars = (
            uint(priceAggregator.getLatestPrice(priceFeedContracts[_tokenAddressIndex])) * userStakes[msg.sender][_tokenAddressIndex].stakedAmount
        ) / 10**(priceAggregator.decimals(priceFeedContracts[_tokenAddressIndex]) + IERC20MetadataUpgradeable(supportedTokens[_tokenAddressIndex]).decimals());

        if (stakedAmountValueInDollars < 100)
            return 0;
        else if (stakedAmountValueInDollars < 500)
            return 2;
        else if (stakedAmountValueInDollars < 1000)
            return 5;
        else
            return 10;
    }

}
