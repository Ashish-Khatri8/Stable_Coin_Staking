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
    
    /// @dev Struct to store a new stake with staked amount and the timestamp.
    struct Stake {
        uint256 amount;
        uint256 timestamp;
    }

    /// @dev An array of addresses of ERC20 tokens supported for staking.
    address[] public supportedTokens;

    /// @dev An array of addresses for Token/USD chainlink data feed contract.
    address[] public priceFeedContracts;

    /// @dev Mapping addresses to a mapping of uint8 to array of Stakes, 
    /// where uint8 is the index of supportedTokens array.
    mapping(address => mapping(uint8 => Stake[])) public userStakes;

    /// @dev Mapping addresses to a mapping of uint8 to uint256, 
    /// where uint8 is the index of supportedTokens array
    /// and uint256 represents the total number of tokens staked for the same.
    mapping(address => mapping(uint8 => uint256)) public totalTokensStaked;

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
     * @notice Returns all stake objects of the specified token for an user.
     * @dev Returns an array of Stake structs for the given address and _tokenAddressIndex.
     * @param _addr Address of user whose stakes to return.
     * @param _tokenAddressIndex Index of token address in supportedTokens array.
     * @return An array of Stake structs for the given address.
     */
    function getStakes(address _addr, uint8 _tokenAddressIndex) external view returns(Stake[] memory) {
        return userStakes[_addr][_tokenAddressIndex];
    }


    /**
     * @notice Function to stake tokens.
     * @dev Stakes the specified amount of tokens.
     * @param _tokenAddressIndex Index of token address in supportedTokens array.
     * @param _amount Amount of tokens to stake.
     */
    function stakeTokens(uint8 _tokenAddressIndex, uint256 _amount) external preStakingValidation(_tokenAddressIndex, _amount) {
        // Transfer the tokens from user to itself.
        IERC20Upgradeable(supportedTokens[_tokenAddressIndex]).safeTransferFrom(msg.sender, address(this), _amount);

        // Create a new struct for Stake.
        Stake memory stake = Stake(_amount, block.timestamp);

        // Push the new Stake struct object to the user's mapping array => userStakes[msg.sender][_tokenAddressIndex].
        userStakes[msg.sender][_tokenAddressIndex].push(stake);

        // Increment the total amount of tokens staked for user in the mapping => totalTokensStaked.
        totalTokensStaked[msg.sender][_tokenAddressIndex] += _amount;

        // Emit the Tokens_Staked event.
        emit Tokens_Staked(msg.sender, supportedTokens[_tokenAddressIndex], _amount, block.timestamp);
        
    }


    /**
     * @notice Function to unstake tokens.
     * @dev Unstakes the specified amount of tokens
     * @param _tokenAddressIndex Index of token address in supportedTokens array.
     * @param _totalUnstakeAmount Total amount of tokens to unstake.
     */
    function unstakeTokens(uint8 _tokenAddressIndex, uint256 _totalUnstakeAmount) external nonReentrant {
        // Check whether user is not trying to unstake more tokens than they have staked.
        require(
            totalTokensStaked[msg.sender][_tokenAddressIndex] >= _totalUnstakeAmount,
            "Staking_Multi_V1: Unstake amount exceeds staked amount."
        );

        // Variable to keep track of total reward tokens to send to user depending upon the Stakes timestamp.
        uint256 totalRewardTokens;

        // Variable to keep track of how many tokens have been unstaked => removed from array.
        uint256 amountUnstaked;

        // Bool to check whether a Stake's amount has reached 0, and it needs to be deleted.
        bool _deleteStakeObject;

        // Loop over the user's array of Stakes until specified amount of tokens are unstaked.
        for(uint i; i < userStakes[msg.sender][_tokenAddressIndex].length; i++) {
            
            // If amountUnstaked < _totalUnstakeAmount => more tokens need to be unstaked.
            if (amountUnstaked < _totalUnstakeAmount) {

                /*
                If current Stake's amount is greater than the number of tokens left to be unstaked,
                then (_totalUnstakeAmount - amountUnstaked) is the amount of tokens that will be deducted
                from current Stake and for which the reward tokens will be calculated.
                */
                if (userStakes[msg.sender][_tokenAddressIndex][i].amount >= (_totalUnstakeAmount - amountUnstaked)) {
                    // Deduct the unstaked token amount from current Stake's amount.
                    userStakes[msg.sender][_tokenAddressIndex][i].amount -= (_totalUnstakeAmount - amountUnstaked);

                    // Calculate reward tokens for the same and increment the totalRewardTokens.
                    totalRewardTokens += _calculateRewardTokens(_totalUnstakeAmount - amountUnstaked, i, _tokenAddressIndex);

                    // Increment the amountUnstaked variable by the number of tokens that are unstaked from current Stake object.
                    amountUnstaked += (_totalUnstakeAmount - amountUnstaked);
                
                /*
                If current Stake's amount is less than the number of tokens left to be unstaked,
                then all tokens of current Stake object will be unstaked
                and reward tokens will be calculated for the same.
                */
                } else {
                    // Increment the amountUnstaked variable by the number of tokens that are unstaked from current Stake object.
                    amountUnstaked += userStakes[msg.sender][_tokenAddressIndex][i].amount;

                    // Calculate reward tokens and increment the totalRewardTokens.
                    totalRewardTokens += _calculateRewardTokens(userStakes[msg.sender][_tokenAddressIndex][i].amount, i, _tokenAddressIndex);
                   
                    // Change current Stake object's amount to 0, as all of its tokens are unstaked.
                    userStakes[msg.sender][_tokenAddressIndex][i].amount = 0;

                    // Set the _deleteStakeObject boolean as true as now, there is a Stake object 
                    // with amount = 0, which will need to be removed from the array of Stakes.
                    _deleteStakeObject = true;
                }
            
            // If amountUnstaked == _totalUnstakeAmount => specified amount of tokens are unstaked.
            } else {
                break;
            }
        }

        // Decrease the totalTokensStaked mapping value for user by the number of tokens unstaked.
        totalTokensStaked[msg.sender][_tokenAddressIndex] -= _totalUnstakeAmount;

        // If the _deleteStakeObject boolean was set to true, then call the
        // _deleteStake() function which will remove the Stake object from array.
        if (_deleteStakeObject) {
            _deleteStake(_tokenAddressIndex);
        }

        // Emit the Tokens_UnStaked event.
        emit Tokens_UnStaked(msg.sender, supportedTokens[_tokenAddressIndex], _totalUnstakeAmount, block.timestamp);
        // Transfer the tokens to the user.
        IERC20Upgradeable(supportedTokens[_tokenAddressIndex]).transfer(msg.sender, _totalUnstakeAmount);

        // Emit the RewardTokensSent event.
        emit RewardTokensSent(msg.sender, totalRewardTokens);
        // Transfer the rewardTokens => BlazeToken to the user.
        rewardToken.transfer(msg.sender, totalRewardTokens);
    }


    /**
     * @dev Deletes the first element of the array, by swapping elements with adjacent elements and then pops the last one.
     * @param _tokenAddressIndex Index of token address in supportedTokens array.
     */
    function _deleteStake(uint8 _tokenAddressIndex) internal {
        // Swap array elements with the adjacent element.
        for(uint i; i < userStakes[msg.sender][_tokenAddressIndex].length-1; i++) {
            userStakes[msg.sender][_tokenAddressIndex][i] = userStakes[msg.sender][_tokenAddressIndex][i+1];
        }

        // Pop the last element.
        userStakes[msg.sender][_tokenAddressIndex].pop();

        // Now check whether the amount of new Stake object at position 0 in array is greater than 0 or not.
        // If it is zero, then recursively call this function => _deleteStake()
        if (userStakes[msg.sender][_tokenAddressIndex][0].amount == 0) {
            _deleteStake(_tokenAddressIndex);
        }
    }


    /**
     * @dev Calculates the reward tokens for an amount of tokens unstaked at a particular time,
     *  depending upon rate and perks.
     * @param _unstakeAmount Amount of unstaked tokens for which to calculate the amount of reward tokens.
     * @param _arrayIndex Index of Stake object in the array.
     * @param _tokenAddressIndex Index of token address in supportedTokens array.
     * @return Number of reward tokens.
     */
    function _calculateRewardTokens(
        uint256 _unstakeAmount,
        uint256 _arrayIndex,
        uint8 _tokenAddressIndex
    ) internal view returns(uint256) {
        /*
            Reward tokens calculated as:
                interestRate(perks included) * unstakeAmount * timeElapsedSinceTokensStaked / (100 * 365 days)
        */
        return (
                _getInterestRate(block.timestamp - userStakes[msg.sender][_tokenAddressIndex][_arrayIndex].timestamp, _tokenAddressIndex) * 
                _unstakeAmount *  
                (block.timestamp - userStakes[msg.sender][_tokenAddressIndex][_arrayIndex].timestamp)
            ) / (100 * 365 days);
    }


    /**
     * @dev Returns the interest rate for reward tokens depending upon the time elapsed since tokens were staked,
        including the perks based upon the dollar value of the number of tokens staked.
     * @param _timeElapsed Time that has elapsed since tokens in current Stake object were staked by the user.
     * @param _tokenAddressIndex Index of token address in supportedTokens array.
     * @return The interest rate for reward tokens including the perks for dollar value of staked tokens.
     */
    function _getInterestRate(uint256 _timeElapsed, uint8 _tokenAddressIndex) internal view returns(uint8) {
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
            uint(priceAggregator.getLatestPrice(priceFeedContracts[_tokenAddressIndex])) * totalTokensStaked[msg.sender][_tokenAddressIndex]
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
